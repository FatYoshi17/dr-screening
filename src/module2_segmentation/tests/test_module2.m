function test_module2()
%TEST_MODULE2 Smoke test for Module 2 on a synthetic image.
%   Confirms every Module 2 function runs and returns sane shapes/ranges.
%   NOT a substitute for accuracy validation against IDRiD/DRIVE ground
%   truth (see docs/status_vs_roadmap.md and src/common/metrics.m).

    img = ioUtils('synthetic', 256);
    mask = fovMask(img);
    assert(any(mask(:)), 'FOV mask is empty');

    [discCenter, discRadius, discMask] = detectOpticDisc(img, mask);
    assert(all(discCenter > 0) && discRadius > 0 && any(discMask(:)), 'Optic disc detection failed');

    [foveaCenter, foveaConf] = detectFovea(img, discCenter, discRadius, mask);
    assert(all(foveaCenter > 0), 'Invalid fovea center');
    assert(foveaConf >= 0 && foveaConf <= 1, 'Fovea confidence out of range');

    vesselMask = segmentVessels(img, mask);
    assert(any(vesselMask(:)), 'Vessel mask is empty - check thresholds');

    [~, maStats] = detectMicroaneurysms(img, mask, vesselMask, discMask); %#ok<ASGLU>
    exudateMask = segmentExudates(img, mask, discMask); %#ok<NASGU>
    [~, hemStats] = classifyHemorrhages(img, mask, vesselMask, discMask); %#ok<ASGLU>
    [~, nvScore] = detectNeovascularization(img, vesselMask, discMask, mask);
    assert(nvScore >= -10 && nvScore <= 10, 'NV score looks unreasonable');

    fprintf('test_module2: ALL PASSED\n');
end
