function denImg = denoiseImage(rgbImage)
%DENOISEIMAGE Suppress sensor/low-light noise while keeping lesion edges.
%   denImg = denoiseImage(rgbImage) uses non-local means denoising
%   (imnlmfilt) per channel — preserves small structures like
%   microaneurysms far better than Gaussian/median blurring would.

    imgD = im2double(rgbImage);
    denImg = zeros(size(imgD));
    for c = 1:3
        chan = imgD(:,:,c);
        [~, estDoS] = imnlmfilt(chan);
        denImg(:,:,c) = imnlmfilt(chan, 'DegreeOfSmoothing', estDoS * 0.7);
    end
    denImg = min(max(denImg, 0), 1);
end
