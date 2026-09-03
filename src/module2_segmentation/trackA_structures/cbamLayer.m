classdef cbamLayer < nnet.layer.Layer & nnet.layer.Formattable
    %CBAMLAYER Convolutional Block Attention Module (channel + spatial attention).
    %   layer = cbamLayer(numChannels, reductionRatio, layerName) builds a
    %   CBAM block for a feature map with numChannels channels.
    %
    %   Channel attention: global average- and max-pooled descriptors
    %   both pass through a shared 2-layer MLP (reduce by reductionRatio,
    %   ReLU, restore), are summed, and squashed by sigmoid into a
    %   per-channel gate that reweights the input.
    %
    %   Spatial attention: average- and max-pool ACROSS channels instead,
    %   concatenate into a 2-channel map, run a 7x7 conv + sigmoid to get
    %   a per-pixel gate, and reweight the channel-attended input.
    %
    %   Used on Track A's decoder / skip connections so the network
    %   learns to boost lesion-relevant channels and locations instead of
    %   treating every learned feature and every pixel equally.
    %
    %   Reference: Woo et al., "CBAM: Convolutional Block Attention
    %   Module", ECCV 2018.

    properties
        ReductionRatio
    end

    properties (Learnable)
        ChannelFC1Weights
        ChannelFC1Bias
        ChannelFC2Weights
        ChannelFC2Bias
        SpatialConvWeights
        SpatialConvBias
    end

    methods
        function layer = cbamLayer(numChannels, reductionRatio, layerName)
            if nargin < 2
                reductionRatio = 16;
            end
            if nargin < 3
                layerName = 'cbam';
            end
            layer.Name = layerName;
            layer.Description = sprintf('CBAM channel+spatial attention (C=%d, r=%d)', ...
                numChannels, reductionRatio);
            layer.ReductionRatio = reductionRatio;

            hidden = max(floor(numChannels / reductionRatio), 4);

            % He-initialized weights for the shared channel-attention MLP
            layer.ChannelFC1Weights = dlarray(initializeHe([hidden, numChannels]));
            layer.ChannelFC1Bias    = dlarray(zeros(hidden, 1, 'single'));
            layer.ChannelFC2Weights = dlarray(initializeHe([numChannels, hidden]));
            layer.ChannelFC2Bias    = dlarray(zeros(numChannels, 1, 'single'));

            % 7x7 conv over the 2-channel (avg,max) spatial descriptor
            layer.SpatialConvWeights = dlarray(initializeHe([7, 7, 2, 1]));
            layer.SpatialConvBias    = dlarray(zeros(1, 1, 'single'));
        end

        function Z = predict(layer, X)
            % X is a formatted dlarray, 'SSCB' (H, W, C, N)

            % ---- Channel attention ----
            avgPool = mean(X, [1 2]);       % 1x1xCxN
            maxPool = max(max(X, [], 1), [], 2); % 1x1xCxN

            avgPool = stripdims(avgPool);
            maxPool = stripdims(maxPool);
            sz = size(X);
            C = sz(3);
            N = sz(4);
            avgVec = reshape(avgPool, C, N);
            maxVec = reshape(maxPool, C, N);

            avgOut = layer.ChannelFC2Weights * max(layer.ChannelFC1Weights * avgVec + layer.ChannelFC1Bias, 0) ...
                     + layer.ChannelFC2Bias;
            maxOut = layer.ChannelFC2Weights * max(layer.ChannelFC1Weights * maxVec + layer.ChannelFC1Bias, 0) ...
                     + layer.ChannelFC2Bias;

            channelGate = sigmoid(avgOut + maxOut);           % CxN
            channelGate = reshape(channelGate, [1, 1, C, N]);
            channelGate = dlarray(channelGate, 'SSCB');

            Xc = X .* channelGate;                             % channel-attended features

            % ---- Spatial attention ----
            avgSpatial = mean(Xc, 3);   % HxWx1xN
            maxSpatial = max(Xc, [], 3);
            spatialDesc = cat(3, avgSpatial, maxSpatial);       % HxWx2xN

            spatialConv = dlconv(spatialDesc, layer.SpatialConvWeights, layer.SpatialConvBias, ...
                'Padding', 'same');
            spatialGate = sigmoid(spatialConv);                 % HxWx1xN

            Z = Xc .* spatialGate;
        end
    end
end

function w = initializeHe(sz)
    fanIn = prod(sz(1:end-1));
    w = randn(sz, 'single') * sqrt(2 / fanIn);
end
