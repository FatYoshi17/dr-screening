function test_module1()
%TEST_MODULE1 Smoke test for Module 1 on a synthetic image.
%   Confirms every Module 1 function runs and returns sane ranges. Not a
%   substitute for tuning thresholds against real labeled "good"/"bad"
%   images — see docs/status_vs_roadmap.md.

    img = ioUtils('synthetic', 256);
    assert(isequal(size(img), [256 256 3]), 'Synthetic image has wrong size');

    qc = assessImageQuality(img);
    assert(qc.overallScore >= 0 && qc.overallScore <= 1, 'Quality score out of range');

    [enhImg, ~, qcAfter] = enhanceImage(img);
    assert(isequal(size(enhImg), size(im2double(img))), 'Enhanced image size mismatch');
    assert(qcAfter.overallScore >= 0 && qcAfter.overallScore <= 1, 'Post-enhance score out of range');

    if ~qc.isGradable
        rejectUngradeable(qc, 'synthetic_test_image');
    end

    fprintf('test_module1: ALL PASSED\n');
end
