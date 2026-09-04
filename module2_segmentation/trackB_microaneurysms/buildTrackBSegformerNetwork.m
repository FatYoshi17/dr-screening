function net = buildTrackBSegformerNetwork(rawMatPath, patchSize, outputNetPath)
%BUILDTRACKBSEGFORMERNETWORK Build the trainable Track B SegFormer dlnetwork.
%   net = buildTrackBSegformerNetwork() loads the raw imported SegFormer
%   (data/models/segformer_imported_raw.mat, produced once by
%   importSegformerPyTorch.m from exportSegformerEager.py's traced
%   export), adds the image input layer, initializes it, and appends the
%   same 4x bilinear upsample + softmax + Dice+Focal loss head used by
%   the rest of Track B, ready for trainNetwork/trainTrackB.m.
%
%   This replaces the old ONNX-based importSegformerMATLAB.m path, which
%   is blocked by a MathWorks packaging defect in the ONNX converter
%   (see docs/segformer_onnx_issue.md) - importNetworkFromPyTorch on a
%   torch.jit.trace export is the path that actually works, once the
%   generated +segformer_eager/ code has the fixes documented inline in
%   its files applied (already done and committed in this repo).
%
%   See also: importSegformerPyTorch, exportSegformerEager.py, trainTrackB.

    if nargin < 1 || isempty(rawMatPath)
        rawMatPath = fullfile('data', 'models', 'segformer_imported_raw.mat');
    end
    if nargin < 2 || isempty(patchSize)
        patchSize = 512;
    end
    if nargin < 3
        outputNetPath = fullfile('data', 'models', 'segformer_ma_imported.mat');
    end
    if ~isfile(rawMatPath)
        error(['Raw import not found at %s.\n' ...
               'Run importSegformerPyTorch.m once first (see its header comment).'], rawMatPath);
    end

    fprintf('Loading raw SegFormer import from %s ...\n', rawMatPath);
    loaded = load(rawMatPath);
    net = loaded.net;

    inputLayer = imageInputLayer([patchSize patchSize 3], 'Normalization', 'none', ...
        'Name', 'segformer_input');
    net = addInputLayer(net, inputLayer, 'Initialize', true);

    % SegFormer outputs at 1/4 the input resolution (a known property of
    % its patch-merging encoder) - add a bilinear upsample back to full
    % patch size so output aligns pixel-for-pixel with the sliding
    % window it came from, ready for the Dice+Focal loss used elsewhere
    % in this pipeline.
    lgraph = layerGraph(net);
    outputLayerNames = net.OutputNames;

    upsampleLayer = resize2dLayer('Scale', [4 4], 'Method', 'bilinear', ...
        'Name', 'segformer_upsample_4x');
    lgraph = addLayers(lgraph, upsampleLayer);
    lgraph = connectLayers(lgraph, outputLayerNames{1}, 'segformer_upsample_4x');

    softmaxLayer_ = softmaxLayer('Name', 'segformer_softmax');
    outputClassLayer = diceFocalPixelClassificationLayer( ...
        {'Background', 'Microaneurysm'}, 2.0, 0.5, 'segformer_output');
    lgraph = addLayers(lgraph, softmaxLayer_);
    lgraph = addLayers(lgraph, outputClassLayer);
    lgraph = connectLayers(lgraph, 'segformer_upsample_4x', 'segformer_softmax');
    lgraph = connectLayers(lgraph, 'segformer_softmax', 'segformer_output');

    net = lgraph;

    outDir = fileparts(outputNetPath);
    if ~isempty(outDir) && ~isfolder(outDir)
        mkdir(outDir);
    end
    save(outputNetPath, 'net');
    fprintf('Trainable SegFormer network saved to %s - ready for trainTrackB.m fine-tuning.\n', ...
        outputNetPath);
end
