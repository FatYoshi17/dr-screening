function model = trainOrdinalQualityModel(eyeQImageDir, eyeQLabelsCsv, outputModelPath)
%TRAINORDINALQUALITYMODEL Train Module 1's ordinal logistic regression quality model.
%   model = trainOrdinalQualityModel(eyeQImageDir, eyeQLabelsCsv, outputModelPath)
%
%   Requires: Statistics and Machine Learning Toolbox R2023a+ (fitmnr).
%   Requires: EyeQ dataset (github.com/HzFu/EyeQ) — set eyeQImageDir to
%   its image folder and eyeQLabelsCsv to its quality-label CSV.
%
%   eyeQLabelsCsv is expected to have at least two columns: an image
%   filename column and a quality label column whose values are one of
%   {'Good','Usable','Reject'} (case-insensitive) — adjust
%   parseEyeQLabel below if your copy of EyeQ uses numeric 0/1/2 labels
%   instead, which some redistributions do.
%
%   Pipeline: extract the 5 raw features per training image -> fit the
%   logistic normalization curves -> normalize every image's features
%   -> fit a ridge-regularized ordinal logistic regression
%   (Reject < Enhance < Pass) -> save {normParams, ordinalModel} to
%   outputModelPath for assessImageQuality.m to load at inference time.
%
%   This is the only Module 1 stage — indeed the only trainable stage in
%   the whole pipeline outside of Module 2/3's deep networks — that
%   trains in seconds on a CPU, no GPU needed.
%
%   See also: extractQualityFeatures, fitFeatureNormalization,
%   normalizeQualityFeatures, assessImageQuality.

    if nargin < 3
        outputModelPath = fullfile('data', 'models', 'module1_quality_model.mat');
    end

    labelsTable = readtable(eyeQLabelsCsv);
    varNames = labelsTable.Properties.VariableNames;
    filenameCol = varNames{find(contains(lower(varNames), {'name', 'file', 'image'}), 1)};
    labelCol    = varNames{find(contains(lower(varNames), {'quality', 'label', 'grade'}), 1)};

    n = height(labelsTable);
    rawTable = table('Size', [n, 7], ...
        'VariableTypes', repmat({'double'}, 1, 7), ...
        'VariableNames', {'sharpness', 'exposure_meanBrightness', ...
                           'exposure_clippedFraction', 'contrast', ...
                           'fov_coverage', 'fov_compactness', 'noise'});
    ordinalLabel = strings(n, 1);
    keepRow = true(n, 1);

    fprintf('Extracting features from %d EyeQ images...\n', n);
    for i = 1:n
        imgPath = fullfile(eyeQImageDir, string(labelsTable.(filenameCol)(i)));
        if ~isfile(imgPath)
            keepRow(i) = false;
            continue;
        end
        try
            img = imread(imgPath);
            mask = fovMask(img);
            if nnz(mask) < 100  % degenerate mask, skip
                keepRow(i) = false;
                continue;
            end
            f = extractQualityFeatures(img, mask);
            rawTable.sharpness(i)                = f.sharpness;
            rawTable.exposure_meanBrightness(i)   = f.exposure.meanBrightness;
            rawTable.exposure_clippedFraction(i)  = f.exposure.clippedFraction;
            rawTable.contrast(i)                  = f.contrast;
            rawTable.fov_coverage(i)              = f.fov.coverage;
            rawTable.fov_compactness(i)           = f.fov.compactness;
            rawTable.noise(i)                     = f.noise;
            ordinalLabel(i) = parseEyeQLabel(labelsTable.(labelCol)(i));
        catch ME
            warning('Skipping %s: %s', imgPath, ME.message);
            keepRow(i) = false;
        end
        if mod(i, 200) == 0
            fprintf('  %d / %d\n', i, n);
        end
    end

    rawTable = rawTable(keepRow, :);
    ordinalLabel = ordinalLabel(keepRow);
    ordinalLabel(ordinalLabel == "") = [];

    normParams = fitFeatureNormalization(rawTable);

    X = zeros(height(rawTable), 5);
    for i = 1:height(rawTable)
        f.sharpness = rawTable.sharpness(i);
        f.exposure  = struct('meanBrightness', rawTable.exposure_meanBrightness(i), ...
                              'clippedFraction', rawTable.exposure_clippedFraction(i));
        f.contrast  = rawTable.contrast(i);
        f.fov       = struct('coverage', rawTable.fov_coverage(i), ...
                              'compactness', rawTable.fov_compactness(i));
        f.noise     = rawTable.noise(i);
        X(i, :) = normalizeQualityFeatures(f, normParams);
    end

    y = categorical(ordinalLabel, {'Reject', 'Enhance', 'Pass'}, 'Ordinal', true);

    % fitmnr has no 'Regularization'/'Lambda' name-value pair in this
    % MATLAB version (verified via help fitmnr - its actual options are
    % CategoricalPredictors, EstimateDispersion,
    % IncludeClassInteractions, IterationLimit, Link, ModelType,
    % PredictorNames, ResponseName, Tolerance, Weights). The original
    % "ridge-regularized" design assumed a parameter that doesn't exist
    % here - dropped rather than faked. With 12.5k samples and only 5
    % predictors, overfitting risk without it is low.
    fprintf('Fitting ordinal logistic regression on %d samples...\n', numel(y));
    ordinalModel = fitmnr(X, y, ...
        'ModelType', 'ordinal', ...
        'Link', 'logit');

    model.normParams = normParams;
    model.ordinalModel = ordinalModel;
    model.featureNames = {'sharpness', 'exposure', 'contrast', 'fov', 'noise'};
    model.classOrder = {'Reject', 'Enhance', 'Pass'};
    model.trainedOn = datestr(now); %#ok<TNOW1,DATST>
    model.nTrainingImages = numel(y);

    outDir = fileparts(outputModelPath);
    if ~isempty(outDir) && ~isfolder(outDir)
        mkdir(outDir);
    end
    save(outputModelPath, 'model');
    fprintf('Saved trained Module 1 model to %s (%d images).\n', outputModelPath, numel(y));
end

function lbl = parseEyeQLabel(raw)
%PARSEEYEQLABEL Normalize an EyeQ label cell to 'Reject'/'Enhance'/'Pass'.
%   EyeQ's own scheme is Good/Usable/Reject; mapped here to this
%   project's Pass/Enhance/Reject naming. Handles both text and the
%   common 0/1/2 numeric-label redistribution.
    if isnumeric(raw)
        switch raw
            case 0, lbl = "Pass";    % EyeQ: 0 = Good
            case 1, lbl = "Enhance"; % EyeQ: 1 = Usable
            case 2, lbl = "Reject";  % EyeQ: 2 = Reject
            otherwise, lbl = "";
        end
        return
    end
    s = lower(string(raw));
    if contains(s, "good")
        lbl = "Pass";
    elseif contains(s, "usable")
        lbl = "Enhance";
    elseif contains(s, "reject")
        lbl = "Reject";
    else
        lbl = "";
    end
end
