function [enhImg, qcBefore, qcAfter] = enhanceImage(rgbImage, modelPath)
%ENHANCEIMAGE Module 1 orchestrator: assess -> enhance if needed -> re-assess.
%   [enhImg, qcBefore, qcAfter] = enhanceImage(rgbImage)
%
%   Pipeline:
%     1. Assess raw image quality (assessImageQuality) -> Pass/Enhance/Reject.
%     2. Reject -> return the image unchanged; caller should call
%        rejectUngradeable and stop, not pass this image to Module 2.
%     3. Pass -> light touch-up only (CLAHE).
%     4. Enhance -> full chain: illumination normalization -> bilateral
%        filter denoise -> CLAHE.
%     5. Re-assess the enhanced image so qcAfter reflects what Module 2
%        will actually receive.
%
%   See also: assessImageQuality, illuminationNormalize,
%   bilateralFilterEnhance, claheEnhance, rejectUngradeable.

    if nargin < 2
        modelPath = fullfile('data', 'models', 'module1_quality_model.mat');
    end

    qcBefore = assessImageQuality(rgbImage, modelPath);

    if ~qcBefore.isGradable
        enhImg = im2double(rgbImage);
        qcAfter = qcBefore;
        return;
    end

    if qcBefore.decision == 'Pass'
        enhImg = claheEnhance(rgbImage);
    else % 'Enhance'
        normImg = illuminationNormalize(rgbImage, qcBefore.fovMask);
        denImg  = bilateralFilterEnhance(normImg);
        enhImg  = claheEnhance(denImg);
    end

    qcAfter = assessImageQuality(im2uint8(enhImg), modelPath);
end
