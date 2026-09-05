function reportPath = generateAnnotatedReport(rgbImage, enhImg, qc, trackAResult, trackBResult, ...
    gradeResult, camResult, overlapResult, patientInfo, imageId, reportPath)
%GENERATEANNOTATEDREPORT Module 4: build the final multi-page clinical report.
%   reportPath = generateAnnotatedReport(rgbImage, enhImg, qc, trackAResult,
%       trackBResult, gradeResult, camResult, overlapResult, patientInfo,
%       imageId, reportPath)
%
%   Page layout follows direct reviewing-ophthalmologist feedback: the
%   original single-page, three-panel technical layout put Grad-CAM
%   overlap percentages and raw lesion pixel counts on equal footing
%   with the grade itself, which is backwards for a <30-second clinical
%   read. Clinically actionable material now comes first; technical
%   detail (Grad-CAM, raw confidence, pixel-level counts) moves to a
%   later appendix page instead of competing for the same glance.
%
%     Page 1 - Patient details, grade, reliability category (not a raw
%              percentage - see categorizeReliability.m), follow-up
%              recommendation.
%     Page 2 - Original image alongside the AI-annotated interpretation,
%              plus the image quality category from Module 1.
%     Page 3 - Grading-reasons table: what Module 2 found, per finding,
%              and how the rule/CNN reasoning arrived at the shown grade.
%     Page 4 - Technical appendix: Grad-CAM heatmap, raw calibrated
%              confidence, lesion-attention overlap, raw pixel counts.
%
%   patientInfo (all optional - pass [] or omit fields for "Unknown"):
%     .diabetesControl        - 'Controlled' | 'Uncontrolled' | ''
%     .diabetesDurationYears  - numeric, or [] for unknown
%     .hba1c                  - numeric (%), or [] for unknown
%     .patientId              - string, or '' for anonymous
%
%   Saves directly to reportPath (multi-page PDF via exportgraphics'
%   Append option) and returns that path, rather than returning a
%   figure handle for the caller to export - a single figure handle
%   can't represent a multi-page document.
%
%   See also: gradeImage, computeGradCAM, lesionAttentionOverlap,
%   calibrateConfidence, categorizeReliability, getFollowUpRecommendation.

    if nargin < 9 || isempty(patientInfo)
        patientInfo = struct();
    end
    if nargin < 10 || isempty(imageId)
        imageId = 'unknown';
    end
    if nargin < 11 || isempty(reportPath)
        reportPath = fullfile('results', sprintf('report_%s.pdf', imageId));
    end
    if isfile(reportPath)
        delete(reportPath); % exportgraphics 'Append' would otherwise pile onto a stale file
    end

    flag = gradeResult.flag;
    calibConf = calibrateConfidence(gradeResult.cnn.rawConfidence);
    reliabilityCategory = categorizeReliability(calibConf);
    followUp = getFollowUpRecommendation(gradeResult.shownGrade, flag.flagged);

    page1_patientSummary(reportPath, gradeResult, flag, reliabilityCategory, followUp, patientInfo, imageId);
    page2_images(reportPath, rgbImage, enhImg, trackAResult, trackBResult, qc);
    page3_reasonsTable(reportPath, trackAResult, trackBResult, gradeResult, flag);
    page4_technicalAppendix(reportPath, camResult, overlapResult, gradeResult, calibConf, trackAResult, trackBResult);
end

function page1_patientSummary(reportPath, gradeResult, flag, reliabilityCategory, followUp, patientInfo, imageId)
    fig = figure('Visible', 'off', 'Position', [0 0 850 1100], 'Color', 'w');
    axes('Position', [0 0 1 1]); axis off;
    yPos = 0.97;

    text(0.05, yPos, 'Diabetic Retinopathy Screening Report', 'FontWeight', 'bold', 'FontSize', 18);
    yPos = yPos - 0.035;
    text(0.05, yPos, sprintf('Image ID: %s', imageId), 'FontSize', 10, 'Color', [0.4 0.4 0.4]);
    yPos = yPos - 0.05;

    % ---- Patient details ----
    text(0.05, yPos, 'Patient Details', 'FontWeight', 'bold', 'FontSize', 13);
    yPos = yPos - 0.03;
    line([0.05 0.95], [yPos yPos], 'Color', [0.7 0.7 0.7]);
    yPos = yPos - 0.03;

    text(0.07, yPos, sprintf('Patient ID: %s', valueOrUnknown(patientInfo, 'patientId', '%s')), 'FontSize', 11);
    yPos = yPos - 0.03;
    text(0.07, yPos, sprintf('Diabetes control: %s', valueOrUnknown(patientInfo, 'diabetesControl', '%s')), 'FontSize', 11);
    yPos = yPos - 0.03;
    text(0.07, yPos, sprintf('Duration of diabetes: %s', valueOrUnknown(patientInfo, 'diabetesDurationYears', '%g years')), 'FontSize', 11);
    yPos = yPos - 0.03;
    text(0.07, yPos, sprintf('HbA1c: %s', valueOrUnknown(patientInfo, 'hba1c', '%.1f%%')), 'FontSize', 11);
    yPos = yPos - 0.06;

    % ---- Grade / outcome ----
    text(0.05, yPos, 'Screening Result', 'FontWeight', 'bold', 'FontSize', 13);
    yPos = yPos - 0.03;
    line([0.05 0.95], [yPos yPos], 'Color', [0.7 0.7 0.7]);
    yPos = yPos - 0.05;

    gradeColor = ternary(gradeResult.isReferable, [0.8 0 0], [0 0.5 0]);
    text(0.07, yPos, sprintf('Grade %d', gradeResult.shownGrade), 'FontWeight', 'bold', 'FontSize', 28, 'Color', gradeColor);
    yPos = yPos - 0.045;
    text(0.07, yPos, ternary(gradeResult.isReferable, 'REFERABLE', 'Non-referable'), ...
        'FontWeight', 'bold', 'FontSize', 14, 'Color', gradeColor);
    yPos = yPos - 0.045;

    if flag.flagged
        bannerText = ternary(strcmp(flag.priority, 'high'), ...
            'FLAGGED - HIGH PRIORITY: automated opinions disagree, possible missed disease', ...
            'FLAGGED - LOW PRIORITY: automated opinions disagree, possible false alarm');
        text(0.07, yPos, bannerText, 'Color', [0.8 0 0], 'FontWeight', 'bold', 'FontSize', 11, ...
            'BackgroundColor', [1 0.9 0.9], 'Interpreter', 'none');
        yPos = yPos - 0.05;
    else
        text(0.07, yPos, sprintf('Reliability: %s', reliabilityCategory), 'FontSize', 12, ...
            'Color', reliabilityColor(reliabilityCategory));
        yPos = yPos - 0.05;
    end

    % ---- Follow-up ----
    text(0.05, yPos, 'Recommended Action', 'FontWeight', 'bold', 'FontSize', 13);
    yPos = yPos - 0.03;
    line([0.05 0.95], [yPos yPos], 'Color', [0.7 0.7 0.7]);
    yPos = yPos - 0.04;
    text(0.07, yPos, followUp, 'FontSize', 12, 'Interpreter', 'none', ...
        'BackgroundColor', [0.92 0.96 1], 'FontWeight', 'bold');
    yPos = yPos - 0.06;

    text(0.05, 0.03, ['Research prototype - AI-assisted screening aid, not a diagnosis. ' ...
        'Clinical judgment of the reviewing practitioner takes precedence.'], ...
        'FontSize', 8, 'Color', [0.5 0.5 0.5], 'Interpreter', 'none');

    exportgraphics(fig, reportPath, 'Append', false);
    close(fig);
end

function page2_images(reportPath, rgbImage, enhImg, trackAResult, trackBResult, qc)
    fig = figure('Visible', 'off', 'Position', [0 0 1400 800], 'Color', 'w');

    subplot(1, 2, 1);
    imshow(im2uint8(rgbImage));
    title('Original Image', 'FontSize', 12);

    subplot(1, 2, 2);
    lesionOverlay = buildLesionOverlay(enhImg, trackAResult, trackBResult);
    imshow(lesionOverlay);
    title('AI-Interpreted Image (findings overlaid)', 'FontSize', 12);

    qualityLabel = qualityCategoryLabel(qc.decision);
    sgtitle(sprintf('Image Quality: %s', qualityLabel), 'FontSize', 13, 'FontWeight', 'bold', ...
        'Color', qualityColor(qc.decision));

    exportgraphics(fig, reportPath, 'Append', true);
    close(fig);
end

function page3_reasonsTable(reportPath, trackAResult, trackBResult, gradeResult, flag)
    fig = figure('Visible', 'off', 'Position', [0 0 850 1100], 'Color', 'w');
    axes('Position', [0 0 1 1]); axis off;
    yPos = 0.96;

    text(0.05, yPos, 'Grading Reasons', 'FontWeight', 'bold', 'FontSize', 16);
    yPos = yPos - 0.04;

    headers = {'Finding', 'Detected', 'Detail'};
    colX = [0.05, 0.45, 0.62];
    rows = buildFindingsRows(trackAResult, trackBResult);

    yPos = drawTableHeader(headers, colX, yPos);
    for i = 1:size(rows, 1)
        yPos = drawTableRow(rows(i, :), colX, yPos, mod(i, 2) == 0);
    end
    yPos = yPos - 0.03;

    text(0.05, yPos, 'How the Grade Was Determined', 'FontWeight', 'bold', 'FontSize', 13);
    yPos = yPos - 0.035;
    line([0.05 0.95], [yPos yPos], 'Color', [0.7 0.7 0.7]);
    yPos = yPos - 0.04;

    text(0.07, yPos, 'Rule-based path (Module 2 findings):', 'FontWeight', 'bold', 'FontSize', 10);
    yPos = yPos - 0.03;
    yPos = wrapText(0.09, yPos, gradeResult.rule.reason, 9, 0.86);
    yPos = yPos - 0.02;

    text(0.07, yPos, sprintf('Deep-learning grading model: Grade %d', gradeResult.cnn.grade), ...
        'FontWeight', 'bold', 'FontSize', 10);
    yPos = yPos - 0.03;

    text(0.07, yPos, sprintf('Final shown grade: %d', gradeResult.shownGrade), ...
        'FontWeight', 'bold', 'FontSize', 10);
    yPos = yPos - 0.03;
    yPos = wrapText(0.09, yPos, flag.message, 9, 0.86);

    exportgraphics(fig, reportPath, 'Append', true);
    close(fig);
end

function page4_technicalAppendix(reportPath, camResult, overlapResult, gradeResult, calibConf, trackAResult, trackBResult)
    fig = figure('Visible', 'off', 'Position', [0 0 1400 900], 'Color', 'w');

    subplot(1, 2, 1);
    imshow(camResult.overlayImage);
    title(sprintf('Grad-CAM (lesion-attention overlap: %.0f%%)', overlapResult.overlapScore * 100));

    subplot(1, 2, 2);
    axis off;
    yPos = 0.95;
    text(0, yPos, 'Technical Appendix', 'FontWeight', 'bold', 'FontSize', 14);
    yPos = yPos - 0.06;

    text(0, yPos, sprintf('CNN continuous score: %.2f (0-4 scale)', gradeResult.cnn.continuousScore), 'FontSize', 10);
    yPos = yPos - 0.045;
    text(0, yPos, sprintf('CNN raw (uncalibrated) confidence: %.2f', gradeResult.cnn.rawConfidence), 'FontSize', 10);
    yPos = yPos - 0.045;
    text(0, yPos, sprintf('Calibrated confidence: %.0f%%', calibConf * 100), 'FontSize', 10);
    yPos = yPos - 0.045;
    text(0, yPos, sprintf('Lesion-attention overlap: %.0f%%', overlapResult.overlapScore * 100), 'FontSize', 10);
    yPos = yPos - 0.045;
    if overlapResult.hasUnexplainedRegion
        text(0, yPos, 'Note: Grad-CAM highlights a region Module 2 did not flag - worth a second look.', ...
            'FontSize', 9, 'Color', [0.5 0.3 0], 'Interpreter', 'none');
        yPos = yPos - 0.05;
    end

    text(0, yPos, 'Raw pixel-level lesion counts:', 'FontWeight', 'bold', 'FontSize', 10);
    yPos = yPos - 0.04;
    lesionList = summarizeLesions(trackAResult, trackBResult);
    for i = 1:numel(lesionList)
        text(0.02, yPos, ['- ' lesionList{i}], 'FontSize', 9);
        yPos = yPos - 0.035;
    end

    exportgraphics(fig, reportPath, 'Append', true);
    close(fig);
end

function rows = buildFindingsRows(trackAResult, trackBResult)
    rows = {};
    ignoredClasses = {'Background', 'Retina'};
    for i = 1:numel(trackAResult.classNames)
        name = trackAResult.classNames{i};
        if any(strcmp(name, ignoredClasses)), continue; end
        fieldName = matlab.lang.makeValidName(name);
        pixelCount = nnz(trackAResult.masks.(fieldName));
        detected = ternary(pixelCount > 25, 'Yes', 'No');
        detail = ternary(pixelCount > 25, sprintf('%d px region', pixelCount), '-');
        rows(end+1, :) = {name, detected, detail}; %#ok<AGROW>
    end
    maDetected = ternary(trackBResult.confirmedCount > 0, 'Yes', ternary(trackBResult.hasAmbiguous, 'Ambiguous', 'No'));
    maDetail = sprintf('%d confirmed, %s ambiguous candidate(s)', trackBResult.confirmedCount, ...
        ternary(trackBResult.hasAmbiguous, 'has', 'no'));
    rows(end+1, :) = {'Microaneurysms', maDetected, maDetail};
end

function yPos = drawTableHeader(headers, colX, yPos)
    for i = 1:numel(headers)
        text(colX(i), yPos, headers{i}, 'FontWeight', 'bold', 'FontSize', 10);
    end
    yPos = yPos - 0.015;
    line([0.05 0.95], [yPos yPos], 'Color', [0.3 0.3 0.3], 'LineWidth', 1);
    yPos = yPos - 0.03;
end

function yPos = drawTableRow(rowData, colX, yPos, shaded)
    if shaded
        rectangle('Position', [0.05, yPos - 0.015, 0.9, 0.03], 'FaceColor', [0.95 0.95 0.95], 'EdgeColor', 'none');
    end
    for i = 1:numel(rowData)
        text(colX(i), yPos, rowData{i}, 'FontSize', 9, 'Interpreter', 'none');
    end
    yPos = yPos - 0.032;
end

function yPos = wrapText(x, yPos, str, fontSize, maxWidthFraction)
    % Simple char-count-based wrap - good enough for the short,
    % plain-language reason strings this pipeline generates.
    charsPerLine = round(maxWidthFraction * 110);
    words = strsplit(str, ' ');
    line_ = '';
    for i = 1:numel(words)
        candidate = strtrim([line_ ' ' words{i}]);
        if numel(candidate) > charsPerLine && ~isempty(line_)
            text(x, yPos, line_, 'FontSize', fontSize, 'Interpreter', 'none');
            yPos = yPos - 0.028;
            line_ = words{i};
        else
            line_ = candidate;
        end
    end
    if ~isempty(line_)
        text(x, yPos, line_, 'FontSize', fontSize, 'Interpreter', 'none');
        yPos = yPos - 0.028;
    end
end

function lesionList = summarizeLesions(trackAResult, trackBResult)
    lesionList = {};
    ignoredClasses = {'Background', 'Retina'};
    for i = 1:numel(trackAResult.classNames)
        name = trackAResult.classNames{i};
        if any(strcmp(name, ignoredClasses)), continue; end
        fieldName = matlab.lang.makeValidName(name);
        pixelCount = nnz(trackAResult.masks.(fieldName));
        if pixelCount > 25
            lesionList{end+1} = sprintf('%s (%d px)', name, pixelCount); %#ok<AGROW>
        end
    end
    confirmedMA = sum(strcmp({trackBResult.candidates.status}, 'confirmed'));
    if confirmedMA > 0
        lesionList{end+1} = sprintf('Microaneurysms: %d confirmed', confirmedMA); %#ok<AGROW>
    end
    if isempty(lesionList)
        lesionList = {'None detected'};
    end
end

function label = qualityCategoryLabel(decision)
    switch char(decision)
        case 'Pass'
            label = 'Good';
        case 'Enhance'
            label = 'Acceptable (auto-enhanced)';
        case 'Reject'
            label = 'Poor';
        otherwise
            label = char(decision);
    end
end

function color = qualityColor(decision)
    switch char(decision)
        case 'Pass'
            color = [0 0.5 0];
        case 'Enhance'
            color = [0.8 0.6 0];
        case 'Reject'
            color = [0.8 0 0];
        otherwise
            color = [0 0 0];
    end
end

function color = reliabilityColor(category)
    switch category
        case 'Reliable'
            color = [0 0.5 0];
        case 'Moderate'
            color = [0.8 0.6 0];
        otherwise
            color = [0.8 0 0];
    end
end

function str = valueOrUnknown(s, fieldName, fmt)
    if isfield(s, fieldName) && ~isempty(s.(fieldName))
        str = sprintf(fmt, s.(fieldName));
    else
        str = 'Unknown';
    end
end

function out = ternary(cond, a, b)
    if cond, out = a; else, out = b; end
end
