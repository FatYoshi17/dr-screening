function [plausible, reason] = checkFundusPlausibility(features)
%CHECKFUNDUSPLAUSIBILITY Deterministic gate: does the FOV mask even look
%like a real fundus-camera vignette?
%   [plausible, reason] = checkFundusPlausibility(features) inspects
%   features.fov (from extractQualityFeatures) and rejects images whose
%   thresholded "field of view" bears no resemblance to a fundus camera's
%   circular optical vignette - independent of the trained/threshold
%   quality model, which only grades HOW GOOD an assumed-fundus photo
%   looks (sharpness/exposure/contrast/noise/FOV-shape) and has no way to
%   notice the photo isn't of a retina at all. A wrong-type photo (an
%   external eye close-up, a random scene) can score fine on every one of
%   those features and still pass the trained model - confirmed
%   empirically on out-of-domain test input.
%
%   Calibrated empirically: a real IDRiD fundus photo measured
%   coverage=0.69 (real fundus cameras always leave a dark border outside
%   the circular optical aperture); an arbitrary non-fundus photo (shot
%   with no such optics, so nothing gets vignetted out) measured
%   coverage=0.999. The 0.95 cutoff leaves a wide margin above genuine
%   fundus photos while catching anything that fills the entire frame.
%
%   See also: extractQualityFeatures, assessImageQuality,
%   assessImageQualityThreshold.

    plausible = true;
    reason = '';

    if features.fov.coverage > 0.95
        plausible = false;
        reason = ['This does not look like a fundus camera photo - no dark ' ...
            'vignette border around the retina was detected (the entire ' ...
            'frame is "in view"). Capture through the fundus camera, ' ...
            'centered on the eye, not a regular photo.'];
        return
    end

    if features.fov.coverage < 0.05
        plausible = false;
        reason = ['Almost nothing in this photo was detected as retina. ' ...
            'Recentre the retina in the frame and retake.'];
        return
    end
end
