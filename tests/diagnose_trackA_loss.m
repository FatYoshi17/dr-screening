%DIAGNOSE_TRACKA_LOSS Reproduce iteration-1's exact forward+loss computation
% on real data to find why the loss came out Inf/NaN.

cfg = config();
classNames = {'Background','VH','Retina','Fovea','Vessel','OD','EX','IRMA','HE','NV','CWS'};
labelIDs = {0, 4, [8; 255], 16, 24, 32, 63, 96, 127, 166, 191};
imds = imageDatastore(cfg.refinedIdridTrainImg);
pxds = pixelLabelDatastore(cfg.refinedIdridTrainLbl, classNames, labelIDs);
augmenter = imageDataAugmenter( ...
    'RandXReflection', true, 'RandYReflection', true, ...
    'RandRotation', [-15 15], 'RandXScale', [0.9 1.1], 'RandYScale', [0.9 1.1]);
trainingData = pixelLabelImageDatastore(imds, pxds, 'OutputSize', [512 512], 'DataAugmentation', augmenter);

data = read(trainingData);
img1 = data{1,1}{1};
lbl1 = data{1,2}{1};

fprintf('any undefined: %d / %d\n', sum(isundefined(lbl1(:))), numel(lbl1));

% One-hot encode exactly like the loss layer expects (HxWxKxN)
K = numel(classNames);
T = zeros([size(lbl1), K, 1], 'single');
for k = 1:K
    T(:,:,k,1) = single(lbl1 == classNames{k});
end
fprintf('T channel-sum range (should be exactly 1 everywhere): min=%g max=%g\n', ...
    min(sum(T,3), [], 'all'), max(sum(T,3), [], 'all'));

lgraph = buildTrackANetwork([512 512 3], classNames);
lgraphNoOut = removeLayers(lgraph, 'trackA_output');
dln = dlnetwork(lgraphNoOut);

X = dlarray(single(img1), 'SSCB');
Y = predict(dln, X); % softmax output, before the loss layer
Yval = extractdata(Y);
fprintf('Y (softmax output) range: min=%g max=%g anyNaN=%d\n', min(Yval(:)), max(Yval(:)), any(isnan(Yval(:))));
fprintf('Y channel-sum range (should be ~1): min=%g max=%g\n', ...
    min(sum(Yval,3), [], 'all'), max(sum(Yval,3), [], 'all'));

% Reproduce diceFocalPixelClassificationLayer.forwardLoss manually
outputLayer = diceFocalPixelClassificationLayer(classNames, 2.0, 0.5, 'test');
Tdl = dlarray(T, 'SSCB');
loss = outputLayer.forwardLoss(Y, Tdl);
fprintf('Manually computed loss: %g\n', extractdata(loss));

% Break it down further
eps_ = 1e-5;
intersection = sum(sum(Y .* Tdl, 1), 2);
unionSum = sum(sum(Y, 1), 2) + sum(sum(Tdl, 1), 2);
diceCoeff = (2 * intersection + eps_) ./ (unionSum + eps_);
diceLoss = 1 - mean(diceCoeff(:));
fprintf('diceLoss: %g\n', extractdata(diceLoss));

Yclipped = max(min(Y, 1 - 1e-7), 1e-7);
pt = sum(Yclipped .* Tdl, 3);
fprintf('pt range: min=%g max=%g\n', min(extractdata(pt(:))), max(extractdata(pt(:))));
focalWeight = (1 - pt) .^ 2.0;
focalLossMap = -focalWeight .* log(pt);
fprintf('focalLossMap range: min=%g max=%g anyInf=%d anyNaN=%d\n', ...
    min(extractdata(focalLossMap(:))), max(extractdata(focalLossMap(:))), ...
    any(isinf(extractdata(focalLossMap(:)))), any(isnan(extractdata(focalLossMap(:)))));
