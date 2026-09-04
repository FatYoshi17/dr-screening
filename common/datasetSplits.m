function split = datasetSplits(mode, varargin)
%DATASETSPLITS Train/val/test split logic — one place, so nobody
%   accidentally validates on training data anywhere in the project.
%
%   split = datasetSplits('trainVal', manifestTable, valFraction)
%       Random train/val split of a single-dataset manifest (from
%       ioUtils('buildManifest', ...)). Use for in-dataset development,
%       e.g. splitting IDRiD's 54 training images into train/val while
%       building Module 2.
%
%   split = datasetSplits('external', trainManifest, testManifest)
%       NOT a random split — wraps two manifests from DIFFERENT datasets
%       (e.g. APTOS for training, Messidor-2 for testing) so the
%       "external validation" pattern from brief section 4/5 is explicit
%       in code, not just a comment. Train and test never share images
%       by construction, because they're not from the same source.
%
%   Both return a struct with .train and .test (or .val) tables plus
%   .description for logging.

    switch lower(mode)
        case 'trainval'
            manifest = varargin{1};
            valFraction = varargin{2};
            n = height(manifest);
            idx = randperm(n);
            nVal = round(n * valFraction);
            split.val = manifest(idx(1:nVal), :);
            split.train = manifest(idx(nVal+1:end), :);
            split.description = sprintf('Random in-dataset split: %d train / %d val (%.0f%% val)', ...
                height(split.train), height(split.val), valFraction*100);

        case 'external'
            split.train = varargin{1};
            split.test = varargin{2};
            split.description = sprintf(['External validation split: %d train images, ' ...
                '%d test images from a DIFFERENT dataset (no shared source, no leakage by construction)'], ...
                height(split.train), height(split.test));

        otherwise
            error('datasetSplits:unknownMode', 'Unknown mode "%s" (use ''trainVal'' or ''external'')', mode);
    end

    fprintf('%s\n', split.description);
end
