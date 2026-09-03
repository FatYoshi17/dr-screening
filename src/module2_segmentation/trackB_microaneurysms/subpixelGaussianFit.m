function [shapeConfidence, fitParams] = subpixelGaussianFit(grayImage, centroid, patchRadius)
%SUBPIXELGAUSSIANFIT Second, independent MA confidence signal: round-blob shape check.
%   [shapeConfidence, fitParams] = subpixelGaussianFit(grayImage, centroid, patchRadius)
%
%   A true microaneurysm is a tiny round outpouching, so its intensity
%   profile (dark centre fading smoothly to background) tends to match
%   an inverted 2D Gaussian bump closely. Noise, vessel crossings, and
%   other artifacts usually don't fit that smooth round profile well.
%   Fitting a Gaussian to the patch around each candidate and measuring
%   how well it actually fits gives a confidence signal that is
%   independent of the network's own learned probability - real MAs
%   should score high on both; blobs where the two signals disagree, or
%   both sit in a middle band, are exactly what Module 3's "ambiguous"
%   bucket is for (see gradeImage.m / grade01Rule.m).
%
%   grayImage: full grayscale (or single-channel) image.
%   centroid: [x y] from objectWiseConfidence.
%   patchRadius: half-width of the local patch to fit (default 8 px).
%
%   Returns:
%     shapeConfidence - in [0,1], 1 = perfect Gaussian match
%     fitParams       - struct(amplitude, sigma, x0, y0, background, r2)
%
%   Uses fminsearch (base MATLAB, no extra toolbox required) rather than
%   lsqcurvefit, so this doesn't add an Optimization Toolbox dependency
%   on top of everything else this pipeline already needs.
%
%   See also: objectWiseConfidence, detectMicroaneurysmsV2.

    if nargin < 3, patchRadius = 8; end

    grayImage = im2double(grayImage);
    [H, W] = size(grayImage);
    cx = round(centroid(1));
    cy = round(centroid(2));

    r1 = max(cy - patchRadius, 1); r2 = min(cy + patchRadius, H);
    c1 = max(cx - patchRadius, 1); c2 = min(cx + patchRadius, W);
    patch = grayImage(r1:r2, c1:c2);

    if numel(patch) < 9
        shapeConfidence = 0;
        fitParams = struct('amplitude', 0, 'sigma', 0, 'x0', 0, 'y0', 0, 'background', 0, 'r2', 0);
        return
    end

    [X, Y] = meshgrid(1:size(patch,2), 1:size(patch,1));
    background0 = prctile(patch(:), 75);
    amplitude0 = background0 - min(patch(:)); % MA is dark relative to background
    x0_0 = size(patch,2) / 2;
    y0_0 = size(patch,1) / 2;
    sigma0 = max(patchRadius / 3, 1);

    % Inverted 2D Gaussian: bright background, dark dip at the centre.
    gaussianModel = @(p) p(5) - p(1) * exp(-((X - p(3)).^2 + (Y - p(4)).^2) / (2 * p(2)^2));
    costFn = @(p) sum((gaussianModel(p) - patch).^2, 'all');

    p0 = [amplitude0, sigma0, x0_0, y0_0, background0];
    opts = optimset('Display', 'off', 'MaxIter', 200);
    pFit = fminsearch(costFn, p0, opts);

    fitted = gaussianModel(pFit);
    residual = patch - fitted;
    ssRes = sum(residual.^2, 'all');
    ssTot = sum((patch - mean(patch(:))).^2, 'all');
    r2 = 1 - ssRes / (ssTot + eps);
    r2 = max(min(r2, 1), 0);

    % Penalize implausible fits (sigma too large = not a tight blob;
    % negative amplitude = fit inverted the wrong way).
    sigmaPenalty = double(pFit(2) <= patchRadius * 1.5 && pFit(2) >= 0.5);
    amplitudePenalty = double(pFit(1) > 0);

    shapeConfidence = r2 * sigmaPenalty * amplitudePenalty;

    fitParams = struct('amplitude', pFit(1), 'sigma', pFit(2), ...
        'x0', pFit(3) + c1 - 1, 'y0', pFit(4) + r1 - 1, ...
        'background', pFit(5), 'r2', r2);
end
