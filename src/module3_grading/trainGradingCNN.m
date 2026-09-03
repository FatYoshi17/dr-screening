function model = trainGradingCNN(aptosImageDir, aptosLabelsCsv, outputModelPath)
%TRAINGRADINGCNN Train Module 3's full-range (0-4) severity grading CNN on APTOS 2019.
%   model = trainGradingCNN(aptosImageDir, aptosLabelsCsv, outputModelPath)
%
%   Requires: GPU strongly recommended. Does not run inside the cloud
%   sandbox that generated this code - run on your own machine/cloud.
%
%   Design follows the APTOS 2019 competition's own winning-solution
%   playbook rather than a plain 5-way softmax classifier:
%     - Regression framing (predict a continuous 0-4 score, Huber loss)
%       instead of 5-way classification - matches how the clinically
%       relevant metric (ordinal closeness) actually scores errors: a
%       predicted 3 when truth is 4 should cost less than predicted 0
%       when truth is 4, which a plain classifier's cross-entropy does
%       not capture.
%     - GeM pooling in place of the backbone's default average pool.
%     - Trained on the FULL 0-4 range, not just 2-4 - this network runs
%       on every image regardless of what Module 2's rule decides,
%       which is what makes the disagreement safety net possible (see
%       disagreementFlag.m).
%     - Rounding thresholds optimized on a held-out validation split
%       rather than naive round() - most of the accuracy gain over a
%       naive classifier baseline comes from this one detail.
%
%   RETFound was considered as the backbone instead of a standard
%   pretrained CNN and NOT adopted here - same PyTorch/MATLAB tooling-
%   risk reasoning that kept Module 2's Track A off it too. This uses
%   resnet50 (MATLAB-native, well-supported transfer learning target).
%
%   aptosLabelsCsv: expects a filename column and a 0-4 grade column.
%
%   See also: gemPoolingLayer, predictGradingCNN, grade01Rule,
%   disagreementFlag, gradeImage.

    if nargin < 3
        outputModelPath = fullfile('data', 'models', 'module3_grading_cnn.mat');
    end

    labelsTable = readtable(aptosLabelsCsv);
    varNames = labelsTable.Properties.VariableNames;
    filenameCol = varNames{find(contains(lower(varNames), {'name', 'file', 'image', 'id_code'}), 1)};
    gradeCol    = varNames{find(contains(lower(varNames), {'grade', 'diagnosis', 'label'}), 1)};

    imagePaths = fullfile(aptosImageDir, string(labelsTable.(filenameCol)) + ".png");
    grades = double(labelsTable.(gradeCol));

    validRows = isfile(imagePaths) & isfinite(grades);
    imagePaths = imagePaths(validRows);
    grades = grades(validRows);

    % 85/15 train/validation split, used both for early stopping and for
    % fitting the rounding thresholds afterward.
    rng(42);
    n = numel(grades);
    idx = randperm(n);
    nVal = round(0.15 * n);
    valIdx = idx(1:nVal);
    trainIdx = idx(nVal+1:end);

    imdsTrain = imageDatastore(imagePaths(trainIdx));
    imdsVal   = imageDatastore(imagePaths(valIdx));
    yTrain = grades(trainIdx);
    yVal   = grades(valIdx);

    inputSize = [512 512 3]; % matches the winning solutions' minimal-preprocessing resize
    augmenter = imageDataAugmenter( ...
        'RandXReflection', true, ...
        'RandRotation', [-20 20], ...
        'RandXScale', [0.9 1.1], ...
        'RandYScale', [0.9 1.1]);
    augTrainDs = augmentedImageDatastore(inputSize, imdsTrain, yTrain, 'DataAugmentation', augmenter);
    augValDs   = augmentedImageDatastore(inputSize, imdsVal, yVal);

    lgraph = buildGradingRegressionNetwork(inputSize);

    options = trainingOptions('adam', ...
        'InitialLearnRate', 1e-4, ...
        'LearnRateSchedule', 'piecewise', ...
        'LearnRateDropFactor', 0.5, ...
        'LearnRateDropPeriod', 8, ...
        'MaxEpochs', 30, ...
        'MiniBatchSize', 8, ...
        'Shuffle', 'every-epoch', ...
        'ValidationData', augValDs, ...
        'ValidationFrequency', 50, ...
        'ExecutionEnvironment', 'auto', ...
        'Plots', 'training-progress', ...
        'Verbose', true);

    fprintf('Training Module 3 grading CNN on %d images (full 0-4 range, regression framing)...\n', numel(yTrain));
    net = trainNetwork(augTrainDs, lgraph, options);

    fprintf('Optimizing rounding thresholds on the validation split...\n');
    valPredictions = predict(net, augValDs);
    thresholds = optimizeRoundingThresholds(valPredictions, yVal);

    model.net = net;
    model.thresholds = thresholds; % 4 thresholds separating grades 0|1|2|3|4
    model.inputSize = inputSize;

    outDir = fileparts(outputModelPath);
    if ~isempty(outDir) && ~isfolder(outDir)
        mkdir(outDir);
    end
    save(outputModelPath, 'model');
    fprintf('Saved Module 3 grading CNN to %s. Rounding thresholds: %s\n', ...
        outputModelPath, mat2str(thresholds, 3));
end

function lgraph = buildGradingRegressionNetwork(inputSize)
    baseNet = resnet50('Weights', 'imagenet');
    lgraph = layerGraph(baseNet);
    lgraph = replaceLayer(lgraph, 'input_1', imageInputLayer(inputSize, 'Name', 'input_1', ...
        'Normalization', 'zscore'));

    lgraph = removeLayers(lgraph, {'avg_pool', 'fc1000', 'fc1000_softmax', 'ClassificationLayer_fc1000'});
    gem = gemPoolingLayer('gem_pool');
    fc1 = fullyConnectedLayer(256, 'Name', 'fc_grade_1');
    relu1 = reluLayer('Name', 'relu_grade_1');
    dropout1 = dropoutLayer(0.3, 'Name', 'dropout_grade_1');
    fc2 = fullyConnectedLayer(1, 'Name', 'fc_grade_out'); % single continuous score output
    huberOut = huberRegressionLayer('grading_huber_output');

    lgraph = addLayers(lgraph, gem);
    lgraph = addLayers(lgraph, fc1);
    lgraph = addLayers(lgraph, relu1);
    lgraph = addLayers(lgraph, dropout1);
    lgraph = addLayers(lgraph, fc2);
    lgraph = addLayers(lgraph, huberOut);

    lgraph = connectLayers(lgraph, 'activation_49_relu', 'gem_pool'); % resnet50's last conv block
    lgraph = connectLayers(lgraph, 'gem_pool', 'fc_grade_1');
    lgraph = connectLayers(lgraph, 'fc_grade_1', 'relu_grade_1');
    lgraph = connectLayers(lgraph, 'relu_grade_1', 'dropout_grade_1');
    lgraph = connectLayers(lgraph, 'dropout_grade_1', 'fc_grade_out');
    lgraph = connectLayers(lgraph, 'fc_grade_out', 'grading_huber_output');
end

function thresholds = optimizeRoundingThresholds(predictions, trueGrades)
%OPTIMIZEROUNDINGTHRESHOLDS Grid-search 4 cutpoints instead of naive round().
    predictions = predictions(:);
    trueGrades = trueGrades(:);
    candidateOffsets = 0.3:0.05:0.7; % search around the naive 0.5-width bins
    bestThresholds = 0.5:1:3.5;
    bestKappa = -Inf;

    for a = candidateOffsets
        for b = candidateOffsets
            for c = candidateOffsets
                for d = candidateOffsets
                    t = [a, 1+b, 2+c, 3+d];
                    if ~issorted(t), continue; end
                    predictedGrade = sum(predictions > t, 2);
                    kappa = quadraticWeightedKappa(predictedGrade, trueGrades, 0:4);
                    if kappa > bestKappa
                        bestKappa = kappa;
                        bestThresholds = t;
                    end
                end
            end
        end
    end
    thresholds = bestThresholds;
    fprintf('  Best validation QWK: %.4f\n', bestKappa);
end

function kappa = quadraticWeightedKappa(pred, actual, classRange)
    n = numel(classRange);
    O = zeros(n, n);
    for i = 1:numel(pred)
        r = find(classRange == pred(i), 1);
        c = find(classRange == actual(i), 1);
        if isempty(r) || isempty(c), continue; end
        O(r, c) = O(r, c) + 1;
    end
    W = ((0:n-1)' - (0:n-1)).^2 / (n-1)^2;
    histPred = sum(O, 2); histActual = sum(O, 1);
    E = histPred * histActual / sum(O(:));
    kappa = 1 - sum(W(:) .* O(:)) / sum(W(:) .* E(:));
end
