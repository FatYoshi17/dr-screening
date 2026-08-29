function [enhImg, qcBefore, qcAfter] = enhanceImage(rgbImage)
%ENHANCEIMAGE Module 1 orchestrator: assess -> enhance if borderline -> re-assess.
%   [enhImg, qcBefore, qcAfter] = enhanceImage(rgbImage)
%
%   Pipeline:
%     1. Assess raw image quality (assessImageQuality).
%     2. Not gradable at all -> return unchanged; caller should call
%        rejectUngradeable and stop, not pass this image downstream.
%     3. Already high quality (score >= 0.80) -> light touch-up only.
%     4. Borderline but gradable -> full chain: illumination
%        normalization + denoising + CLAHE.
%
%   See also: assessImageQuality, illuminationNormalize, denoiseImage,
%   claheEnhance, rejectUngradeable

    qcBefore = assessImageQuality(rgbImage);

    if ~qcBefore.isGradable
        enhImg = im2double(rgbImage);
        qcAfter = qcBefore;
        return;
    end

    if qcBefore.overallScore >= 0.80
        enhImg = claheEnhance(rgbImage);
    else
        normImg = illuminationNormalize(rgbImage, qcBefore.fovMask);
        denImg  = denoiseImage(normImg);
        enhImg  = claheEnhance(denImg);
    end

    qcAfter = assessImageQuality(im2uint8(enhImg));
end
