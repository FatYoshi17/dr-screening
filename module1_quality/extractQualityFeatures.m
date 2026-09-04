function features = extractQualityFeatures(rgbImage, mask)
%EXTRACTQUALITYFEATURES Compute the 5 classical quality features (Module 1, "Version A").
%   features = extractQualityFeatures(rgbImage) returns a struct:
%     features.sharpness   - Laplacian variance inside the FOV (higher = sharper)
%     features.exposure    - struct(meanBrightness, clippedFraction)
%     features.contrast    - RMS contrast (std of intensities) inside the FOV
%     features.fov         - struct(coverage, compactness)
%     features.noise       - robust MAD-based noise estimate (lower = cleaner)
%
%   features = extractQualityFeatures(rgbImage, mask) reuses an
%   already-computed fovMask instead of recomputing it.
%
%   These 5 raw values feed normalizeQualityFeatures -> the trained
%   ordinal logistic regression model. See also: fovMask,
%   normalizeQualityFeatures, trainOrdinalQualityModel, assessImageQuality.

    rgbImage = im2uint8(rgbImage);
    if nargin < 2 || isempty(mask)
        mask = fovMask(rgbImage);
    end

    grayImg = im2double(rgb2gray(rgbImage));

    % ---- 1. Sharpness: Laplacian variance, FOV-restricted ----
    lapKernel = fspecial('laplacian', 0.2);
    lapResponse = imfilter(grayImg, lapKernel, 'replicate');
    features.sharpness = var(lapResponse(mask));

    % ---- 2. Exposure: mean brightness + clipped-pixel fraction ----
    greenChan = im2double(rgbImage(:,:,2)); % green channel: best vessel/lesion contrast
    pixelsInFov = greenChan(mask);
    meanBrightness = mean(pixelsInFov);
    clippedLow  = sum(pixelsInFov < 0.02) / numel(pixelsInFov);
    clippedHigh = sum(pixelsInFov > 0.98) / numel(pixelsInFov);
    features.exposure = struct('meanBrightness', meanBrightness, ...
                                'clippedFraction', clippedLow + clippedHigh);

    % ---- 3. Contrast: RMS contrast, FOV-restricted ----
    features.contrast = std(pixelsInFov);

    % ---- 4. FOV: coverage + compactness ----
    area = nnz(mask);
    coverage = area / numel(mask);
    perim = bwperim(mask);
    perimLen = nnz(perim);
    if perimLen > 0
        compactness = min((4 * pi * area) / (perimLen^2), 1); % 1.0 = perfect circle
    else
        compactness = 0;
    end
    features.fov = struct('coverage', coverage, 'compactness', compactness);

    % ---- 5. Noise: robust MAD-based estimate on the high-frequency residual ----
    denoised = medfilt2(grayImg, [3 3]);
    residual = grayImg - denoised;
    residualInFov = residual(mask);
    features.noise = mad(residualInFov, 1) * 1.4826; % 1.4826x MAD ~= robust std under Gaussian noise
end
