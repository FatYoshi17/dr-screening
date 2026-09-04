function mask = fovMask(rgbImage)
%FOVMASK Estimate the field-of-view (circular fundus) mask.
%   mask = fovMask(rgbImage) returns a logical mask that is TRUE inside
%   the circular retinal field of view and FALSE in the black background
%   surrounding it. Used by both Module 1 (quality scoring) and Module 2
%   (every segmentation function) — kept here once rather than duplicated.

    grayImg = rgb2gray(rgbImage);
    level = graythresh(grayImg);
    mask = imbinarize(grayImg, max(level * 0.5, 0.03));
    mask = bwareafilt(mask, 1);
    mask = imfill(mask, 'holes');
    se = strel('disk', 5);
    mask = imopen(mask, se);
    mask = imclose(mask, se);
end
