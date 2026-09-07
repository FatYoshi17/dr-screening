function results = evaluate_referable_dr(cfg, maxImages)
%EVALUATE_REFERABLE_DR Real sensitivity/specificity + rule-vs-CNN-vs-combined
%ablation, on held-out IDRiD grading labels and external Messidor-2 grades.
%   results = evaluate_referable_dr() runs Module 1->2->3 (no Module 4 -
%   Grad-CAM/report generation isn't needed for accuracy evaluation and
%   would cost real time across hundreds of images) on every image in:
%     1. IDRiD's Disease Grading TEST set (103 images, real ICDR 0-4
%        grades) - a held-out set the pipeline never trained on directly
%        for grading (trainGradingCNN.m only ever sees APTOS).
%     2. Messidor-2, a genuinely external population never touched
%        during training, using grades merged from MAPLES-DR (Lepetit-
%        Aimon et al., Nature Scientific Data 2024) matched by filename
%        against the locally-downloaded Messidor-2 images (162/1810
%        matched - see data/raw/messidor2/messidor2_grades.csv).
%
%   For every image, gradeImage.m already runs BOTH the rule (grade01Rule)
%   and CNN (predictGradingCNN) pathways independently - this script just
%   compares all three (rule-only where the rule commits, CNN-only, and
%   the combined/shown grade actually surfaced to users) against ground
%   truth at the referable-DR threshold (grade >= 2), using common/metrics.m
%   as the single source of truth for sensitivity/specificity.
%
%   results = evaluate_referable_dr(cfg, maxImages) caps images per
%   dataset (for a quick smoke run); omit/Inf for the full set.
%
%   See also: gradeImage, grade01Rule, predictGradingCNN, common/metrics.

    if nargin < 1 || isempty(cfg)
        cfg = config();
    end
    if nargin < 2 || isempty(maxImages)
        maxImages = Inf;
    end

    fprintf('\n########## IDRiD Disease Grading Test Set ##########\n');
    % Delimiter forced explicitly: MATLAB's auto-detection picks '_' on
    % the Messidor-2 file below (filenames like "20051020_44923_0100_PP"
    % have far more underscores than the file has actual comma
    % delimiters), so it's forced here too for consistency/safety.
    idridTable = readtable(cfg.idridGradingLabelsTest, 'VariableNamingRule', 'preserve', 'Delimiter', ',');
    idridNames = idridTable.("Image name");
    idridGrades = idridTable.("Retinopathy grade");
    idridResults = evaluateDataset(cfg, idridNames, idridGrades, ...
        cfg.idridGradingImagesTest, '.jpg', maxImages, 'IDRiD');

    fprintf('\n########## Messidor-2 External Validation Set (MAPLES-DR grades) ##########\n');
    messidorTable = readtable(cfg.messidor2LabelsPath, 'VariableNamingRule', 'preserve', 'Delimiter', ',');
    messidorNames = messidorTable.("image_name");
    messidorGrades = messidorTable.("dr_grade");
    messidorResults = evaluateDataset(cfg, messidorNames, messidorGrades, ...
        cfg.messidor2Dir, '.png', maxImages, 'Messidor-2');

    results.idrid = idridResults;
    results.messidor2 = messidorResults;

    reportSummary('IDRiD (held-out, same population as Module 2/3 training data family)', idridResults);
    reportSummary('Messidor-2 (genuinely external population)', messidorResults);

    save(fullfile(cfg.resultsDir, 'evaluate_referable_dr_results.mat'), 'results');
    fprintf('\nSaved results to %s\n', fullfile(cfg.resultsDir, 'evaluate_referable_dr_results.mat'));
end

function ds = evaluateDataset(cfg, names, gtGrades, imageDir, ext, maxImages, label)
    n = min(numel(names), maxImages);
    ruleGrade = nan(n, 1);   % NaN where the rule didn't commit
    cnnGrade  = nan(n, 1);
    shownGrade = nan(n, 1);
    trueGrade = nan(n, 1);
    included = false(n, 1);

    for i = 1:n
        name = strtrim(string(names(i)));
        imgPath = findImage(imageDir, name, ext);
        if isempty(imgPath)
            fprintf('  [%s] %s: image not found, skipping\n', label, name);
            continue
        end

        try
            rgbImage = imread(imgPath);
            [enhImg, qcBefore, ~] = enhanceImage(rgbImage, cfg.module1QualityModel);
            if ~qcBefore.isGradable
                fprintf('  [%s] %d/%d %s: rejected at quality gate, skipping\n', label, i, n, name);
                continue
            end

            trackAResult = segmentStructures(enhImg, cfg.trackANetPath);
            trackBResult = detectMicroaneurysmsV2(rgbImage, cfg.trackBActiveNetPath);
            gradeResult = gradeImage(rgbImage, trackAResult, trackBResult, cfg.module3GradingCnnPath);

            if gradeResult.rule.committed
                ruleGrade(i) = gradeResult.rule.grade;
            end
            cnnGrade(i) = gradeResult.cnn.grade;
            shownGrade(i) = gradeResult.shownGrade;
            trueGrade(i) = gtGrades(i);
            included(i) = true;

            if mod(i, 20) == 0
                fprintf('  [%s] %d/%d processed\n', label, i, n);
            end
        catch ME
            fprintf('  [%s] %d/%d %s: ERROR - %s\n', label, i, n, name, ME.message);
        end
    end

    ds.n = nnz(included);
    ds.nExcludedRejected = nnz(~included);
    ds.trueGrade = trueGrade(included);
    ds.ruleGrade = ruleGrade(included);
    ds.cnnGrade = cnnGrade(included);
    ds.shownGrade = shownGrade(included);

    trueReferable = ds.trueGrade >= 2;

    % Rule-only: evaluated ONLY on the subset where the rule actually
    % committed (grade01Rule.m never itself decides referable/not on
    % images it defers - including those here would just be re-scoring
    % the CNN's decision under the rule's name).
    ruleCommitted = ~isnan(ds.ruleGrade);
    if any(ruleCommitted)
        ds.ruleOnly = metrics(ds.ruleGrade(ruleCommitted) >= 2, trueReferable(ruleCommitted));
        ds.ruleOnly.nEvaluated = nnz(ruleCommitted);
    else
        ds.ruleOnly = [];
    end

    ds.cnnOnly = metrics(ds.cnnGrade >= 2, trueReferable);
    ds.cnnOnly.nEvaluated = ds.n;

    ds.combined = metrics(ds.shownGrade >= 2, trueReferable);
    ds.combined.nEvaluated = ds.n;
end

function imgPath = findImage(imageDir, name, ext)
    % Messidor-2 images are split across IMAGES-1..4 subfolders; IDRiD's
    % are flat. Try the flat path first, then search one level of
    % subfolders.
    candidate = fullfile(imageDir, name + ext);
    if isfile(candidate)
        imgPath = char(candidate);
        return
    end
    subdirs = dir(imageDir);
    subdirs = subdirs([subdirs.isdir] & ~startsWith({subdirs.name}, '.'));
    for i = 1:numel(subdirs)
        candidate = fullfile(imageDir, subdirs(i).name, name + ext);
        if isfile(candidate)
            imgPath = char(candidate);
            return
        end
    end
    imgPath = '';
end

function reportSummary(label, ds)
    fprintf('\n=== %s ===\n', label);
    fprintf('  n = %d evaluated (%d excluded at quality gate / not found)\n', ds.n, ds.nExcludedRejected);
    if ~isempty(ds.ruleOnly)
        fprintf('  Rule-only  (n=%3d, committed cases): sensitivity=%.3f specificity=%.3f\n', ...
            ds.ruleOnly.nEvaluated, ds.ruleOnly.sensitivity, ds.ruleOnly.specificity);
    else
        fprintf('  Rule-only: rule never committed on this set (all deferred to CNN)\n');
    end
    fprintf('  CNN-only   (n=%3d): sensitivity=%.3f specificity=%.3f\n', ...
        ds.cnnOnly.nEvaluated, ds.cnnOnly.sensitivity, ds.cnnOnly.specificity);
    fprintf('  Combined   (n=%3d): sensitivity=%.3f specificity=%.3f  <-- what the app actually shows users\n', ...
        ds.combined.nEvaluated, ds.combined.sensitivity, ds.combined.specificity);
end
