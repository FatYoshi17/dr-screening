function lgraph = buildTrackANetwork(imageSize, classNames)
%BUILDTRACKANETWORK Assemble Track A: DeepLabv3+ (resnet18) + multi-scale attention + CBAM.
%   lgraph = buildTrackANetwork(imageSize, classNames) returns a
%   layerGraph ready for trainNetwork/trainnet, covering every Refined
%   IDRiD class except microaneurysm (that's Track B):
%     background, VH, retina, fovea, vessel, OD, EX, IRMA, HE, NV, CWS
%   -> 11 classes total.
%
%   imageSize: e.g. [512 512 3] (reduced from Refined IDRiD's native
%   1024x1024 - training at full resolution ran out of memory on a 6GB
%   laptop GPU).
%   classNames: cellstr of the 11 class names, background first.
%
%   Requires: Computer Vision Toolbox (deeplabv3plusLayers), Deep
%   Learning Toolbox, and the "Deep Learning Toolbox Model for ResNet-18
%   Network" support package (for pretrained ImageNet weights).
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
%   LAYER NAME NOTE: verified directly against this MATLAB install
%   (R2025a) two ways - lgraph.Layers AND lgraph.Connections (the
%   listing order doesn't reflect real topology for a branching graph
%   like this one). Two real bugs from the first draft, caught this
%   way: (1) the default classification output layer is named
%   'classification', not 'labels' as assumed - removeLayers with a
%   nonexistent name would have errored immediately. (2) 'dec_relu2' is
%   NOT the decoder's final feature as the original comment claimed -
%   tracing lgraph.Connections shows it's the LOW-LEVEL SKIP branch
%   (fed from res2b_relu, channel-reduced), which merges via 'dec_cat1'
%   with the upsampled ASPP path and then runs through two more conv
%   blocks (dec_c3, dec_c4) before 'scorer'. Splicing attention in after
%   'dec_relu2' as originally written would have attached the
%   attention+scoring head to only the low-level skip path, bypassing
%   the ASPP fusion entirely - a silently-broken architecture, not just
%   a crash. The real final decoder feature, right before 'scorer', is
%   'dec_relu4'.
%
%   See also: cbamLayer, multiScaleAttentionLayer,
%   diceFocalPixelClassificationLayer, trainTrackA.

    numClasses = numel(classNames);

    % deeplabv3plusLayers already returns a layerGraph directly (not raw
    % layers) - wrapping it in layerGraph() again errors.
    lgraph = deeplabv3plusLayers(imageSize, numClasses, 'resnet18');

    decoderFeatureLayerName = 'dec_relu4';
    decoderChannels = 256; % dec_c4's NumFilters - verified against this install, not assumed

    % Only remove the scoring conv + its output layers - 'dec_upsample2'
    % and 'dec_crop2' stay, since they're what brings the prediction
    % back up to full input resolution (dec_crop2 references 'data' for
    % exact pixel alignment). Removing them too (as an earlier version
    % of this function did) leaves them dangling with an unconnected
    % input - reuse them instead of reinventing upsampling.
    lgraph = removeLayers(lgraph, {'scorer', 'softmax-out', 'classification'});

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
    lgraph = connectLayers(lgraph, 'trackA_final_conv', 'dec_upsample2');
    lgraph = connectLayers(lgraph, 'dec_crop2', 'trackA_softmax');
    lgraph = connectLayers(lgraph, 'trackA_softmax', 'trackA_output');
end
