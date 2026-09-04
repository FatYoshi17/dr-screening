function flagResult = disagreementFlag(ruleResult, cnnResult, trackAResult, trackBResult)
%DISAGREEMENTFLAG Compare the rule's implicit stance against the CNN's independent read.
%   flagResult = disagreementFlag(ruleResult, cnnResult, trackAResult, trackBResult)
%
%   The CNN is trained on the full 0-4 range and runs on every image
%   regardless of which path decides the shown grade, giving two
%   independent reads to compare:
%
%     Module 2 found         | Grade shown | CNN's read | Outcome
%     nothing / MA only      | rule 0/1    | also 0/1   | agree, no flag
%     nothing / MA only      | rule 0/1    | CNN says 2+| HIGH priority - possible missed disease
%     other lesions present  | CNN 2/3/4   | CNN agrees | agree, no flag
%     other lesions present  | CNN 2/3/4   | CNN says 0/1| LOW priority - possible false alarm
%     other lesions, no MA   | -           | -          | not a flag, logged for MA-detector diagnostics only
%
%   Returns flagResult with fields:
%     .shownGrade     - the grade actually shown to the user
%     .flagged        - true/false
%     .priority       - 'none' | 'high' | 'low'
%     .message        - plain-language explanation for the report
%     .showConfidence - false when flagged (per Module 4's report rules
%                        - no confidence number shown on a flagged case)
%
%   See also: grade01Rule, predictGradingCNN, gradeImage,
%   generateAnnotatedReport (Module 4).

    cnnGrade = cnnResult.grade;
    cnnSaysReferable = cnnGrade >= 2;

    if ruleResult.committed
        % Rule committed to an exact 0 or 1.
        shownGrade = ruleResult.grade;
        if cnnSaysReferable
            flagResult.flagged = true;
            flagResult.priority = 'high';
            flagResult.message = sprintf( ...
                ['Rule path: Grade %d, no significant lesions found. ' ...
                 'CNN: Grade %d, looks referable.'], ruleResult.grade, cnnGrade);
        else
            flagResult.flagged = false;
            flagResult.priority = 'none';
            flagResult.message = 'Rule and CNN agree.';
        end

    elseif isequal(ruleResult.impliesReferable, true)
        % Track A found other lesions - rule implies referable, CNN
        % supplies the actual 2/3/4 grade.
        shownGrade = cnnGrade;
        if cnnSaysReferable
            flagResult.flagged = false;
            flagResult.priority = 'none';
            flagResult.message = 'Rule and CNN agree.';
        else
            flagResult.flagged = true;
            flagResult.priority = 'low';
            lesionList = listOtherLesions(trackAResult);
            flagResult.message = sprintf( ...
                'Module 2 found: %s. CNN grade: %d.', lesionList, cnnGrade);
        end

    else
        % Ambiguous MA candidate - rule deferred entirely, CNN decides alone.
        shownGrade = cnnGrade;
        flagResult.flagged = false;
        flagResult.priority = 'none';
        flagResult.message = 'MA confidence was ambiguous - CNN decided alone (no rule opinion to compare).';
    end

    % Special case from the spec: other lesions present but zero MA -
    % logged silently for aggregate MA-detector diagnostics, never
    % surfaced as a flag (advanced lesions already imply referable
    % regardless of MA count, so an MA miss here doesn't change the
    % outcome).
    if isequal(ruleResult.impliesReferable, true) && trackBResult.confirmedCount == 0 && ~trackBResult.hasAmbiguous
        flagResult.silentDiagnosticNote = 'Other lesions present, zero MA detected - logged for MA-detector diagnostics.';
    else
        flagResult.silentDiagnosticNote = '';
    end

    flagResult.shownGrade = shownGrade;
    % Confidence solved by construction: shown whenever rule and CNN
    % agree (or the rule deferred cleanly), withheld on any flagged case.
    flagResult.showConfidence = ~flagResult.flagged;
end

function lesionList = listOtherLesions(trackAResult)
    ignoredClasses = {'Background', 'Retina'};
    found = {};
    for i = 1:numel(trackAResult.classNames)
        name = trackAResult.classNames{i};
        if any(strcmp(name, ignoredClasses)), continue; end
        fieldName = matlab.lang.makeValidName(name);
        if nnz(trackAResult.masks.(fieldName)) > 25
            found{end+1} = name; %#ok<AGROW>
        end
    end
    if isempty(found)
        lesionList = 'none';
    else
        lesionList = strjoin(found, ', ');
    end
end
