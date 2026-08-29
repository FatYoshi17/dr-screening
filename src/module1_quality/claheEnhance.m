function enhImg = claheEnhance(rgbImage)
%CLAHEENHANCE Adaptive local contrast enhancement for fundus images.
%   enhImg = claheEnhance(rgbImage) applies CLAHE to the L* channel of
%   the Lab colour space — boosts local contrast so subtle lesions
%   become more visible without blowing out the disc or vessels.

    labImg = rgb2lab(im2double(rgbImage));
    L = labImg(:,:,1) / 100;
    L_eq = adapthisteq(L, 'ClipLimit', 0.01, 'Distribution', 'rayleigh');
    labImg(:,:,1) = L_eq * 100;
    enhImg = lab2rgb(labImg);
    enhImg = min(max(enhImg, 0), 1);
end
