function normParams = fitFeatureNormalization(rawFeatureTable)
%FITFEATURENORMALIZATION Fit a per-feature logistic 0-1 normalization curve.
%   normParams = fitFeatureNormalization(rawFeatureTable) takes a table
%   with one row per training image and columns:
%     sharpness, exposure_meanBrightness, exposure_clippedFraction,
%     contrast, fov_coverage, fov_compactness, noise
%   (i.e. the flattened output of extractQualityFeatures across your
%   EyeQ training set) and fits a logistic curve
%       score = 1 / (1 + exp(-k * (x - x0)))
%   per feature, so that "better" raw values map toward 1 and "worse"
%   raw values map toward 0. k's sign is chosen per feature so that
%   direction is correct (e.g. higher sharpness -> higher score, but
%   higher clippedFraction -> LOWER score).
%
%   Returns normParams, a struct with one sub-struct per feature holding
%   {x0, k}. Fitting is a simple robust median/MAD-based heuristic
%   rather than full maximum-likelihood logistic fitting, since the goal
%   here is a smooth monotonic 0-1 rescaling, not a classifier in its
%   own right — the actual classification power comes from the ordinal
%   regression stage downstream.
%
%   See also: normalizeQualityFeatures, trainOrdinalQualityModel.

    featureSpecs = {
        'sharpness',                 1;   % higher raw value -> higher score
        'exposure_meanBrightness',   1;   % closer-to-mid handled separately, see note below
        'exposure_clippedFraction', -1;   % higher raw value -> LOWER score
        'contrast',                  1;
        'fov_coverage',               1;
        'fov_compactness',            1;
        'noise',                     -1;
    };

    for i = 1:size(featureSpecs, 1)
        name = featureSpecs{i, 1};
        direction = featureSpecs{i, 2};
        x = rawFeatureTable.(name);
        x = x(isfinite(x));

        x0 = median(x);
        spread = mad(x, 1) * 1.4826;
        if spread < eps
            spread = std(x) + eps;
        end
        % k chosen so the logistic transitions over roughly +/-2 MAD
        k = direction * (4 / (4 * spread + eps));

        normParams.(name) = struct('x0', x0, 'k', k);
    end

    % exposure_meanBrightness is special: quality is best near a mid-grey
    % target, not monotonically increasing, so it gets a symmetric
    % "distance from target" transform instead of a plain logistic.
    mb = rawFeatureTable.exposure_meanBrightness;
    mb = mb(isfinite(mb));
    normParams.exposure_meanBrightness = struct( ...
        'target', median(mb), ...
        'tolerance', max(mad(mb, 1) * 1.4826 * 2, 0.05));
end
