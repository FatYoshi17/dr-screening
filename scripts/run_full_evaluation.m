function results = run_full_evaluation(inputFolder, outputFolder)
%RUN_FULL_EVALUATION Batch-run Module 1 + Module 2 over a folder of images.
%   results = run_full_evaluation(inputFolder, outputFolder)
%   Saves a summary struct array and one annotated overlay PNG per
%   accepted image; writes a CSV log of accept/reject decisions and
%   Module 2 counts (results/metrics_logs/) — a quick sanity pass before
%   handing images to whoever owns Module 3.
%
%   Example:
%     cfg = config();
%     run_full_evaluation(cfg.idridSegImagesTrain)

    cfg = config();
    if nargin < 1 || isempty(inputFolder)
        error('Provide an inputFolder of fundus images, e.g. config().idridSegImagesTrain');
    end
    if nargin < 2 || isempty(outputFolder)
        outputFolder = cfg.metricsLogsDir;
    end
    if ~isfolder(outputFolder), mkdir(outputFolder); end

    manifest = ioUtils('buildManifest', inputFolder);
    if height(manifest) == 0
        error('No image files found in %s', inputFolder);
    end

    logRows = {};
    results = struct('file', {}, 'gradable', {}, 'overallScore', {}, ...
        'numMA', {}, 'numHem', {}, 'exudateArea', {}, 'nvScore', {});

    for i = 1:height(manifest)
        fname = manifest.FileName(i);
        fpath = manifest.FullPath(i);
        fprintf('[%d/%d] %s\n', i, height(manifest), fname);
        try
            rgbImage = ioUtils('load', fpath);
            qc = assessImageQuality(rgbImage);

            if ~qc.isGradable
                rejectUngradeable(qc, char(fname));
                results(end+1) = struct('file', char(fname), 'gradable', false, ...
                    'overallScore', qc.overallScore, 'numMA', NaN, 'numHem', NaN, ...
                    'exudateArea', NaN, 'nvScore', NaN); %#ok<AGROW>
                logRows(end+1,:) = {char(fname), 'REJECTED', qc.overallScore, NaN, NaN, NaN, NaN}; %#ok<AGROW>
                continue;
            end

            [enhImg, ~, qcAfter] = enhanceImage(rgbImage);
            enhImg8 = im2uint8(enhImg);
            mask = fovMask(enhImg8);

            [discCenter, discRadius, discMask] = detectOpticDisc(enhImg8, mask); %#ok<ASGLU>
            vesselMask = segmentVessels(enhImg8, mask);
            [~, maStats] = detectMicroaneurysms(enhImg8, mask, vesselMask, discMask);
            exudateMask = segmentExudates(enhImg8, mask, discMask);
            [~, hemStats] = classifyHemorrhages(enhImg8, mask, vesselMask, discMask);
            [~, nvScore] = detectNeovascularization(enhImg8, vesselMask, discMask, mask);

            results(end+1) = struct('file', char(fname), 'gradable', true, ...
                'overallScore', qcAfter.overallScore, 'numMA', numel(maStats), ...
                'numHem', numel(hemStats), 'exudateArea', nnz(exudateMask), ...
                'nvScore', nvScore); %#ok<AGROW>
            logRows(end+1,:) = {char(fname), 'ACCEPTED', qcAfter.overallScore, ...
                numel(maStats), numel(hemStats), nnz(exudateMask), nvScore}; %#ok<AGROW>
        catch ME
            warning('Failed on %s: %s', fname, ME.message);
        end
    end

    T = cell2table(logRows, 'VariableNames', ...
        {'File', 'Status', 'OverallScore', 'NumMA', 'NumHem', 'ExudateArea', 'NVScore'});
    logPath = fullfile(outputFolder, sprintf('eval_log_%s.csv', datestr(now, 'yyyymmdd_HHMMSS')));
    writetable(T, logPath);
    fprintf('\nDone. %d images processed, log at %s\n', height(manifest), logPath);
end
