function run_pipeline_api(imagePath, patientInfoJsonPath, outputJsonPath)
%RUN_PIPELINE_API Web-API adapter: run the pipeline, write frontend-shaped JSON.
%   run_pipeline_api(imagePath, patientInfoJsonPath, outputJsonPath)
%
%   Thin wrapper around run_end_to_end_pipeline.m for the web backend
%   (backend/main.py) to invoke via subprocess and read back a JSON
%   result shaped to match the frontend's existing TypeScript types
%   (src/types/index.ts: QualityFeature, LesionFinding, SeverityAssessment,
%   Explainability) - the frontend's screeningService.ts used to return
%   hardcoded demo data in exactly this shape; this produces the real
%   thing from the actual trained models instead.
%
%   patientInfoJsonPath: path to a JSON file (jsondecode'd into the
%   patientInfo struct run_end_to_end_pipeline.m expects), or '' for
%   none. Takes a FILE PATH rather than the JSON text itself: Python's
%   subprocess argument-joining on Windows re-escapes embedded double
%   quotes when building the single command-line string MATLAB
%   receives, corrupting JSON passed directly as a -batch argument -
%   a file sidesteps that entirely.
%
%   Writes outputJsonPath and returns nothing - the caller (Python) owns
%   reading it back. Never throws even on pipeline failure: catches and
%   writes an error-shaped JSON instead, since a subprocess crash with
%   no output file is much harder for the API layer to report cleanly.
%
%   See also: run_end_to_end_pipeline, getFollowUpRecommendation,
%   categorizeReliability.

    try
        cfg = config();
        if nargin < 2 || isempty(patientInfoJsonPath)
            patientInfo = struct();
        else
            patientInfo = jsondecode(fileread(patientInfoJsonPath));
        end

        result = run_end_to_end_pipeline(imagePath, cfg, patientInfo);
        outDir = fileparts(outputJsonPath);
        apiResult = buildApiResult(result, cfg, outDir);

        fid = fopen(outputJsonPath, 'w');
        fprintf(fid, '%s', jsonencode(apiResult));
        fclose(fid);
    catch ME
        errResult = struct('status', 'ERROR', 'errorMessage', ME.message);
        fid = fopen(outputJsonPath, 'w');
        fprintf(fid, '%s', jsonencode(errResult));
        fclose(fid);
    end
end

function apiResult = buildApiResult(result, cfg, outDir)
    if strcmp(result.status, 'REJECTED')
        apiResult.status = 'REJECTED';
        apiResult.qualityStatus = 'FAIL';
        apiResult.qualityReason = strjoin(result.qc.failReasons, '; ');
        apiResult.resultCategory = 'RETAKE';
        apiResult.resultRecommendation = 'Image quality is insufficient to evaluate retinal health. Capture again.';
        apiResult.qualityFeatures = buildQualityFeatures(result.qc);
        return
    end

    apiResult.status = 'GRADED';
    apiResult.qualityStatus = 'PASS';
    apiResult.qualityReason = '';
    apiResult.qualityFeatures = buildQualityFeatures(result.qcBefore);

    apiResult.findings = buildFindings(result.trackA, result.trackB);

    % AI-interpreted (segmentation overlay) and Grad-CAM images - saved
    % as standalone files so the web frontend can display them directly
    % (previously these only ever got embedded inside the PDF report,
    % via generateAnnotatedReport.m's own copy of this same overlay
    % logic - now shared via buildLesionOverlay.m). Resized + saved as
    % JPEG rather than full-resolution PNG: IDRiD source images are
    % ~4300x2800, which produced ~10MB PNGs - directly against this
    % app's own "low-bandwidth rural" design goal (see UploadPage.tsx's
    % client-side image compression, which this mirrors server-side).
    displayWidth = 800;
    segmentationImage = buildLesionOverlay(result.enhancedImage, result.trackA, result.trackB);
    segmentationImage = imresize(segmentationImage, [NaN, displayWidth]);
    segmentationFileName = 'segmentation.jpg';
    imwrite(segmentationImage, fullfile(outDir, segmentationFileName), 'Quality', 80);
    apiResult.segmentationImageFileName = segmentationFileName;

    gradCamImage = imresize(result.cam.overlayImage, [NaN, displayWidth]);
    gradCamFileName = 'gradcam.jpg';
    imwrite(gradCamImage, fullfile(outDir, gradCamFileName), 'Quality', 80);
    apiResult.gradCamImageFileName = gradCamFileName;

    grade = result.grade;
    apiResult.severity.icdrGrade = grade.shownGrade;
    apiResult.severity.gradeLabel = gradeLabel(grade.shownGrade);
    apiResult.severity.referable = grade.isReferable;
    apiResult.severity.gradingPathway = char(ternary(grade.rule.committed, 'rule-based', 'cnn'));
    apiResult.severity.agreement = ~grade.flag.flagged;

    calibConf = calibrateConfidence(grade.cnn.rawConfidence);
    apiResult.explainability.calibratedConfidence = calibConf;
    apiResult.explainability.reliabilityCategory = categorizeReliability(calibConf);
    apiResult.explainability.lesionAttentionOverlap = result.overlap.overlapScore;
    apiResult.explainability.flagged = grade.flag.flagged;
    apiResult.explainability.flagReason = char(grade.flag.message);

    apiResult.resultCategory = char(resultCategory(grade));
    apiResult.resultRecommendation = getFollowUpRecommendation(grade.shownGrade, grade.flag.flagged);
    apiResult.reportFileName = regexprep(result.reportPath, '.*[\\/]', ''); % reportPath is already named report_<imageId>.pdf
end

function features = buildQualityFeatures(qc)
    features = struct('name', {}, 'score', {}, 'assessment', {});
    for i = 1:numel(qc.featureNames)
        s = qc.featureScores(i);
        features(i).name = qc.featureNames{i};
        features(i).score = s;
        features(i).assessment = char(ternary(s >= 0.66, 'Good', ternary(s >= 0.4, 'Acceptable', 'Poor')));
    end
end

function findings = buildFindings(trackAResult, trackBResult)
    findings = struct('lesionType', {}, 'count', {}, 'confidence', {});
    ignoredClasses = {'Background', 'Retina'};
    idx = 1;
    for i = 1:numel(trackAResult.classNames)
        name = trackAResult.classNames{i};
        if any(strcmp(name, ignoredClasses)), continue; end
        fieldName = matlab.lang.makeValidName(name);
        pixelCount = nnz(trackAResult.masks.(fieldName));
        if pixelCount > 25
            findings(idx).lesionType = name;
            findings(idx).count = 1; % Track A is region-level, not object-count
            findings(idx).confidence = min(1, pixelCount / 5000); % rough size-based proxy, not a real probability
            idx = idx + 1;
        end
    end
    if trackBResult.confirmedCount > 0
        confirmedConf = [trackBResult.candidates(strcmp({trackBResult.candidates.status}, 'confirmed')).combinedConfidence];
        findings(idx).lesionType = 'Microaneurysm';
        findings(idx).count = trackBResult.confirmedCount;
        findings(idx).confidence = mean(confirmedConf);
    end
end

function label = gradeLabel(grade)
    labels = {'No DR', 'Mild NPDR', 'Moderate NPDR', 'Severe NPDR', 'Proliferative DR'};
    if grade >= 0 && grade <= 4
        label = labels{grade + 1};
    else
        label = 'Unknown';
    end
end

function cat = resultCategory(gradeResult)
    if gradeResult.flag.flagged
        if strcmp(gradeResult.flag.priority, 'high')
            cat = 'PRIORITY';
        else
            cat = 'REVIEW';
        end
    elseif gradeResult.shownGrade >= 3
        cat = 'PRIORITY';
    elseif gradeResult.shownGrade == 2
        cat = 'REVIEW';
    else
        cat = 'ROUTINE';
    end
end

function out = ternary(cond, a, b)
    if cond, out = a; else, out = b; end
end
