repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
loaded = load(fullfile(repoRoot, 'data/models/segformer_imported_raw.mat'));
net = loaded.net;
inputLayer1 = imageInputLayer([512 512 3], 'Normalization', 'none');
net = addInputLayer(net, inputLayer1, 'Initialize', true);

for trial = 1:2
    img = dlarray(rand(512,512,3,1,'single'), 'SSCB');
    try
        out = predict(net, img);
        outData = extractdata(out);
        fprintf('Trial %d SUCCESS. Output size: %s\n', trial, mat2str(size(out)));
        fprintf('  Any NaN: %d, Any Inf: %d\n', any(isnan(outData),'all'), any(isinf(outData),'all'));
        fprintf('  min=%.4f max=%.4f mean=%.4f std=%.4f\n', min(outData,[],'all'), max(outData,[],'all'), mean(outData,'all'), std(outData(:)));
    catch ME
        fprintf('Trial %d FAILED: %s\n', trial, ME.message);
    end
end
