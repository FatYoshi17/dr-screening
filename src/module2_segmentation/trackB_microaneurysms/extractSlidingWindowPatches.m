function patches = extractSlidingWindowPatches(rgbImage, patchSize, strideFraction)
%EXTRACTSLIDINGWINDOWPATCHES Cut a full-resolution image into overlapping tiles.
%   patches = extractSlidingWindowPatches(rgbImage, patchSize, strideFraction)
%   returns a struct array, one entry per tile:
%     patches(i).image  - patchSize x patchSize x 3 image tile
%     patches(i).row    - top-left row in the original image
%     patches(i).col    - top-left column in the original image
%
%   patchSize: e.g. 512 (must divide evenly for SegFormer's patch-merge
%   strides - use 256 or 512, not an arbitrary size).
%   strideFraction: overlap control, default 0.75 (25% overlap) so a
%   microaneurysm sitting on a tile boundary isn't cut in half in every
%   tile that sees it.
%
%   Never downsamples - this is the whole point of Track B's sliding-
%   window design: a lesion a few pixels wide has to survive at full
%   resolution, which a single whole-image resize would erase.
%
%   See also: objectWiseConfidence, detectMicroaneurysmsV2.

    if nargin < 2, patchSize = 512; end
    if nargin < 3, strideFraction = 0.75; end

    [H, W, ~] = size(rgbImage);
    stride = round(patchSize * strideFraction);

    rowStarts = 1:stride:max(H - patchSize + 1, 1);
    colStarts = 1:stride:max(W - patchSize + 1, 1);
    % Ensure the last row/col of tiles reaches the image edge even if it
    % doesn't land exactly on a stride boundary.
    if rowStarts(end) + patchSize - 1 < H
        rowStarts(end+1) = H - patchSize + 1;
    end
    if colStarts(end) + patchSize - 1 < W
        colStarts(end+1) = W - patchSize + 1;
    end
    rowStarts = max(rowStarts, 1);
    colStarts = max(colStarts, 1);

    patches = struct('image', {}, 'row', {}, 'col', {});
    idx = 1;
    for r = rowStarts
        for c = colStarts
            rEnd = min(r + patchSize - 1, H);
            cEnd = min(c + patchSize - 1, W);
            tile = rgbImage(r:rEnd, c:cEnd, :);
            if size(tile, 1) < patchSize || size(tile, 2) < patchSize
                % Pad edge tiles up to full patch size (reflect padding
                % keeps texture statistics sane at the image border).
                padRow = patchSize - size(tile, 1);
                padCol = patchSize - size(tile, 2);
                tile = padarray(tile, [padRow, padCol], 'symmetric', 'post');
            end
            patches(idx).image = tile; %#ok<AGROW>
            patches(idx).row = r;
            patches(idx).col = c;
            idx = idx + 1;
        end
    end
end
