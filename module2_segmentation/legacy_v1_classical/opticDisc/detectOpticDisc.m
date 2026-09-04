function [discCenter, discRadius, discMask] = detectOpticDisc(rgbImage, mask)
%DETECTOPTICDISC Localize the optic disc via brightness + compactness.
%   [discCenter, discRadius, discMask] = detectOpticDisc(rgbImage, mask)
%   Returns discCenter = [x y], discRadius in pixels, and a logical mask.
%
%   Method: the optic disc is the largest bright, compact, roughly-
%   circular structure in a fundus image. We suppress the thin vessel
%   network with morphological opening-by-reconstruction (removes
%   structures narrower than the disc but keeps the disc's bright core),
%   then take the brightest, largest connected region among what remains.
%
%   Validate against IDRiD's optic disc center CSVs (see config().idridOdCenterCsv)
%   before trusting centroid-distance accuracy claims.

    if nargin < 2
        mask = fovMask(rgbImage);
    end
    imgD = im2double(rgbImage);
    redChan = imgD(:,:,1); % strongest disc/background contrast, least vessel absorption
    redChan(~mask) = 0;

    se = strel('disk', 15);
    marker = imerode(redChan, se);
    opened = imreconstruct(marker, redChan);

    vals = opened(mask);
    thresh = prctile(vals, 98);
    candidateMask = opened >= thresh & mask;
    candidateMask = imopen(candidateMask, strel('disk', 3));
    candidateMask = imfill(candidateMask, 'holes');

    cc = bwconncomp(candidateMask);
    if cc.NumObjects == 0
        candidateMask = opened >= prctile(vals, 99.5) & mask;
        cc = bwconncomp(candidateMask);
    end

    stats = regionprops(cc, opened, 'Area', 'Centroid', 'EquivDiameter', 'MeanIntensity');
    scores = [stats.Area] .* [stats.MeanIntensity];
    [~, idx] = max(scores);

    discCenter = stats(idx).Centroid;
    discRadius = stats(idx).EquivDiameter / 2;
    discMask = false(size(candidateMask));
    discMask(cc.PixelIdxList{idx}) = true;
    discMask = bwconvhull(discMask);
end
