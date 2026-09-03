function hardNegativePatches = topHatHardNegativeMining(imageDir, labelDir, patchSize, maxPatches)
%TOPHATHARDNEGATIVEMINING Offline-only: find patches that fool a classical top-hat filter.
%   hardNegativePatches = topHatHardNegativeMining(imageDir, labelDir, patchSize, maxPatches)
%
%   IMPORTANT: this runs only at training-set-construction time, never
%   at inference. Track B's actual detector sees every pixel directly -
%   this function's job is narrower: use the classical top-hat
%   transform (a fixed, non-learned filter that highlights small
%   bright/dark blobs) to find image regions that LOOK like a
%   microaneurysm to that simple rule but are NOT real MAs per the
%   ground-truth label. Feeding those specific confusing patches into
%   training - oversampled, alongside the positive-patch oversampling in
%   trainTrackB.m - teaches the network to reject exactly the kind of
%   false alarm a classical filter falls for, without ever letting
%   top-hat gate what the network is allowed to see.
%
%   Returns a struct array: hardNegativePatches(i).image,
%   hardNegativePatches(i).row, hardNegativePatches(i).col,
%   hardNegativePatches(i).sourceFile.
%
%   See also: extractSlidingWindowPatches, trainTrackB.

    if nargin < 3, patchSize = 512; end
    if nargin < 4, maxPatches = 2000; end

    imageFiles = dir(fullfile(imageDir, '*.jpg'));
    hardNegativePatches = struct('image', {}, 'row', {}, 'col', {}, 'sourceFile', {});
    count = 0;

    se = strel('disk', 3); % structuring element sized for MA's typical few-pixel radius

    for i = 1:numel(imageFiles)
        if count >= maxPatches
            break;
        end
        imgPath = fullfile(imageDir, imageFiles(i).name);
        [~, baseName, ~] = fileparts(imageFiles(i).name);
        lblPath = fullfile(labelDir, [baseName '_vessel.png']); % Refined IDRiD naming convention

        if ~isfile(lblPath)
            continue;
        end

        img = imread(imgPath);
        gray = im2double(rgb2gray(img));
        label = imread(lblPath);
        trueMaMask = (label == 255); % MA class per Refined IDRiD's Table 2 scheme

        % Top-hat highlights small dark blobs (MAs are dark against the
        % retina) - use the complement so dark spots become bright
        % before top-hat, matching the classical convention.
        topHatResponse = imtophat(imcomplement(gray), se);
        topHatCandidates = imbinarize(topHatResponse, graythresh(topHatResponse));

        % False positives: top-hat says "candidate here", ground truth
        % says "not actually MA".
        falsePositiveMask = topHatCandidates & ~imdilate(trueMaMask, strel('disk', 2));

        cc = bwconncomp(falsePositiveMask);
        stats = regionprops(cc, 'Centroid');

        for k = 1:numel(stats)
            if count >= maxPatches
                break;
            end
            cx = round(stats(k).Centroid(1));
            cy = round(stats(k).Centroid(2));
            r = max(cy - floor(patchSize/2), 1);
            c = max(cx - floor(patchSize/2), 1);
            r = min(r, size(img,1) - patchSize + 1);
            c = min(c, size(img,2) - patchSize + 1);
            if r < 1 || c < 1
                continue; % image smaller than patchSize, skip
            end

            count = count + 1;
            hardNegativePatches(count).image = img(r:r+patchSize-1, c:c+patchSize-1, :); %#ok<AGROW>
            hardNegativePatches(count).row = r;
            hardNegativePatches(count).col = c;
            hardNegativePatches(count).sourceFile = imageFiles(i).name;
        end
    end

    fprintf('Mined %d hard-negative patches (top-hat false positives) for Track B training.\n', count);
end
