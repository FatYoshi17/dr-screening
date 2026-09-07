function reportPath = generateAnnotatedReport(rgbImage, enhImg, qc, trackAResult, trackBResult, ...
    gradeResult, camResult, overlapResult, patientInfo, imageId, reportPath)
%GENERATEANNOTATEDREPORT Module 4: build the final multi-page clinical report.
%   reportPath = generateAnnotatedReport(rgbImage, enhImg, qc, trackAResult,
%       trackBResult, gradeResult, camResult, overlapResult, patientInfo,
%       imageId, reportPath)
%
%   Deliberately styled to match the web app's report page (same numbered
%   sections, pill-style status badges, InfoGrid label/value layout,
%   findings table columns) rather than its own separate visual language -
%   this and DR-SCREENING-WEBPORTAL/src/pages/screening/ReportPage.tsx are
%   two renderers of the same report and should read as one product, not
%   two. Per-lesion location/count/reliability come from the shared
%   buildLesionFindings.m so the two surfaces can't silently disagree.
%
%     Page 1 - Branded header, patient details, Section 1 Recommendation
%              (status pill, action plan box, disagreement banner if
%              flagged).
%     Page 2 - Section 2 Retinal Findings: original image + quality pill
%              alongside the findings table (lesion type / count /
%              location / reliability category).
%     Page 3 - Section 3 DR Severity Assessment (grade/referable/pathway/
%              agreement) + Section 4 AI Analysis Visualizations
%              (segmentation overlay + Grad-CAM, with the color legend).
%     Page 4 - Grading-reasons detail table and the technical appendix
%              (raw confidence, pixel counts) - MATLAB-report-only detail
%              beyond what the web report shows inline.
%
%   patientInfo (all optional - pass [] or omit fields for "Unknown"):
%     .diabetesControl        - 'Controlled' | 'Uncontrolled' | ''
%     .diabetesDurationYears  - numeric, or [] for unknown
%     .hba1c                  - numeric (%), or [] for unknown
%     .patientId              - string, or '' for anonymous
%
%   Saves directly to reportPath (multi-page PDF via exportgraphics'
%   Append option) and returns that path.
%
%   See also: gradeImage, computeGradCAM, lesionAttentionOverlap,
%   calibrateConfidence, categorizeReliability, getFollowUpRecommendation,
%   buildLesionFindings.

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
    findings = buildLesionFindings(trackAResult, trackBResult);

    page1_header_recommendation(reportPath, gradeResult, flag, followUp, patientInfo, imageId);
    page2_retinalFindings(reportPath, rgbImage, qc, findings);
    page3_severityAndVisualizations(reportPath, enhImg, trackAResult, trackBResult, camResult, overlapResult, gradeResult);
    page4_reasonsAndAppendix(reportPath, trackAResult, trackBResult, gradeResult, flag, camResult, overlapResult, calibConf, reliabilityCategory);
end

% ============================================================
% Shared layout constants and helpers
% ============================================================

function step = lh(fontSize, figHeightPx)
%LH Vertical step (normalized figure units) for one line of text at
%fontSize points, on a figure figHeightPx pixels tall (~1.35x leading,
%96->72 DPI conversion baked in).
    step = fontSize * 1.35 / (figHeightPx * 0.75);
end

function COL = reportColors()
    COL.ink        = [0.11 0.15 0.19];
    COL.inkDim     = [0.38 0.44 0.51];
    COL.inkFaint   = [0.58 0.63 0.69];
    COL.line       = [0.85 0.87 0.90];
    COL.lineStrong = [0.65 0.68 0.73];
    COL.cardBg     = [0.98 0.98 0.99];
    COL.brand      = [0.02 0.40 0.36];
    COL.priorityBg = [0.99 0.93 0.95]; COL.priorityText = [0.76 0.10 0.24];
    COL.reviewBg   = [0.99 0.95 0.85]; COL.reviewText   = [0.71 0.42 0.04];
    COL.routineBg  = [0.90 0.97 0.94]; COL.routineText  = [0.02 0.45 0.31];
    COL.actionBg   = [0.92 0.96 1.00]; COL.actionText   = [0.10 0.25 0.45]; COL.actionEdge = [0.72 0.82 0.94];
end

function [bg, text_] = resultTone(resultCategory, COL)
    switch resultCategory
        case 'PRIORITY'
            bg = COL.priorityBg; text_ = COL.priorityText;
        case 'REVIEW'
            bg = COL.reviewBg; text_ = COL.reviewText;
        otherwise
            bg = COL.routineBg; text_ = COL.routineText;
    end
end

function cat = resultCategoryOf(gradeResult)
    if gradeResult.flag.flagged
        cat = ternary(strcmp(gradeResult.flag.priority, 'high'), 'PRIORITY', 'REVIEW');
    elseif gradeResult.shownGrade >= 3
        cat = 'PRIORITY';
    elseif gradeResult.shownGrade == 2
        cat = 'REVIEW';
    else
        cat = 'ROUTINE';
    end
end

function newAx = freshAxes()
    newAx = axes('Position', [0 0 1 1]); axis off; hold on; xlim([0 1]); ylim([0 1]);
end

function yPos = drawChipHeader(number, titleStr, MX, yPos, PAGE_W, PAGE_H, COL)
%DRAWCHIPHEADER Numbered gray chip + bold uppercase title + full-width
%divider, matching the web report's section header style.
    chipW = 0.028; chipH = lh(11, PAGE_H) + 0.010;
    rectangle('Position', [MX, yPos - chipH*0.78, chipW, chipH], ...
        'FaceColor', COL.cardBg, 'EdgeColor', 'none', 'Curvature', 0.3);
    text(MX + chipW/2 * (850/PAGE_W), yPos - chipH*0.40, number, 'FontSize', 10, ...
        'Color', COL.inkFaint, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
    text(MX + chipW + 0.014, yPos - chipH*0.40, upper(titleStr), 'FontSize', 12.5, ...
        'FontWeight', 'bold', 'Color', COL.ink, 'VerticalAlignment', 'middle');
    yPos = yPos - chipH - 0.010;
    line([MX 1-MX], [yPos yPos], 'Color', COL.ink, 'LineWidth', 1.4);
    yPos = yPos - 0.026;
end

function drawPill(x, y, w, h, str, textColor, edgeColor)
    rectangle('Position', [x, y, w, h], 'FaceColor', 'w', 'EdgeColor', edgeColor, ...
        'LineWidth', 1.1, 'Curvature', 0.9);
    text(x + w/2, y + h/2, str, 'FontSize', 11, 'FontWeight', 'bold', 'Color', textColor, ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle');
end

function lines = wrapTextLines(str, fontSize, maxWidthFraction)
    charsPerLine = max(20, round(maxWidthFraction * 118));
    words = strsplit(strtrim(str), ' ');
    lines = {};
    line_ = '';
    for i = 1:numel(words)
        candidate = strtrim([line_ ' ' words{i}]);
        if numel(candidate) > charsPerLine && ~isempty(line_)
            lines{end+1} = line_; %#ok<AGROW>
            line_ = words{i};
        else
            line_ = candidate;
        end
    end
    if ~isempty(line_)
        lines{end+1} = line_; %#ok<AGROW>
    end
end

function yPos = drawWrappedLines(x, yPos, lines, fontSize, figHeightPx, color)
    if nargin < 6, color = [0.11 0.15 0.19]; end
    step = lh(fontSize, figHeightPx);
    for i = 1:numel(lines)
        text(x, yPos, lines{i}, 'FontSize', fontSize, 'Interpreter', 'none', 'Color', color);
        yPos = yPos - step;
    end
end

function drawInfoGrid(x0, yPos, totalWidth, fields, PAGE_H, COL, nCols)
%DRAWINFOGRID Small gray uppercase label above a bold value, laid out in
%nCols columns - matches the web report's InfoGrid component.
    if nargin < 7, nCols = 4; end
    colW = totalWidth / nCols;
    for i = 1:size(fields, 1)
        col = mod(i - 1, nCols);
        row = floor((i - 1) / nCols);
        fx = x0 + col * colW;
        fy = yPos - row * (lh(9, PAGE_H) + lh(12, PAGE_H) + 0.020);
        text(fx, fy, upper(fields{i,1}), 'FontSize', 8.5, 'Color', COL.inkFaint, 'FontWeight', 'bold');
        valColor = COL.ink;
        if size(fields, 2) >= 3 && ~isempty(fields{i,3})
            valColor = fields{i,3};
        end
        text(fx, fy - lh(9, PAGE_H) - 0.008, fields{i,2}, 'FontSize', 12, 'FontWeight', 'bold', ...
            'Color', valColor, 'Interpreter', 'none');
    end
end

% ============================================================
% Page 1 - branded header, patient info, Section 1 Recommendation
% ============================================================

function page1_header_recommendation(reportPath, gradeResult, flag, followUp, patientInfo, imageId)
    PAGE_H = 1100; PAGE_W = 850;
    COL = reportColors();
    fig = figure('Visible', 'off', 'Position', [0 0 PAGE_W PAGE_H], 'Color', 'w');
    freshAxes();
    MX = 0.065;

    % ---- Branded header ----
    yPos = 0.965;
    rectangle('Position', [MX, yPos - 0.032, 0.045, 0.032], 'FaceColor', COL.brand, ...
        'EdgeColor', 'none', 'Curvature', 0.3);
    text(MX + 0.0225, yPos - 0.016, 'DS', 'FontSize', 13, 'FontWeight', 'bold', 'Color', 'w', ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle');
    text(MX + 0.062, yPos - 0.006, 'DrishtiSetu', 'FontSize', 12, 'FontWeight', 'bold', 'Color', COL.ink, ...
        'VerticalAlignment', 'middle');
    text(MX + 0.062, yPos - 0.023, 'AI-Assisted Automated Fundus Analysis', 'FontSize', 8.5, ...
        'Color', COL.inkFaint, 'FontAngle', 'italic', 'VerticalAlignment', 'middle');
    text(1 - MX, yPos - 0.006, sprintf('Image ID: %s', imageId), 'FontSize', 9.5, 'Color', COL.inkDim, ...
        'HorizontalAlignment', 'right', 'Interpreter', 'none');
    text(1 - MX, yPos - 0.021, sprintf('Date: %s', datestr(now, 'mm/dd/yyyy')), 'FontSize', 9.5, ... %#ok<TNOW1,DATST>
        'Color', COL.inkFaint, 'HorizontalAlignment', 'right');
    yPos = yPos - 0.050;
    line([MX 1-MX], [yPos yPos], 'Color', COL.ink, 'LineWidth', 1.4);
    yPos = yPos - 0.038;

    % ---- Patient info (plain InfoGrid, no card box) ----
    fields = {
        'Patient ID', valueOrUnknown(patientInfo, 'patientId', '%s'), [];
        'Diabetes Control', valueOrUnknown(patientInfo, 'diabetesControl', '%s'), [];
        'Duration of Diabetes', valueOrUnknown(patientInfo, 'diabetesDurationYears', '%g years'), [];
        'HbA1c', valueOrUnknown(patientInfo, 'hba1c', '%.1f%%'), [];
    };
    drawInfoGrid(MX, yPos, 1 - 2*MX, fields, PAGE_H, COL, 4);
    yPos = yPos - (lh(9, PAGE_H) + lh(12, PAGE_H) + 0.020) - 0.026;

    % ---- Section 1: Recommendation ----
    yPos = drawChipHeader('1', 'Recommendation', MX, yPos, PAGE_W, PAGE_H, COL);

    resultCategory = resultCategoryOf(gradeResult);
    [pillBg, pillText] = resultTone(resultCategory, COL); %#ok<ASGLU>
    pillW = 0.20; pillH = 0.040;
    drawPill(MX, yPos - pillH, pillW, pillH, resultCategory, pillText, pillText);
    yPos = yPos - pillH - 0.026;

    % Recommended clinical action plan box (dynamically sized to wrapped text)
    actionLines = wrapTextLines(followUp, 12, 1 - 2*MX - 0.05);
    headerH = lh(9, PAGE_H) + 0.020;
    bodyH = numel(actionLines) * lh(12, PAGE_H);
    boxH = headerH + bodyH + 0.030;
    rectangle('Position', [MX, yPos - boxH, 1 - 2*MX, boxH], ...
        'FaceColor', COL.actionBg, 'EdgeColor', COL.actionEdge, 'LineWidth', 1, 'Curvature', 0.04);
    inY = yPos - 0.022;
    text(MX + 0.025, inY, 'RECOMMENDED CLINICAL ACTION PLAN', 'FontSize', 9, 'FontWeight', 'bold', ...
        'Color', COL.inkFaint);
    inY = inY - headerH;
    drawWrappedLines(MX + 0.025, inY, actionLines, 12, PAGE_H, COL.actionText);
    yPos = yPos - boxH - 0.026;

    % Disagreement banner (replaces the removed, unsubstantiated
    % "Protocol Decision Support Verified" claim - matches the web
    % report's DisagreementBanner exactly: shown only when the rule and
    % CNN pathways actually disagree).
    if flag.flagged
        bannerText = ternary(strcmp(flag.priority, 'high'), ...
            'Automated opinions disagree - high-risk lesion pattern requires specialist confirmation.', ...
            'Automated opinions disagree - possible false alarm, specialist confirmation recommended.');
        bannerLines = wrapTextLines(bannerText, 10.5, 1 - 2*MX - 0.05);
        bHeaderH = lh(11, PAGE_H) + 0.012;
        bBodyH = numel(bannerLines) * lh(10.5, PAGE_H);
        bBoxH = bHeaderH + bBodyH + 0.026;
        rectangle('Position', [MX, yPos - bBoxH, 1 - 2*MX, bBoxH], ...
            'FaceColor', COL.priorityBg, 'EdgeColor', COL.priorityText, 'LineWidth', 1, 'Curvature', 0.04);
        inY = yPos - 0.022;
        text(MX + 0.025, inY, 'Automated Opinions Disagree', 'FontSize', 11, 'FontWeight', 'bold', ...
            'Color', COL.priorityText);
        inY = inY - bHeaderH;
        drawWrappedLines(MX + 0.025, inY, bannerLines, 10.5, PAGE_H, COL.priorityText);
    end

    % ---- Footer ----
    text(MX, 0.032, ['Research prototype - AI-assisted screening aid, not a diagnosis. ' ...
        'Clinical judgment of the reviewing practitioner takes precedence.'], ...
        'FontSize', 8, 'Color', COL.inkFaint, 'Interpreter', 'none');

    exportgraphics(fig, reportPath, 'Append', false);
    close(fig);
end

% ============================================================
% Page 2 - Section 2: Retinal Findings (image + table)
% ============================================================

function page2_retinalFindings(reportPath, rgbImage, qc, findings)
    PAGE_H = 900; PAGE_W = 1400;
    COL = reportColors();
    fig = figure('Visible', 'off', 'Position', [0 0 PAGE_W PAGE_H], 'Color', 'w');

    textAx = axes('Position', [0 0 1 1]); axis off; hold on; xlim([0 1]); ylim([0 1]); %#ok<NASGU>
    MX = 0.035;
    yPos = drawChipHeader('2', 'Retinal Findings', MX, 0.965, PAGE_W, PAGE_H, COL);
    imageTop = yPos;

    % ---- Left: original image + quality pill ----
    imgAx = axes('Position', [MX, 0.10, 0.34, imageTop - 0.20]);
    imshow(im2uint8(rgbImage), 'Parent', imgAx);
    axes(textAx); %#ok<LTARG>
    qualityLabel = qualityCategoryLabel(qc.decision);
    qColor = qualityColor(qc.decision);
    pillY = 0.055;
    drawPill(MX, pillY, 0.30, 0.038, sprintf('Overall Quality: %s', upper(qualityLabel)), qColor, qColor);

    % ---- Right: findings table ----
    tableX = MX + 0.38;
    tableW = 1 - tableX - MX;
    colX = tableX + tableW * [0, 0.32, 0.58, 0.82];
    ty = imageTop;
    headers = {'Lesion Type', 'Count', 'Location', 'Confidence'};
    for i = 1:numel(headers)
        text(colX(i), ty, upper(headers{i}), 'FontSize', 9, 'FontWeight', 'bold', 'Color', COL.inkFaint);
    end
    ty = ty - lh(9, PAGE_H) - 0.010;
    line([tableX tableX+tableW], [ty ty], 'Color', COL.lineStrong, 'LineWidth', 1.1);
    ty = ty - 0.026;

    rowStep = lh(13, PAGE_H) + 0.024;
    if isempty(findings)
        text(colX(1), ty, 'No lesions detected above the reporting threshold.', 'FontSize', 10.5, 'Color', COL.inkDim);
    end
    for i = 1:numel(findings)
        if mod(i, 2) == 0
            rectangle('Position', [tableX, ty - rowStep + lh(13,PAGE_H)*0.30, tableW, rowStep], ...
                'FaceColor', COL.cardBg, 'EdgeColor', 'none');
        end
        text(colX(1), ty, findings(i).lesionType, 'FontSize', 11, 'FontWeight', 'bold', 'Color', COL.ink, 'Interpreter', 'none');
        text(colX(2), ty, sprintf('%d', findings(i).count), 'FontSize', 11, 'Color', COL.ink);
        text(colX(3), ty, findings(i).location, 'FontSize', 10.5, 'Color', COL.inkDim, 'Interpreter', 'none');
        relColor = reliabilityColor(findings(i).reliabilityCategory, COL);
        text(colX(4), ty, findings(i).reliabilityCategory, 'FontSize', 10.5, 'FontWeight', 'bold', 'Color', relColor);
        ty = ty - rowStep;
    end

    exportgraphics(fig, reportPath, 'Append', true);
    close(fig);
end

% ============================================================
% Page 3 - Section 3: DR Severity + Section 4: AI Visualizations
% ============================================================

function page3_severityAndVisualizations(reportPath, enhImg, trackAResult, trackBResult, camResult, overlapResult, gradeResult)
    PAGE_H = 1050; PAGE_W = 1400;
    COL = reportColors();
    fig = figure('Visible', 'off', 'Position', [0 0 PAGE_W PAGE_H], 'Color', 'w');
    textAx = axes('Position', [0 0 1 1]); axis off; hold on; xlim([0 1]); ylim([0 1]); %#ok<NASGU>
    MX = 0.035;

    % ---- Section 3: DR Severity Assessment ----
    yPos = drawChipHeader('3', 'DR Severity Assessment', MX, 0.975, PAGE_W, PAGE_H, COL);
    agreementColor = ternary(gradeResult.flag.flagged == 0, COL.routineText, COL.reviewText);
    sevFields = {
        'ICDR Severity Grade', sprintf('Grade %d - %s', gradeResult.shownGrade, gradeLabel(gradeResult.shownGrade)), [];
        'Referable DR', ternary(gradeResult.isReferable, 'YES', 'NO'), ternary(gradeResult.isReferable, COL.priorityText, COL.routineText);
        'Grading Pathway', ternary(gradeResult.rule.committed, 'Rule-based', 'CNN'), [];
        'Rule / CNN Agreement', ternary(~gradeResult.flag.flagged, 'Agree', 'Disagreement - flagged'), agreementColor;
    };
    drawInfoGrid(MX, yPos, 1 - 2*MX, sevFields, PAGE_H, COL, 4);
    yPos = yPos - (lh(9, PAGE_H) + lh(12, PAGE_H) + 0.020) - 0.030;

    % ---- Section 4: AI Analysis Visualizations ----
    yPos = drawChipHeader('4', 'AI Analysis Visualizations', MX, yPos, PAGE_W, PAGE_H, COL);
    imgTop = yPos;
    imgH = 0.44;

    segAx = axes('Position', [MX, imgTop - imgH, 0.44, imgH]);
    lesionOverlay = buildLesionOverlay(enhImg, trackAResult, trackBResult);
    imshow(lesionOverlay, 'Parent', segAx);
    axes(textAx); %#ok<LTARG>
    capY = imgTop - imgH - 0.022;
    text(MX + 0.22, capY, 'AI-Interpreted Image (lesion overlay)', 'FontSize', 9.5, 'Color', COL.inkFaint, ...
        'HorizontalAlignment', 'center');

    camX = MX + 0.50;
    camAx = axes('Position', [camX, imgTop - imgH, 0.44, imgH]);
    imshow(camResult.overlayImage, 'Parent', camAx);
    axes(textAx); %#ok<LTARG>
    text(camX + 0.22, capY, 'Grad-CAM Attention Heatmap', 'FontSize', 9.5, 'Color', COL.inkFaint, ...
        'HorizontalAlignment', 'center');

    drawColorLegend(MX, capY - 0.045, 0.44, COL);

    exportgraphics(fig, reportPath, 'Append', true);
    close(fig);
end

function drawColorLegend(x0, yTop, width, COL)
%DRAWCOLORLEGEND Color key for the AI-Interpreted Image panel - must
%match buildLesionOverlay.m's colorMap exactly, and the web report's
%legend grid in ReportPage.tsx.
    legendItems = {
        [1 0 0],       'Vessel';
        [1 1 1],       'Optic Disc';
        [0 1 0],       'Fovea';
        [1 1 0],       'Hard Exudates';
        [0 1 1],       'Hemorrhages';
        [0 0 1],       'Cotton Wool Spots';
        [1 0.55 0],    'Vitreous Hemorrhage';
        [1 0.27 0],    'IRMA';
        [1 0 1],       'Neovascularization / confirmed MA (X)';
    };
    nCols = 2;
    colW = width / nCols;
    rowH = 0.026;
    for i = 1:size(legendItems, 1)
        col = mod(i - 1, nCols);
        row = floor((i - 1) / nCols);
        x = x0 + col * colW;
        y = yTop - row * rowH;
        rectangle('Position', [x, y - 0.010, 0.012, 0.014], ...
            'FaceColor', legendItems{i, 1}, 'EdgeColor', [0.35 0.35 0.35], 'LineWidth', 0.6);
        text(x + 0.018, y - 0.003, legendItems{i, 2}, 'FontSize', 8.5, 'Color', COL.inkDim);
    end
end

% ============================================================
% Page 4 - Grading reasons detail + technical appendix
% ============================================================

function page4_reasonsAndAppendix(reportPath, trackAResult, trackBResult, gradeResult, flag, camResult, overlapResult, calibConf, reliabilityCategory)
    PAGE_H = 1100; PAGE_W = 850;
    COL = reportColors();
    fig = figure('Visible', 'off', 'Position', [0 0 PAGE_W PAGE_H], 'Color', 'w');
    freshAxes();
    MX = 0.065;

    yPos = drawChipHeader('5', 'Grading Reasons (Detail)', MX, 0.965, PAGE_W, PAGE_H, COL);

    headers = {'Finding', 'Detected', 'Detail'};
    colX = [MX + 0.02, MX + 0.42, MX + 0.58];
    for i = 1:numel(headers)
        text(colX(i), yPos, upper(headers{i}), 'FontWeight', 'bold', 'FontSize', 9, 'Color', COL.inkFaint);
    end
    yPos = yPos - lh(9, PAGE_H) - 0.008;
    line([MX 1-MX], [yPos yPos], 'Color', COL.lineStrong, 'LineWidth', 1);
    yPos = yPos - 0.018;

    rows = buildFindingsRows(trackAResult, trackBResult);
    rowStep = lh(10, PAGE_H) + 0.016;
    for i = 1:size(rows, 1)
        if mod(i, 2) == 0
            rectangle('Position', [MX, yPos - rowStep + lh(10,PAGE_H)*0.35, 1 - 2*MX, rowStep], ...
                'FaceColor', COL.cardBg, 'EdgeColor', 'none');
        end
        for c = 1:3
            text(colX(c), yPos, rows{i,c}, 'FontSize', 9.5, 'Interpreter', 'none', 'Color', COL.ink);
        end
        yPos = yPos - rowStep;
    end
    yPos = yPos - 0.018;

    text(MX, yPos, 'How the Grade Was Determined', 'FontWeight', 'bold', 'FontSize', 12, 'Color', COL.ink);
    yPos = yPos - lh(12, PAGE_H) - 0.016;
    line([MX 1-MX], [yPos yPos], 'Color', COL.line, 'LineWidth', 1);
    yPos = yPos - 0.024;

    text(MX + 0.02, yPos, 'Rule-based path (Module 2 findings):', 'FontWeight', 'bold', 'FontSize', 10, 'Color', COL.inkDim);
    yPos = yPos - lh(10, PAGE_H) - 0.010;
    ruleLines = wrapTextLines(gradeResult.rule.reason, 9.5, 1 - 2*MX - 0.06);
    yPos = drawWrappedLines(MX + 0.035, yPos, ruleLines, 9.5, PAGE_H, COL.ink);
    yPos = yPos - 0.016;

    text(MX + 0.02, yPos, sprintf('Deep-learning grading model: Grade %d', gradeResult.cnn.grade), ...
        'FontWeight', 'bold', 'FontSize', 10, 'Color', COL.inkDim);
    yPos = yPos - lh(10, PAGE_H) - 0.012;
    text(MX + 0.02, yPos, sprintf('Final shown grade: %d', gradeResult.shownGrade), ...
        'FontWeight', 'bold', 'FontSize', 10, 'Color', COL.inkDim);
    yPos = yPos - lh(10, PAGE_H) - 0.010;
    flagLines = wrapTextLines(flag.message, 9.5, 1 - 2*MX - 0.06);
    yPos = drawWrappedLines(MX + 0.035, yPos, flagLines, 9.5, PAGE_H, COL.ink);
    yPos = yPos - 0.028;

    line([MX 1-MX], [yPos yPos], 'Color', COL.line, 'LineWidth', 1);
    yPos = yPos - 0.026;
    text(MX, yPos, 'Technical Appendix', 'FontWeight', 'bold', 'FontSize', 12, 'Color', COL.ink);
    yPos = yPos - lh(12, PAGE_H) - 0.018;

    metricFields = {
        'Calibrated Confidence', sprintf('%.0f%% (%s)', calibConf * 100, reliabilityCategory), [];
        'Lesion-Attention Overlap', sprintf('%.0f%%', overlapResult.overlapScore * 100), [];
        'CNN Continuous Score', sprintf('%.2f / 4', gradeResult.cnn.continuousScore), [];
        'CNN Raw Confidence', sprintf('%.2f (uncalibrated)', gradeResult.cnn.rawConfidence), [];
    };
    drawInfoGrid(MX, yPos, 1 - 2*MX, metricFields, PAGE_H, COL, 2);
    yPos = yPos - 2*(lh(9, PAGE_H) + lh(12, PAGE_H) + 0.020) - 0.010;

    if overlapResult.hasUnexplainedRegion
        noteLines = wrapTextLines('Note: Grad-CAM highlights a region Module 2 did not flag - worth a second look.', 9, 1 - 2*MX);
        yPos = drawWrappedLines(MX, yPos, noteLines, 9, PAGE_H, COL.reviewText);
        yPos = yPos - 0.012;
    end

    line([MX 1-MX], [yPos yPos], 'Color', COL.line, 'LineWidth', 1);
    yPos = yPos - 0.030;
    disclaimerLines = wrapTextLines(['This report is generated by an AI-assisted screening pipeline and is intended as a ' ...
        'decision-support aid for referral triage only. It does not constitute a comprehensive ' ...
        'ophthalmic examination or final diagnosis. All findings require confirmation by a qualified ' ...
        'ophthalmologist before any clinical decision is made.'], 8.5, 1 - 2*MX);
    for i = 1:numel(disclaimerLines)
        text(MX, yPos, disclaimerLines{i}, 'FontSize', 8.5, 'Color', COL.inkFaint, ...
            'FontAngle', 'italic', 'Interpreter', 'none');
        yPos = yPos - lh(8.5, PAGE_H);
    end

    exportgraphics(fig, reportPath, 'Append', true);
    close(fig);
end

% ============================================================
% Shared small helpers
% ============================================================

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

function label = gradeLabel(grade)
    labels = {'No DR', 'Mild NPDR', 'Moderate NPDR', 'Severe NPDR', 'Proliferative DR'};
    if grade >= 0 && grade <= 4
        label = labels{grade + 1};
    else
        label = 'Unknown';
    end
end

function label = qualityCategoryLabel(decision)
    switch char(decision)
        case 'Pass'
            label = 'Pass';
        case 'Enhance'
            label = 'Acceptable';
        case 'Reject'
            label = 'Reject';
        otherwise
            label = char(decision);
    end
end

function color = qualityColor(decision)
    COL = reportColors();
    switch char(decision)
        case 'Pass'
            color = COL.routineText;
        case 'Enhance'
            color = COL.reviewText;
        case 'Reject'
            color = COL.priorityText;
        otherwise
            color = COL.ink;
    end
end

function color = reliabilityColor(category, COL)
    switch category
        case 'Reliable'
            color = COL.routineText;
        case 'Moderate'
            color = COL.reviewText;
        otherwise
            color = COL.priorityText;
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
