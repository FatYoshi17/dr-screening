function m = metrics(predMask, gtMask)
%METRICS Single source of truth for sensitivity/specificity/Dice/IoU.
%   m = metrics(predMask, gtMask) compares two same-size logical masks
%   (or two equal-length logical/binary vectors of predicted vs. true
%   referable/non-referable labels) and returns a struct:
%     m.TP, m.FP, m.TN, m.FN
%     m.sensitivity  - TP/(TP+FN)  a.k.a. recall — brief target >90%
%     m.specificity  - TN/(TN+FP)                 brief target >85%
%     m.precision    - TP/(TP+FP)
%     m.dice         - 2*TP/(2*TP+FP+FN)          standard segmentation overlap metric
%     m.iou          - TP/(TP+FP+FN)               a.k.a. Jaccard index
%
%   Use this for EVERY sensitivity/specificity number reported anywhere
%   in the project (Module 2 lesion detection, Module 3 grading, the
%   Messidor-2 external validation run) so numbers in the PPT are
%   guaranteed to be computed the same way everywhere.

    predMask = logical(predMask);
    gtMask = logical(gtMask);
    if ~isequal(size(predMask), size(gtMask))
        error('metrics:sizeMismatch', 'predMask and gtMask must be the same size.');
    end

    TP = nnz(predMask & gtMask);
    FP = nnz(predMask & ~gtMask);
    TN = nnz(~predMask & ~gtMask);
    FN = nnz(~predMask & gtMask);

    m.TP = TP; m.FP = FP; m.TN = TN; m.FN = FN;
    m.sensitivity = TP / max(TP + FN, 1);
    m.specificity = TN / max(TN + FP, 1);
    m.precision   = TP / max(TP + FP, 1);
    m.dice = 2*TP / max(2*TP + FP + FN, 1);
    m.iou  = TP / max(TP + FP + FN, 1);
end
