function Y = pyLayerNorm(X, normalizedShape, scale, offset, epsilon)
%PYLAYERNORM Normalizes mini-batches of data over the normalized shape.

%Copyright 2023 The MathWorks, Inc.

import segformer_eager.ops.*

% Inputs are in reverse-pytorch
Xval = X.value;
Xrank = X.rank;

normalizedShape = normalizedShape.value;

if isempty(scale.value)
    scale = dlarray(ones(flip(normalizedShape)), repmat('U', [1 numel(normalizedShape)]));
else
    scale = scale.value;
end

if isempty(offset.value)
    offset = dlarray(zeros(flip(normalizedShape)), repmat('U', [1 numel(normalizedShape)]));
else
    offset = offset.value;
end

epsilon = double(epsilon.value);
% Epsilon must be non-negative.
if(epsilon <= 0)
    warning(message("nnet_cnn_pytorchconverter:pytorchconverter:BadEpsilon"));
    epsilon = 1e-5;
end

% Calculate statistics
dimension = 1: numel(normalizedShape);
XMean = mean(Xval, dimension);
XVar = mean((Xval - XMean).^2, dimension);

% Normalize
invSqrtVarPlusEps = 1 ./ sqrt(matlab.lang.internal.move(XVar) + epsilon);
scale = scale .* invSqrtVarPlusEps;
offset = offset - XMean .* scale;

% Evaluate output
Y = scale .* Xval + offset;

Y = dlarray(Y, repmat('U',1, max(2,Xrank)));
% Return outputs as structs
Y = struct('value', Y, 'rank', Xrank);

end