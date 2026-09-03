function [featureVector, featureNames] = normalizeQualityFeatures(features, normParams)
%NORMALIZEQUALITYFEATURES Apply fitted logistic normalization to raw features.
%   [featureVector, featureNames] = normalizeQualityFeatures(features, normParams)
%   takes the struct returned by extractQualityFeatures and the
%   normParams struct returned by fitFeatureNormalization, and returns a
%   1x5 row vector of scores in [0,1] (one per feature) ready to feed
%   into the ordinal logistic regression model, plus a cell array of the
%   feature names in the same column order.
%
%   See also: extractQualityFeatures, fitFeatureNormalization,
%   trainOrdinalQualityModel, assessImageQuality.

    logistic = @(x, p) 1 ./ (1 + exp(-p.k * (x - p.x0)));

    sharpnessScore = logistic(features.sharpness, normParams.sharpness);

    % Exposure: mean brightness uses the symmetric "distance from
    % target" transform fit in fitFeatureNormalization; clipped-pixel
    % fraction uses the plain logistic (higher fraction = worse).
    p = normParams.exposure_meanBrightness;
    exposureBrightnessScore = max(1 - abs(features.exposure.meanBrightness - p.target) / p.tolerance, 0);
    exposureClipScore = logistic(features.exposure.clippedFraction, normParams.exposure_clippedFraction);
    exposureScore = 0.6 * exposureBrightnessScore + 0.4 * exposureClipScore;

    contrastScore = logistic(features.contrast, normParams.contrast);

    fovCoverageScore    = logistic(features.fov.coverage, normParams.fov_coverage);
    fovCompactnessScore = logistic(features.fov.compactness, normParams.fov_compactness);
    fovScore = 0.7 * fovCoverageScore + 0.3 * fovCompactnessScore;

    noiseScore = logistic(features.noise, normParams.noise);

    featureVector = [sharpnessScore, exposureScore, contrastScore, fovScore, noiseScore];
    featureVector = min(max(featureVector, 0), 1);
    featureNames = {'sharpness', 'exposure', 'contrast', 'fov', 'noise'};
end
