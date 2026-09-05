function overlay = buildLesionOverlay(rgbImage, trackAResult, trackBResult)
%BUILDLESIONOVERLAY Module 4: AI-interpreted image - Track A/B findings drawn on the photo.
%   overlay = buildLesionOverlay(rgbImage, trackAResult, trackBResult)
%
%   Colors each Track A structure/lesion class directly onto the image
%   and marks confirmed Track B microaneurysm candidates - the actual
%   "AI-interpreted image" a clinician can compare against the original
%   photo, as distinct from the Grad-CAM attention heatmap (see
%   computeGradCAM.m), which shows where the grading CNN looked rather
%   than what the lesion detectors found.
%
%   Extracted from generateAnnotatedReport.m so both the PDF report and
%   backend/main.py's web API (via run_pipeline_api.m) can produce the
%   same image without duplicating this logic.
%
%   See also: segmentStructures, detectMicroaneurysmsV2, computeGradCAM,
%   generateAnnotatedReport, run_pipeline_api.

    overlay = im2uint8(rgbImage);
    canvasSize = [size(overlay, 1), size(overlay, 2)];
    colorMap = struct('VH', [255 140 0], 'Fovea', [0 255 0], 'Vessel', [255 0 0], ...
        'OD', [255 255 255], 'EX', [255 255 0], 'IRMA', [255 69 0], ...
        'HE', [0 255 255], 'NV', [255 0 255], 'CWS', [0 0 255]);
    classNames = fieldnames(colorMap);
    % Dilate each mask before coloring: lesion regions are often only a
    % few pixels wide, and both the API's display-size resize
    % (run_pipeline_api.m, ~5x downscale for IDRiD's ~4300px source
    % images) and JPEG compression blur anything that thin into
    % near-invisibility. A few pixels of dilation makes findings
    % something a clinician can actually see without changing what was
    % detected, just how visible it is.
    dilationRadius = 4;
    se = strel('disk', dilationRadius);
    for i = 1:numel(classNames)
        fieldName = matlab.lang.makeValidName(classNames{i});
        if isfield(trackAResult.masks, fieldName)
            mask = trackAResult.masks.(fieldName);
            % Track A's masks are at its own internal working resolution
            % (segmentStructures.m resizes the input down before
            % semanticseg, and never resizes the result back up) - NOT
            % necessarily rgbImage's resolution. Applying a mask of one
            % size as a logical index into a channel of a DIFFERENT size
            % doesn't error in MATLAB (it linearly indexes instead), it
            % silently scatters the color to spatially wrong pixels -
            % confirmed directly: a real, measurable pixel difference
            % existed with no visually coherent overlay anywhere.
            if ~isequal(size(mask), canvasSize)
                mask = imresize(mask, canvasSize, 'nearest');
            end
            mask = imdilate(mask, se);
            color = colorMap.(classNames{i});
            for c = 1:3
                channel = overlay(:,:,c);
                channel(mask) = color(c);
                overlay(:,:,c) = channel;
            end
        end
    end
    for i = 1:numel(trackBResult.candidates)
        if strcmp(trackBResult.candidates(i).status, 'confirmed')
            overlay = insertMarker(overlay, trackBResult.candidates(i).centroid, ...
                'x', 'Color', 'magenta', 'Size', 20);
        end
    end
end
