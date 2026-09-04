repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(repoRoot, 'module2_segmentation', 'trackB_microaneurysms'));
cd(repoRoot);

lgraph = buildTrackBSegformerNetwork([], 512);

img = rand(512, 512, 3, 3, 'single');
lbl = randi([0 1], 512, 512, 1, 3) == 1;

imgDs = arrayDatastore(img, 'IterationDimension', 4);
lblDs = arrayDatastore(categorical(lbl, [false true], {'Background', 'Microaneurysm'}), 'IterationDimension', 4);
trainingData = combine(imgDs, lblDs);

options = trainingOptions('adam', ...
    'InitialLearnRate', 1e-4, ...
    'MaxEpochs', 1, ...
    'MiniBatchSize', 1, ...
    'ExecutionEnvironment', 'auto', ...
    'Verbose', true, ...
    'Plots', 'none');

try
    net = trainNetwork(trainingData, lgraph, options);
    fprintf('BACKWARD SMOKE TEST: SUCCESS\n');
catch ME
    fprintf('BACKWARD SMOKE TEST: FAILED\n');
    e = ME;
    depth = 0;
    while ~isempty(e)
        fprintf('--- level %d: %s ---\n%s\n', depth, e.identifier, e.message);
        for k = 1:min(numel(e.stack), 6)
            fprintf('  %s (line %d)\n', e.stack(k).name, e.stack(k).line);
        end
        if isempty(e.cause)
            break;
        end
        e = e.cause{1};
        depth = depth + 1;
    end
end
