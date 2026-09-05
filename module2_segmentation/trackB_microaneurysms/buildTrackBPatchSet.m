function [patchImages, patchLabels] = buildTrackBPatchSet(cfg, patchSize, targetPatchCount)
%BUILDTRACKBPATCHSET Assemble a positive-biased + hard-negative patch datastore.
%   Shared by trainTrackB.m (SegFormer) and trainTrackBCbam.m (native
%   CBAM CNN) so both train on the same real microaneurysm ground truth.

    positiveRatio = 0.5; % half the training patches deliberately contain a labeled MA

    % Refined IDRiD's Labels folder only has *_vessel.png (vessel masks,
    % used by Track A) - no microaneurysm ground truth. The real MA
    % masks live in the original (non-refined) IDRiD segmentation set,
    % one lesion type per subfolder; use that directly instead, at full
    % resolution (cropAroundPoint pulls a local patchSize window, so
    % there's no alignment concern from mixing image sources like there
    % would be with Refined IDRiD's separately-resized copies).
    imageDir = cfg.idridSegImagesTrain;
    maGroundtruthDir = fullfile(cfg.idridSegGroundtruthTrain, '1. Microaneurysms');

    imageFiles = dir(fullfile(imageDir, '*.jpg'));
    allImages = {};
    allLabels = {};

    nPositiveTarget = round(targetPatchCount * positiveRatio);
    nCollected = 0;

    for i = 1:numel(imageFiles)
        [~, baseName, ~] = fileparts(imageFiles(i).name);
        imgPath = fullfile(imageDir, imageFiles(i).name);
        lblPath = fullfile(maGroundtruthDir, [baseName '_MA.tif']);
        if ~isfile(lblPath)
            continue;
        end
        img = imread(imgPath);
        maMask = logical(imread(lblPath));

        cc = bwconncomp(maMask);
        stats = regionprops(cc, 'Centroid');
        for k = 1:numel(stats)
            if nCollected >= nPositiveTarget
                break;
            end
            [imgPatch, lblPatch] = cropAroundPoint(img, maMask, stats(k).Centroid, patchSize);
            if isempty(imgPatch), continue; end
            allImages{end+1} = imgPatch; %#ok<AGROW>
            allLabels{end+1} = lblPatch; %#ok<AGROW>
            nCollected = nCollected + 1;
        end
    end
    fprintf('  %d positive (MA-containing) patches collected.\n', nCollected);

    % Hard negatives via offline top-hat mining (see its own docstring
    % for why this is safe to use here without reintroducing a recall
    % ceiling - it never gates inference, only enriches training data).
    hardNeg = topHatHardNegativeMining(imageDir, maGroundtruthDir, ...
        patchSize, round(targetPatchCount * (1 - positiveRatio) * 0.5));
    for i = 1:numel(hardNeg)
        allImages{end+1} = hardNeg(i).image; %#ok<AGROW>
        allLabels{end+1} = false(patchSize, patchSize); %#ok<AGROW>
    end
    fprintf('  %d hard-negative patches added.\n', numel(hardNeg));

    % Plain random negatives to round out the set.
    nPlainNegatives = targetPatchCount - numel(allImages);
    for i = 1:max(nPlainNegatives, 0)
        randIdx = randi(numel(imageFiles));
        img = imread(fullfile(imageDir, imageFiles(randIdx).name));
        [H, W, ~] = size(img);
        if H < patchSize || W < patchSize, continue; end
        r = randi(H - patchSize + 1);
        c = randi(W - patchSize + 1);
        allImages{end+1} = img(r:r+patchSize-1, c:c+patchSize-1, :); %#ok<AGROW>
        allLabels{end+1} = false(patchSize, patchSize); %#ok<AGROW>
    end
    fprintf('  %d plain random-background patches added. Total: %d\n', ...
        max(nPlainNegatives, 0), numel(allImages));

    patchImages = arrayDatastore(cat(4, allImages{:}), 'IterationDimension', 4);
    labelStack = cat(4, allLabels{:});
    patchLabels = arrayDatastore(categorical(labelStack, [false true], {'Background', 'Microaneurysm'}), ...
        'IterationDimension', 4);
end

function [imgPatch, lblPatch] = cropAroundPoint(img, mask, centroid, patchSize)
    [H, W, ~] = size(img);
    cx = round(centroid(1)); cy = round(centroid(2));
    r = round(cy - patchSize/2); c = round(cx - patchSize/2);
    r = max(min(r, H - patchSize + 1), 1);
    c = max(min(c, W - patchSize + 1), 1);
    if H < patchSize || W < patchSize
        imgPatch = []; lblPatch = [];
        return
    end
    imgPatch = img(r:r+patchSize-1, c:c+patchSize-1, :);
    lblPatch = mask(r:r+patchSize-1, c:c+patchSize-1);
end
