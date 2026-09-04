function [Yout] = pyUpsample2d(X, mode, outputSize, alignCorners, scale, scaleExtra)
%pyUpsample2d applies a resize operation on the input tensor 

%Copyright 2022-2023 The MathWorks, Inc.

import segformer_eager.ops.*

[X] = labelWithPropagatedFormats(X,"*CSS");
Xval = X.value;
Xrank = X.rank;

if nargin >=6
    scaleH = scale.value;
    scaleW = scaleExtra.value;
    scaleVal = [scaleH scaleW];
else
    scaleVal = scale.value;
end

outputSizeCell = {outputSize.value};
for iOutSize = 1:numel(outputSizeCell)
    if isa(outputSizeCell{iOutSize}, 'dlarray')
        outputSizeCell{iOutSize} = extractdata(outputSizeCell{iOutSize});
    end
end
outputSizeVal = double([outputSizeCell{:}]);
alignCornersVal = alignCorners.value;

%No equivalent geometric transform for alignCorners = true in MATLAB
if alignCornersVal
     warning(message("nnet_cnn_pytorchconverter:pytorchconverter:NumericalMismatchInOperator","pyUpsample2d","aten::upsample_bilinear2d","AlignCorners = true"));
end

%The "dlresize" function does not support "cubic" interpolation, "linear"
%interpolation method is used in its place.
if mode == "cubic"
    warning(message("nnet_cnn_pytorchconverter:pytorchconverter:UnsupportedUpsamplingMode"));
    mode = "linear";
end


if mode == "linear"
    gTransformMode = 'half-pixel';
else
    gTransformMode = 'asymmetric';
end


if isempty(scaleVal)
    Yval = dlresize(Xval, 'OutputSize',outputSizeVal, 'Method',mode, ...
        'GeometricTransformMode',gTransformMode, 'NearestRoundingMode','floor');
else
    %When scaleH ~= scaleW numerics do not match between MATLAB and PyTorch
    if mode == "nearest"
        if scaleVal(1) ~= scaleVal(2)
             warning(message("nnet_cnn_pytorchconverter:pytorchconverter:NumericalMismatchInOperator","pyUpsample2d","aten::upsample_nearest2d","scaleH ~= scaleW"));
        end
    end
    Yval = dlresize(Xval, 'Scale',scaleVal, 'Method',mode, ...
        'GeometricTransformMode',gTransformMode, 'NearestRoundingMode','floor');
end

[YRevPyTorch,~] = permuteToReversePyTorch(Yval, '*CSS');

Yout = struct('value',YRevPyTorch,'rank',Xrank);
end

