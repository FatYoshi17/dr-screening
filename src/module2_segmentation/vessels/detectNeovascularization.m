function [nvRiskMask, nvScore] = detectNeovascularization(rgbImage, vesselMask, discMask, mask)
%DETECTNEOVASCULARIZATION Heuristic screen for neovascularization (NV).
%   [nvRiskMask, nvScore] = detectNeovascularization(rgbImage, vesselMask, discMask, mask)
%
%   HONEST SCOPE NOTE: true NV detection is an open research problem and
%   NOT solved here. This is a coarse RISK-FLAGGING heuristic based on
%   local vessel density and fine-vessel fraction, meant to surface
%   candidate regions for the CNN (Module 3) / ophthalmologist review
%   (Module 4) — not a standalone detector. Must not be reported as one
%   without validation against NV-labeled data.
%
%   Heuristic: NV regions tend to show unusually HIGH local vessel
%   density made of unusually THIN vessel segments, most often near the
%   optic disc (NVD) or scattered elsewhere (NVE). Per tile: vessel
%   density + a "thinness" proxy (skeleton length / vessel area); flag
%   tiles high on both relative to the whole-image distribution.

    if nargin < 1
        error('rgbImage is required for sizing context.');
    end
    if nargin < 4 || isempty(mask)
        mask = true(size(vesselMask));
    end

    tileSize = max(round(size(vesselMask,1)/16), 16);
    [rows, cols] = size(vesselMask);
    nTilesR = ceil(rows/tileSize);
    nTilesC = ceil(cols/tileSize);

    density = nan(nTilesR, nTilesC);
    thinness = nan(nTilesR, nTilesC);
    skel = bwskel(vesselMask);

    for r = 1:nTilesR
        for c = 1:nTilesC
            rIdx = (r-1)*tileSize+1 : min(r*tileSize, rows);
            cIdx = (c-1)*tileSize+1 : min(c*tileSize, cols);
            tileFov = mask(rIdx, cIdx);
            if nnz(tileFov) < 0.5 * numel(tileFov)
                continue;
            end
            tileVessel = vesselMask(rIdx, cIdx);
            tileSkel = skel(rIdx, cIdx);
            density(r,c) = nnz(tileVessel) / max(nnz(tileFov), 1);
            thinness(r,c) = nnz(tileSkel) / max(nnz(tileVessel), 1);
        end
    end

    validVals = ~isnan(density);
    if ~any(validVals(:))
        nvRiskMask = false(rows, cols);
        nvScore = 0;
        return;
    end
    densZ = (density - mean(density(validVals))) / (std(density(validVals)) + eps);
    thinZ = (thinness - mean(thinness(validVals))) / (std(thinness(validVals)) + eps);
    riskScore = densZ + thinZ;
    riskScore(~validVals) = -Inf;
    riskTiles = riskScore > 1.5;

    nvRiskMask = false(rows, cols);
    for r = 1:nTilesR
        for c = 1:nTilesC
            if riskTiles(r,c)
                rIdx = (r-1)*tileSize+1 : min(r*tileSize, rows);
                cIdx = (c-1)*tileSize+1 : min(c*tileSize, cols);
                nvRiskMask(rIdx, cIdx) = true;
            end
        end
    end

    nvScore = mean(riskScore(validVals & riskTiles), 'omitnan');
    if isnan(nvScore), nvScore = 0; end
    if nargin >= 3 && ~isempty(discMask)
        nearDisc = imdilate(discMask, strel('disk', round(size(vesselMask,1)/8)));
        if any(nvRiskMask(:) & nearDisc(:))
            nvScore = nvScore * 1.3;
        end
    end
end
