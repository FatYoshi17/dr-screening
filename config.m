function cfg = config()
%CONFIG Central paths for the project. Edit this file once, not
%   scattered path strings inside individual scripts.
%   cfg = config(); imds = imageDatastore(cfg.idridSegImagesTrain);

    root = fileparts(mfilename('fullpath'));
    cfg.root = root;

    cfg.dataRaw      = fullfile(root, 'data', 'raw');
    cfg.aptosDir     = fullfile(cfg.dataRaw, 'aptos2019');
    cfg.driveDir     = fullfile(cfg.dataRaw, 'drive');
    cfg.idridDir     = fullfile(cfg.dataRaw, 'idrid', 'IDRiD');
    cfg.messidor2Dir = fullfile(cfg.dataRaw, 'messidor2', 'Messidor-2');
    cfg.eyeqDir      = fullfile(cfg.dataRaw, 'eyeq');
    cfg.refinedIdridDir      = fullfile(cfg.dataRaw, 'refined_idrid');
    cfg.refinedIdridTrainImg = fullfile(cfg.refinedIdridDir, 'Train', 'Images');
    cfg.refinedIdridTrainLbl = fullfile(cfg.refinedIdridDir, 'Train', 'Labels');
    cfg.refinedIdridTestImg  = fullfile(cfg.refinedIdridDir, 'Test', 'Images');
    cfg.refinedIdridTestLbl  = fullfile(cfg.refinedIdridDir, 'Test', 'Labels');

    cfg.idridSegImagesTrain = fullfile(cfg.idridDir, 'A. Segmentation', ...
        '1. Original Images', 'a. Training Set');
    cfg.idridSegImagesTest  = fullfile(cfg.idridDir, 'A. Segmentation', ...
        '1. Original Images', 'b. Testing Set');
    cfg.idridSegGroundtruthTrain = fullfile(cfg.idridDir, 'A. Segmentation', ...
        '2. All Segmentation Groundtruths', 'a. Training Set');
    cfg.idridSegGroundtruthTest  = fullfile(cfg.idridDir, 'A. Segmentation', ...
        '2. All Segmentation Groundtruths', 'b. Testing Set');

    cfg.dataProcessed = fullfile(root, 'data', 'processed');
    cfg.resultsDir     = fullfile(root, 'results');

    % Trained model outputs - Modules 1-4 (see docs/RUN_GUIDE.md).
    cfg.dataModels                    = fullfile(root, 'data', 'models');
    cfg.module1QualityModel           = fullfile(cfg.dataModels, 'module1_quality_model.mat');
    cfg.trackANetPath                 = fullfile(cfg.dataModels, 'trackA_net.mat');
    cfg.trackBSegformerNetPath        = fullfile(cfg.dataModels, 'trackB_segformer_net.mat');
    cfg.trackBCbamNetPath             = fullfile(cfg.dataModels, 'trackB_cbam_net.mat');
    % Which Track B model the pipeline actually uses - CBAM is the
    % working, evaluated model as of now (mean Dice 0.36 on held-out
    % IDRiD test patches); SegFormer is a promising but still-being-
    % tuned alternative (see trainTrackB.m's history). Flip this to
    % cfg.trackBSegformerNetPath once SegFormer's fully evaluated and
    % preferred.
    cfg.trackBActiveNetPath           = cfg.trackBCbamNetPath;
    cfg.trackBSegformerOnnxPath       = fullfile(cfg.dataModels, 'segformer_ma.onnx');
    cfg.module3GradingCnnPath         = fullfile(cfg.dataModels, 'module3_grading_cnn.mat');
    cfg.module4ConfidenceCalibPath    = fullfile(cfg.dataModels, 'module4_confidence_calibration.mat');

    for d = {cfg.dataProcessed, cfg.resultsDir, cfg.dataModels}
        if ~isfolder(d{1}), mkdir(d{1}); end
    end
end
