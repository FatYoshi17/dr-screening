function normImg = illuminationNormalize(rgbImage, mask)
%ILLUMINATIONNORMALIZE Correct uneven fundus illumination.
%   normImg = illuminationNormalize(rgbImage, mask) estimates slow
%   background illumination (large-kernel Gaussian blur) per channel and
%   divides it out (Foracchia et al.-style luminosity normalization).
%   mask is optional — pass fovMask(rgbImage) if you already have it.

    if nargin < 2
        mask = fovMask(rgbImage);
    end
    rgbD = im2double(rgbImage);
    sigma = round(size(rgbD,1) / 10);

    normImg = zeros(size(rgbD));
    for c = 1:3
        chan = rgbD(:,:,c);
        background = imgaussfilt(chan, sigma);
        background(background < 0.05) = 0.05;
        corrected = chan ./ background * mean(background(mask));
        normImg(:,:,c) = corrected;
    end
    normImg = min(max(normImg, 0), 1);
    normImg(repmat(~mask, 1, 1, 3)) = 0;
end
