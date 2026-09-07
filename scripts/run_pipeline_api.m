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
    findings = struct('lesionType', {}, 'count', {}, 'confidence', {}, ...
        'location', {}, 'reliabilityCategory', {});
    ignoredClasses = {'Background', 'Retina'};

    canvasSize = [];
    fn = fieldnames(trackAResult.masks);
    if ~isempty(fn)
        canvasSize = size(trackAResult.masks.(fn{1}));
    end
    odCentroid = landmarkCentroid(trackAResult, 'OD');
    foveaCentroid = landmarkCentroid(trackAResult, 'Fovea');

    idx = 1;
    for i = 1:numel(trackAResult.classNames)
        name = trackAResult.classNames{i};
        if any(strcmp(name, ignoredClasses)), continue; end
        fieldName = matlab.lang.makeValidName(name);
        mask = trackAResult.masks.(fieldName);
        pixelCount = nnz(mask);
        if pixelCount > 25
            cc = bwconncomp(mask, 8);
            stats = regionprops(cc, 'Centroid', 'Area');
            stats = stats([stats.Area] > 25); % drop speckle-sized components from the object count

            confidence = min(1, pixelCount / 5000); % rough size-based proxy, not a real probability
            findings(idx).lesionType = name;
            findings(idx).count = max(1, numel(stats));
            findings(idx).confidence = confidence;
            findings(idx).reliabilityCategory = categorizeReliability(confidence);
            findings(idx).location = describeLocation(stats, canvasSize, odCentroid, foveaCentroid);
            idx = idx + 1;
        end
    end
    if trackBResult.confirmedCount > 0
        confirmedIdx = strcmp({trackBResult.candidates.status}, 'confirmed');
        confirmedConf = [trackBResult.candidates(confirmedIdx).combinedConfidence];
        confirmedCentroids = reshape([trackBResult.candidates(confirmedIdx).centroid], 2, [])';
        maStats = struct('Centroid', num2cell(confirmedCentroids, 2));
        meanConf = mean(confirmedConf);
        findings(idx).lesionType = 'Microaneurysm';
        findings(idx).count = trackBResult.confirmedCount;
        findings(idx).confidence = meanConf;
        findings(idx).reliabilityCategory = categorizeReliability(meanConf);
        findings(idx).location = describeLocation(maStats, canvasSize, odCentroid, foveaCentroid);
    end
end

function centroid = landmarkCentroid(trackAResult, className)
%LANDMARKCENTROID Centroid of a class's largest connected component, or
%empty if the class wasn't detected - used as an anatomical reference
%point (optic disc / fovea) for naming other lesions' quadrants.
    centroid = [];
    fieldName = matlab.lang.makeValidName(className);
    if ~isfield(trackAResult.masks, fieldName), return; end
    mask = trackAResult.masks.(fieldName);
    if nnz(mask) < 25, return; end
    cc = bwconncomp(mask, 8);
    stats = regionprops(cc, 'Area', 'Centroid');
    if isempty(stats), return; end
    [~, biggest] = max([stats.Area]);
    centroid = stats(biggest).Centroid; % [x y]
end

function loc = describeLocation(stats, canvasSize, odCentroid, foveaCentroid)
%DESCRIBELOCATION Anatomical quadrant(s) a set of object centroids fall
%in. Nasal/temporal is derived from the optic disc's position relative
%to the fovea (the disc is always on the nasal side of the retina) so
%this works without needing eye laterality (OD/OS) plumbed through from
%the frontend. Falls back to plain image-quadrant naming when the disc
%or fovea wasn't detected in this image.
    if isempty(stats)
        loc = 'Not specified';
        return
    end
    quadrants = strings(1, numel(stats));
    useAnatomical = ~isempty(odCentroid) && ~isempty(foveaCentroid) && ...
        abs(odCentroid(1) - foveaCentroid(1)) > 1;
    for k = 1:numel(stats)
        c = stats(k).Centroid;
        if useAnatomical
            nasalSign = sign(odCentroid(1) - foveaCentroid(1));
            isNasal = sign(c(1) - foveaCentroid(1)) == nasalSign;
            horiz = ternary(isNasal, "Nasal", "Temporal");
            vert = ternary(c(2) < foveaCentroid(2), "Superior", "Inferior");
        else
            horiz = ternary(c(1) < canvasSize(2) / 2, "Left", "Right");
            vert = ternary(c(2) < canvasSize(1) / 2, "Upper", "Lower");
        end
        quadrants(k) = vert + " " + horiz;
    end
    uniqueQuadrants = unique(quadrants);
    if numel(uniqueQuadrants) == 1
        loc = char(uniqueQuadrants(1));
    else
        loc = 'Multiple quadrants';
    end
end

function out = ternary(cond, a, b)
    if cond, out = a; else, out = b; end
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
