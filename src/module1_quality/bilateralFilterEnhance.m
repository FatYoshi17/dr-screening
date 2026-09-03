function denImg = bilateralFilterEnhance(rgbImage)
%BILATERALFILTERENHANCE Edge-preserving denoise via bilateral filtering.
%   denImg = bilateralFilterEnhance(rgbImage) applies MATLAB's imbilatfilt
%   per channel. Bilateral filtering smooths flat regions while
%   preserving edges (vessel walls, lesion boundaries) better than a
%   plain Gaussian/median blur would - this is the denoise stage named
%   in Module 1's "Version A" enhance path (CLAHE + bilateral filter +
%   illumination norm), replacing the non-local-means approach used in
%   an earlier draft of this pipeline.
%
%   See also: claheEnhance, illuminationNormalize, enhanceImage.

    imgD = im2double(rgbImage);
    denImg = zeros(size(imgD));
    for c = 1:3
        chan = imgD(:,:,c);
        degreeOfSmoothing = 0.01 * var(chan(:)) * numel(chan); % imbilatfilt default heuristic scale
        denImg(:,:,c) = imbilatfilt(chan, degreeOfSmoothing, 2);
    end
    denImg = min(max(denImg, 0), 1);
end
