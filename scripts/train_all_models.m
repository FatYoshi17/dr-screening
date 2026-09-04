%TRAIN_ALL_MODELS Orchestrates training every trainable piece of the pipeline, in order.
%   Run this once, top to bottom, before run_end_to_end_pipeline works.
%   Each stage is independent - comment out stages you've already
%   trained, or that you don't have the data for yet.
%
%   Realistic time expectations (NOT achievable inside a chat session -
%   this needs your own machine/cloud with a GPU for stages 2-4):
%     Module 1 (ordinal regression): seconds-minutes, CPU is fine.
%     Module 2 Track A (DeepLabv3+ + attention): hours on a GPU, 81
%       images but heavy augmentation multiplies effective epochs needed.
%     Module 2 Track B (SegFormer fine-tune): needs the ONNX export/
%       import done FIRST (see step 3 below) - hours on a GPU.
%     Module 3 (grading CNN): hours on a GPU, ~3,662 APTOS images.
%     Module 4: seconds - it's a calibration fit, not a network.
%
%   See also: docs/RUN_GUIDE.md, run_end_to_end_pipeline.

startup;
cfg = config();

%% Step 1: Module 1 - ordinal quality regression (fast, CPU-only)
% Requires EyeQ dataset downloaded separately - see docs/RUN_GUIDE.md.
eyeQImageDir = fullfile(cfg.dataRaw, 'eyeq', 'images');
eyeQLabelsCsv = fullfile(cfg.dataRaw, 'eyeq', 'labels.csv');
if isfolder(eyeQImageDir)
    trainOrdinalQualityModel(eyeQImageDir, eyeQLabelsCsv);
else
    warning('EyeQ not found at %s - skipping Module 1 training. See docs/RUN_GUIDE.md.', eyeQImageDir);
end

%% Step 2: Module 2 Track A - unified structure segmentation (GPU, hours)
trainTrackA(cfg);

%% Step 3: Module 2 Track B - SegFormer ONNX export + import + fine-tune
% Part A runs in Python, NOT MATLAB - see the printed instructions below.
segformerOnnxPath = fullfile(cfg.dataRaw, '..', 'models', 'segformer_ma.onnx');
if ~isfile(segformerOnnxPath)
    fprintf(['\n>>> Before continuing: run this on a machine with PyTorch installed:\n' ...
             '    python module2_segmentation/trackB_microaneurysms/exportSegformerONNX.py ' ...
             '--out %s\n' ...
             '    Then copy the resulting .onnx file to that path and re-run this script.\n\n'], ...
        segformerOnnxPath);
else
    importSegformerMATLAB(segformerOnnxPath);
    trainTrackB(cfg);
end

%% Step 4: Module 3 - grading CNN (GPU, hours)
% Requires APTOS 2019 dataset downloaded separately - see docs/RUN_GUIDE.md.
aptosImageDir = fullfile(cfg.dataRaw, 'aptos2019', 'train_images');
aptosLabelsCsv = fullfile(cfg.dataRaw, 'aptos2019', 'train.csv');
if isfolder(aptosImageDir)
    trainGradingCNN(aptosImageDir, aptosLabelsCsv);
else
    warning('APTOS 2019 not found at %s - skipping Module 3 training. See docs/RUN_GUIDE.md.', aptosImageDir);
end

%% Step 5: Module 4 - confidence calibration (fast, needs Module 3's
% validation predictions - re-run the val split through predictGradingCNN
% and fitConfidenceCalibration once Module 3 is trained; not automated
% here since it depends on your chosen validation split).
fprintf('\nAll available stages complete. See docs/RUN_GUIDE.md for the ' ...
    'confidence-calibration step and how to run the end-to-end demo.\n');
