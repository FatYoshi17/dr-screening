function [hemMask, hemStats] = classifyHemorrhages(rgbImage, mask, vesselMask, discMask)
%CLASSIFYHEMORRHAGES Detect and shape-classify hemorrhages (blot/flame).
%   [hemMask, hemStats] = classifyHemorrhages(rgbImage, mask, vesselMask, discMask)
%
%   Larger, darker, less regular than MAs. Reuses the dark-blob candidate
%   approach with a larger structuring element and size range, then
%   classifies each candidate's shape:
%     'blot'  - compact, roughly circular (Circularity > 0.5)
%     'flame' - elongated, follows nerve fibre layer (Eccentricity > 0.8)

    if nargin < 2 || isempty(mask), mask = fovMask(rgbImage); end
    greenChan = im2double(rgbImage(:,:,2));
    greenChan(~mask) = mean(greenChan(mask));

    inv = imcomplement(greenChan);
    med = medfilt2(inv, [3 3]);

    se = strel('disk', 20);
    tophat = imtophat(med, se);
    tophat = imadjust(tophat);

    candidateMask = imbinarize(tophat, 'adaptive', 'Sensitivity', 0.55);
    candidateMask = candidateMask & mask;

    if nargin >= 3 && ~isempty(vesselMask)
        candidateMask = candidateMask & ~imdilate(vesselMask, strel('disk', 1));
    end
    if nargin >= 4 && ~isempty(discMask)
        candidateMask = candidateMask & ~imdilate(discMask, strel('disk', 5));
    end
    candidateMask = bwareaopen(candidateMask, 15);

    cc = bwconncomp(candidateMask);
    stats = regionprops(cc, 'Area', 'Centroid', 'Circularity', 'Eccentricity');

    hemMask = false(size(candidateMask));
    hemStats = struct('Centroid', {}, 'Area', {}, 'Type', {});
    n = 0;
    for i = 1:numel(stats)
        if stats(i).Area < 15 || stats(i).Area > 2000
            continue;
        end
        n = n + 1;
        hemMask(cc.PixelIdxList{i}) = true;
        hemStats(n).Centroid = stats(i).Centroid;
        hemStats(n).Area = stats(i).Area;
        if stats(i).Eccentricity > 0.8 && stats(i).Circularity < 0.5
            hemStats(n).Type = 'flame';
        else
            hemStats(n).Type = 'blot';
        end
    end
end
