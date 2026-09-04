function Y = pyConcat(varargin)
%PYCONCAT Concatenates tensors together along the dimension dim
%   at::Tensor at::concat(at::TensorList tensors, int64_t dim = 0)

%   Copyright 2022-2023 The MathWorks, Inc.

import segformer_eager.ops.*

numInputs = numel(varargin);
if numInputs == 2
    Xs = varargin{1};
    dim = varargin{2};
else
    Xs = [varargin{1:end-1}];
    dim = varargin{end};
end
dim = dim.value;

% Convert dim to reverse-pytorch
dim = Xs(1).rank - dim; 

Yval = cat(dim, Xs.value);

Yval = dlarray(Yval, repmat('U', 1, Xs(1).rank));


Y = struct('value', Yval, 'rank', Xs(1).rank);
end