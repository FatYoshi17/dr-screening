function reportFig = generateAnnotatedReport(rgbImage, trackAResult, trackBResult, gradeResult, camResult, overlapResult, imageId)
%GENERATEANNOTATEDREPORT Module 4: build the final report, one of 3 layouts.
%   reportFig = generateAnnotatedReport(rgbImage, trackAResult,
%       trackBResult, gradeResult, camResult, overlapResult, imageId)
%
%   Layout depends on gradeResult.flag, per the Module 3 disagreement
%   spec's own report-presentation rules:
%     - No flag: grade badge, calibrated confidence, Grad-CAM overlay,
%       Module 2 lesion list.
%     - High-priority flag: banner above the grade, BOTH opinions shown
%       ("Rule path: Grade X..." / "CNN: Grade Y..."), NO confidence
%       number.
%     - Low-priority flag: banner, "Module 2 found: [...]. CNN grade: [...]",
%       NO confidence number.
%
%   Returns a figure handle (Visible off by default - caller saves it,
%   e.g. exportgraphics(reportFig, 'report_IDRiD_17.pdf')). Overlays
%   Module 2's actual lesion masks, not just the Grad-CAM heatmap, since
%   a location-grounded picture is what makes a <30-second ophthalmologist
%   review realistic.
%
%   See also: gradeImage, computeGradCAM, lesionAttentionOverlap,
%   calibrateConfidence.

    if nargin < 7
        imageId = 'unknown';
    end

    reportFig = figure('Visible', 'off', 'Position', [0 0 1400 900], 'Color', 'w');

    % ---- Panel 1: original image with Module 2 lesion overlay ----
    subplot(1, 3, 1);
    lesionOverlay = buildLesionOverlay(rgbImage, trackAResult, trackBResult);
    imshow(lesionOverlay);
    title('Module 2 findings');

    % ---- Panel 2: Grad-CAM heatmap overlay ----
    subplot(1, 3, 2);
    imshow(camResult.overlayImage);
    title(sprintf('Grad-CAM (lesion overlap: %.0f%%)', overlapResult.overlapScore * 100));

    % ---- Panel 3: text panel, layout depends on flag status ----
    subplot(1, 3, 3);
    axis off;
    yPos = 0.95;
    lineStep = 0.06;

    text(0, yPos, sprintf('Image: %s', imageId), 'FontWeight', 'bold', 'FontSize', 11);
    yPos = yPos - lineStep * 1.5;

    flag = gradeResult.flag;
    if flag.flagged
        bannerColor = 'r';
        if strcmp(flag.priority, 'high')
            bannerText = 'FLAGGED - HIGH PRIORITY (possible missed disease)';
        else
            bannerText = 'FLAGGED - LOW PRIORITY (possible false alarm)';
        end
        text(0, yPos, bannerText, 'Color', bannerColor, 'FontWeight', 'bold', 'FontSize', 12, ...
            'BackgroundColor', [1 0.9 0.9]);
        yPos = yPos - lineStep * 1.5;

        text(0, yPos, flag.message, 'FontSize', 10, 'Interpreter', 'none');
        yPos = yPos - lineStep * 2;
        % No confidence number shown on a flagged case - both raw
        % opinions are already in flag.message, that's the whole point.
    else
        text(0, yPos, sprintf('Grade: %d  (%s)', gradeResult.shownGrade, ...
            ternary(gradeResult.isReferable, 'REFERABLE', 'non-referable')), ...
            'FontWeight', 'bold', 'FontSize', 14, ...
            'Color', ternary(gradeResult.isReferable, [0.8 0 0], [0 0.5 0]));
        yPos = yPos - lineStep * 1.5;

        calibConf = calibrateConfidence(gradeResult.cnn.rawConfidence);
        text(0, yPos, sprintf('Calibrated confidence: %.0f%%', calibConf * 100), 'FontSize', 11);
        yPos = yPos - lineStep * 1.5;
    end

    text(0, yPos, 'Module 2 lesion list:', 'FontWeight', 'bold', 'FontSize', 10);
    yPos = yPos - lineStep;
    lesionList = summarizeLesions(trackAResult, trackBResult);
    for i = 1:numel(lesionList)
        text(0.03, yPos, ['- ' lesionList{i}], 'FontSize', 9);
        yPos = yPos - lineStep * 0.8;
    end

    if overlapResult.hasUnexplainedRegion
        yPos = yPos - lineStep * 0.5;
        text(0, yPos, 'Note: Grad-CAM highlights a region Module 2 did not flag -', ...
            'FontSize', 8, 'Color', [0.5 0.3 0], 'Interpreter', 'none');
        yPos = yPos - lineStep * 0.6;
        text(0, yPos, 'worth a second look.', 'FontSize', 8, 'Color', [0.5 0.3 0]);
    end

    if ~isempty(flag.silentDiagnosticNote)
        % Logged for aggregate diagnostics only - not shown to the
        % reviewing clinician, per spec. (Left here as a code comment
        % rather than UI text: hook this into a logging call in your
        % batch-evaluation script, not the per-patient report.)
    end
end

function overlay = buildLesionOverlay(rgbImage, trackAResult, trackBResult)
    overlay = im2uint8(rgbImage);
    colorMap = struct('VH', [255 140 0], 'Fovea', [0 255 0], 'Vessel', [255 0 0], ...
        'OD', [255 255 255], 'EX', [255 255 0], 'IRMA', [255 69 0], ...
        'HE', [0 255 255], 'NV', [255 0 255], 'CWS', [0 0 255]);
    classNames = fieldnames(colorMap);
    for i = 1:numel(classNames)
        fieldName = matlab.lang.makeValidName(classNames{i});
        if isfield(trackAResult.masks, fieldName)
            mask = trackAResult.masks.(fieldName);
            color = colorMap.(classNames{i});
            for c = 1:3
                channel = overlay(:,:,c);
                channel(mask) = color(c);
                overlay(:,:,c) = channel;
            end
        end
    end
    for i = 1:numel(trackBResult.candidates)
        if strcmp(trackBResult.candidates(i).status, 'confirmed')
            overlay = insertMarker(overlay, trackBResult.candidates(i).centroid, ...
                'x', 'Color', 'magenta', 'Size', 4);
        end
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

function out = ternary(cond, a, b)
    if cond, out = a; else, out = b; end
end
