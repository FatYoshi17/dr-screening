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
        outputNetPath = fullfile(cfg.dataModels, 'trackB_segformer_net.mat');
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

    checkpointDir = fullfile(cfg.dataModels, 'checkpoints_trackB');
    if ~isfolder(checkpointDir), mkdir(checkpointDir); end

    options = trainingOptions('adam', ...
        'InitialLearnRate', 1e-3, ... % the imported SegFormer's decode head is randomly initialized (swapped from ADE20K's 150-class head to our 2-class one via ignore_mismatched_sizes) - only the encoder is pretrained. A 3-epoch run at 1e-4 (chosen as if fine-tuning an already-good head) never got the random head off the ground: per-pixel MA-class scores stayed flat around 0.08-0.12 everywhere, including on training patches, meaning zero learned discrimination. Raised to 1e-3 so the head can actually move; watch the loss/score behavior early rather than assuming this alone fixes it.
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
