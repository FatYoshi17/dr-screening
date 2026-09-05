function result = detectMicroaneurysmsV2(rgbImage, netPath)
%DETECTMICROANEURYSMSV2 Track B full inference pipeline: image -> confident MA candidates.
%   result = detectMicroaneurysmsV2(rgbImage, netPath)
%
%   Pipeline: sliding-window patches -> SegFormer dense prediction per
%   patch -> stitch back to full-image probability map (averaging
%   overlaps) -> object-wise confidence thresholding -> sub-pixel
%   Gaussian shape fit as a second, independent confidence signal ->
%   classify each candidate as confirmed / ambiguous / rejected.
%
%   Returns:
%     result.probMap         - full-image MA probability map
%     result.candidates       - struct array from objectWiseConfidence,
%                                each with an added .shapeConfidence,
%                                .combinedConfidence, and .status field
%                                (status is 'confirmed'|'ambiguous'|'rejected')
%     result.confirmedCount   - number of confirmed MAs
%     result.hasAmbiguous     - true if any candidate landed in the
%                                ambiguous band (this is what routes
%                                Module 3's grade-0/1 rule to skip and
%                                defer to the CNN - see grade01Rule.m)
%
%   Confidence bands (tune against a validation set before trusting
%   clinically): combinedConfidence >= 0.6 -> confirmed;
%   0.35 <= combinedConfidence < 0.6 -> ambiguous; < 0.35 -> rejected.
%
%   See also: extractSlidingWindowPatches, objectWiseConfidence,
%   subpixelGaussianFit, trainTrackB, grade01Rule.

    if nargin < 2 || isempty(netPath)
        netPath = fullfile('data', 'models', 'trackB_segformer_net.mat');
    end
    if ~isfile(netPath)
        error(['No trained Track B network found at %s.\n' ...
               'Run exportSegformerONNX.py -> importSegformerMATLAB.m -> trainTrackB.m ' ...
               'first - see docs/RUN_GUIDE.md.'], netPath);
    end
    loaded = load(netPath, 'net', 'patchSize');
    net = loaded.net;
    patchSize = loaded.patchSize;

    grayImage = im2double(rgb2gray(rgbImage));
    [H, W, ~] = size(rgbImage);

    patches = extractSlidingWindowPatches(rgbImage, patchSize, 0.75);

    probMapSum = zeros(H, W, 'single');
    probMapCount = zeros(H, W, 'single');

    fprintf('Running Track B dense prediction over %d sliding-window patches...\n', numel(patches));
    for i = 1:numel(patches)
        patchProb = predict(net, patches(i).image); % HxWx2, softmax output
        maProb = patchProb(:, :, 2); % 'Microaneurysm' class channel

        r1 = patches(i).row;
        c1 = patches(i).col;
        rEnd = min(r1 + patchSize - 1, H);
        cEnd = min(c1 + patchSize - 1, W);
        validRows = 1:(rEnd - r1 + 1);
        validCols = 1:(cEnd - c1 + 1);

        probMapSum(r1:rEnd, c1:cEnd) = probMapSum(r1:rEnd, c1:cEnd) + maProb(validRows, validCols);
        probMapCount(r1:rEnd, c1:cEnd) = probMapCount(r1:rEnd, c1:cEnd) + 1;
    end
    probMap = probMapSum ./ max(probMapCount, 1); % average overlapping tile predictions

    candidates = objectWiseConfidence(probMap, 2);

    % objectWiseConfidence's empty-case struct only defines its own 6
    % fields (centroid, pixelIdxList, area, meanProb, maxProb,
    % confidence) - shapeConfidence/combinedConfidence/status only get
    % attached to the struct's type by the loop below actually running
    % at least once. With zero candidates found, that never happens, so
    % downstream code touching candidates.status on a genuinely-empty
    % result errors with "Unrecognized field name" instead of just
    % seeing an empty array. Predefine them here so the fields always
    % exist regardless of candidate count.
    if isempty(candidates)
        candidates = struct('centroid', {}, 'pixelIdxList', {}, 'area', {}, ...
            'meanProb', {}, 'maxProb', {}, 'confidence', {}, ...
            'shapeConfidence', {}, 'combinedConfidence', {}, 'status', {});
    end

    confirmedCount = 0;
    hasAmbiguous = false;
    for i = 1:numel(candidates)
        [shapeConf, ~] = subpixelGaussianFit(grayImage, candidates(i).centroid, 8);
        candidates(i).shapeConfidence = shapeConf;
        % Combined confidence: the network's own object-wise score and
        % the independent Gaussian shape fit both have to contribute -
        % a candidate that only the network likes, or only fits the
        % shape prior, shouldn't sail through as confidently as one
        % where both signals agree.
        combined = 0.6 * candidates(i).confidence + 0.4 * shapeConf;
        candidates(i).combinedConfidence = combined;

        if combined >= 0.6
            candidates(i).status = 'confirmed';
            confirmedCount = confirmedCount + 1;
        elseif combined >= 0.35
            candidates(i).status = 'ambiguous';
            hasAmbiguous = true;
        else
            candidates(i).status = 'rejected';
        end
    end

    result.probMap = probMap;
    result.candidates = candidates;
    result.confirmedCount = confirmedCount;
    result.hasAmbiguous = hasAmbiguous;
end
