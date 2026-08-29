function startup()
%STARTUP Add src/ and scripts/ to the MATLAB path. Run once per session.
    root = fileparts(mfilename('fullpath'));
    addpath(genpath(fullfile(root, 'src')));
    addpath(fullfile(root, 'scripts'));
    addpath(root);
    fprintf('dr-screening paths added (root: %s)\n', root);
end
