function startup()
%STARTUP Add every module folder, common/, tests/, and scripts/ to the
%MATLAB path. Run once per session.
    root = fileparts(mfilename('fullpath'));
    moduleDirs = {'module1_quality', 'module2_segmentation', ...
        'module3_grading', 'module4_explainability', 'common'};
    for i = 1:numel(moduleDirs)
        addpath(genpath(fullfile(root, moduleDirs{i})));
    end
    addpath(fullfile(root, 'scripts'));
    addpath(fullfile(root, 'tests'));
    addpath(root);
    fprintf('dr-screening paths added (root: %s)\n', root);
end
