function Yval = pySize(X, dim)
%PYSIZE Returns the size of the input tensor at the given dim
% If dim is empty, return the sizes of all dimensions
% int64_t at::size(const Tensor &tensor, int64_t dim)

%   Copyright 2022-2023 The MathWorks, Inc.

import segformer_eager.ops.*

dim = dim.value;

Xval = X.value;
Xrank = X.rank;

if Xrank == 0 % X is a scalar
    Yval = [];
elseif Xrank == 1 % X is a vector
    Yval = numel(Xval);
else
    % Convert dim to reverse-pytorch order
    if isempty(dim)
        dim = 0:Xrank-1;
    end

    % Convert negative indices to positive indices
    dim(dim < 0) = dim(dim < 0) + Xrank;

    % Convert forward- to reverse- dimension order
    dltDim = Xrank - dim;

    % Xrank can overstate the array's actual MATLAB-side ndims when a
    % leading singleton (e.g. batch=1) got silently squeezed out of the
    % stored data - MATLAB doesn't preserve degenerate leading/trailing
    % dimensions the way an explicit rank count assumes. When that
    % happens, dltDim resolves to an index MATLAB's size() can't answer
    % (<1, or >ndims(Xval)); by definition a squeezed dimension has
    % size 1, so return that directly instead of erroring.
    Yval = zeros(size(dltDim));
    for iDim = 1:numel(dltDim)
        d = dltDim(iDim);
        if d < 1 || d > ndims(Xval)
            Yval(iDim) = 1;
        else
            Yval(iDim) = size(Xval, d);
        end
    end
end

% Set the output rank
if isscalar(dim)
    Yrank = 0;
else
    Yrank = 1;
end

Yval = struct('value', int64(Yval(:)), 'rank', Yrank);
end