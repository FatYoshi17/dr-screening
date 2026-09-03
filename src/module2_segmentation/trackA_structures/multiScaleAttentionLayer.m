classdef multiScaleAttentionLayer < nnet.layer.Layer & nnet.layer.Formattable
    %MULTISCALEATTENTIONLAYER Parallel dilated convolutions, attention-weighted.
    %   layer = multiScaleAttentionLayer(numChannels, layerName) processes
    %   the input through three parallel 3x3 convolutions at dilation
    %   rates [1, 2, 4] - small receptive field for tiny structures
    %   (early exudates), progressively larger for big ones (optic disc)
    %   - then learns a per-scale, per-image softmax weighting (via
    %   global average pooling + a small FC) to combine the three scale
    %   outputs, instead of a fixed concatenation. This is what lets
    %   Track A handle structures of very different sizes in one network
    %   (MLNet-style multi-scale attention).
    %
    %   See also: cbamLayer, buildTrackANetwork.

    properties
        NumChannels
        DilationRates = [1 2 4]
    end

    properties (Learnable)
        Conv1Weights
        Conv1Bias
        Conv2Weights
        Conv2Bias
        Conv3Weights
        Conv3Bias
        AttnFCWeights
        AttnFCBias
    end

    methods
        function layer = multiScaleAttentionLayer(numChannels, layerName)
            if nargin < 2
                layerName = 'multiscale_attn';
            end
            layer.Name = layerName;
            layer.Description = sprintf('Multi-scale attention (C=%d, dilations=[1 2 4])', numChannels);
            layer.NumChannels = numChannels;

            layer.Conv1Weights = dlarray(initializeHe([3, 3, numChannels, numChannels]));
            layer.Conv1Bias    = dlarray(zeros(numChannels, 1, 'single'));
            layer.Conv2Weights = dlarray(initializeHe([3, 3, numChannels, numChannels]));
            layer.Conv2Bias    = dlarray(zeros(numChannels, 1, 'single'));
            layer.Conv3Weights = dlarray(initializeHe([3, 3, numChannels, numChannels]));
            layer.Conv3Bias    = dlarray(zeros(numChannels, 1, 'single'));

            % Attention MLP: pooled numChannels -> 3 scale weights
            layer.AttnFCWeights = dlarray(initializeHe([3, numChannels]));
            layer.AttnFCBias    = dlarray(zeros(3, 1, 'single'));
        end

        function Z = predict(layer, X)
            % X: formatted dlarray 'SSCB'
            s1 = dlconv(X, layer.Conv1Weights, layer.Conv1Bias, 'Padding', 'same', ...
                'DilationFactor', layer.DilationRates(1));
            s2 = dlconv(X, layer.Conv2Weights, layer.Conv2Bias, 'Padding', 'same', ...
                'DilationFactor', layer.DilationRates(2));
            s3 = dlconv(X, layer.Conv3Weights, layer.Conv3Bias, 'Padding', 'same', ...
                'DilationFactor', layer.DilationRates(3));
            s1 = relu(s1); s2 = relu(s2); s3 = relu(s3);

            pooled = stripdims(mean(X, [1 2])); % 1x1xCxN -> squeeze
            sz = size(X);
            C = sz(3); N = sz(4);
            pooledVec = reshape(pooled, C, N);

            attnLogits = layer.AttnFCWeights * pooledVec + layer.AttnFCBias; % 3xN
            attnWeights = softmax(attnLogits, 'DataFormat', 'CB');           % 3xN, sums to 1 per image

            w1 = reshape(attnWeights(1, :), [1 1 1 N]);
            w2 = reshape(attnWeights(2, :), [1 1 1 N]);
            w3 = reshape(attnWeights(3, :), [1 1 1 N]);
            w1 = dlarray(w1, 'SSCB'); w2 = dlarray(w2, 'SSCB'); w3 = dlarray(w3, 'SSCB');

            Z = s1 .* w1 + s2 .* w2 + s3 .* w3;
        end
    end
end

function w = initializeHe(sz)
    fanIn = prod(sz(1:end-1));
    w = randn(sz, 'single') * sqrt(2 / fanIn);
end
