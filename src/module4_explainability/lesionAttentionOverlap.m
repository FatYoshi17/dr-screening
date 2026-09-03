function overlapResult = lesionAttentionOverlap(camResult, trackAResult, trackBResult)
%LESIONATTENTIONOVERLAP Score how much Grad-CAM's attention overlaps with real lesions.
%   overlapResult = lesionAttentionOverlap(camResult, trackAResult, trackBResult)
%
%   This is the brief's own Tier-1 differentiator: instead of just
%   showing a heatmap and calling it "explainable", measure what
%   percentage of it actually overlaps with lesions Module 2 really
%   found. Turns explainability into a number, not just a picture, and
%   is the one place in the whole pipeline where Module 2's output and
%   the grading CNN's own attention get directly compared.
%
%   Returns:
%     overlapResult.overlapScore    - fraction of camResult.heatmapMask
%                                      pixels that fall inside ANY real
%                                      lesion mask from Track A or Track B
%     overlapResult.unexplainedMask - heatmap-flagged pixels that do NOT
%                                      overlap any known lesion - surfaced
%                                      to the reviewer rather than
%                                      discarded (could be a real finding
%                                      Module 2 missed, or spurious
%                                      attention - either way worth a look)
%     overlapResult.hasUnexplainedRegion - true if unexplainedMask is
%                                      non-trivial (>50 px)
%
%   See also: computeGradCAM, generateAnnotatedReport, segmentStructures,
%   detectMicroaneurysmsV2.

    heatmapMask = camResult.heatmapMask;

    lesionMask = false(size(heatmapMask));
    ignoredClasses = {'Background', 'Retina'};
    for i = 1:numel(trackAResult.classNames)
        name = trackAResult.classNames{i};
        if any(strcmp(name, ignoredClasses)), continue; end
        fieldName = matlab.lang.makeValidName(name);
        classMask = imresize(trackAResult.masks.(fieldName), size(heatmapMask), 'nearest');
        lesionMask = lesionMask | classMask;
    end

    % Add confirmed (not ambiguous/rejected) MA candidates from Track B.
    maMask = false(size(heatmapMask));
    for i = 1:numel(trackBResult.candidates)
        if strcmp(trackBResult.candidates(i).status, 'confirmed')
            maMask(trackBResult.candidates(i).pixelIdxList) = true;
        end
    end
    maMask = imresize(maMask, size(heatmapMask), 'nearest');
    lesionMask = lesionMask | maMask;

    % Dilate slightly so near-miss alignment (a heatmap pixel just
    % outside a lesion's exact boundary) still counts as "explained" -
    % Grad-CAM heatmaps are coarse by nature, exact pixel alignment
    % isn't the realistic bar.
    lesionMaskDilated = imdilate(lesionMask, strel('disk', 5));

    overlapPixels = heatmapMask & lesionMaskDilated;
    unexplainedMask = heatmapMask & ~lesionMaskDilated;

    totalHeatmapPixels = nnz(heatmapMask);
    if totalHeatmapPixels > 0
        overlapScore = nnz(overlapPixels) / totalHeatmapPixels;
    else
        overlapScore = 0;
    end

    overlapResult.overlapScore = overlapScore;
    overlapResult.unexplainedMask = unexplainedMask;
    overlapResult.hasUnexplainedRegion = nnz(unexplainedMask) > 50;
end
