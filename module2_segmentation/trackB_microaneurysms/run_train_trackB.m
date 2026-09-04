% MATLAB's run() temporarily cds into this script's own folder while it
% executes - restore repo root explicitly rather than rely on every
% path downstream being absolute.
repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
cd(repoRoot);

cfg = config();
% Reduced from the 6000-patch/20-epoch default: at ~5.5s/iteration
% (MiniBatchSize=1, measured on this GPU), the full default schedule is
% a ~166-hour run. 900 patches x 4 epochs = 3600 iterations, ~5.5 hours -
% a genuine fine-tune run sized to actually finish, not a smoke test.
net = trainTrackB(cfg, fullfile(cfg.dataModels, 'trackB_segformer_net.mat'), 900, 4);
fprintf('trainTrackB completed successfully.\n');
