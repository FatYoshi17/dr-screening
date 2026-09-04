function net = importSegformerPyTorch(ptPath, outputRawPath)
%IMPORTSEGFORMERPYTORCH One-time raw import of the traced SegFormer .pt file.
%   net = importSegformerPyTorch(ptPath, outputRawPath) calls
%   importNetworkFromPyTorch on the given .pt file (produced by
%   exportSegformerEager.py) and saves the raw, unmodified result.
%
%   *** DO NOT RUN THIS if +segformer_eager/ already contains the
%   hand-patched generated code for this model. importNetworkFromPyTorch
%   regenerates that entire package from scratch on every call, silently
%   overwriting all of it. Only run this on a fresh clone/setup where
%   +segformer_eager/ does not yet exist, or after deliberately deciding
%   to discard the existing patches. ***
%
%   Every downstream use should load outputRawPath instead of calling
%   this function again - see buildTrackBSegformerNetwork.m.
%
%   The generated +segformer_eager/ package requires extensive manual
%   fixes to actually run (MATLAB's dlnetwork/predict() dispatch
%   silently squeezes/corrupts batch and rank information threaded
%   through nested custom layers - see the comments throughout
%   +segformer_eager/*.m for the diagnosed root causes and workarounds).
%   Those fixes are already applied and committed to this repo; this
%   function exists only for the (rare) case of setting this up from
%   scratch on a machine that has never run the import before.
%
%   See also: exportSegformerEager.py, buildTrackBSegformerNetwork.

    cfg = config();
    if nargin < 2 || isempty(outputRawPath)
        outputRawPath = fullfile(cfg.dataModels, 'segformer_imported_raw.mat');
    end
    if ~isfile(ptPath)
        error(['Traced .pt file not found at %s.\n' ...
               'Run exportSegformerEager.py first (in .venv-segformer, ' ...
               'PyTorch >= 2.8) to produce it.'], ptPath);
    end
    if isfolder(fullfile(cfg.root, '+segformer_eager')) && isfile(outputRawPath)
        error(['importSegformerPyTorch:AlreadySetUp'], ...
            ['Both +segformer_eager/ and %s already exist. Re-running the ' ...
             'import will silently overwrite all hand-patched fixes in ' ...
             '+segformer_eager/. Delete both first if you really intend to ' ...
             're-import from scratch.'], outputRawPath);
    end

    fprintf('Importing %s via importNetworkFromPyTorch (this generates +segformer_eager/) ...\n', ptPath);
    net = importNetworkFromPyTorch(ptPath, 'PreferredNestingType', 'customlayer');

    outDir = fileparts(outputRawPath);
    if ~isempty(outDir) && ~isfolder(outDir)
        mkdir(outDir);
    end
    save(outputRawPath, 'net');
    fprintf(['Raw import saved to %s.\n' ...
             'Next: apply the fixes documented in +segformer_eager/*.m ' ...
             '(or pull them from version control if starting fresh), then ' ...
             'use buildTrackBSegformerNetwork.m to build the trainable network.\n'], ...
            outputRawPath);
end
