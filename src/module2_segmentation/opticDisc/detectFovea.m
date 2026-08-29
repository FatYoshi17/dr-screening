function [foveaCenter, confidence] = detectFovea(rgbImage, discCenter, discRadius, mask)
%DETECTFOVEA Localize the fovea relative to the optic disc.
%   [foveaCenter, confidence] = detectFovea(rgbImage, discCenter, discRadius, mask)
%
%   Anatomical prior: the fovea sits roughly 2.5 optic-disc-diameters
%   temporal to the disc, at about the same vertical level, and appears
%   as the darkest, most homogeneous region in that vicinity. Laterality
%   (left/right eye) is not assumed — both temporal directions are
%   searched and the darker candidate wins.
%
%   Validate against config().idridFoveaCsv before trusting accuracy claims.

    if nargin < 4
        mask = fovMask(rgbImage);
    end
    imgD = im2double(rgbImage);
    greenChan = imgD(:,:,2);
    smoothed = imgaussfilt(greenChan, discRadius/4);

    discDiam = discRadius * 2;
    searchRadius = discDiam * 1.2;

    [rows, cols] = size(greenChan);
    [X, Y] = meshgrid(1:cols, 1:rows);

    bestScore = Inf;
    foveaCenter = discCenter;
    for direction = [-1, 1]
        candX = discCenter(1) + direction * 2.5 * discDiam;
        candY = discCenter(2);
        if candX < 1 || candX > cols
            continue;
        end
        searchMask = ((X - candX).^2 + (Y - candY).^2) <= searchRadius^2 & mask;
        if ~any(searchMask(:))
            continue;
        end
        regionVals = smoothed;
        regionVals(~searchMask) = NaN;
        [minVal, linIdx] = min(regionVals(:));
        if minVal < bestScore
            bestScore = minVal;
            [ry, rx] = ind2sub(size(regionVals), linIdx);
            foveaCenter = [rx, ry];
        end
    end

    fovMean = mean(greenChan(mask));
    confidence = max(0, min(1, (fovMean - bestScore) / (fovMean + eps)));
end
