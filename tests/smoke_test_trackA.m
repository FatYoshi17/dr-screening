%SMOKE_TEST_TRACKA Tiny real trainNetwork run (2 images, 2 epochs, small
% size) to verify the full forward+loss+backward+update loop works for
% Track A's custom layers, before committing to real multi-hour training.

cfg = config();
classNames = {'Background','VH','Retina','Fovea','Vessel','OD','EX','IRMA','HE','NV','CWS'};
labelIDs = {0, 4, [8; 255], 16, 24, 32, 63, 96, 127, 166, 191};

imds = imageDatastore(cfg.refinedIdridTrainImg);
imds = subset(imds, 1:2);
pxds = pixelLabelDatastore(cfg.refinedIdridTrainLbl, classNames, labelIDs);
pxds = subset(pxds, 1:2);

imageSize = [256 256 3]; % small for speed - real training uses [512 512 3]

augmenter = imageDataAugmenter( ...
    'RandXReflection', true, 'RandYReflection', true, ...
    'RandRotation', [-15 15], 'RandXScale', [0.9 1.1], 'RandYScale', [0.9 1.1]);
trainingData = pixelLabelImageDatastore(imds, pxds, 'OutputSize', imageSize(1:2), ...
    'DataAugmentation', augmenter);

lgraph = buildTrackANetwork(imageSize, classNames);

options = trainingOptions('adam', ...
    'InitialLearnRate', 1e-4, ...
    'MaxEpochs', 10, ... % stress-test the NaN fix over many random rotations, not just one
    'MiniBatchSize', 2, ...
    'Shuffle', 'every-epoch', ...
    'ExecutionEnvironment', 'auto', ...
    'Plots', 'none', ...
    'Verbose', true);

fprintf('Starting tiny smoke-test training run...\n');
net = trainNetwork(trainingData, lgraph, options);
fprintf('SMOKE TEST PASSED: trainNetwork completed without error.\n');

img = readimage(imds, 1);
img = imresize(img, imageSize(1:2));
[predLabels, scores] = semanticseg(img, net);
fprintf('semanticseg inference OK. predLabels size: %s\n', mat2str(size(predLabels)));
fprintf('scores size: %s\n', mat2str(size(scores)));
