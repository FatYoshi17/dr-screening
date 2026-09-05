function run_quality_check_api(imagePath, outputJsonPath)
%RUN_QUALITY_CHECK_API Web-API adapter: Module 1 ONLY, for a fast quality gate.
%   run_quality_check_api(imagePath, outputJsonPath)
%
%   Runs just enhanceImage.m (quality assessment - the checkFundusPlausibility
%   gate, then the trained/threshold quality model) and nothing else -
%   no segmentation, grading, or Grad-CAM. Those cost real time (Modules
%   2-4 run a CNN + sliding-window microaneurysm detector + gradCAM over
%   the full image) and have no bearing on whether the PHOTO ITSELF is
%   usable, so paying for them just to answer "is this image good
%   enough" makes the quality-check step as slow as a full screening for
%   no reason. See backend/main.py's POST /api/quality-check.
%
%   Writes outputJsonPath: {qualityStatus, qualityReason, qualityFeatures}
%   in the same shape run_pipeline_api.m already uses, so the frontend's
%   existing types need no changes. Never throws - catches all errors
%   and writes an {status:'ERROR', errorMessage} JSON instead.
%
%   See also: run_pipeline_api, run_end_to_end_pipeline, enhanceImage.

    try
        cfg = config();
        rgbImage = imread(imagePath);
        [~, qc] = enhanceImage(rgbImage, cfg.module1QualityModel);

        result.qualityStatus = char(ternary(qc.isGradable, 'PASS', 'FAIL'));
        result.qualityReason = strjoin(qc.failReasons, '; ');
        result.qualityFeatures = buildQualityFeatures(qc);

        fid = fopen(outputJsonPath, 'w');
        fprintf(fid, '%s', jsonencode(result));
        fclose(fid);
    catch ME
        errResult = struct('status', 'ERROR', 'errorMessage', ME.message);
        fid = fopen(outputJsonPath, 'w');
        fprintf(fid, '%s', jsonencode(errResult));
        fclose(fid);
    end
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

function out = ternary(cond, a, b)
    if cond, out = a; else, out = b; end
end
