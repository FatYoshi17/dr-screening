function cnnResult = predictGradingCNN(rgbImage, modelPath)
%PREDICTGRADINGCNN Run the Module 3 grading CNN on one image (full 0-4 range).
%   cnnResult = predictGradingCNN(rgbImage, modelPath)
%
%   Runs on EVERY image regardless of what grade01Rule.m decides - this
%   independence is what makes the disagreement safety net meaningful
%   (see disagreementFlag.m's docstring for why that matters).
%
%   Returns:
%     cnnResult.continuousScore - raw regression output (roughly 0-4)
%     cnnResult.grade           - rounded grade using the optimized
%                                  thresholds from training, not naive round()
%     cnnResult.rawConfidence   - distance-based pseudo-confidence,
%                                  NOT yet calibrated (see
%                                  calibrateConfidence.m in Module 4 -
%                                  that is what produces the number
%                                  actually shown in the report)
%
%   See also: trainGradingCNN, grade01Rule, disagreementFlag, gradeImage.

    if nargin < 2 || isempty(modelPath)
        modelPath = fullfile('data', 'models', 'module3_grading_cnn.mat');
    end
    if ~isfile(modelPath)
        error(['No trained Module 3 grading CNN found at %s.\n' ...
               'Run trainGradingCNN(aptosImageDir, aptosLabelsCsv) first - ' ...
               'see docs/RUN_GUIDE.md.'], modelPath);
    end
    loaded = load(modelPath, 'model');
    model = loaded.model;

    imgResized = imresize(im2uint8(rgbImage), model.inputSize(1:2));
    continuousScore = predict(model.net, imgResized);
    continuousScore = double(continuousScore);

    grade = sum(continuousScore > model.thresholds);

    % Distance from the nearest threshold as a rough, uncalibrated
    % confidence proxy - closer to a threshold = less confident.
    distToThresholds = abs(continuousScore - model.thresholds);
    rawConfidence = min(distToThresholds) / 0.5;
    rawConfidence = min(max(rawConfidence, 0), 1);

    cnnResult.continuousScore = continuousScore;
    cnnResult.grade = grade;
    cnnResult.rawConfidence = rawConfidence;
end
