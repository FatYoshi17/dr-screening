function recommendation = getFollowUpRecommendation(shownGrade, isFlagged)
%GETFOLLOWUPRECOMMENDATION Plain-language review/follow-up action for the report's first page.
%   recommendation = getFollowUpRecommendation(shownGrade, isFlagged)
%
%   Intervals follow standard ICDR severity-to-follow-up conventions
%   (general screening guidance, not this project's own derivation) -
%   present as a starting point for the reviewing clinician to adjust,
%   not a clinical directive. A flagged (rule/CNN disagreement) case
%   always gets bumped to manual review regardless of the grade shown,
%   since the disagreement itself is the more important signal there.
%
%   See also: disagreementFlag, gradeImage, generateAnnotatedReport.

    if isFlagged
        recommendation = 'Manual review recommended - automated grading opinions disagreed on this image.';
        return
    end

    switch shownGrade
        case 0
            recommendation = 'No diabetic retinopathy detected. Routine annual screening.';
        case 1
            recommendation = 'Mild NPDR (microaneurysms only). Routine follow-up in ~12 months.';
        case 2
            recommendation = 'Moderate NPDR. Ophthalmology referral recommended within 3-6 months.';
        case 3
            recommendation = 'Severe NPDR. Ophthalmology referral recommended within 1 month.';
        case 4
            recommendation = 'Proliferative DR. URGENT ophthalmology referral required (1-2 weeks).';
        otherwise
            recommendation = 'Grade not recognized - manual review required.';
    end
end
