function exudateMask = segmentExudates(rgbImage, mask, discMask)
%SEGMENTEXUDATES Detect exudates (bright, yellowish lipid deposits).
%   exudateMask = segmentExudates(rgbImage, mask, discMask)
%
%   Exudates are high-contrast bright lesions — easier than MAs. Method:
%   green channel CLAHE -> morphological closing (fills lesion interiors
%   vessels might interrupt) -> adaptive threshold on the "closed minus
%   original" residual (bright blobs standing above local background) ->
%   exclude the optic disc (also bright) -> remove tiny specks.

    if nargin < 2 || isempty(mask), mask = fovMask(rgbImage); end
    greenChan = im2double(rgbImage(:,:,2));
    enhanced = adapthisteq(greenChan, 'ClipLimit', 0.01);

    se = strel('disk', 10);
    closed = imclose(enhanced, se);
    residual = closed - enhanced;
    residual(~mask) = 0;

    exudateMask = imbinarize(residual, 'adaptive', 'Sensitivity', 0.5);
    exudateMask = exudateMask & mask;

    if nargin >= 3 && ~isempty(discMask)
        exudateMask = exudateMask & ~imdilate(discMask, strel('disk', 8));
    end

    exudateMask = bwareaopen(exudateMask, 15);
    exudateMask = imclose(exudateMask, strel('disk', 2));
    exudateMask = imfill(exudateMask, 'holes');
end
