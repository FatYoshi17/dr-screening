function results = evaluateTrackBCheckpoint(checkpointPath, numTestPatches, scoreThreshold)
%EVALUATETRACKBCHECKPOINT Sanity-check a Track B checkpoint on held-out IDRiD test images.
%   results = evaluateTrackBCheckpoint(checkpointPath) loads a saved
%   trainNetwork checkpoint (a DAGNetwork), runs it on positive
%   (MA-containing) patches drawn from IDRiD's TEST set - images the
%   training run in trainTrackB.m never saw, since that only reads the
%   Training Set - and reports per-patch Dice score for the
%   Microaneurysm class, plus overall stats. Also saves a handful of
%   image/ground-truth/prediction overlay PNGs to
%   data/models/trackB_eval_overlays/ for a qualitative look.
%
%   Raw pixel accuracy is not reported: microaneurysm pixels are a tiny
%   fraction of any patch, so a model that predicts "no MA anywhere"
%   scores ~99% accuracy while being useless. Dice on the MA class is
%   the metric that actually reflects whether it found anything.
%
%   results = evaluateTrackBCheckpoint(checkpointPath, numTestPatches, scoreThreshold)
%   uses a custom threshold directly on the raw Microaneurysm-class
%   score instead of semanticseg's default argmax-between-classes rule.
%   This matters a lot for severely imbalanced models: SegFormer's
%   first several training attempts scored 0.000 Dice under the default
%   rule despite genuinely learning to rank MA pixels above background
%   (confirmed by checking raw scores directly) - the imbalance drags
%   both classes' absolute confidence toward "background" so far that
%   the MA channel's score never actually exceeds the background
%   channel's, even at true lesion locations. A threshold in the
%   ~0.1-0.2 range (tune per checkpoint - it varies) recovers real,
%   substantial Dice from the same underlying model. Leave empty/omit
%   to use the default argmax rule (fine for well-calibrated models
%   like the CBAM CNN, which doesn't show this problem).
%
%   See also: trainTrackB, buildTrackBSegformerNetwork.

    if nargin < 2 || isempty(numTestPatches)
        numTestPatches = 20;
    end
    if nargin < 3
        scoreThreshold = [];
    end

    cfg = config();
    patchSize = 512;

    fprintf('Loading checkpoint %s ...\n', checkpointPath);
    loaded = load(checkpointPath);
    net = loaded.net;

    testImageDir = cfg.idridSegImagesTest;
    testMaDir = fullfile(cfg.idridSegGroundtruthTest, '1. Microaneurysms');

    imageFiles = dir(fullfile(testImageDir, '*.jpg'));
    if isempty(imageFiles)
        error('No test images found at %s', testImageDir);
    end

    overlayDir = fullfile(cfg.dataModels, 'trackB_eval_overlays');
    if ~isfolder(overlayDir), mkdir(overlayDir); end

    diceScores = [];
    nCollected = 0;

    for i = 1:numel(imageFiles)
        if nCollected >= numTestPatches
            break;
        end
        [~, baseName, ~] = fileparts(imageFiles(i).name);
        lblPath = fullfile(testMaDir, [baseName '_MA.tif']);
        if ~isfile(lblPath)
            continue;
        end

        img = imread(fullfile(testImageDir, imageFiles(i).name));
        maMask = logical(imread(lblPath));

        cc = bwconncomp(maMask);
        stats = regionprops(cc, 'Centroid');

        for k = 1:numel(stats)
            if nCollected >= numTestPatches
                break;
            end
            [H, W, ~] = size(img);
            cx = round(stats(k).Centroid(1)); cy = round(stats(k).Centroid(2));
            r = round(cy - patchSize/2); c = round(cx - patchSize/2);
            r = max(min(r, H - patchSize + 1), 1);
            c = max(min(c, W - patchSize + 1), 1);
            if H < patchSize || W < patchSize
                continue;
            end
            imgPatch = img(r:r+patchSize-1, c:c+patchSize-1, :);
            gtPatch = maMask(r:r+patchSize-1, c:c+patchSize-1);

            if isempty(scoreThreshold)
                predLabels = semanticseg(imgPatch, net);
                predMask = predLabels == 'Microaneurysm';
            else
                [~, ~, allScores] = semanticseg(imgPatch, net);
                predMask = allScores(:,:,2) > scoreThreshold;
            end

            intersection = nnz(predMask & gtPatch);
            diceScore = 2 * intersection / (nnz(predMask) + nnz(gtPatch) + eps);
            diceScores(end+1) = diceScore; %#ok<AGROW>

            nCollected = nCollected + 1;

            overlay = imgPatch;
            overlayGT = cat(3, uint8(gtPatch)*255, zeros(patchSize, patchSize, 'uint8'), zeros(patchSize, patchSize, 'uint8'));
            overlayPred = cat(3, zeros(patchSize, patchSize, 'uint8'), zeros(patchSize, patchSize, 'uint8'), uint8(predMask)*255);
            combined = imfuse(overlay, imadd(overlayGT, overlayPred), 'blend');
            imwrite(combined, fullfile(overlayDir, sprintf('%s_patch%d_dice%.2f.png', baseName, k, diceScore)));

            fprintf('  %s patch %d: Dice=%.3f (pred %d px, gt %d px, overlap %d px)\n', ...
                baseName, k, diceScore, nnz(predMask), nnz(gtPatch), intersection);
        end
    end

    if isempty(diceScores)
        error('No test patches with MA ground truth were found/evaluated.');
    end

    results.diceScores = diceScores;
    results.meanDice = mean(diceScores);
    results.medianDice = median(diceScores);
    results.nPatches = numel(diceScores);
    results.nZeroDice = sum(diceScores == 0); % patches where it predicted nothing overlapping at all

    fprintf('\n=== Evaluation summary (%d patches, held-out IDRiD test set) ===\n', results.nPatches);
    fprintf('Mean Dice:   %.3f\n', results.meanDice);
    fprintf('Median Dice: %.3f\n', results.medianDice);
    fprintf('Zero-overlap patches: %d/%d (%.0f%%)\n', results.nZeroDice, results.nPatches, ...
        100*results.nZeroDice/results.nPatches);
    fprintf('Overlays saved to %s\n', overlayDir);
end
