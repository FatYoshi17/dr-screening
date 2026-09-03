function net = trainTrackB(cfg, importedNetPath, outputNetPath)
%TRAINTRACKB Fine-tune the imported SegFormer on Refined IDRiD's MA channel.
%   net = trainTrackB(cfg, importedNetPath) builds a training patch set
%   from Refined IDRiD (positive-biased sliding-window patches + offline
%   top-hat hard negatives), then fine-tunes the SegFormer network
%   imported by importSegformerMATLAB.m.
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
%   See also: importSegformerMATLAB, extractSlidingWindowPatches,
%   topHatHardNegativeMining, detectMicroaneurysmsV2.

    if nargin < 2 || isempty(importedNetPath)
        importedNetPath = fullfile('data', 'models', 'segformer_ma_imported.mat');
    end
    if nargin < 3
        outputNetPath = fullfile('data', 'models', 'trackB_segformer_net.mat');
    end

    patchSize = 512;

    fprintf('Building Track B training patch set (positive-biased)...\n');
    [patchImages, patchLabels] = buildTrackBPatchSet(cfg, patchSize);

    loaded = load(importedNetPath, 'net');
    lgraph = loaded.net;

    options = trainingOptions('adam', ...
        'InitialLearnRate', 5e-5, ... % lower LR - fine-tuning a pretrained transformer, not training from scratch
        'LearnRateSchedule', 'piecewise', ...
        'LearnRateDropFactor', 0.5, ...
        'LearnRateDropPeriod', 10, ...
        'MaxEpochs', 40, ...
        'MiniBatchSize', 4, ...
        'Shuffle', 'every-epoch', ...
        'ExecutionEnvironment', 'auto', ...
        'Plots', 'training-progress', ...
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

function [patchImages, patchLabels] = buildTrackBPatchSet(cfg, patchSize)
%BUILDTRACKBPATCHSET Assemble a positive-biased + hard-negative patch datastore.

    positiveRatio = 0.5; % half the training patches deliberately contain a labeled MA
    targetPatchCount = 6000;

    imageFiles = dir(fullfile(cfg.refinedIdridTrainImg, '*.jpg'));
    allImages = {};
    allLabels = {};

    nPositiveTarget = round(targetPatchCount * positiveRatio);
    nCollected = 0;

    for i = 1:numel(imageFiles)
        [~, baseName, ~] = fileparts(imageFiles(i).name);
        imgPath = fullfile(cfg.refinedIdridTrainImg, imageFiles(i).name);
        lblPath = fullfile(cfg.refinedIdridTrainLbl, [baseName '_vessel.png']);
        if ~isfile(lblPath)
            continue;
        end
        img = imread(imgPath);
        label = imread(lblPath);
        maMask = (label == 255);

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
    hardNeg = topHatHardNegativeMining(cfg.refinedIdridTrainImg, cfg.refinedIdridTrainLbl, ...
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
        img = imread(fullfile(cfg.refinedIdridTrainImg, imageFiles(randIdx).name));
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
