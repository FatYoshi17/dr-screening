function net = trainTrackBCbam(cfg, outputNetPath, targetPatchCount, maxEpochs)
%TRAINTRACKBCBAM Train Track B's native CBAM CNN on IDRiD's microaneurysm ground truth.
%   net = trainTrackBCbam(cfg) builds a training patch set from IDRiD's
%   segmentation set (see buildTrackBPatchSet.m - real "1. Microaneurysms"
%   ground truth, not Refined IDRiD's vessel masks), then trains
%   buildTrackBNetwork.m's CBAM-attention CNN from scratch.
%
%   Unlike trainTrackB.m (SegFormer), this network has no pretrained
%   weights to protect and no batch-size restriction inherited from a
%   PyTorch import workaround, so it trains at a normal batch size and
%   should run far faster per iteration - see buildTrackBNetwork.m's
%   architecture (4 shallow conv blocks, 32-64-64-32 channels, no
%   transformer attention) vs. SegFormer-B0's 8-block transformer
%   encoder.
%
%   net = trainTrackBCbam(cfg, outputNetPath, targetPatchCount, maxEpochs)
%   overrides the default 6000-patch / 20-epoch schedule.
%
%   See also: buildTrackBNetwork, buildTrackBPatchSet, trainTrackB.

    if nargin < 2 || isempty(outputNetPath)
        outputNetPath = fullfile(cfg.dataModels, 'trackB_cbam_net.mat');
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

    lgraph = buildTrackBNetwork(patchSize);

    checkpointDir = fullfile(cfg.dataModels, 'checkpoints_trackB_cbam');
    if ~isfolder(checkpointDir), mkdir(checkpointDir); end

    options = trainingOptions('adam', ...
        'InitialLearnRate', 1e-3, ... % training from scratch, no pretrained weights to protect
        'LearnRateSchedule', 'piecewise', ...
        'LearnRateDropFactor', 0.5, ...
        'LearnRateDropPeriod', 6, ...
        'MaxEpochs', maxEpochs, ...
        'MiniBatchSize', 4, ... % no import-workaround batch constraint here; verified OOM-safe on this 6GB laptop GPU
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
    fprintf('Saved trained Track B CBAM network to %s\n', outputNetPath);
end
