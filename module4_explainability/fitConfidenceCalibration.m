function calibParams = fitConfidenceCalibration(rawConfidences, wasCorrect)
%FITCONFIDENCECALIBRATION Fit Platt-style calibration for the grading CNN's confidence.
%   calibParams = fitConfidenceCalibration(rawConfidences, wasCorrect)
%
%   Raw CNN confidence (predictGradingCNN.m's distance-from-threshold
%   proxy) tends to run overconfident, like most raw model confidence -
%   this fits a 1-D logistic (Platt scaling, the regression-output
%   analogue of temperature scaling for a softmax classifier) mapping
%   raw confidence to an actual empirical probability of being correct,
%   using a held-out validation set where ground truth is known.
%
%   rawConfidences: Nx1 vector of predictGradingCNN's rawConfidence
%                   values on a validation set.
%   wasCorrect:     Nx1 logical, whether the CNN's rounded grade matched
%                   the true label for that same validation image.
%
%   Returns calibParams = struct(a, b) for
%       calibratedConfidence = 1 / (1 + exp(-(a * rawConfidence + b)))
%
%   Fit via fminsearch (no extra toolbox dependency) minimizing negative
%   log-likelihood, the standard Platt-scaling objective.
%
%   See also: calibrateConfidence, predictGradingCNN.

    rawConfidences = rawConfidences(:);
    wasCorrect = double(wasCorrect(:));

    nll = @(p) -sum( wasCorrect .* log(sigmoidFn(p(1)*rawConfidences + p(2)) + eps) + ...
                      (1 - wasCorrect) .* log(1 - sigmoidFn(p(1)*rawConfidences + p(2)) + eps) );

    p0 = [1, 0];
    opts = optimset('Display', 'off', 'MaxIter', 500);
    pFit = fminsearch(nll, p0, opts);

    calibParams.a = pFit(1);
    calibParams.b = pFit(2);
end

function y = sigmoidFn(x)
    y = 1 ./ (1 + exp(-x));
end
