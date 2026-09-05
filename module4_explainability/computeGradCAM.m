function camResult = computeGradCAM(rgbImage, gradingModelPath, targetGrade)
%COMPUTEGRADCAM Module 4: Grad-CAM heatmap for the grading CNN's decision.
%   camResult = computeGradCAM(rgbImage, gradingModelPath, targetGrade)
%
%   Wraps MATLAB's built-in gradCAM function (Deep Learning Toolbox) on
%   the Module 3 grading network. Since that network is a regression
%   head (continuous 0-4 score, not a softmax classifier - see
%   trainGradingCNN.m), gradCAM is pointed at the scalar regression
%   output directly rather than a class-probability channel.
%
%   Returns:
%     camResult.heatmap      - HxW Grad-CAM activation map, resized to
%                               the input image size
%     camResult.heatmapMask  - HxW logical, heatmap thresholded at the
%                               75th percentile of its own values (used
%                               by lesionAttentionOverlap.m)
%     camResult.overlayImage - RGB image with the heatmap blended on top,
%                               ready to drop into the annotated report
%
%   See also: lesionAttentionOverlap, generateAnnotatedReport,
%   predictGradingCNN.

    if nargin < 3
        targetGrade = []; % not used for a regression head, kept for API symmetry
    end
    if nargin < 2 || isempty(gradingModelPath)
        gradingModelPath = fullfile('data', 'models', 'module3_grading_cnn.mat');
    end
    loaded = load(gradingModelPath, 'model');
    model = loaded.model;

    imgResized = imresize(im2uint8(rgbImage), model.inputSize(1:2));

    % gradCAM's actual name-value parameter is 'ReductionLayer', not
    % 'OutputLayer' (which isn't a recognized parameter at all - this
    % errored immediately when first exercised end-to-end). It also has
    % to be a non-output layer - 'grading_huber_output' (the network's
    % actual output/loss layer) errors; 'fc_grade_out', the fully
    % connected layer producing the raw regression score just before
    % it, is what's actually wanted here. Likewise 'gem_pool' (GeM
    % pooling, by definition) has already collapsed the spatial
    % dimensions gradCAM needs to build a heatmap over - use
    % 'activation_49_relu', the last resnet50 layer before that pooling
    % that still has real spatial resolution.
    scoreMap = gradCAM(model.net, imgResized, 1, ...
        'ReductionLayer', 'fc_grade_out', ...
        'FeatureLayer', 'activation_49_relu');

    heatmap = imresize(scoreMap, [size(rgbImage,1), size(rgbImage,2)]);
    heatmap = rescale(heatmap); % normalize to [0,1] for display/thresholding

    threshold = prctile(heatmap(:), 75);
    heatmapMask = heatmap > threshold;

    figHandle = figure('Visible', 'off');
    imshow(im2uint8(rgbImage));
    hold on;
    imAlpha = imshow(heatmap, 'Colormap', jet(256));
    imAlpha.AlphaData = 0.4 * (heatmap > 0.2);
    hold off;
    frame = getframe(gca);
    overlayImage = frame.cdata;
    close(figHandle);

    camResult.heatmap = heatmap;
    camResult.heatmapMask = heatmapMask;
    camResult.overlayImage = overlayImage;
end
