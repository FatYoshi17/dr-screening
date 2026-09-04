function vesselMask = segmentVessels(rgbImage, mask)
%SEGMENTVESSELS Extract the retinal vasculature.
%   vesselMask = segmentVessels(rgbImage, mask)
%
%   Method: green channel (best vessel/background contrast) -> CLAHE ->
%   multiscale tubular-structure enhancement (fibermetric, Image
%   Processing Toolbox) -> adaptive threshold -> morphological cleanup.
%   Benchmark against DRIVE's manual masks before trusting accuracy
%   numbers from this function (see metrics.m).

    if nargin < 2
        mask = fovMask(rgbImage);
    end
    greenChan = im2double(rgbImage(:,:,2));
    greenChan(~mask) = mean(greenChan(mask));

    enhanced = adapthisteq(greenChan, 'ClipLimit', 0.008);
    inverted = imcomplement(enhanced);
    vesselness = fibermetric(inverted, [2 3 4 5 6], 'ObjectPolarity', 'bright');

    vesselMask = imbinarize(vesselness, 'adaptive', 'Sensitivity', 0.45);
    vesselMask = vesselMask & mask;

    vesselMask = bwareaopen(vesselMask, 30);
    vesselMask = imclose(vesselMask, strel('disk', 1));
end
