%% run_pipeline_single_image.m
% End-to-end demo: Module 1 (quality + enhancement) then Module 2 (every
% structure/lesion detector) on one image, with a visual summary figure.
% Defaults to a synthetic test image so this runs with zero setup;
% point sampleImagePath at a real IDRiD image once you're ready.

cfg = config();

sampleImagePath = ''; % e.g. fullfile(cfg.idridSegImagesTrain, 'IDRiD_01.jpg')

if isempty(sampleImagePath) || ~isfile(sampleImagePath)
    fprintf('No real sample image configured - using synthetic test image.\n');
    rgbImage = ioUtils('synthetic', 512);
else
    rgbImage = ioUtils('load', sampleImagePath);
end

%% Module 1
qc = assessImageQuality(rgbImage);
fprintf('\n--- Module 1: Quality Assessment ---\n');
fprintf('FOV coverage      : %.1f%%\n', qc.fovCoverage*100);
fprintf('Overall score     : %.2f | Gradable: %d\n', qc.overallScore, qc.isGradable);
if ~qc.isGradable
    rejectUngradeable(qc, 'demo_image');
    warning('Proceeding on an ungradeable image for demo purposes only.');
end
[enhImg, qcBefore, qcAfter] = enhanceImage(rgbImage);
enhImg8 = im2uint8(enhImg);

%% Module 2
mask = fovMask(enhImg8);
[discCenter, discRadius, discMask] = detectOpticDisc(enhImg8, mask);
[foveaCenter, foveaConfidence] = detectFovea(enhImg8, discCenter, discRadius, mask);
vesselMask = segmentVessels(enhImg8, mask);
[maMask, maStats] = detectMicroaneurysms(enhImg8, mask, vesselMask, discMask);
exudateMask = segmentExudates(enhImg8, mask, discMask);
[hemMask, hemStats] = classifyHemorrhages(enhImg8, mask, vesselMask, discMask);
[nvRiskMask, nvScore] = detectNeovascularization(enhImg8, vesselMask, discMask, mask);

fprintf('\n--- Module 2: Structure Segmentation ---\n');
fprintf('Optic disc   : center=(%.0f,%.0f) r=%.1fpx\n', discCenter(1), discCenter(2), discRadius);
fprintf('Fovea        : center=(%.0f,%.0f) confidence=%.2f\n', foveaCenter(1), foveaCenter(2), foveaConfidence);
fprintf('Vessel pixels: %d (%.1f%% of FOV)\n', nnz(vesselMask), 100*nnz(vesselMask)/nnz(mask));
fprintf('MA candidates: %d\n', numel(maStats));
fprintf('Exudate area : %d px\n', nnz(exudateMask));
fprintf('Hemorrhages  : %d\n', numel(hemStats));
fprintf('NV risk score: %.2f (heuristic screen only)\n', nvScore);

%% Visualization
fig = figure('Name', 'Full Pipeline Demo', 'Position', [50 50 1400 800]);
subplot(2,4,1); imshow(rgbImage); title('Original');
subplot(2,4,2); imshow(enhImg8); title(sprintf('Enhanced (score %.2f->%.2f)', qcBefore.overallScore, qcAfter.overallScore));
subplot(2,4,3); imshow(enhImg8); hold on;
viscircles(discCenter, discRadius, 'Color', 'y', 'LineWidth', 1.5);
plot(foveaCenter(1), foveaCenter(2), 'c+', 'MarkerSize', 15, 'LineWidth', 2);
title('Optic disc & fovea'); hold off;
subplot(2,4,4); imshow(vesselMask); title('Vessels');
subplot(2,4,5); imshow(exudateMask); title('Exudates');
subplot(2,4,6); imshow(hemMask); title('Hemorrhages');
subplot(2,4,7); imshow(maMask); title(sprintf('MA candidates (n=%d)', numel(maStats)));
subplot(2,4,8); imshow(nvRiskMask); title(sprintf('NV risk (score %.2f)', nvScore));

outPath = fullfile(cfg.figuresDir, 'pipeline_demo_summary.png');
saveas(fig, outPath);
fprintf('\nSaved summary figure to %s\n', outPath);
