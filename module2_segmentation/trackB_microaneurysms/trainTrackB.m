function net = trainTrackB(cfg, outputNetPath, targetPatchCount, maxEpochs)
%TRAINTRACKB Fine-tune Track B's imported SegFormer on IDRiD's microaneurysm ground truth.
%   net = trainTrackB(cfg) builds a training patch set from IDRiD's
%   segmentation set (positive-biased sliding-window patches around real
%   "1. Microaneurysms" ground truth + offline top-hat hard negatives -
%   NOT Refined IDRiD, whose Labels folder only has vessel masks), then
%   fine-tunes the pretrained SegFormer-B0 encoder
%   imported via buildTrackBSegformerNetwork.m (importNetworkFromPyTorch
%   on a torch.jit.trace export - see docs/segformer_onnx_issue.md for
%   why the original ONNX import path was dropped, and the comments in
%   +segformer_eager/*.m for the MATLAB dlnetwork dispatch bugs that had
%   to be worked around to make the import actually run).
%
%   net = trainTrackB(cfg, outputNetPath, targetPatchCount, maxEpochs)
%   overrides the default 6000-patch / 20-epoch schedule. Worth doing:
%   training runs at MiniBatchSize=1 (see options below for why), which
%   on a 6GB laptop GPU measures ~5.5s/iteration for this model, so the
%   full default schedule is a ~166-hour run - plan targetPatchCount and
%   maxEpochs around your actual time budget and hardware instead of
%   assuming the defaults are practical to run as-is.
%
%   Requires: GPU strongly recommended. Does not run inside the cloud
%   sandbox that generated this code - run on your own machine/cloud.
%
%   Patch sampling is deliberately biased toward positives: without a
%   classical pre-filter gating what the network sees (that role was
%   removed - see topHatHardNegativeMining.m's docstring), most random
%   crops from a retina photo are pure background, and an unbiased
%   sampler would let the network learn to just predict "nothing"
%   everywhere and still look accurate.
%
%   See also: buildTrackBSegformerNetwork, importSegformerPyTorch,
%   extractSlidingWindowPatches, topHatHardNegativeMining,
%   detectMicroaneurysmsV2.

    if nargin < 2 || isempty(outputNetPath)
        outputNetPath = fullfile('data', 'models', 'trackB_segformer_net.mat');
    end
    if nargin < 3 || isempty(targetPatchCount)
        targetPatchCount = 6000;
    end
    if nargin < 4 || isempty(maxEpochs)
        maxEpochs = 20;
    end

    patchSize = 512;

    fprintf('Building Track B training patch set (positive-biased, target %d patches)...\n', targetPatchCount);
    [patchImages, patchLabels] = buildTrackBPatchSet(cfg, patchSize, targetPatchCount);

    lgraph = buildTrackBSegformerNetwork([], patchSize);

    checkpointDir = fullfile('data', 'models', 'checkpoints_trackB');
    if ~isfolder(checkpointDir), mkdir(checkpointDir); end

    options = trainingOptions('adam', ...
        'InitialLearnRate', 1e-4, ... % fine-tuning a pretrained encoder, not training from scratch - lower LR to avoid wrecking the pretrained weights
        'LearnRateSchedule', 'piecewise', ...
        'LearnRateDropFactor', 0.5, ...
        'LearnRateDropPeriod', 6, ...
        'MaxEpochs', maxEpochs, ...
        'MiniBatchSize', 1, ... % the imported SegFormer's generated code hardcodes batch=1 in its H/W and batch/channel derivation workarounds (see +segformer_eager/*.m comments) - batch>1 fails with a "not a perfect square" reshape error. Fixing this for arbitrary batch sizes would mean re-deriving batch dynamically at ~20+ call sites; not worth it for a model this size where batch=1 trains fine, just slower/noisier gradients.
        'Shuffle', 'every-epoch', ...
        'ExecutionEnvironment', 'auto', ...
        'CheckpointPath', checkpointDir, ...
        'CheckpointFrequency', 1, ...
        'CheckpointFrequencyUnit', 'epoch', ...
        'Plots', 'none', ... % headless-safe (no figure window); rely on 'Verbose' console output for progress instead
        'Verbose', true);

    trainingData = combine(patchImages, patchLabels);
    net = trainNetwork(trainingData, lgraph, options);

    outDir = fileparts(outputNetPath);
    if ~isempty(outDir) && ~isfolder(outDir)
        mkdir(outDir);
    end
    save(outputNetPath, 'net', 'patchSize');
    fprintf('Saved fine-tuned Track B network to %s\n', outputNetPath);
end

function [patchImages, patchLabels] = buildTrackBPatchSet(cfg, patchSize, targetPatchCount)
%BUILDTRACKBPATCHSET Assemble a positive-biased + hard-negative patch datastore.

    positiveRatio = 0.5; % half the training patches deliberately contain a labeled MA

    % Refined IDRiD's Labels folder only has *_vessel.png (vessel masks,
    % used by Track A) - no microaneurysm ground truth. The real MA
    % masks live in the original (non-refined) IDRiD segmentation set,
    % one lesion type per subfolder; use that directly instead, at full
    % resolution (cropAroundPoint pulls a local patchSize window, so
    % there's no alignment concern from mixing image sources like there
    % would be with Refined IDRiD's separately-resized copies).
    imageDir = cfg.idridSegImagesTrain;
    maGroundtruthDir = fullfile(cfg.idridSegGroundtruthTrain, '1. Microaneurysms');

    imageFiles = dir(fullfile(imageDir, '*.jpg'));
    allImages = {};
    allLabels = {};

    nPositiveTarget = round(targetPatchCount * positiveRatio);
    nCollected = 0;

    for i = 1:numel(imageFiles)
        [~, baseName, ~] = fileparts(imageFiles(i).name);
        imgPath = fullfile(imageDir, imageFiles(i).name);
        lblPath = fullfile(maGroundtruthDir, [baseName '_MA.tif']);
        if ~isfile(lblPath)
            continue;
        end
        img = imread(imgPath);
        maMask = logical(imread(lblPath));

        cc = bwconncomp(maMask);
        stats = regionprops(cc, 'Centroid');
        for k = 1:numel(stats)
            if nCollected >= nPositiveTarget
                break;
            end
            [imgPatch, lblPatch] = cropAroundPoint(img, maMask, stats(k).Centroid, patchSize);
            if isempty(imgPatch), continue; end
            allImages{end+1} = imgPatch; %#ok<AGROW>
            allLabels{end+1} = lblPatch; %#ok<AGROW>
            nCollected = nCollected + 1;
        end
    end
    fprintf('  %d positive (MA-containing) patches collected.\n', nCollected);

    % Hard negatives via offline top-hat mining (see its own docstring
    % for why this is safe to use here without reintroducing a recall
    % ceiling - it never gates inference, only enriches training data).
    hardNeg = topHatHardNegativeMining(imageDir, maGroundtruthDir, ...
        patchSize, round(targetPatchCount * (1 - positiveRatio) * 0.5));
    for i = 1:numel(hardNeg)
        allImages{end+1} = hardNeg(i).image; %#ok<AGROW>
        allLabels{end+1} = false(patchSize, patchSize); %#ok<AGROW>
    end
    fprintf('  %d hard-negative patches added.\n', numel(hardNeg));

    % Plain random negatives to round out the set.
    nPlainNegatives = targetPatchCount - numel(allImages);
    for i = 1:max(nPlainNegatives, 0)
        randIdx = randi(numel(imageFiles));
        img = imread(fullfile(imageDir, imageFiles(randIdx).name));
        [H, W, ~] = size(img);
        if H < patchSize || W < patchSize, continue; end
        r = randi(H - patchSize + 1);
        c = randi(W - patchSize + 1);
        allImages{end+1} = img(r:r+patchSize-1, c:c+patchSize-1, :); %#ok<AGROW>
        allLabels{end+1} = false(patchSize, patchSize); %#ok<AGROW>
    end
    fprintf('  %d plain random-background patches added. Total: %d\n', ...
        max(nPlainNegatives, 0), numel(allImages));

    patchImages = arrayDatastore(cat(4, allImages{:}), 'IterationDimension', 4);
    labelStack = cat(4, allLabels{:});
    patchLabels = arrayDatastore(categorical(labelStack, [false true], {'Background', 'Microaneurysm'}), ...
        'IterationDimension', 4);
end

function [imgPatch, lblPatch] = cropAroundPoint(img, mask, centroid, patchSize)
    [H, W, ~] = size(img);
    cx = round(centroid(1)); cy = round(centroid(2));
    r = round(cy - patchSize/2); c = round(cx - patchSize/2);
    r = max(min(r, H - patchSize + 1), 1);
    c = max(min(c, W - patchSize + 1), 1);
    if H < patchSize || W < patchSize
        imgPatch = []; lblPatch = [];
        return
    end
    imgPatch = img(r:r+patchSize-1, c:c+patchSize-1, :);
    lblPatch = mask(r:r+patchSize-1, c:c+patchSize-1);
end
