function qc = assessImageQualityThreshold(rgbImage)
%ASSESSIMAGEQUALITYTHRESHOLD Fallback for Module 1 when no EyeQ-trained
%model exists yet.
%   qc = assessImageQualityThreshold(rgbImage) computes the same 5
%   classical features as extractQualityFeatures.m, maps each to a [0,1]
%   score against FIXED reference anchors (not fitted from data), and
%   combines them with a simple averaging rule instead of the trained
%   ridge-regularized ordinal logistic regression.
%
%   This exists because EyeQ (the dataset trainOrdinalQualityModel.m
%   needs) requires the ~80GB EyePACS/Kaggle image set, which isn't
%   available locally. The anchors below were set by sampling raw
%   feature values across Refined IDRiD's 54 real training images (a
%   curated clinical dataset, so it only tells us what "decent" looks
%   like, not the full Reject/Enhance/Pass spread) - NOT fitted quality
%   labels. Treat this as a documented stopgap, not a calibrated model.
%
%   Returns the same qc struct shape as assessImageQuality.m so every
%   downstream caller (enhanceImage, rejectUngradeable, Module 4's
%   report) works unchanged. qc.method = 'threshold_fallback' marks the
%   provenance so the UI/report can say so honestly instead of implying
%   a trained model made this call.
%
%   Replace this path entirely once EyeQ is available: run
%   fitFeatureNormalization + trainOrdinalQualityModel, and
%   assessImageQuality.m will pick up the trained model automatically.
%
%   See also: assessImageQuality, extractQualityFeatures,
%   trainOrdinalQualityModel.

    rgbImage = im2uint8(rgbImage);
    mask = fovMask(rgbImage);
    features = extractQualityFeatures(rgbImage, mask);

    sharpnessScore  = anchorScore(features.sharpness, 0.00005, 0.00030);
    contrastScore   = anchorScore(features.contrast, 0.02, 0.08);
    % Noise (MAD-based) has near-zero dynamic range on clean, well-lit
    % fundus photos - more than half the median-filter residual is
    % exactly zero, so MAD collapses to 0 for most decent images. This
    % makes the feature weak at discriminating within "decent" images;
    % a wide anchor band avoids letting that weakness dominate the
    % overall score until real (noisy) examples are available.
    noiseScore      = 1 - anchorScore(features.noise, 0.0, 0.02);
    brightnessScore = 1 - min(abs(features.exposure.meanBrightness - 0.32) / 0.18, 1);
    clippedScore    = 1 - anchorScore(features.exposure.clippedFraction, 0, 0.05);
    exposureScore   = mean([brightnessScore, clippedScore]);
    coverageScore   = anchorScore(features.fov.coverage, 0.35, 0.65);
    compactScore    = anchorScore(features.fov.compactness, 0.5, 0.9);
    fovScore        = mean([coverageScore, compactScore]);

    featureNames = {'sharpness', 'exposure', 'contrast', 'fov', 'noise'};
    featureScores = [sharpnessScore, exposureScore, contrastScore, fovScore, noiseScore];

    qualityScore = mean(featureScores);
    worstScore = min(featureScores);

    if qualityScore < 0.4 || worstScore < 0.2
        decision = categorical({'Reject'}, {'Reject', 'Enhance', 'Pass'});
        classProbs = [1 0 0];
    elseif qualityScore >= 0.7 && worstScore >= 0.4
        decision = categorical({'Pass'}, {'Reject', 'Enhance', 'Pass'});
        classProbs = [0 0 1];
    else
        decision = categorical({'Enhance'}, {'Reject', 'Enhance', 'Pass'});
        classProbs = [0 1 0];
    end

    qc.fovMask = mask;
    qc.features = features;
    qc.featureScores = featureScores;
    qc.featureNames = featureNames;
    qc.qualityScore = qualityScore;
    qc.decision = decision;
    qc.classProbs = classProbs;
    qc.isGradable = (decision ~= 'Reject');
    qc.method = 'threshold_fallback';

    qc.failReasons = {};
    if decision ~= 'Pass'
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

function score = anchorScore(value, badAnchor, goodAnchor)
%ANCHORSCORE Linearly map value into [0,1] between two fixed reference
%points, clamped at both ends. badAnchor maps to 0, goodAnchor to 1.
    score = (value - badAnchor) / (goodAnchor - badAnchor);
    score = min(max(score, 0), 1);
end
