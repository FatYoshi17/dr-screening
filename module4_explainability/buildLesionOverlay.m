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
    colorMap = struct('VH', [255 140 0], 'Fovea', [0 255 0], 'Vessel', [255 0 0], ...
        'OD', [255 255 255], 'EX', [255 255 0], 'IRMA', [255 69 0], ...
        'HE', [0 255 255], 'NV', [255 0 255], 'CWS', [0 0 255]);
    classNames = fieldnames(colorMap);
    for i = 1:numel(classNames)
        fieldName = matlab.lang.makeValidName(classNames{i});
        if isfield(trackAResult.masks, fieldName)
            mask = trackAResult.masks.(fieldName);
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
                'x', 'Color', 'magenta', 'Size', 4);
        end
    end
end
