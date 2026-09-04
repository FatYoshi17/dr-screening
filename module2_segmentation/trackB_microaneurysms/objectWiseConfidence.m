function candidates = objectWiseConfidence(probMap, minBlobArea)
%OBJECTWISECONFIDENCE Group a dense MA probability map into scored candidate blobs.
%   candidates = objectWiseConfidence(probMap, minBlobArea) takes the
%   per-pixel MA probability map (from Track B's dense predictor,
%   already stitched back to full image size - see
%   detectMicroaneurysmsV2) and returns a struct array, one entry per
%   candidate blob:
%     candidates(i).centroid    - [x y] in the full image
%     candidates(i).pixelIdxList - linear indices of the blob's pixels
%     candidates(i).area         - pixel count
%     candidates(i).meanProb     - mean per-pixel probability across the blob
%     candidates(i).maxProb      - peak per-pixel probability
%     candidates(i).confidence   - combined object-wise confidence score
%
%   This is what "object-wise confidence thresholding" means in this
%   pipeline: connected pixels get grouped first, then the whole blob is
%   scored and thresholded as one unit - much more robust to isolated
%   speckle-noise false positives than thresholding pixel-by-pixel.
%
%   minBlobArea filters out single/few-pixel noise before scoring
%   (default 2 pixels - MAs are small but rarely a literal single pixel).
%
%   See also: subpixelGaussianFit, detectMicroaneurysmsV2.

    if nargin < 2, minBlobArea = 2; end

    binaryMask = probMap > 0.5; % coarse gate before grouping; final decision is object-wise
    cc = bwconncomp(binaryMask, 8);
    stats = regionprops(cc, probMap, 'Centroid', 'Area', 'MeanIntensity', 'MaxIntensity', 'PixelIdxList');

    candidates = struct('centroid', {}, 'pixelIdxList', {}, 'area', {}, ...
                         'meanProb', {}, 'maxProb', {}, 'confidence', {});
    idx = 1;
    for i = 1:numel(stats)
        if stats(i).Area < minBlobArea
            continue;
        end
        % Combined confidence: mean probability (how consistently
        % confident the network is across the whole blob) weighted
        % together with peak probability (rewards a strong, unambiguous
        % centre even if the blob's edges are fuzzy).
        confidence = 0.6 * stats(i).MeanIntensity + 0.4 * stats(i).MaxIntensity;

        candidates(idx).centroid = stats(i).Centroid; %#ok<AGROW>
        candidates(idx).pixelIdxList = stats(i).PixelIdxList;
        candidates(idx).area = stats(i).Area;
        candidates(idx).meanProb = stats(i).MeanIntensity;
        candidates(idx).maxProb = stats(i).MaxIntensity;
        candidates(idx).confidence = confidence;
        idx = idx + 1;
    end
end
