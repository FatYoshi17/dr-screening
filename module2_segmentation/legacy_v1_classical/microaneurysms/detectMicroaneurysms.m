function [maMask, maStats] = detectMicroaneurysms(rgbImage, mask, vesselMask, discMask)
%DETECTMICROANEURYSMS Candidate microaneurysm (MA) detection.
%   [maMask, maStats] = detectMicroaneurysms(rgbImage, mask, vesselMask, discMask)
%
%   HONEST SCOPE NOTE (see PROJECT_BRIEF.md section 3, Module 2):
%   sub-pixel MA detection is a research-grade problem. This is a
%   classical candidate-detection pipeline (morphological top-hat +
%   shape/size filtering), NOT a clinically validated detector. Expect a
%   meaningful false-positive rate; treat maStats(i).Confidence as a
%   ranking signal, not a calibrated probability. See the RETFound /
%   foundation-model reading list for a more current alternative
%   approach if you outgrow this baseline. Validate against IDRiD's
%   pixel-level MA masks (metrics.m) before quoting any accuracy number.

    if nargin < 2 || isempty(mask), mask = fovMask(rgbImage); end
    greenChan = im2double(rgbImage(:,:,2));
    greenChan(~mask) = mean(greenChan(mask));

    inv = imcomplement(greenChan);
    med = medfilt2(inv, [3 3]);

    se = strel('disk', 8);
    tophat = imtophat(med, se);
    tophat = imadjust(tophat);

    candidateMask = imbinarize(tophat, 'adaptive', 'Sensitivity', 0.6);
    candidateMask = candidateMask & mask;

    if nargin >= 3 && ~isempty(vesselMask)
        candidateMask = candidateMask & ~imdilate(vesselMask, strel('disk', 2));
    end
    if nargin >= 4 && ~isempty(discMask)
        candidateMask = candidateMask & ~imdilate(discMask, strel('disk', 5));
    end

    cc = bwconncomp(candidateMask);
    stats = regionprops(cc, tophat, 'Area', 'Centroid', 'Circularity', 'MaxIntensity');

    keep = false(numel(stats), 1);
    for i = 1:numel(stats)
        keep(i) = stats(i).Area >= 2 && stats(i).Area <= 60 && stats(i).Circularity >= 0.5;
    end

    maMask = false(size(candidateMask));
    maStats = struct('Centroid', {}, 'Area', {}, 'Confidence', {});
    keptIdx = find(keep);
    for k = 1:numel(keptIdx)
        i = keptIdx(k);
        maMask(cc.PixelIdxList{i}) = true;
        maStats(k).Centroid = stats(i).Centroid;
        maStats(k).Area = stats(i).Area;
        maStats(k).Confidence = min(1, stats(i).Circularity * stats(i).MaxIntensity);
    end
end
