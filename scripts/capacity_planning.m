function results = capacity_planning()
%CAPACITY_PLANNING Connects the scalability PDF's tier data to the
%SimEvents queueing story with an actual optimization result: the
%GPU/server count needed per tier to keep utilization under a target
%ceiling, under a stated burst-load assumption - not just a stress test.
%
%   No .slx/SimEvents file was available to modify directly, so this
%   reproduces the same queueing question (M/M/c: arrival rate vs.
%   service capacity) analytically in MATLAB, using the real numbers
%   already published in scalability_cost_projection.pdf (tier
%   screenings/month, 2 images/screening, 3-5s/image on a T4-class GPU)
%   instead of an unstated synthetic rate.
%
%   Two arrival-rate regimes are computed, because they answer different
%   questions:
%     1. STEADY-STATE (spread across realistic clinic working hours) -
%        answers "is the system provisioned for average load".
%     2. BURST (a stated fraction of a tier's health workers uploading
%        within the same short window, e.g. shift-start) - answers "how
%        many servers does PEAK concurrency actually need", which is
%        the real capacity-planning question and the one the SimEvents
%        99%-utilization stress test was implicitly probing without
%        connecting it to a real number.
%
%   Target: keep per-server utilization rho <= UTIL_CEILING under the
%   burst regime (a stricter, more useful bar than steady-state, which
%   is trivially satisfied at every tier).

    UTIL_CEILING = 0.80;
    IMAGES_PER_SCREENING = 2;
    SERVICE_TIME_RANGE_SEC = [3, 5]; % from the scalability PDF, T4-class GPU
    SERVICE_TIME_MID_SEC = 4;
    WORKING_HOURS_PER_DAY = 8;
    WORKING_DAYS_PER_MONTH = 22;
    BURST_WINDOW_SEC = 5 * 60; % 5-minute shift-start upload rush
    BURST_WORKER_FRACTION = 0.20; % stated assumption: 20% of a tier's health workers upload within the same burst window

    tiers = struct( ...
        'name',            {'Pilot', 'Growth', 'Scale'}, ...
        'screeningsPerMo', {100, 1000, 10000}, ...
        'healthWorkers',   {10, 50, 300}); % upper end of each tier's stated range

    fprintf('=== Capacity planning: connecting scalability_cost_projection.pdf to the SimEvents queueing model ===\n');
    fprintf('Assumptions: %d images/screening, %.0f-%.0fs/image (T4 GPU), %dh/day x %d days/mo clinic hours,\n', ...
        IMAGES_PER_SCREENING, SERVICE_TIME_RANGE_SEC(1), SERVICE_TIME_RANGE_SEC(2), ...
        WORKING_HOURS_PER_DAY, WORKING_DAYS_PER_MONTH);
    fprintf('burst = %.0f%% of a tier''s health workers uploading within the same %d-minute window.\n\n', ...
        BURST_WORKER_FRACTION * 100, BURST_WINDOW_SEC / 60);

    mu = 1 / SERVICE_TIME_MID_SEC; % service rate, images/sec, one server

    results = struct('name', {}, 'steadyStateUtil1Server', {}, ...
        'burstArrivalRateImgPerSec', {}, 'serversNeededForBurst', {}, ...
        'resultingBurstUtil', {});

    for t = 1:numel(tiers)
        tier = tiers(t);
        imagesPerMonth = tier.screeningsPerMo * IMAGES_PER_SCREENING;
        workingSecPerMonth = WORKING_HOURS_PER_DAY * WORKING_DAYS_PER_MONTH * 3600;
        lambdaSteady = imagesPerMonth / workingSecPerMonth; % images/sec, averaged over clinic hours

        burstWorkers = tier.healthWorkers * BURST_WORKER_FRACTION;
        burstImages = burstWorkers * IMAGES_PER_SCREENING;
        lambdaBurst = burstImages / BURST_WINDOW_SEC;

        rhoSteady1 = lambdaSteady / mu;
        serversNeeded = max(1, ceil(lambdaBurst / (UTIL_CEILING * mu)));
        rhoBurstActual = lambdaBurst / (serversNeeded * mu);

        fprintf('--- %s (%d screenings/mo, ~%d health workers) ---\n', tier.name, tier.screeningsPerMo, tier.healthWorkers);
        fprintf('  Steady-state (clinic-hours average): lambda=%.5f img/s -> 1-server utilization=%.2f%% (ample headroom)\n', ...
            lambdaSteady, rhoSteady1 * 100);
        fprintf('  Burst (%.0f%% of workers, %d-min window): lambda=%.4f img/s\n', ...
            BURST_WORKER_FRACTION * 100, BURST_WINDOW_SEC / 60, lambdaBurst);
        fprintf('  -> Servers needed to keep burst utilization <= %.0f%%: %d (resulting utilization: %.1f%%)\n\n', ...
            UTIL_CEILING * 100, serversNeeded, rhoBurstActual * 100);

        results(end+1) = struct('name', tier.name, ... %#ok<AGROW>
            'steadyStateUtil1Server', rhoSteady1, ...
            'burstArrivalRateImgPerSec', lambdaBurst, ...
            'serversNeededForBurst', serversNeeded, ...
            'resultingBurstUtil', rhoBurstActual);
    end

    % Cross-reference: what arrival rate would a single-server SimEvents
    % run need to reproduce its own reported ~99% utilization result?
    lambdaFor99pct = 0.99 * mu;
    fprintf('=== Connecting to the SimEvents write-up ===\n');
    fprintf('The reported 99%% single-server utilization corresponds to an arrival rate of\n');
    fprintf('~%.3f img/s (~1 image every %.1fs) sustained - that is a deliberate stress-test rate,\n', ...
        lambdaFor99pct, 1/lambdaFor99pct);
    fprintf('roughly %.0fx the Scale tier''s own steady-state average (%.4f img/s) and close to its\n', ...
        lambdaFor99pct / results(end).steadyStateUtil1Server / mu, results(end).steadyStateUtil1Server * mu);
    fprintf('burst-window rate (%.4f img/s) - i.e. the SimEvents graphs show what happens at sustained\n', results(end).burstArrivalRateImgPerSec);
    fprintf('peak load, not average load, and this analysis is what turns that into a staffing number:\n');
    fprintf('%s needs %d GPU instance(s), %s needs %d, %s needs %d to keep burst utilization <= %.0f%%.\n', ...
        results(1).name, results(1).serversNeededForBurst, ...
        results(2).name, results(2).serversNeededForBurst, ...
        results(3).name, results(3).serversNeededForBurst, UTIL_CEILING * 100);

    cfg = config();
    save(fullfile(cfg.resultsDir, 'capacity_planning_results.mat'), 'results');
    fprintf('\nSaved results to %s\n', fullfile(cfg.resultsDir, 'capacity_planning_results.mat'));
end
