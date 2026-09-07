function findings = buildLesionFindings(trackAResult, trackBResult)
%BUILDLESIONFINDINGS Per-lesion findings: type, real object count, real
%anatomical location, and a categorical reliability band - the single
%source of truth for both report surfaces (the web app's findings table
%via run_pipeline_api.m, and the MATLAB PDF via generateAnnotatedReport.m)
%so they can never silently show different numbers for the same image.
%
%   findings = buildLesionFindings(trackAResult, trackBResult) returns a
%   struct array with fields:
%     .lesionType           - Track A class name, or 'Microaneurysm'
%     .count                - real connected-component count (bwconncomp),
%                              not a placeholder 1
%     .confidence            - size-based detection proxy in [0,1], NOT a
%                              calibrated probability (Track A) or the
%                              real per-candidate combinedConfidence mean
%                              (Track B microaneurysms)
%     .reliabilityCategory  - categorizeReliability.m applied to .confidence
%     .location             - anatomical quadrant string (see describeLocation)
%
%   See also: categorizeReliability, segmentStructures, detectMicroaneurysmsV2.

    findings = struct('lesionType', {}, 'count', {}, 'confidence', {}, ...
        'location', {}, 'reliabilityCategory', {});
    ignoredClasses = {'Background', 'Retina'};

    canvasSize = [];
    fn = fieldnames(trackAResult.masks);
    if ~isempty(fn)
        canvasSize = size(trackAResult.masks.(fn{1}));
    end
    odCentroid = landmarkCentroid(trackAResult, 'OD');
    foveaCentroid = landmarkCentroid(trackAResult, 'Fovea');

    idx = 1;
    for i = 1:numel(trackAResult.classNames)
        name = trackAResult.classNames{i};
        if any(strcmp(name, ignoredClasses)), continue; end
        fieldName = matlab.lang.makeValidName(name);
        mask = trackAResult.masks.(fieldName);
        pixelCount = nnz(mask);
        if pixelCount > 25
            cc = bwconncomp(mask, 8);
            stats = regionprops(cc, 'Centroid', 'Area');
            stats = stats([stats.Area] > 25); % drop speckle-sized components from the object count

            confidence = min(1, pixelCount / 5000); % rough size-based proxy, not a real probability
            findings(idx).lesionType = name;
            findings(idx).count = max(1, numel(stats));
            findings(idx).confidence = confidence;
            findings(idx).reliabilityCategory = categorizeReliability(confidence);
            findings(idx).location = describeLocation(stats, canvasSize, odCentroid, foveaCentroid);
            idx = idx + 1;
        end
    end
    if trackBResult.confirmedCount > 0
        confirmedIdx = strcmp({trackBResult.candidates.status}, 'confirmed');
        confirmedConf = [trackBResult.candidates(confirmedIdx).combinedConfidence];
        confirmedCentroids = reshape([trackBResult.candidates(confirmedIdx).centroid], 2, [])';
        maStats = struct('Centroid', num2cell(confirmedCentroids, 2));
        meanConf = mean(confirmedConf);
        findings(idx).lesionType = 'Microaneurysm';
        findings(idx).count = trackBResult.confirmedCount;
        findings(idx).confidence = meanConf;
        findings(idx).reliabilityCategory = categorizeReliability(meanConf);
        findings(idx).location = describeLocation(maStats, canvasSize, odCentroid, foveaCentroid);
    end
end

function centroid = landmarkCentroid(trackAResult, className)
%LANDMARKCENTROID Centroid of a class's largest connected component, or
%empty if the class wasn't detected - used as an anatomical reference
%point (optic disc / fovea) for naming other lesions' quadrants.
    centroid = [];
    fieldName = matlab.lang.makeValidName(className);
    if ~isfield(trackAResult.masks, fieldName), return; end
    mask = trackAResult.masks.(fieldName);
    if nnz(mask) < 25, return; end
    cc = bwconncomp(mask, 8);
    stats = regionprops(cc, 'Area', 'Centroid');
    if isempty(stats), return; end
    [~, biggest] = max([stats.Area]);
    centroid = stats(biggest).Centroid; % [x y]
end

function loc = describeLocation(stats, canvasSize, odCentroid, foveaCentroid)
%DESCRIBELOCATION Anatomical quadrant(s) a set of object centroids fall
%in. Nasal/temporal is derived from the optic disc's position relative
%to the fovea (the disc is always on the nasal side of the retina) so
%this works without needing eye laterality plumbed through from the
%frontend. Falls back to plain image-quadrant naming when the disc or
%fovea wasn't detected in this image.
    if isempty(stats)
        loc = 'Not specified';
        return
    end
    quadrants = strings(1, numel(stats));
    useAnatomical = ~isempty(odCentroid) && ~isempty(foveaCentroid) && ...
        abs(odCentroid(1) - foveaCentroid(1)) > 1;
    for k = 1:numel(stats)
        c = stats(k).Centroid;
        if useAnatomical
            nasalSign = sign(odCentroid(1) - foveaCentroid(1));
            isNasal = sign(c(1) - foveaCentroid(1)) == nasalSign;
            horiz = ternary(isNasal, "Nasal", "Temporal");
            vert = ternary(c(2) < foveaCentroid(2), "Superior", "Inferior");
        else
            horiz = ternary(c(1) < canvasSize(2) / 2, "Left", "Right");
            vert = ternary(c(2) < canvasSize(1) / 2, "Upper", "Lower");
        end
        quadrants(k) = vert + " " + horiz;
    end
    uniqueQuadrants = unique(quadrants);
    if numel(uniqueQuadrants) == 1
        loc = char(uniqueQuadrants(1));
    else
        loc = 'Multiple quadrants';
    end
end

function out = ternary(cond, a, b)
    if cond, out = a; else, out = b; end
end
