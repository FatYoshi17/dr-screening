classdef gemPoolingLayer < nnet.layer.Layer & nnet.layer.Formattable
    %GEMPOOLINGLAYER Generalized Mean (GeM) pooling, replacing plain global average pool.
    %   layer = gemPoolingLayer(layerName) computes, per channel:
    %       y = ( mean( max(x, eps) .^ p ) ) ^ (1/p)
    %   with p a single learnable scalar (initialized to 3, the common
    %   default) shared across channels. p=1 reduces to average pooling;
    %   larger p behaves more like max pooling, letting the network
    %   learn where on that spectrum works best for this task. This was
    %   one of the small architectural swaps in the APTOS 2019 winning
    %   solution's grading CNN (Xu et al.) - used here in place of the
    %   pretrained backbone's default average-pooling layer before the
    %   grading head.
    %
    %   See also: trainGradingCNN.

    properties (Learnable)
        P
    end

    methods
        function layer = gemPoolingLayer(layerName)
            if nargin < 1
                layerName = 'gem_pool';
            end
            layer.Name = layerName;
            layer.Description = 'Generalized Mean (GeM) pooling';
            layer.P = dlarray(single(3));
        end

        function Z = predict(layer, X)
            pClamped = max(layer.P, 1); % keep p well-defined/stable
            Xclamped = max(X, 1e-6);
            Z = mean(Xclamped .^ pClamped, [1 2]) .^ (1 ./ pClamped);
        end
    end
end
