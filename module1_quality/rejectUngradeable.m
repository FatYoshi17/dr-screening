function report = rejectUngradeable(qc, imageId)
%REJECTUNGRADEABLE Build a recapture-feedback report for a rejected image.
%   report = rejectUngradeable(qc, imageId) turns assessImageQuality's
%   failReasons (already plain-language) into a structured report and
%   prints it to the console. Call this only when qc.decision == 'Reject'
%   (qc.isGradable == false); for 'Enhance' images, use enhanceImage
%   instead and continue to Module 2.

    if nargin < 2
        imageId = 'unknown';
    end

    report.imageId = imageId;
    report.status = 'REJECTED';
    report.reasons = qc.failReasons;
    report.qualityScore = qc.qualityScore;
    report.classProbs = qc.classProbs;

    fprintf('--- Image %s REJECTED (quality score %.2f) ---\n', imageId, qc.qualityScore);
    for i = 1:numel(report.reasons)
        fprintf('  [%d] %s\n', i, report.reasons{i});
    end
end
