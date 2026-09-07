function results = evaluate_trackA_dice(cfg)
%EVALUATE_TRACKA_DICE Per-class Dice/IoU for Track A's lesion classes, on
%IDRiD's held-out segmentation test set.
%   results = evaluate_trackA_dice() runs Track A (segmentStructures) on
%   every image in IDRiD's Segmentation test set and computes Dice/IoU
%   per class against real pixel-level ground truth, via common/metrics.m
%   (the project's single source of truth for this - same function
%   evaluateTrackBCheckpoint.m already uses for microaneurysms).
%
%   Covers EX (Hard Exudates), HE (Haemorrhages), CWS (Cotton Wool
%   Spots = IDRiD's "Soft Exudates"). IRMA and NV are NOT evaluated here
%   - IDRiD's segmentation ground truth has no annotations for either
%   class at all (confirmed: only Microaneurysms/Haemorrhages/Hard
%   Exudates/Soft Exudates/Optic Disc folders exist under "2. All
%   Segmentation Groundtruths"). Reporting a Dice score for them against
%   this dataset would mean scoring against masks that don't exist -
%   this function explicitly records them as "not evaluable" rather than
%   silently omitting them, so the gap is visible, not hidden.
%
%   Track A was trained on enhanced (Refined IDRiD) images, but its
%   masks come out at its own internal working resolution - both handled
%   here the same way buildLesionOverlay.m does for the live report.
%
%   See also: segmentStructures, evaluateTrackBCheckpoint, common/metrics.

    if nargin < 1 || isempty(cfg)
        cfg = config();
    end

    % IDRiD class name -> Track A class name, and which groundtruth
    % folder + filename suffix holds its masks.
    classMap = {
        'EX',  '3. Hard Exudates',   '_EX.tif';
        'HE',  '2. Haemorrhages',    '_HE.tif';
        'CWS', '4. Soft Exudates',   '_SE.tif';
    };
    unevaluableClasses = {'IRMA', 'NV'};

    imageFiles = dir(fullfile(cfg.idridSegImagesTest, '*.jpg'));
    fprintf('Evaluating Track A on %d IDRiD segmentation test images...\n', numel(imageFiles));

    perClassMetrics = struct();
    for c = 1:size(classMap, 1)
        perClassMetrics.(classMap{c, 1}) = [];
    end

    for i = 1:numel(imageFiles)
        [~, baseName, ~] = fileparts(imageFiles(i).name);
        imgPath = fullfile(cfg.idridSegImagesTest, imageFiles(i).name);
        rgbImage = imread(imgPath);
        [enhImg, ~, ~] = enhanceImage(rgbImage, cfg.module1QualityModel);
        trackAResult = segmentStructures(enhImg, cfg.trackANetPath);
        canvasSize = [size(rgbImage, 1), size(rgbImage, 2)];

        for c = 1:size(classMap, 1)
            [className, gtFolder, gtSuffix] = classMap{c, :};
            gtPath = fullfile(cfg.idridSegGroundtruthTest, gtFolder, [baseName gtSuffix]);
            if ~isfile(gtPath)
                continue % this image has no lesion of this class - not a scoreable pair
            end
            gtMask = imread(gtPath);
            if ndims(gtMask) == 3
                gtMask = any(gtMask, 3); % some IDRiD groundtruth TIFs are RGB-encoded, not single-channel
            end
            gtMask = logical(gtMask);
            fieldName = matlab.lang.makeValidName(className);
            predMask = trackAResult.masks.(fieldName);
            if ~isequal(size(predMask), canvasSize)
                predMask = imresize(predMask, canvasSize, 'nearest');
            end
            m = metrics(predMask, gtMask);
            perClassMetrics.(className)(end+1) = m.dice; %#ok<AGROW>
            fprintf('  %s [%s]: Dice=%.3f IoU=%.3f\n', baseName, className, m.dice, m.iou);
        end
    end

    fprintf('\n=== Track A per-class Dice (IDRiD segmentation test set, n=%d images) ===\n', numel(imageFiles));
    results = struct();
    for c = 1:size(classMap, 1)
        className = classMap{c, 1};
        scores = perClassMetrics.(className);
        results.(className).diceScores = scores;
        results.(className).meanDice = mean(scores);
        results.(className).nImages = numel(scores);
        fprintf('  %-4s: mean Dice = %.3f (n=%d images with ground truth for this class)\n', ...
            className, mean(scores), numel(scores));
    end
    for i = 1:numel(unevaluableClasses)
        fprintf('  %-4s: NOT EVALUABLE - IDRiD has no ground truth annotations for this class\n', ...
            unevaluableClasses{i});
        results.(unevaluableClasses{i}) = 'not evaluable - no IDRiD ground truth exists for this class';
    end

    save(fullfile(cfg.resultsDir, 'evaluate_trackA_dice_results.mat'), 'results');
    fprintf('\nSaved results to %s\n', fullfile(cfg.resultsDir, 'evaluate_trackA_dice_results.mat'));
end
