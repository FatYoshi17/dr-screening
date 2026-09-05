% MATLAB's run() temporarily cds into this script's own folder while it
% executes - restore repo root explicitly rather than rely on every
% path downstream being absolute.
repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
cd(repoRoot);

cfg = config();
% Full 6000-patch dataset (no pretraining here, so CBAM benefits from
% more data than SegFormer needed), capped at 4 epochs to land around
% ~4.6 hours at the measured ~2.75s/iteration (MiniBatchSize=4) -  and
% epoch-matched to the SegFormer run for a fairer comparison.
net = trainTrackBCbam(cfg, fullfile(cfg.dataModels, 'trackB_cbam_net.mat'), 6000, 4);
fprintf('trainTrackBCbam completed successfully.\n');
