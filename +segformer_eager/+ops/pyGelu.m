function Y = pyGelu(X, approximate)
%PYLEAKYRELU Returns the GELU activation of the input X
% at::Tensor at::gelu(const at::Tensor &self, c10::string_view approximate = "none")

%Copyright 2023 The MathWorks, Inc.

import segformer_eager.ops.*

if ~any(strcmp(approximate.value, {'none', 'tanh'}))
    approximate.value = 'none';
    warning(message('nnet_cnn_pytorchconverter:pytorchconverter:NumericalMismatchInOperator', ...
    'pyGelu', 'aten::gelu', "approximate ~= 'none' or 'tanh'"));
end

Yval = gelu(X.value, Approximation=approximate.value);
Yrank = X.rank;
Y = struct('value', Yval, 'rank', Yrank);
end
