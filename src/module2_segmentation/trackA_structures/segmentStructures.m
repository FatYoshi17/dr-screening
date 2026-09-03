function result = segmentStructures(rgbImage, netPath)
%SEGMENTSTRUCTURES Track A inference: run the trained network on one image.
%   result = segmentStructures(rgbImage, netPath) loads the trained
%   Track A network (default data/models/trackA_net.mat) and returns:
%     result.labelMap   - HxW categorical label image (11 classes)
%     result.probMaps   - HxWx11 softmax probability maps
%     result.classNames - the 11 class names, same order as probMaps' 3rd dim
%     result.masks      - struct with one logical HxW mask per class
%                          (result.masks.OD, result.masks.Vessel, etc.)
%
%   See also: trainTrackA, buildTrackANetwork.

    if nargin < 2 || isempty(netPath)
        netPath = fullfile('data', 'models', 'trackA_net.mat');
    end
    if ~isfile(netPath)
        error(['No trained Track A network found at %s.\n' ...
               'Run trainTrackA(config()) first - see docs/RUN_GUIDE.md.'], netPath);
    end
    loaded = load(netPath, 'net', 'classNames', 'imageSize');

    imgResized = imresize(im2uint8(rgbImage), loaded.imageSize(1:2));

    [labelMap, probMaps] = semanticseg(imgResized, loaded.net, 'OutputType', 'both');

    result.labelMap = labelMap;
    result.probMaps = probMaps;
    result.classNames = loaded.classNames;

    result.masks = struct();
    for i = 1:numel(loaded.classNames)
        fieldName = matlab.lang.makeValidName(loaded.classNames{i});
        result.masks.(fieldName) = (labelMap == loaded.classNames{i});
    end
end
