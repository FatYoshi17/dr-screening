function Y = pySoftmax(X, ptDim)
%PYSOFTMAX Applies a softmax transformation to the input data.
% at::Tensor at::softmax(const at::Tensor &self, int64_t dim, c10::optional<at::ScalarType> dtype = c10::nullopt)

%Copyright 2022-2023 The MathWorks, Inc.

import segformer_eager.ops.*

Xval = X.value;
Xrank = X.rank;
Yrank = Xrank;

% If X is a vector, ensure it is a column vector
if Xrank==1
    Xval = [Xval(:)];
end

% Convert dim to reverse-pytorch
ptDim = ptDim.value;
if (ptDim<0)
    Cdim = -ptDim;
else
    Cdim = Xrank - ptDim;
end


% Label Xval "S*CU*" with C in the desired dimension, then call
% dlarray/softmax, then remove the label. Note that the labeling does not
% cause a permutation to occur.

Xval = dlarray(Xval, [repmat('S',1,Cdim-1), 'C', repmat('U',1,Xrank-Cdim)]);
Yval = stripdims(softmax(Xval));

Yval = dlarray(Yval, repmat('U', 1, max(2,Yrank)));

Y = struct('value', Yval, 'rank', Xrank);
end