function lgraph = buildTrackANetwork(imageSize, classNames)
%BUILDTRACKANETWORK Assemble Track A: DeepLabv3+ (resnet18) + multi-scale attention + CBAM.
%   lgraph = buildTrackANetwork(imageSize, classNames) returns a
%   layerGraph ready for trainNetwork/trainnet, covering every Refined
%   IDRiD class except microaneurysm (that's Track B):
%     background, VH, retina, fovea, vessel, OD, EX, IRMA, HE, NV, CWS
%   -> 11 classes total.
%
%   imageSize: e.g. [1024 1024 3] to match Refined IDRiD's mask resolution.
%   classNames: cellstr of the 11 class names, background first.
%
%   Requires: Computer Vision Toolbox (deeplabv3plusLayers), Deep
%   Learning Toolbox.
%
%   Base network is DeepLabv3+ on a resnet18 encoder - resnet18 rather
%   than resnet34/EfficientNet-B0 as earlier discussed, because
%   deeplabv3plusLayers only ships with resnet18/resnet50/mobilenetv2/
%   xception/inceptionresnetv2 as supported pretrained backbones in
%   MATLAB; resnet18 is the closest lightweight match and keeps this on
%   fully-supported, testable MATLAB tooling rather than a hand-grafted
%   backbone. Also matches the DeepLabV3+ family Refined IDRiD's own
%   paper baseline used, so results are a fair comparison point.
%
%   After the base network's ASPP/decoder feature map, this inserts:
%     multiScaleAttentionLayer -> cbamLayer -> final 1x1 conv -> softmax
%     -> diceFocalPixelClassificationLayer
%   replacing the default cross-entropy pixel classification layer.
%
%   See also: cbamLayer, multiScaleAttentionLayer,
%   diceFocalPixelClassificationLayer, trainTrackA.

    numClasses = numel(classNames);

    baseNet = deeplabv3plusLayers(imageSize, numClasses, 'resnet18');
    lgraph = layerGraph(baseNet);

    % The layer immediately upstream of the default classification head
    % in MATLAB's deeplabv3plusLayers output is named 'scorer' (1x1 conv
    % to numClasses) preceded by 'dec_relu2'. We splice our attention
    % blocks in right after the decoder's last ReLU, before that final
    % scoring conv, then rebuild the head ourselves.
    decoderFeatureLayerName = 'dec_relu2';
    decoderChannels = 256; % deeplabv3plusLayers' decoder output channel count

    lgraph = removeLayers(lgraph, {'scorer', 'softmax-out', 'labels'});

    multiScale = multiScaleAttentionLayer(decoderChannels, 'trackA_multiscale_attn');
    cbam = cbamLayer(decoderChannels, 16, 'trackA_cbam');
    finalConv = convolution2dLayer(1, numClasses, 'Name', 'trackA_final_conv', ...
        'WeightsInitializer', 'he');
    softmaxLayer_ = softmaxLayer('Name', 'trackA_softmax');
    outputLayer = diceFocalPixelClassificationLayer(classNames, 2.0, 0.5, 'trackA_output');

    lgraph = addLayers(lgraph, multiScale);
    lgraph = addLayers(lgraph, cbam);
    lgraph = addLayers(lgraph, finalConv);
    lgraph = addLayers(lgraph, softmaxLayer_);
    lgraph = addLayers(lgraph, outputLayer);

    lgraph = connectLayers(lgraph, decoderFeatureLayerName, 'trackA_multiscale_attn');
    lgraph = connectLayers(lgraph, 'trackA_multiscale_attn', 'trackA_cbam');
    lgraph = connectLayers(lgraph, 'trackA_cbam', 'trackA_final_conv');
    lgraph = connectLayers(lgraph, 'trackA_final_conv', 'trackA_softmax');
    lgraph = connectLayers(lgraph, 'trackA_softmax', 'trackA_output');
end
