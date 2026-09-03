# DR Screening — Handoff Context for Claude Code

This file exists so a fresh Claude Code session (or any other engineer) can pick up this project with full context, without re-deriving the architecture decisions from scratch. Read this before touching code.

Repo: `github.com/FatYoshi17/dr-screening`
Problem statement: SIH26038, "Explainable AI for Diabetic Retinopathy Screening in Rural India" (Smart India Hackathon 2026).

**Critical fact about this codebase: none of it has been run yet.** It was written in a cloud sandbox with no MATLAB installation, no GPU, and no trained models — so it's real, complete code written carefully against documented MATLAB/Deep Learning Toolbox APIs, but it is untested. Expect small API/syntax issues on first run. Treat every `.m` file as a strong first draft that needs a debugging pass, not verified-working code. `docs/RUN_GUIDE.md` has an explicit "most likely failure points" section — read it before training anything.

---

## 1. The problem, in one paragraph

India has 77M+ diabetic adults and ~1 ophthalmologist per 100,000 rural population — manual DR screening doesn't scale. The pipeline takes a fundus (retina) photo and: (1) checks if it's good enough to grade, (2) finds the structures/lesions in it, (3) grades DR severity 0–4 (referable = grade 2+), (4) explains the decision so a clinician can validate it in under 30 seconds. Target metrics: sensitivity >90%, specificity >85% on referable DR (2+). Full medical background and the original 5-module scope are in `PROJECT_BRIEF.md` — Module 5 (Simulink queueing simulation) is out of scope for this handoff, it's a separate deliverable not covered by the code below.

## 2. Repo structure

```
dr-screening/
├── config.m                        central path config — READ THIS FIRST when adding any new file that touches disk
├── startup.m                       adds src/ subfolders to path
├── README.md                       setup + structure overview (shorter version of this file)
├── PROJECT_BRIEF.md                original problem-statement brief, medical background, all 5 modules, datasets, 2-week plan
├── docs/
│   └── RUN_GUIDE.md                requirements, dataset table, training order, "why no public hosting", most-likely-failure-points
├── scripts/
│   ├── train_all_models.m          orchestrates training every module in order (Module 1 → 2A → 2B → 3; Module 4 calibration is manual, see RUN_GUIDE.md step 5)
│   ├── run_end_to_end_pipeline.m   CURRENT single-image driver: Module 1 → 2 → 3 → 4, saves a PDF report
│   ├── app_try_it.m                uifigure GUI wrapping run_end_to_end_pipeline — the "try it" experience (no MATLAB Web App Server assumed, so this is a local app, not a public URL)
│   ├── run_pipeline_single_image.m ⚠️ STALE — pre-dates the Module 1 rewrite and the module2_segmentation restructure; calls qc.overallScore/qc.fovCoverage (fields that no longer exist — new qc struct is qc.qualityScore/qc.decision/qc.classProbs/qc.fovMask etc., see assessImageQuality.m) and calls the old Module 2 functions directly by their pre-Track-A/B names. Either delete it or rewrite it to match run_end_to_end_pipeline.m — do NOT trust it as-is.
│   └── run_full_evaluation.m       ⚠️ STALE — references cfg.metricsLogsDir, which config.m no longer defines. Needs updating (add the field back to config.m, or change what this script writes to) before use.
├── src/
│   ├── common/
│   │   ├── fovMask.m                Otsu threshold + largest-connected-component + morphological open/close → logical FOV mask. Used everywhere. Stable, unchanged.
│   │   ├── ioUtils.m                image load/synthetic-test-image helpers
│   │   ├── metrics.m                sensitivity/specificity/etc. helpers
│   │   └── datasetSplits.m          train/val split helpers
│   ├── module1_quality/            ── MODULE 1: image quality ──
│   │   ├── extractQualityFeatures.m       5 features: sharpness (Laplacian variance), exposure (mean green-channel brightness + clipped-pixel fraction), contrast (std/RMS), fov (coverage + compactness via bwperim), noise (MAD on median-filter residual)
│   │   ├── fitFeatureNormalization.m      fits per-feature logistic normalization params (median/MAD-based) from a training table; exposure uses a symmetric "distance from target" transform instead of monotonic logistic
│   │   ├── normalizeQualityFeatures.m     applies fitted params → 1×5 [0,1] feature vector
│   │   ├── trainOrdinalQualityModel.m     trains fitmnr(X, y, 'ModelType','ordinal','Regularization','ridge','Lambda',0.05) on EyeQ, saves data/models/module1_quality_model.mat
│   │   ├── assessImageQuality.m           MAIN ENTRY POINT — loads trained model, extracts+normalizes features, predicts, returns qc struct: .decision (Pass/Enhance/Reject), .classProbs, .qualityScore, .fovMask, .features, .featureScores, .featureNames, .isGradable, .failReasons
│   │   ├── bilateralFilterEnhance.m       per-channel imbilatfilt
│   │   ├── enhanceImage.m                 orchestrator: Pass → CLAHE only; Enhance → illumination-norm → bilateral filter → CLAHE; re-assesses after
│   │   ├── rejectUngradeable.m            builds a recapture-feedback report for Reject-decision images
│   │   ├── claheEnhance.m, illuminationNormalize.m, denoiseImage.m   lower-level image-processing helpers called by enhanceImage.m
│   │   └── tests/test_module1.m
│   ├── module2_segmentation/       ── MODULE 2: structure/lesion segmentation, two tracks ──
│   │   ├── trackA_structures/            unified multi-class net: everything EXCEPT microaneurysms
│   │   │   ├── cbamLayer.m                     classdef custom layer — channel attention (shared MLP on avg+max pooled descriptors) + spatial attention (avg+max across channels, 7×7 conv), sigmoid gates
│   │   │   ├── multiScaleAttentionLayer.m      classdef custom layer — 3 parallel dilated convs (rates [1,2,4]) combined via learned per-image softmax weights
│   │   │   ├── diceFocalPixelClassificationLayer.m   classdef < nnet.layer.ClassificationLayer — combined Dice + Focal loss (FocalGamma, DiceWeight properties)
│   │   │   ├── buildTrackANetwork.m            deeplabv3plusLayers(imageSize, numClasses, 'resnet18') base, splices in multiScaleAttentionLayer + cbamLayer + final conv + softmax + the custom loss layer after removing the default {'scorer','softmax-out','labels'}, connecting from 'dec_relu2' — ⚠️ layer name may not match your MATLAB version, verify with lgraph.Layers
│   │   │   ├── trainTrackA.m                   11-class scheme {Background,VH,Retina,Fovea,Vessel,OD,EX,IRMA,HE,NV,CWS}; labelIDs = {0,4,{8,255},16,24,32,63,96,127,166,191} — note MA (255) is folded INTO the Retina class here since Track A doesn't own microaneurysms, Track B does
│   │   │   └── segmentStructures.m             inference wrapper using semanticseg(), returns .labelMap, .probMaps, .masks (per-class logical masks, field names via matlab.lang.makeValidName)
│   │   ├── trackB_microaneurysms/        dedicated MA detector — the hardest sub-task in the whole project
│   │   │   ├── exportSegformerONNX.py          Python (torch/transformers/onnx) — exports nvidia/segformer-b0-finetuned-ade-512-512 with a modified 2-class head to .onnx. THE ONLY STEP IN THIS PROJECT THAT ISN'T MATLAB — run this separately, then bring the .onnx file into MATLAB
│   │   │   ├── importSegformerMATLAB.m         importNetworkFromONNX (needs the Deep Learning Toolbox Converter for ONNX Model Format add-on), adds a 4× bilinear upsample layer (resize2dLayer) to compensate for SegFormer's native 1/4-resolution output, then softmax + diceFocalPixelClassificationLayer({'Background','Microaneurysm'})
│   │   │   ├── extractSlidingWindowPatches.m   tiling with configurable overlap (default 0.75 strideFraction), symmetric-padding for edge tiles — patch sizes 256/512, chosen to be divisible for SegFormer's stride structure
│   │   │   ├── topHatHardNegativeMining.m      ⚠️ OFFLINE / TRAINING-SET-CONSTRUCTION ONLY, never call this at inference time — imtophat(imcomplement(gray), strel('disk',3)) finds false positives vs ground truth, used to mine hard negatives for training. If this gets wired into detectMicroaneurysmsV2.m as an inference-time gate, that's a bug — top-hat's own low recall would become a ceiling on the whole pipeline
│   │   │   ├── trainTrackB.m                   builds a positive-biased (50% target) + hard-negative + plain-random patch set, fine-tunes the imported SegFormer at a low LR (5e-5)
│   │   │   ├── objectWiseConfidence.m           bwconncomp + regionprops blob grouping; confidence = 0.6×MeanIntensity + 0.4×MaxIntensity — deliberately per-blob, not per-pixel
│   │   │   ├── subpixelGaussianFit.m            inverted 2D Gaussian fit via fminsearch (base MATLAB, no Optimization Toolbox needed) on each candidate blob's local intensity patch; returns shapeConfidence (R² × sigma/amplitude plausibility penalties) and fitParams
│   │   │   └── detectMicroaneurysmsV2.m         MAIN ENTRY POINT — sliding-window predict → overlap-averaged stitching → objectWiseConfidence → subpixelGaussianFit per candidate → combinedConfidence = 0.6×confidence + 0.4×shapeConf; thresholds: ≥0.6 confirmed, 0.35–0.6 ambiguous, <0.35 rejected
│   │   └── legacy_v1_classical/          pre-Track-A/B classical (non-deep-learning) Module 2 approach — kept for reference, NOT part of the current pipeline, not called by anything in scripts/. Subfolders: exudates/, hemorrhages/, microaneurysms/, opticDisc/, vessels/, tests_v1/
│   ├── module3_grading/            ── MODULE 3: severity grading, hybrid rule + CNN ──
│   │   ├── grade01Rule.m                  checks Track A masks for anything besides {Background,Retina} with >25px; if found, impliesReferable=true (not committed as final — CNN still runs); else commits Grade 0 (no confirmed MA) or Grade 1 (≥1 confirmed MA from Track B). If Track B has any ambiguous candidates, defers entirely (impliesReferable = [])
│   │   ├── gemPoolingLayer.m              classdef custom layer — GeM (Generalized Mean) pooling, learnable scalar P (init 3), replaces plain avg-pool — APTOS-2019-winning-solution trick
│   │   ├── huberRegressionLayer.m         classdef < nnet.layer.RegressionLayer, Delta property
│   │   ├── trainGradingCNN.m              resnet50('Weights','imagenet') base, replaces {avg_pool, fc1000, fc1000_softmax, ClassificationLayer_fc1000} with gemPoolingLayer → FC(256) → ReLU → Dropout → FC(1) → huberRegressionLayer; connects from 'activation_49_relu' (⚠️ verify against your MATLAB version); trains on the FULL 0-4 grade range (regression, not classification) with an 85/15 split (rng(42)); optimizeRoundingThresholds does a grid search maximizing Quadratic Weighted Kappa to turn the continuous score back into a 0-4 grade, instead of naive round()
│   │   ├── predictGradingCNN.m            loads model, returns .continuousScore, .grade (via the optimized thresholds), .rawConfidence (distance-to-nearest-threshold proxy — explicitly uncalibrated, Module 4 calibrates it)
│   │   ├── disagreementFlag.m             implements the full disagreement-flag table (see §3 below): compares grade01Rule's read against predictGradingCNN's read, sets flagged/priority/message/showConfidence(false when flagged)/silentDiagnosticNote
│   │   └── gradeImage.m                   orchestrator: grade01Rule + predictGradingCNN (always runs, independent second read) + disagreementFlag
│   └── module4_explainability/     ── MODULE 4: explainability ──
│       ├── computeGradCAM.m               wraps gradCAM(model.net, img, 1, 'OutputLayer','grading_huber_output','FeatureLayer','gem_pool') — pointed at the regression output neuron, not a class-probability channel; builds an alpha-blended overlay, thresholds heatmap at 75th percentile
│       ├── fitConfidenceCalibration.m      Platt scaling (1-D logistic fit via fminsearch) — analogous to temperature scaling for a regression-then-threshold setup
│       ├── calibrateConfidence.m           applies 1/(1+exp(-(a·rawConfidence+b)))
│       ├── lesionAttentionOverlap.m        compares camResult.heatmapMask against the dilated union of Track A masks + confirmed Track B candidates; flags hasUnexplainedRegion if >50px of the heatmap falls outside any known lesion — this is the project's explainability differentiator: "does the model agree with Module 2 about WHERE the disease is"
│       └── generateAnnotatedReport.m       3-panel figure (Module 2 lesion overlay / Grad-CAM overlay / text panel); text panel layout branches on gradeResult.flag — see §3, "report presentation rules"
├── data/
│   ├── raw/                        datasets go here, gitignored (see §4)
│   ├── processed/                  gitignored
│   └── models/                     trained .mat/.onnx files land here, gitignored
└── results/                        pipeline output (reports, logs), gitignored except results/samples/
```

## 3. Key architecture decisions (so you don't re-litigate them)

**Module 2 is two independent tracks, not one network**, because microaneurysms are a fundamentally different detection problem (few-pixel blobs, extreme class imbalance, precision-critical) from everything else (larger, more textured structures where a segmentation net does fine). Track A owns {optic disc, fovea, vessels, exudates, hemorrhages, IRMA, neovascularization, CWS}; Track B owns only microaneurysms. Track A's label scheme folds the MA pixel value into "Retina" so the two tracks don't double-count.

Track B's model is **SegFormer-B0**, not a CBAM CNN — this was reversed once mid-project (toward CBAM per a teammate's tooling-risk argument, then back per explicit instruction: "use segformer in track b"). If you see any CBAM-based microaneurysm code, it's stale — CBAM is Track A's attention mechanism (`cbamLayer.m`), not Track B's model.

**Top-hat filtering is offline-only** (`topHatHardNegativeMining.m`) — training-set construction, never an inference-time gate. This was a deliberate correction: gating inference on top-hat would make top-hat's own recall a ceiling on the whole pipeline.

**Module 3 is a hybrid, not "just a CNN"**: a rule straight from Module 2's output handles the Grade 0/1 boundary (ICDR: microaneurysms-only = Grade 1, nothing = Grade 0), while an independent CNN reads the full 0-4 range on every single image regardless of what the rule said. Two independent opinions, compared via the disagreement table below — this doubles as a QA mechanism, not just redundancy.

**Priority is accuracy over compute cost.** The problem statement's only hard numeric targets are sensitivity >90% / specificity >85%, with no stated compute budget — Modules 2 and 3 are designed to run at a district-tier server, not on the rural capture device itself (device does capture + Module 1 only; heavier modules run downstream, per the (out-of-scope-here) Module 5 queueing design).

**Disagreement flag table** (implemented exactly in `disagreementFlag.m`):

| Rule (Module 2-derived) | CNN (full-range) | Flag | Priority | Confidence shown? |
|---|---|---|---|---|
| Grade 0 or 1 | Grade 2+ | Flagged | HIGH — possible missed disease | No |
| Grade 2+ (implied) | Grade 0 or 1 | Flagged | LOW — possible false alarm | No |
| Ambiguous Track B candidates present | (any) | Deferred, not committed | — | — |
| Agree | Agree | Not flagged | — | Yes (calibrated) |

A **verbal-only feedback loop** is planned (not built): flagged/corrected cases become free active-learning labels for periodic (not real-time) retraining. Nothing in the codebase implements this yet — it's a documented intention only.

**Report presentation rules** (`generateAnnotatedReport.m`): no flag → grade badge + calibrated confidence + Grad-CAM overlay + Module 2 lesion list. High-priority flag → red banner, BOTH raw opinions shown as text, NO confidence number. Low-priority flag → banner, "Module 2 found: [...]. CNN grade: [...]", NO confidence number. The rationale: don't show a confidence number when the two independent reads disagree — it'd be misleading either way.

**Module 1 "Version A"** (as opposed to an unspecified, never-built "Version B" that would add vessel density as a 6th feature): 5 classical features → per-feature logistic normalization → ridge-regularized ordinal logistic regression (`fitmnr`, MATLAB R2023a+) → Pass/Enhance/Reject. Calibrated on EyeQ (primary), optionally FIQuA, plus ~30-50 hand-labeled portable-camera images for field-condition realism; Messidor-2 is held out untouched for final reporting only, never used in calibration.

**No public web hosting.** "Hosted and running, try it" was scoped down to `app_try_it.m`, a local MATLAB GUI — a real public URL needs MATLAB Web App Server or Production Server, both separate licensed products not assumed to be available. This was an explicit, user-approved scope decision, not an oversight.

## 4. Datasets (none are in the repo — `.gitignore`d, download separately)

| Dataset | Used by | Path (see `config.m`) |
|---|---|---|
| Refined IDRiD | Module 2, both tracks | `data/raw/refined_idrid/{Train,Test}/{Images,Labels}/` — 12-class unified masks (bg, VH, retina, fovea, vessel, OD, EX, IRMA, HE, NV, CWS, MA as single-channel PNGs) |
| EyeQ | Module 1 | `data/raw/eyeq/` — github.com/HzFu/EyeQ |
| APTOS 2019 | Module 3 | `data/raw/aptos2019/` — kaggle.com/competitions/aptos2019-blindness-detection |
| Messidor-2 | External validation only, never training | `data/raw/messidor2/Messidor-2/` |
| IDRiD (original) | Legacy Module 2 / DRIVE-style reference | `data/raw/idrid/IDRiD/` |
| DRIVE | Vessel segmentation benchmark, not wired into the current pipeline | `data/raw/drive/` |

## 5. Training order & running it

See `docs/RUN_GUIDE.md` for the full version (requirements, toolboxes, exact commands). Short version: `scripts/train_all_models.m` runs Module 1 (fast, CPU) → Module 2 Track A (GPU, hours) → Module 2 Track B (needs `exportSegformerONNX.py` run in Python first, then GPU hours) → Module 3 (GPU, hours). Module 4's confidence calibration is a manual last step (fit against Module 3's validation predictions — not automated since it depends on your chosen split). Then `app_try_it` or `run_end_to_end_pipeline(imagePath)`.

## 6. What to actually do with this handoff

This is untested code, so the highest-value first pass is **not** adding new features — it's:
1. Get a MATLAB session and run `lgraph.Layers` against `deeplabv3plusLayers` and `resnet50` outputs on your installed version, fix any layer-name mismatches in `buildTrackANetwork.m` and `trainGradingCNN.m`.
2. Sanity-check every custom layer's `predict` method (`cbamLayer.m`, `multiScaleAttentionLayer.m`, `gemPoolingLayer.m`) against real `dlarray` inputs — dimension/format handling is the likeliest subtle bug.
3. Either fix or delete `scripts/run_pipeline_single_image.m` and `scripts/run_full_evaluation.m` — both are stale and reference APIs the current codebase no longer has.
4. Only after the above: get real datasets in place and run `train_all_models.m` stage by stage, not all at once, so failures are attributable to one module.
