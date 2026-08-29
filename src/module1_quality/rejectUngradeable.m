function report = rejectUngradeable(qc, imageId)
%REJECTUNGRADEABLE Build a recapture-feedback report for a failed image.
%   report = rejectUngradeable(qc, imageId) turns assessImageQuality's
%   failReasons into structured, technician-facing recapture guidance
%   and prints it to the console.

    if nargin < 2
        imageId = 'unknown';
    end

    adviceMap = containers.Map( ...
        {'Image too blurred / out of focus', ...
         'Retina fills too little of the frame (reposition camera)', ...
         'Image too dark (increase illumination / flash)', ...
         'Image overexposed (reduce illumination / flash)', ...
         'Uneven illumination across the retina'}, ...
        {'Ask patient to fixate steadily; hold camera still; refocus.', ...
         'Move camera closer / recentre pupil in the viewfinder.', ...
         'Increase flash intensity or check for pupil dilation.', ...
         'Reduce flash intensity or reposition to avoid glare.', ...
         'Recentre the eye and avoid reflections from the cornea.'});

    report.imageId = imageId;
    report.status = 'REJECTED';
    report.reasons = qc.failReasons;
    report.recaptureAdvice = cell(size(qc.failReasons));
    for i = 1:numel(qc.failReasons)
        if isKey(adviceMap, qc.failReasons{i})
            report.recaptureAdvice{i} = adviceMap(qc.failReasons{i});
        else
            report.recaptureAdvice{i} = 'Recapture image following standard protocol.';
        end
    end
    report.overallScore = qc.overallScore;

    fprintf('--- Image %s REJECTED (score %.2f) ---\n', imageId, qc.overallScore);
    for i = 1:numel(report.reasons)
        fprintf('  [%d] %s\n      -> %s\n', i, report.reasons{i}, report.recaptureAdvice{i});
    end
end
