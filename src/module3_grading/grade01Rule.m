function ruleResult = grade01Rule(trackAResult, trackBResult)
%GRADE01RULE Module 3's deterministic Grade 0/1 rule, straight off Module 2.
%   ruleResult = grade01Rule(trackAResult, trackBResult)
%
%   trackAResult: output of segmentStructures.m (Track A masks)
%   trackBResult: output of detectMicroaneurysmsV2.m (Track B candidates)
%
%   ICDR defines this boundary as lesion presence, not visual subtlety:
%   Grade 1 = microaneurysms and nothing else. So:
%     - Track B: 0 confirmed MA, Track A: nothing else -> Grade 0
%     - Track B: >=1 confirmed MA, Track A: nothing else -> Grade 1
%     - Track B has an ambiguous candidate -> rule doesn't commit,
%       defers to the CNN (see gradeImage.m)
%     - Track A found anything besides background/retina context ->
%       rule implies "referable-leaning" (not a specific grade - that
%       comes from the CNN) rather than committing to 0/1
%
%   Returns ruleResult with fields:
%     .committed        - true if the rule assigns an exact grade (0 or 1)
%     .grade            - 0 or 1 if committed, [] otherwise
%     .impliesReferable - true/false - the rule's implicit referable-or-not
%                          stance, used for the disagreement check even
%                          when .committed is false (see disagreementFlag.m)
%     .reason           - plain-language explanation
%
%   See also: disagreementFlag, gradeImage, segmentStructures,
%   detectMicroaneurysmsV2.

    % "Nothing else" = no confirmed/ambiguous findings in any Track A
    % class besides Background and Retina (the context/background
    % classes - see trainTrackA.m's class list).
    ignoredClasses = {'Background', 'Retina'};
    trackAClassNames = trackAResult.classNames;
    otherLesionFound = false;
    for i = 1:numel(trackAClassNames)
        name = trackAClassNames{i};
        if any(strcmp(name, ignoredClasses))
            continue;
        end
        fieldName = matlab.lang.makeValidName(name);
        maskPixels = nnz(trackAResult.masks.(fieldName));
        % Small pixel-count noise floor - a handful of stray pixels
        % shouldn't count as "found a lesion".
        if maskPixels > 25
            otherLesionFound = true;
            break;
        end
    end

    if otherLesionFound
        ruleResult.committed = false;
        ruleResult.grade = [];
        ruleResult.impliesReferable = true;
        ruleResult.reason = 'Track A found lesions beyond MA - implies referable (2+), exact grade from CNN.';
        return
    end

    if trackBResult.hasAmbiguous
        ruleResult.committed = false;
        ruleResult.grade = [];
        ruleResult.impliesReferable = []; % genuinely unknown - defer entirely to the CNN
        ruleResult.reason = 'MA confidence in the ambiguous band - rule does not commit, CNN decides alone.';
        return
    end

    if trackBResult.confirmedCount == 0
        ruleResult.committed = true;
        ruleResult.grade = 0;
        ruleResult.impliesReferable = false;
        ruleResult.reason = 'No confirmed MA, nothing else found by Track A -> Grade 0.';
    else
        ruleResult.committed = true;
        ruleResult.grade = 1;
        ruleResult.impliesReferable = false;
        ruleResult.reason = sprintf( ...
            '%d confirmed MA, nothing else found by Track A -> Grade 1.', trackBResult.confirmedCount);
    end
end
