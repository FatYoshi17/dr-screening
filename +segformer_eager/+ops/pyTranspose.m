function Y = pyTranspose(X, dim0, dim1)
% at::transpose(const at::Tensor &self, int64_t dim0, int64_t dim1)
% Swaps the dimensions dim0 and dim1 in X

%Copyright 2022-2023 The MathWorks, Inc.

import segformer_eager.ops.*

dim0 = dim0.value;
dim1 = dim1.value;

% Input dlarray is expected to be in reverse-PyTorch Ordering
Xval = X.value;

% X.rank can understate the tensor's true PyTorch rank: in reverse-order
% storage the PyTorch batch dimension lands last, and MATLAB silently
% drops a trailing singleton (batch=1) dimension from the stored array,
% so ndims()-derived rank comes out one short. dim0/dim1 are the actual
% PyTorch dims this transpose needs to reach, so use them as a floor on
% the effective rank - permute() itself tolerates a target rank higher
% than ndims(Xval) (missing trailing dims are implicitly size-1).
effRank = double(X.rank);
effRank = max(effRank, neededRankForDim(dim0));
effRank = max(effRank, neededRankForDim(dim1));

% Perform Transpose only if input rank >= 2
if effRank >= 2
    mlDim0 = transformDim(dim0, effRank);
    mlDim1 = transformDim(dim1, effRank);

    % Create permutation vector
    perm = 1:effRank;
    perm(mlDim0) = mlDim1;
    perm(mlDim1) = mlDim0;

    Yval = dlarray(permute(Xval, perm), repmat('U', 1, effRank));
    Y = struct('value', Yval, 'rank', effRank);
else
    Y = struct('value', Xval, 'rank', effRank);
end
    function revPTDim = transformDim(dimRef ,XRank)
        if dimRef < 0
            revPTDim = -dimRef;
        else
            revPTDim = XRank - dimRef;
        end
    end
    function r = neededRankForDim(d)
        d = double(d);
        if d >= 0
            r = d + 1;
        else
            r = -d;
        end
    end
end