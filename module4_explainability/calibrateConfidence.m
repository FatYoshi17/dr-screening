function calibratedConfidence = calibrateConfidence(rawConfidence, calibParamsPath)
%CALIBRATECONFIDENCE Apply Platt-scaling calibration to the CNN's raw confidence.
%   calibratedConfidence = calibrateConfidence(rawConfidence, calibParamsPath)
%
%   Loads calibParams fit by fitConfidenceCalibration.m and applies:
%       calibratedConfidence = 1 / (1 + exp(-(a * rawConfidence + b)))
%
%   Per Module 3's report rules, this number is only ever shown when
%   the rule and CNN agree (or the rule cleanly deferred) - a flagged,
%   disagreeing case shows both raw opinions instead, with no
%   confidence number at all (see disagreementFlag.m /
%   generateAnnotatedReport.m).
%
%   See also: fitConfidenceCalibration, predictGradingCNN,
%   disagreementFlag, generateAnnotatedReport.

    if nargin < 2 || isempty(calibParamsPath)
        calibParamsPath = fullfile('data', 'models', 'module4_confidence_calibration.mat');
    end
    if ~isfile(calibParamsPath)
        warning(['No confidence calibration found at %s - returning raw ' ...
                 'confidence uncalibrated. Run fitConfidenceCalibration on a ' ...
                 'validation set first.'], calibParamsPath);
        calibratedConfidence = rawConfidence;
        return
    end
    loaded = load(calibParamsPath, 'calibParams');
    p = loaded.calibParams;
    calibratedConfidence = 1 / (1 + exp(-(p.a * rawConfidence + p.b)));
end
