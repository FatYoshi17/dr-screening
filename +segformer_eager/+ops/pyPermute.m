function Y = pyPermute(X, pyDims)
%PYPERMUTE  The result is always returned in reverse-pytorch ordering and
%labeled with all U's.
% at::Tensor at::permute(const at::Tensor &self, at::IntArrayRef dims)

%   Copyright 2022-2023 The MathWorks, Inc.

import segformer_eager.ops.*

Xrev = X.value;
if X.rank<2
    Yrev = Xrev(:);                           % Permuting <2D does nothing
else
    mlPerm = X.rank - flip(pyDims.value);
    Yrev = permute(Xrev, mlPerm);
end

% Apply output label of all U's
Yrev = dlarray(Yrev, repmat('U', 1, max(2,X.rank)));

% Return Y
Y = struct('value', Yrev, 'rank', X.rank);
end