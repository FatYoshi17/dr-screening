function app_try_it()
%APP_TRY_IT Minimal interactive GUI: pick an image, run the full pipeline, see the report.
%   app_try_it() opens a uifigure with a "Load Image" button and a
%   results panel. This is the "try it" experience for this project -
%   there's no MATLAB-native equivalent of a public hosted web link
%   without MATLAB Web App Server / Production Server (separate,
%   licensed products this pipeline doesn't assume you have), so this
%   local app is the realistic "click something and see it work" option
%   once every module is trained.
%
%   Requires all models trained first - see train_all_models.m and
%   docs/RUN_GUIDE.md.
%
%   See also: run_end_to_end_pipeline, train_all_models.

    cfg = config();

    fig = uifigure('Name', 'DR Screening Pipeline - Try It', 'Position', [100 100 1000 700]);

    loadBtn = uibutton(fig, 'Text', 'Load Fundus Image...', ...
        'Position', [20 650 160 30], ...
        'ButtonPushedFcn', @(btn, event) onLoadImage());

    statusLabel = uilabel(fig, 'Text', 'No image loaded.', ...
        'Position', [200 650 700 30], 'FontSize', 12);

    imgAxes = uiaxes(fig, 'Position', [20 350 460 280]);
    title(imgAxes, 'Input image');

    reportAxes = uiaxes(fig, 'Position', [500 350 480 280]);
    title(reportAxes, 'Annotated report');

    resultsArea = uitextarea(fig, 'Position', [20 20 960 310], ...
        'Editable', 'off', 'FontName', 'Consolas', 'FontSize', 11);

    function onLoadImage()
        [file, path] = uigetfile({'*.jpg;*.jpeg;*.png;*.tif', 'Fundus images'});
        if isequal(file, 0)
            return
        end
        imagePath = fullfile(path, file);

        statusLabel.Text = 'Running pipeline (this can take a while, especially Module 2)...';
        drawnow;

        img = imread(imagePath);
        imshow(img, 'Parent', imgAxes);

        try
            result = run_end_to_end_pipeline(imagePath, cfg);
        catch ME
            resultsArea.Value = {sprintf('ERROR: %s', ME.message), ...
                '', 'Have you trained all the models yet? See train_all_models.m and docs/RUN_GUIDE.md.'};
            statusLabel.Text = 'Pipeline failed - see log below.';
            return
        end

        if strcmp(result.status, 'REJECTED')
            statusLabel.Text = 'Image REJECTED at Module 1 - not gradable.';
            lines = {'Status: REJECTED (Module 1)', ''};
            for i = 1:numel(result.qc.failReasons)
                lines{end+1} = ['- ' result.qc.failReasons{i}]; %#ok<AGROW>
            end
            resultsArea.Value = lines;
            cla(reportAxes);
            return
        end

        statusLabel.Text = sprintf('Done - Grade %d (%s)%s', result.grade.shownGrade, ...
            ternary(result.grade.isReferable, 'REFERABLE', 'non-referable'), ...
            ternary(result.grade.flag.flagged, sprintf(' - FLAGGED (%s priority)', result.grade.flag.priority), ''));

        reportImg = imread(result.reportPath, 1);
        imshow(reportImg, 'Parent', reportAxes);

        lines = {
            sprintf('Image: %s', file), ...
            sprintf('Module 1 quality: %s (score %.2f)', string(result.qcBefore.decision), result.qcBefore.qualityScore), ...
            sprintf('Track A structures found: %s', strjoin(fieldnames(result.trackA.masks), ', ')), ...
            sprintf('Track B: %d confirmed MA, ambiguous=%d', result.trackB.confirmedCount, result.trackB.hasAmbiguous), ...
            sprintf('Grade shown: %d  |  Referable: %d', result.grade.shownGrade, result.grade.isReferable), ...
            sprintf('Disagreement flag: %s', ternary(result.grade.flag.flagged, upper(result.grade.flag.priority), 'none')), ...
            sprintf('Flag message: %s', result.grade.flag.message), ...
            sprintf('Lesion-attention overlap: %.0f%%', result.overlap.overlapScore * 100), ...
            sprintf('Full report saved to: %s', result.reportPath), ...
        };
        resultsArea.Value = lines;
    end
end

function out = ternary(cond, a, b)
    if cond, out = a; else, out = b; end
end
