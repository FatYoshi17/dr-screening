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

    for d = {cfg.dataProcessed, cfg.resultsDir}
        if ~isfolder(d{1}), mkdir(d{1}); end
    end
end
