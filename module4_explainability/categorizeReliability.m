function category = categorizeReliability(calibratedConfidence)
%CATEGORIZERELIABILITY Map calibrated confidence to a clinician-facing category.
%   category = categorizeReliability(calibratedConfidence)
%
%   A reviewing clinician asked for this directly: a bare "80% reliable"
%   number invites over-interpretation of a number that is itself only
%   roughly calibrated (see calibrateConfidence.m - Platt-scaled from a
%   distance-to-threshold proxy, not a true posterior). Categorical
%   bands are more honest about the actual precision of this signal and
%   match how confidence is already communicated elsewhere in this
%   pipeline (e.g. Track B's confirmed/ambiguous/rejected bands in
%   detectMicroaneurysmsV2.m).
%
%   Cutoffs (>=0.75 Reliable, >=0.5 Moderate, else Low) are a reasonable
%   starting point, not validated against outcome data - tune against a
%   real reviewer-agreement study before trusting them clinically.
%
%   See also: calibrateConfidence, generateAnnotatedReport.

    if calibratedConfidence >= 0.75
        category = 'Reliable';
    elseif calibratedConfidence >= 0.5
        category = 'Moderate';
    else
        category = 'Low';
    end
end
