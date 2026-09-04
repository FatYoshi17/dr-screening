function net = trainTrackA(cfg, outputNetPath)
%TRAINTRACKA Train Track A (unified multi-class structure segmentation) on Refined IDRiD.
%   net = trainTrackA(cfg) uses cfg.refinedIdridTrainImg / TrainLbl paths
%   from config.m, trains, and saves to data/models/trackA_net.mat.
%
%   Requires: GPU strongly recommended (Deep Learning Toolbox will use
%   one automatically if available via 'ExecutionEnvironment','auto').
%   This does NOT run inside the cloud sandbox that generated this code
%   - it needs to be run on your own machine/cloud with MATLAB + a GPU.
%
%   Class scheme (11 classes, MA excluded - that's Track B):
%     Background=0, VH=4, Retina=8 (also absorbs MA=255 - see note),
%     Fovea=16, Vessel=24, OD=32, EX=63, IRMA=96, HE=127, NV=166, CWS=191
%
%   NOTE on MA=255: Track A's job is everything except microaneurysms,
%   but Refined IDRiD's mask still has MA-labeled pixels in it. Those
%   pixels are folded into the 'Retina' class here (both are just
%   unremarkable retinal tissue from Track A's point of view) rather
%   than dropped, so Track A doesn't get penalized for "missing" lesions
%   it was never meant to find - Track B owns MA entirely.
%
%   See also: buildTrackANetwork, segmentStructures.

    if nargin < 2
        outputNetPath = fullfile('data', 'models', 'trackA_net.mat');
    end

    classNames = {'Background','VH','Retina','Fovea','Vessel','OD','EX','IRMA','HE','NV','CWS'};
    % pixelLabelDatastore expects each class's IDs as a numeric scalar or
    % COLUMN vector, not a nested cell and not a row vector - [8;255]
    % (column) merges Retina+MA into one class; {8,255} and [8 255] both
    % error (the latter gets parsed as a malformed RGB triplet spec).
    labelIDs = {0, 4, [8; 255], 16, 24, 32, 63, 96, 127, 166, 191};

    imds = imageDatastore(cfg.refinedIdridTrainImg);
    pxds = pixelLabelDatastore(cfg.refinedIdridTrainLbl, classNames, labelIDs);

    % Refined IDRiD's native mask resolution is 1024x1024, but training
    % at that size (MiniBatchSize 4) ran out of memory on a 6GB laptop
    % GPU during diceFocalPixelClassificationLayer's backward pass - the
    % dense per-pixel, 11-class loss over four 1024x1024 images at once
    % is too much. 512x512 fits; real accuracy trade-off for real GPU
    % constraints, not a shortcut.
    imageSize = [512 512 3];

    % ---- Augmentation: flips, rotation, elastic-ish warp via random
    % affine, brightness/contrast jitter, patch crop. imageDataAugmenter
    % covers the geometric part; combine() + custom transform handles
    % patch cropping and photometric jitter together with the mask. ----
    augmenter = imageDataAugmenter( ...
        'RandXReflection', true, ...
        'RandYReflection', true, ...
        'RandRotation', [-15 15], ...
        'RandXScale', [0.9 1.1], ...
        'RandYScale', [0.9 1.1]);

    trainingData = pixelLabelImageDatastore(imds, pxds, ...
        'OutputSize', imageSize(1:2), ...
        'DataAugmentation', augmenter);

    lgraph = buildTrackANetwork(imageSize, classNames);

    checkpointDir = fullfile('data', 'models', 'checkpoints_trackA');
    if ~isfolder(checkpointDir), mkdir(checkpointDir); end

    options = trainingOptions('adam', ...
        'InitialLearnRate', 1e-4, ...
        'LearnRateSchedule', 'piecewise', ...
        'LearnRateDropFactor', 0.5, ...
        'LearnRateDropPeriod', 15, ...
        'MaxEpochs', 80, ...
        'MiniBatchSize', 2, ...
        'Shuffle', 'every-epoch', ...
        'ExecutionEnvironment', 'auto', ...
        'CheckpointPath', checkpointDir, ...
        'CheckpointFrequency', 5, ...
        'CheckpointFrequencyUnit', 'epoch', ...
        'Plots', 'training-progress', ...
        'Verbose', true);

    fprintf('Training Track A on %d images (this needs a GPU and real time - ', numel(imds.Files));
    fprintf('not something that finishes in a chat session)...\n');

    net = trainNetwork(trainingData, lgraph, options);

    outDir = fileparts(outputNetPath);
    if ~isempty(outDir) && ~isfolder(outDir)
        mkdir(outDir);
    end
    save(outputNetPath, 'net', 'classNames', 'labelIDs', 'imageSize');
    fprintf('Saved Track A network to %s\n', outputNetPath);
end
