%TEST_GRADING_BACKBONE Verify Module 3's SqueezeNet-based grading network
% builds, initializes, and forward-passes correctly. Run:
% matlab -batch "test_grading_backbone"

try
    inputSize = [512 512 3];
    baseNet = squeezenet;
    lgraph = layerGraph(baseNet);
    lgraph = replaceLayer(lgraph, 'data', imageInputLayer(inputSize, 'Name', 'data', ...
        'Normalization', 'zscore'));
    lgraph = removeLayers(lgraph, {'drop9', 'conv10', 'relu_conv10', 'pool10', ...
        'prob', 'ClassificationLayer_predictions'});

    gem = gemPoolingLayer('gem_pool');
    fc1 = fullyConnectedLayer(256, 'Name', 'fc_grade_1');
    relu1 = reluLayer('Name', 'relu_grade_1');
    dropout1 = dropoutLayer(0.3, 'Name', 'dropout_grade_1');
    fc2 = fullyConnectedLayer(1, 'Name', 'fc_grade_out');

    lgraph = addLayers(lgraph, [gem, fc1, relu1, dropout1, fc2]);
    lgraph = connectLayers(lgraph, 'fire9-concat', 'gem_pool');

    disp('construction OK');
    dln = dlnetwork(lgraph);
    disp('dlnetwork init OK');
    img = dlarray(rand(512, 512, 3, 2, 'single'), 'SSCB');
    out = predict(dln, img);
    fprintf('predict output size: %s (expect [1 2] i.e. one score per image)\n', mat2str(size(out)));
catch e
    fprintf('FAIL: %s\n', getReport(e));
end
