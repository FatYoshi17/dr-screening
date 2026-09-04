%SMOKE_TEST_TRACKB Tiny real trainNetwork run on a handful of patches to
% verify Track B's native CBAM CNN trains end to end before committing
% to a real run.

cfg = config();
patchSize = 256; % small for speed - real training uses 512

imageFiles = dir(fullfile(cfg.refinedIdridTrainImg, '*.jpg'));
allImages = {};
allLabels = {};

for i = 1:5
    [~, baseName, ~] = fileparts(imageFiles(i).name);
    imgPath = fullfile(cfg.refinedIdridTrainImg, imageFiles(i).name);
    lblPath = fullfile(cfg.refinedIdridTrainLbl, [baseName '_vessel.png']);
    img = imread(imgPath);
    label = imread(lblPath);
    maMask = (label == 255);

    [H, W, ~] = size(img);
    if H < patchSize || W < patchSize, continue; end
    r = randi(H - patchSize + 1);
    c = randi(W - patchSize + 1);
    allImages{end+1} = img(r:r+patchSize-1, c:c+patchSize-1, :); %#ok<AGROW>
    allLabels{end+1} = maMask(r:r+patchSize-1, c:c+patchSize-1); %#ok<AGROW>
end

fprintf('Collected %d patches for smoke test.\n', numel(allImages));

patchImages = arrayDatastore(cat(4, allImages{:}), 'IterationDimension', 4);
labelStack = cat(4, allLabels{:});
patchLabels = arrayDatastore(categorical(labelStack, [false true], {'Background', 'Microaneurysm'}), ...
    'IterationDimension', 4);
trainingData = combine(patchImages, patchLabels);

lgraph = buildTrackBNetwork(patchSize);

options = trainingOptions('adam', ...
    'InitialLearnRate', 1e-3, ...
    'MaxEpochs', 2, ...
    'MiniBatchSize', 2, ...
    'Shuffle', 'every-epoch', ...
    'ExecutionEnvironment', 'auto', ...
    'Plots', 'none', ...
    'Verbose', true);

fprintf('Starting tiny Track B smoke-test training run...\n');
net = trainNetwork(trainingData, lgraph, options);
fprintf('SMOKE TEST PASSED: trainNetwork completed without error.\n');

testImg = allImages{1};
pred = predict(net, testImg);
fprintf('predict output size: %s\n', mat2str(size(pred)));
