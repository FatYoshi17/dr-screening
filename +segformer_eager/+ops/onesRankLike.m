function Y = onesRankLike(rankVal, refValue)
%ONESRANKLIKE Placeholder ones([1,rank]) array matching refValue's GPU/CPU placement.
%   Used for the auto-generated "_rank" bookkeeping outputs threaded
%   between custom layers - only numel() of the result is ever read
%   downstream to recover a rank count, so the values themselves don't
%   matter, but dlnetwork's output-type checker requires every declared
%   multi-output to be gpuArray-backed whenever the layer runs on GPU.
%   MATLAB's own generated code creates these with plain ones([1,rank],
%   'single'), which stays on the CPU regardless of where the rest of
%   the layer's data lives - this fixes that by matching refValue's
%   actual placement instead.

    if isa(refValue, 'dlarray')
        raw = extractdata(refValue);
    else
        raw = refValue;
    end
    if isa(raw, 'gpuArray')
        Y = gpuArray.ones([1, rankVal], 'single');
    else
        Y = ones([1, rankVal], 'single');
    end
end
