function lgraph = buildTrackBNetwork(patchSize)
%BUILDTRACKBNETWORK Assemble Track B: a MATLAB-native CBAM-attention CNN
%for dense microaneurysm (MA) segmentation, no pooling/downsampling.
%   lgraph = buildTrackBNetwork(patchSize) returns a layerGraph ready
%   for trainNetwork, mapping a patchSize x patchSize x 3 RGB patch to a
%   patchSize x patchSize x 2 (Background/Microaneurysm) dense
%   prediction - full input resolution preserved throughout, since MAs
%   are only a few pixels wide and any pooling risks erasing them
%   entirely (the same reasoning that ruled out whole-image downsampling
%   for this track in the first place).
%
%   BACKBONE NOTE: the original design imported a pretrained SegFormer-B0
%   via ONNX (exportSegformerONNX.py -> importSegformerMATLAB.m). That
%   needs the "Deep Learning Toolbox Converter for ONNX Model Format"
%   add-on, which needs an active MathWorks Software Maintenance license
%   - unavailable here (Add-On Explorer itself is locked), even though
%   the .onnx file itself was already exported successfully. This
%   builds Track B as a standalone CBAM-attention CNN instead - no
%   ONNX, no Python at inference or training time, matches the
%   MATLAB-tooling-risk reasoning your own architecture doc already
%   gave for preferring a native CNN here. Receptive field comes from
%   multiScaleAttentionLayer's parallel dilated convolutions (rates
%   [1,2,4]) instead of SegFormer's transformer attention - smaller
%   model, but never downsamples, so it arguably fits Track B's own
%   "don't erase tiny lesions" design goal more directly than the
%   SegFormer path did (which needed a 4x downsample then a 4x
%   upsample to compensate).
%
%   Output contract matches what detectMicroaneurysmsV2.m expects
%   exactly: predict(net, patch) -> patchSize x patchSize x 2 softmax
%   probability map, channel 2 = 'Microaneurysm'. No SegFormer-specific
%   downstream code needed - detectMicroaneurysmsV2.m is backbone-
%   agnostic already.
%
%   See also: cbamLayer, multiScaleAttentionLayer,
%   diceFocalPixelClassificationLayer, trainTrackB, detectMicroaneurysmsV2.

    classNames = {'Background', 'Microaneurysm'};
    inputSize = [patchSize, patchSize, 3];

    input = imageInputLayer(inputSize, 'Name', 'input', 'Normalization', 'zscore');

    stemConv = convolution2dLayer(3, 32, 'Name', 'trackB_stem_conv', 'Padding', 'same', 'WeightsInitializer', 'he');
    stemBN = batchNormalizationLayer('Name', 'trackB_stem_bn');
    stemRelu = reluLayer('Name', 'trackB_stem_relu');

    msab1 = multiScaleAttentionLayer(32, 'trackB_msab1');
    cbam1 = cbamLayer(32, 8, 'trackB_cbam1');

    conv2 = convolution2dLayer(3, 64, 'Name', 'trackB_conv2', 'Padding', 'same', 'WeightsInitializer', 'he');
    bn2 = batchNormalizationLayer('Name', 'trackB_bn2');
    relu2 = reluLayer('Name', 'trackB_relu2');

    msab2 = multiScaleAttentionLayer(64, 'trackB_msab2');
    cbam2 = cbamLayer(64, 16, 'trackB_cbam2');

    conv3 = convolution2dLayer(3, 64, 'Name', 'trackB_conv3', 'Padding', 'same', 'WeightsInitializer', 'he');
    bn3 = batchNormalizationLayer('Name', 'trackB_bn3');
    relu3 = reluLayer('Name', 'trackB_relu3');

    msab3 = multiScaleAttentionLayer(64, 'trackB_msab3');
    cbam3 = cbamLayer(64, 16, 'trackB_cbam3');

    conv4 = convolution2dLayer(3, 32, 'Name', 'trackB_conv4', 'Padding', 'same', 'WeightsInitializer', 'he');
    bn4 = batchNormalizationLayer('Name', 'trackB_bn4');
    relu4 = reluLayer('Name', 'trackB_relu4');

    finalConv = convolution2dLayer(1, numel(classNames), 'Name', 'trackB_final_conv', 'WeightsInitializer', 'he');
    softmaxLayer_ = softmaxLayer('Name', 'trackB_softmax');
    outputLayer = diceFocalPixelClassificationLayer(classNames, 2.0, 0.5, 'trackB_output');

    layers = [input, stemConv, stemBN, stemRelu, ...
        msab1, cbam1, conv2, bn2, relu2, ...
        msab2, cbam2, conv3, bn3, relu3, ...
        msab3, cbam3, conv4, bn4, relu4, ...
        finalConv, softmaxLayer_, outputLayer];

    lgraph = layerGraph(layers);
end
