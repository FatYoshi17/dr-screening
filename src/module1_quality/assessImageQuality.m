function qc = assessImageQuality(rgbImage, modelPath)
%ASSESSIMAGEQUALITY Module 1: score a fundus image and classify Pass/Enhance/Reject.
%   qc = assessImageQuality(rgbImage) loads the trained ordinal
%   logistic regression model from data/models/module1_quality_model.mat
%   (train it first with trainOrdinalQualityModel) and returns:
%     qc.fovMask       - logical FOV mask
%     qc.features      - raw feature struct (extractQualityFeatures output)
%     qc.featureScores - 1x5 normalized [0,1] scores, same order as qc.featureNames
%     qc.featureNames  - {'sharpness','exposure','contrast','fov','noise'}
%     qc.qualityScore  - continuous ordinal-regression score (higher = better)
%     qc.decision      - categorical 'Reject' | 'Enhance' | 'Pass'
%     qc.classProbs    - [P(Reject) P(Enhance) P(Pass)]
%     qc.isGradable    - true unless decision == 'Reject'
%     qc.failReasons   - cell array of plain-language reasons, populated
%                        whenever decision ~= 'Pass' (empty for Pass)
%
%   qc = assessImageQuality(rgbImage, modelPath) loads a model from a
%   non-default path.
%
%   This replaces the earlier hand-tuned weighted-sum version with the
%   trained "Version A" ordinal regression design: 5 classical features,
%   each logistic-normalized to [0,1], combined by a ridge-regularized
%   ordinal logistic regression calibrated on EyeQ.
%
%   See also: extractQualityFeatures, normalizeQualityFeatures,
%   trainOrdinalQualityModel, enhanceImage, rejectUngradeable.

    if nargin < 2 || isempty(modelPath)
        modelPath = fullfile('data', 'models', 'module1_quality_model.mat');
    end
    if ~isfile(modelPath)
        persistent warned
        if isempty(warned)
            warning(['No trained Module 1 model at %s (needs EyeQ, not available locally) - ' ...
                     'falling back to assessImageQualityThreshold (fixed thresholds, not ML-calibrated). ' ...
                     'Run trainOrdinalQualityModel(eyeQImageDir, eyeQLabelsCsv) once EyeQ is in place ' ...
                     'to switch back to the trained model automatically.'], modelPath);
            warned = true;
        end
        qc = assessImageQualityThreshold(rgbImage);
        return
    end
    loaded = load(modelPath, 'model');
    model = loaded.model;

    rgbImage = im2uint8(rgbImage);
    mask = fovMask(rgbImage);

    features = extractQualityFeatures(rgbImage, mask);
    [featureScores, featureNames] = normalizeQualityFeatures(features, model.normParams);

    [predictedClass, classProbs] = predict(model.ordinalModel, featureScores);
    % Continuous score: probability-weighted position on the ordinal
    % scale (0 = certain Reject, 1 = certain Pass) - useful for logging
    % and for Module 4's report even though the categorical decision is
    % what actually drives Pass/Enhance/Reject.
    ordinalWeights = [0, 0.5, 1]; % Reject, Enhance, Pass
    qualityScore = classProbs * ordinalWeights';

    qc.fovMask = mask;
    qc.features = features;
    qc.featureScores = featureScores;
    qc.featureNames = featureNames;
    qc.qualityScore = qualityScore;
    qc.decision = predictedClass;
    qc.classProbs = classProbs;
    qc.isGradable = (predictedClass ~= 'Reject');
    qc.method = 'trained_ordinal';

    qc.failReasons = {};
    if predictedClass ~= 'Pass'
        lowIdx = find(featureScores < 0.5);
        reasonMap = containers.Map( ...
            {'sharpness', 'exposure', 'contrast', 'fov', 'noise'}, ...
            {'Image too blurred / out of focus - refocus and hold steady', ...
             'Poor exposure (too dark, overexposed, or too many clipped pixels) - adjust flash/illumination', ...
             'Low contrast - check lens cleanliness and illumination', ...
             'Retina fills too little of the frame, or FOV is irregular - recentre and get closer', ...
             'Excess noise - check for low-light sensor noise or camera shake'});
        for i = 1:numel(lowIdx)
            qc.failReasons{end+1} = reasonMap(featureNames{lowIdx(i)}); %#ok<AGROW>
        end
        if isempty(qc.failReasons)
            qc.failReasons{end+1} = sprintf( ...
                'Borderline overall quality (score %.2f) - no single feature failed outright', qualityScore);
        end
    end
end
