%TEST_CUSTOM_LAYERS Standalone sanity check for every custom layer's
% predict()/forwardLoss() against real dlarray inputs, independent of any
% pretrained backbone. Run: matlab -batch "test_custom_layers"

fprintf('=== cbamLayer ===\n');
try
    X = dlarray(rand(32, 32, 64, 2, 'single'), 'SSCB');
    layer = cbamLayer(64, 16, 'cbam1');
    Z = layer.predict(X);
    fprintf('  OK. Input %s -> Output %s\n', mat2str(size(X)), mat2str(size(Z)));
    assert(isequal(size(Z), size(X)), 'shape mismatch');
catch e
    fprintf('  FAIL: %s\n', getReport(e, 'basic'));
end

fprintf('=== multiScaleAttentionLayer ===\n');
try
    X = dlarray(rand(32, 32, 64, 2, 'single'), 'SSCB');
    layer = multiScaleAttentionLayer(64, 'msab1');
    Z = layer.predict(X);
    fprintf('  OK. Input %s -> Output %s\n', mat2str(size(X)), mat2str(size(Z)));
    assert(isequal(size(Z), size(X)), 'shape mismatch');
catch e
    fprintf('  FAIL: %s\n', getReport(e, 'basic'));
end

fprintf('=== gemPoolingLayer ===\n');
try
    X = dlarray(rand(16, 16, 2048, 2, 'single'), 'SSCB');
    layer = gemPoolingLayer('gem1');
    Z = layer.predict(X);
    fprintf('  OK. Input %s -> Output %s\n', mat2str(size(X)), mat2str(size(Z)));
    assert(isequal(size(Z), [1 1 2048 2]), 'shape mismatch');
catch e
    fprintf('  FAIL: %s\n', getReport(e, 'basic'));
end

fprintf('=== huberRegressionLayer ===\n');
try
    layer = huberRegressionLayer('huber1', 1.0);
    Y = single(rand(1, 4) * 4);
    T = single([0 1 2 4]);
    loss = layer.forwardLoss(Y, T);
    fprintf('  OK. loss = %g (scalar: %d)\n', loss, isscalar(loss));
catch e
    fprintf('  FAIL: %s\n', getReport(e, 'basic'));
end

fprintf('=== diceFocalPixelClassificationLayer ===\n');
try
    classNames = {'Background','VH','Retina','Fovea','Vessel','OD','EX','IRMA','HE','NV','CWS'};
    layer = diceFocalPixelClassificationLayer(classNames, 2.0, 0.5, 'dicefocal1');
    K = numel(classNames);
    raw = rand(8, 8, K, 2, 'single');
    Y = dlarray(raw ./ sum(raw, 3), 'SSCB');   % fake softmax output
    labelIdx = randi(K, 8, 8, 1, 2);
    T = zeros(8, 8, K, 2, 'single');
    for n = 1:2
        for r = 1:8
            for c = 1:8
                T(r, c, labelIdx(r,c,1,n), n) = 1;
            end
        end
    end
    T = dlarray(T, 'SSCB');
    loss = layer.forwardLoss(Y, T);
    fprintf('  OK. loss = %g (scalar: %d)\n', extractdata(loss), isscalar(loss));
catch e
    fprintf('  FAIL: %s\n', getReport(e, 'basic'));
end

