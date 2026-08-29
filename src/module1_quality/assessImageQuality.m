function qc = assessImageQuality(rgbImage)
%ASSESSIMAGEQUALITY Evaluate a fundus image for gradability.
%   qc = assessImageQuality(rgbImage) returns a struct:
%     qc.fovMask, qc.fovCoverage, qc.sharpness, qc.illumMean,
%     qc.illumUniformity, qc.overallScore, qc.isGradable, qc.failReasons
%
%   Thresholds below are starting points tuned for typical desktop and
%   portable fundus camera output. Re-tune against a labeled batch of
%   your own "good" vs "bad" images before trusting them clinically.
%
%   See also: fovMask, enhanceImage, rejectUngradeable

    rgbImage = im2uint8(rgbImage);
    mask = fovMask(rgbImage);
    fovCoverage = nnz(mask) / numel(mask);

    grayImg = im2double(rgb2gray(rgbImage));

    lap = fspecial('laplacian', 0.2);
    lapResponse = imfilter(grayImg, lap, 'replicate');
    sharpness = var(lapResponse(mask));

    greenChan = im2double(rgbImage(:,:,2));
    illumMean = mean(greenChan(mask)) * 255;

    blockSize = max(floor(size(grayImg,1)/8), 16);
    blockMeans = blockproc(greenChan, [blockSize blockSize], @(b) mean(b.data(:)));
    illumUniformity = 1 - min(std(blockMeans(:)) / (mean(blockMeans(:)) + eps), 1);

    sharpNorm = min(sharpness / 0.01, 1);
    fovNorm   = min(fovCoverage / 0.60, 1);
    illumNorm = max(1 - abs(illumMean/255 - 0.45) / 0.45, 0);

    weights = [0.40 0.25 0.20 0.15];
    overallScore = weights * [sharpNorm; fovNorm; illumNorm; illumUniformity];

    failReasons = {};
    if sharpNorm < 0.25
        failReasons{end+1} = 'Image too blurred / out of focus';
    end
    if fovNorm < 0.5
        failReasons{end+1} = 'Retina fills too little of the frame (reposition camera)';
    end
    if illumMean < 40
        failReasons{end+1} = 'Image too dark (increase illumination / flash)';
    elseif illumMean > 220
        failReasons{end+1} = 'Image overexposed (reduce illumination / flash)';
    end
    if illumUniformity < 0.5
        failReasons{end+1} = 'Uneven illumination across the retina';
    end

    qc.fovMask = mask;
    qc.fovCoverage = fovCoverage;
    qc.sharpness = sharpness;
    qc.illumMean = illumMean;
    qc.illumUniformity = illumUniformity;
    qc.overallScore = overallScore;
    qc.isGradable = isempty(failReasons);
    qc.failReasons = failReasons;
end
