classdef huberRegressionLayer < nnet.layer.RegressionLayer
    %HUBERREGRESSIONLAYER Huber loss for the grading CNN's continuous 0-4 output.
    %   layer = huberRegressionLayer(layerName, delta)
    %
    %   Huber loss is quadratic for small errors and linear for large
    %   ones (threshold delta) - an L1/robust-regression alternative to
    %   plain MSE, less sensitive to the occasional badly-graded outlier
    %   in the training labels. Predicting a continuous score (then
    %   optimizing rounding thresholds separately - see
    %   trainGradingCNN.m) is the regression-framing choice adopted from
    %   the APTOS 2019 competition's winning solutions, which matches
    %   how ordinal closeness actually gets scored far better than a
    %   plain 5-way softmax classifier would.
    %
    %   See also: trainGradingCNN, gemPoolingLayer.

    properties
        Delta
    end

    methods
        function layer = huberRegressionLayer(layerName, delta)
            if nargin < 1, layerName = 'huber_output'; end
            if nargin < 2, delta = 1.0; end
            layer.Name = layerName;
            layer.Delta = delta;
            layer.Description = sprintf('Huber regression loss (delta=%.2f)', delta);
        end

        function loss = forwardLoss(layer, Y, T)
            err = Y - T;
            absErr = abs(err);
            quadraticPart = 0.5 * err.^2;
            linearPart = layer.Delta * (absErr - 0.5 * layer.Delta);
            elementLoss = (absErr <= layer.Delta) .* quadraticPart + ...
                          (absErr > layer.Delta) .* linearPart;
            loss = mean(elementLoss(:));
        end
    end
end
