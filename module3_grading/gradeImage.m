function gradeResult = gradeImage(rgbImage, trackAResult, trackBResult, gradingModelPath)
%GRADEIMAGE Module 3 orchestrator: rule + CNN + disagreement flag, end to end.
%   gradeResult = gradeImage(rgbImage, trackAResult, trackBResult, gradingModelPath)
%
%   trackAResult: output of segmentStructures.m
%   trackBResult: output of detectMicroaneurysmsV2.m
%
%   Runs grade01Rule.m and predictGradingCNN.m (the CNN always runs,
%   regardless of the rule's outcome), then disagreementFlag.m to
%   reconcile them.
%
%   See also: grade01Rule, predictGradingCNN, disagreementFlag.

    ruleResult = grade01Rule(trackAResult, trackBResult);
    cnnResult = predictGradingCNN(rgbImage, gradingModelPath);
    flagResult = disagreementFlag(ruleResult, cnnResult, trackAResult, trackBResult);

    gradeResult.rule = ruleResult;
    gradeResult.cnn = cnnResult;
    gradeResult.flag = flagResult;
    gradeResult.shownGrade = flagResult.shownGrade;
    gradeResult.isReferable = gradeResult.shownGrade >= 2;
end
