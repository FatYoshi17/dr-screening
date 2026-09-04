function rgbImage = ioUtils(action, varargin)
%IOUTILS Shared load/save/manifest helpers, dispatched by action string.
%   img = ioUtils('load', filePath)              - read + standardize one fundus image
%   img = ioUtils('synthetic', imgSize)           - generate a synthetic test fundus image
%   T   = ioUtils('buildManifest', folderPath)    - table of every image file in a folder
%
%   Kept as a single dispatcher (rather than one function per file) so
%   every "load an image" call in the project goes through one place.

    switch lower(action)
        case 'load'
            rgbImage = loadFundusImage(varargin{:});
        case 'synthetic'
            rgbImage = generateSyntheticFundusImage(varargin{:});
        case 'buildmanifest'
            rgbImage = buildManifest(varargin{:}); % name kept generic for the switch
        otherwise
            error('ioUtils:unknownAction', 'Unknown action "%s"', action);
    end
end

% ---- local functions ----

function rgbImage = loadFundusImage(filePath)
    rgbImage = imread(filePath);
    if size(rgbImage, 3) == 1
        rgbImage = repmat(rgbImage, 1, 1, 3);
    end
    rgbImage = im2uint8(rgbImage);
end

function rgbImage = generateSyntheticFundusImage(imgSize)
%   Rough synthetic fundus test image (circular FOV, optic disc,
%   branching vessels, a handful of blob lesions) — purely so the
%   pipeline can be smoke-tested before/without real datasets. NOT a
%   substitute for real data validation.
    if nargin < 1, imgSize = 512; end
    [X, Y] = meshgrid(1:imgSize, 1:imgSize);
    cx = imgSize/2; cy = imgSize/2; r = imgSize*0.45;
    fov = ((X-cx).^2 + (Y-cy).^2) <= r^2;

    img = zeros(imgSize, imgSize, 3);
    img(:,:,1) = 0.55; img(:,:,2) = 0.25; img(:,:,3) = 0.15;
    img = img + 0.05*randn(imgSize, imgSize, 3);

    discCX = cx + r*0.4; discCY = cy;
    discMask = ((X-discCX).^2 + (Y-discCY).^2) <= (r*0.12)^2;
    for c = 1:3
        chan = img(:,:,c); chan(discMask) = chan(discMask) + 0.35; img(:,:,c) = chan;
    end

    vesselMask = false(imgSize, imgSize);
    theta = linspace(0, 2*pi, 6);
    for t = theta
        for rr = 1:r*0.9
            px = round(discCX - rr*cos(t)*0.6);
            py = round(discCY + rr*sin(t) + 30*sin(rr/40 + t));
            if px >= 1 && px <= imgSize && py >= 1 && py <= imgSize
                vesselMask(max(py-1,1):min(py+1,imgSize), max(px-1,1):min(px+1,imgSize)) = true;
            end
        end
    end
    for c = 1:3
        chan = img(:,:,c); chan(vesselMask) = chan(vesselMask) - 0.15; img(:,:,c) = chan;
    end

    rng(1);
    for i = 1:15
        ang = 2*pi*rand(); rad = r*0.7*rand();
        lx = round(cx + rad*cos(ang)); ly = round(cy + rad*sin(ang));
        lesionMask = ((X-lx).^2 + (Y-ly).^2) <= (2+6*rand())^2 & fov;
        delta = 0.3 * (mod(i,3)==0) - 0.25 * (mod(i,3)~=0);
        for c = 1:3
            chan = img(:,:,c); chan(lesionMask) = chan(lesionMask) + delta; img(:,:,c) = chan;
        end
    end

    img(~repmat(fov, 1, 1, 3)) = 0;
    img = min(max(img, 0), 1);
    rgbImage = im2uint8(img);
end

function T = buildManifest(folderPath)
%   Table of every image file (png/jpg/jpeg/tif) found directly in
%   folderPath, one row per file, with full path + filename columns.
    exts = {'*.png', '*.jpg', '*.jpeg', '*.tif', '*.tiff'};
    files = [];
    for i = 1:numel(exts)
        files = [files; dir(fullfile(folderPath, exts{i}))]; %#ok<AGROW>
    end
    if isempty(files)
        T = table('Size', [0 2], 'VariableTypes', {'string','string'}, ...
            'VariableNames', {'FileName', 'FullPath'});
        return;
    end
    fileName = string({files.name}');
    fullPath = string(fullfile({files.folder}', {files.name}'));
    T = table(fileName, fullPath, 'VariableNames', {'FileName', 'FullPath'});
end
