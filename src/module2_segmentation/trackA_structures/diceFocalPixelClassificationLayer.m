classdef diceFocalPixelClassificationLayer < nnet.layer.ClassificationLayer
    %DICEFOCALPIXELCLASSIFICATIONLAYER Combined Dice + Focal loss for pixel classification.
    %   layer = diceFocalPixelClassificationLayer(classNames, focalGamma, diceWeight)
    %
    %   loss = diceWeight * diceLoss + (1 - diceWeight) * focalLoss
    %
    %   Dice loss rewards correct overlap between predicted and true
    %   lesion regions directly (not just per-pixel accuracy, which is
    %   trivially high when background dominates). Focal loss
    %   down-weights easy, already-confident pixels so training
    %   attention concentrates on hard, rare classes. Used instead of
    %   plain cross-entropy specifically because Track A's classes are
    %   wildly imbalanced (background/vessel pixels vastly outnumber
    %   e.g. cotton-wool-spot pixels).
    %
    %   See also: buildTrackANetwork.

    properties
        FocalGamma
        DiceWeight
        SmoothingFactor = 1e-5
    end

    methods
        function layer = diceFocalPixelClassificationLayer(classNames, focalGamma, diceWeight, layerName)
            if nargin < 2, focalGamma = 2.0; end
            if nargin < 3, diceWeight = 0.5; end
            if nargin < 4, layerName = 'dice_focal_output'; end

            layer.Name = layerName;
            layer.Classes = classNames;
            layer.FocalGamma = focalGamma;
            layer.DiceWeight = diceWeight;
            layer.Description = sprintf('Dice(%.1f) + Focal(gamma=%.1f) pixel loss', diceWeight, focalGamma);
        end

        function loss = forwardLoss(layer, Y, T)
            % Y: predicted probabilities, HxWxKxN (softmax output)
            % T: one-hot ground truth, HxWxKxN
            eps_ = layer.SmoothingFactor;

            % ---- Dice loss, averaged over classes and batch ----
            intersection = sum(sum(Y .* T, 1), 2);          % 1x1xKxN
            unionSum = sum(sum(Y, 1), 2) + sum(sum(T, 1), 2); % 1x1xKxN
            diceCoeff = (2 * intersection + eps_) ./ (unionSum + eps_);
            diceLoss = 1 - mean(diceCoeff(:));

            % ---- Focal loss ----
            Yclipped = max(min(Y, 1 - 1e-7), 1e-7);
            pt = sum(Yclipped .* T, 3);                       % HxWx1xN, prob assigned to true class
            focalWeight = (1 - pt) .^ layer.FocalGamma;
            focalLossMap = -focalWeight .* log(pt);
            focalLoss = mean(focalLossMap(:));

            loss = layer.DiceWeight * diceLoss + (1 - layer.DiceWeight) * focalLoss;
        end
    end
end
