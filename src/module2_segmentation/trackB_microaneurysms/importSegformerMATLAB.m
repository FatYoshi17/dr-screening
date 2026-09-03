function net = importSegformerMATLAB(onnxPath, outputNetPath)
%IMPORTSEGFORMERMATLAB Import the ONNX SegFormer export into MATLAB.
%   net = importSegformerMATLAB(onnxPath) imports the .onnx file
%   produced by exportSegformerONNX.py using MATLAB's ONNX importer,
%   adds an upsampling layer to bring SegFormer's 1/4-resolution output
%   back to full patch resolution, and returns a dlnetwork ready for
%   fine-tuning (see trainTrackB.m).
%
%   Requires: Deep Learning Toolbox Converter for ONNX Model Format
%   (install via Add-On Explorer if not already present).
%
%   This is the one deliberate step outside native MATLAB tooling for
%   this project - SegFormer has no built-in MATLAB support, so the
%   path is: export from PyTorch (exportSegformerONNX.py) -> import here
%   -> fine-tune natively in MATLAB from this point on.
%
%   See also: exportSegformerONNX.py, trainTrackB, detectMicroaneurysmsV2.

    if nargin < 2
        outputNetPath = fullfile('data', 'models', 'segformer_ma_imported.mat');
    end
    if ~isfile(onnxPath)
        error(['ONNX file not found at %s.\n' ...
               'Run exportSegformerONNX.py first (on a machine with PyTorch + ' ...
               'transformers installed) - see docs/RUN_GUIDE.md.'], onnxPath);
    end

    fprintf('Importing %s ...\n', onnxPath);
    importedNet = importNetworkFromONNX(onnxPath, ...
        'InputDataFormats', 'BCSS', ...
        'OutputDataFormats', 'BCSS');

    % SegFormer outputs at 1/4 the input resolution (a known property of
    % its patch-merging encoder) - add a bilinear upsample back to full
    % patch size so output aligns pixel-for-pixel with the sliding
    % window it came from, ready for the Dice+Focal loss used elsewhere
    % in this pipeline.
    lgraph = layerGraph(importedNet);
    outputLayerNames = importedNet.OutputNames;

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
    fprintf('Imported and re-headed SegFormer saved to %s - ready for trainTrackB.m fine-tuning.\n', ...
        outputNetPath);
end
