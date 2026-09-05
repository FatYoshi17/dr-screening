function pipelineResult = run_end_to_end_pipeline(imagePath, cfg)
%RUN_END_TO_END_PIPELINE Module 1 -> 2 -> 3 -> 4, one image, full pipeline.
%   pipelineResult = run_end_to_end_pipeline(imagePath) runs:
%     1. Module 1: assess quality, enhance if needed, reject if ungradeable
%     2. Module 2: Track A (structures) + Track B (microaneurysms)
%     3. Module 3: grade + disagreement flag
%     4. Module 4: Grad-CAM, calibrated confidence, lesion-attention
%        overlap, annotated report
%
%   ALL FOUR MODULES NEED THEIR MODELS TRAINED FIRST - see
%   docs/RUN_GUIDE.md and train_all_models.m. This function will error
%   out with a clear message at whichever module's model is missing.
%
%   Saves the annotated report to cfg.resultsDir and returns a struct
%   with every intermediate result for inspection.
%
%   See also: train_all_models, app_try_it.

    if nargin < 2
        cfg = config();
    end

    [~, imageId, ~] = fileparts(imagePath);
    rgbImage = imread(imagePath);

    fprintf('=== Module 1: Image Quality ===\n');
    [enhImg, qcBefore, qcAfter] = enhanceImage(rgbImage, cfg.module1QualityModel);
    fprintf('  Decision: %s (score %.2f)\n', string(qcBefore.decision), qcBefore.qualityScore);

    if ~qcBefore.isGradable
        rejectUngradeable(qcBefore, imageId);
        pipelineResult.status = 'REJECTED';
        pipelineResult.qc = qcBefore;
        return
    end

    % Track A was trained on Refined IDRiD's already-enhanced images, so
    % it correctly gets enhImg. Track B (buildTrackBPatchSet.m reads raw
    % IDRiD JPGs via plain imread(), no enhancement) and Module 3
    % (trainGradingCNN.m's augmentedImageDatastore does the same on raw
    % APTOS images) were both trained on UNenhanced images - passing
    % them enhImg is a real train/inference distribution mismatch, not
    % just a theoretical concern: confirmed directly by testing, Track B
    % found 179 real candidate microaneurysm blobs on the raw image and
    % exactly 0 on the enhanced one for the same photo.
    fprintf('=== Module 2: Structure Segmentation ===\n');
    fprintf('  Track A (structures)...\n');
    trackAResult = segmentStructures(enhImg, cfg.trackANetPath);
    fprintf('  Track B (microaneurysms)...\n');
    trackBResult = detectMicroaneurysmsV2(rgbImage, cfg.trackBActiveNetPath);
    fprintf('  Track B: %d confirmed MA, ambiguous=%d\n', ...
        trackBResult.confirmedCount, trackBResult.hasAmbiguous);

    fprintf('=== Module 3: Severity Grading ===\n');
    gradeResult = gradeImage(rgbImage, trackAResult, trackBResult, cfg.module3GradingCnnPath);
    fprintf('  Shown grade: %d (referable=%d), flagged=%d (%s)\n', ...
        gradeResult.shownGrade, gradeResult.isReferable, ...
        gradeResult.flag.flagged, gradeResult.flag.priority);

    fprintf('=== Module 4: Explainability ===\n');
    camResult = computeGradCAM(rgbImage, cfg.module3GradingCnnPath);
    overlapResult = lesionAttentionOverlap(camResult, trackAResult, trackBResult);
    fprintf('  Lesion-attention overlap: %.0f%%\n', overlapResult.overlapScore * 100);

    reportFig = generateAnnotatedReport(enhImg, trackAResult, trackBResult, ...
        gradeResult, camResult, overlapResult, imageId);

    reportPath = fullfile(cfg.resultsDir, sprintf('report_%s.pdf', imageId));
    exportgraphics(reportFig, reportPath);
    close(reportFig);
    fprintf('Saved report to %s\n', reportPath);

    pipelineResult.status = 'GRADED';
    pipelineResult.qcBefore = qcBefore;
    pipelineResult.qcAfter = qcAfter;
    pipelineResult.enhancedImage = enhImg;
    pipelineResult.trackA = trackAResult;
    pipelineResult.trackB = trackBResult;
    pipelineResult.grade = gradeResult;
    pipelineResult.cam = camResult;
    pipelineResult.overlap = overlapResult;
    pipelineResult.reportPath = reportPath;
end
