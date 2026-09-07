# DR Screening

MATLAB pipeline for diabetic retinopathy screening from fundus
photographs — image quality assessment, dual-track lesion/structure
segmentation, severity grading, and explainability. Built for the
MathWorks "Explainable AI for Diabetic Retinopathy Screening in Rural
India" problem statement (SIH26038); full medical/architectural
background in [PROJECT_BRIEF.md](PROJECT_BRIEF.md).

## Current status

| Module | Status | Result |
|---|---|---|
| **Module 1** — image quality | **Trained** (ordinal logistic regression, EyeQ) + a deterministic fundus-plausibility gate ahead of it (`checkFundusPlausibility.m`) | Correctly rejects non-fundus photos (FOV coverage > 0.95, e.g. an external eye/eyebrow close-up) that the trained model alone did not catch |
| **Module 2, Track A** — structures (OD, vessels, EX, HE, IRMA, NV, CWS...) | **Trained** (resnet18 DeepLabV3+, 80 epochs) | Loss ~0.26, ~95% pixel accuracy (train). Held-out per-class Dice (IDRiD segmentation test, n=27, via `evaluate_trackA_dice.m`): **EX 0.416, HE 0.296, CWS 0.507**. IRMA/NV: not evaluable — IDRiD's ground truth has no annotations for either class |
| **Module 2, Track B** — microaneurysms | **CBAM CNN is the active model** (~0.36 mean Dice, held-out IDRiD patches). SegFormer-B0 import works end-to-end and was fully fine-tuned (3600 iterations, LR 3e-4), but scored **0.000 Dice at every threshold tested (0.10-0.30)** on held-out patches — the import/training pipeline runs, the model itself just isn't competitive yet. `cfg.trackBActiveNetPath` stays on CBAM | See `module2_segmentation/trackB_microaneurysms/evaluateTrackBCheckpoint.m` |
| **Module 3** — severity grading | **Trained** (resnet50 + GeM pooling, 30 epochs) | Validation QWK **0.9156** (APTOS internal 85/15 split — a training-time metric, not held-out sensitivity/specificity). Real sensitivity/specificity at the referable-DR threshold (grade≥2), on IDRiD's held-out Disease Grading test set and an external Messidor-2 subset with real grades (matched via MAPLES-DR), plus a rule-only vs. CNN-only vs. combined ablation: see `evaluate_referable_dr.m` and `results/evaluate_referable_dr_results.mat` |
| **Module 4** — explainability (Grad-CAM, calibration) | Code complete and wired into every real report | Calibrated confidence, lesion-attention overlap, disagreement flagging all live in both the MATLAB PDF and the web report |
| **Module 5** — capacity planning | Analytical M/M/c queueing model (`capacity_planning.m`) connecting `scalability_cost_projection.pdf`'s real tier data to a concrete GPU/server-count recommendation per tier, rather than an unconnected SimEvents stress test | Pilot: 1 server, Growth: 1 server, Scale: 2 servers to keep burst-load utilization ≤80% |
| **Frontend** | Built and wired to the real pipeline via `backend/` — see [frontend/README.md](frontend/README.md) | Real captures produce real grades/reports, not demo data; a separate fast `/api/quality-check` endpoint runs Module 1 alone (~seconds) so the quality-check step doesn't pay for the full grading pipeline |

**Track B's SegFormer import is fixed.** MATLAB's ONNX converter is
blocked by a genuine MathWorks packaging defect — the "Deep Learning
Toolbox Converter for ONNX Model Format" package needs a protobuf
symbol (`RepeatedPtrFieldBase::element_at`) missing from every copy of
`libprotobuf3.dll` this project could find (R2025a, a fresh R2025b
install, and the Compiler SDK's own copy — confirmed by direct PE
import/export table inspection, not a guess; see
[docs/segformer_onnx_issue.md](docs/segformer_onnx_issue.md)). That
path was abandoned in favor of `importNetworkFromPyTorch` on a
`torch.jit.trace` export
(`exportSegformerEager.py` → `importSegformerPyTorch.m`), which
required `attn_implementation='eager'` (the default SDPA path has a
tracer-breaking dynamic bool) and PyTorch ≥ 2.8.

The generated custom-layer code (`+segformer_eager/`) needed extensive
manual fixes to actually run: MATLAB's `dlnetwork/predict()` dispatch
silently squeezes the leading batch=1 dimension out of nested custom
layers' array storage, corrupting every rank/size/batch/channel value
threaded through the generated code — nondeterministically, since some
`predict()` calls hit it and others don't. Fixed by deriving batch,
channels, and sequence length directly from each tensor's own raw
storage shape instead of trusting the threaded values, at every call
site across the encoder and every per-stage duplicate of each
generated class (see the inline comments throughout `+segformer_eager/*.m`
for the full diagnosis at each site). `predict()` now runs the full
network end to end (`test_segformer_predict.m`), producing a stable
`[128 128 2 1]` output with no NaNs across repeated runs.

`buildTrackBSegformerNetwork.m` wraps the imported encoder with the
same 4x upsample + softmax + Dice+Focal loss head the rest of Track B
uses. Fine-tuning has since been run to completion (3600 iterations,
LR 3e-4, `run_train_trackB.m`) and evaluated (`evaluateTrackBCheckpoint.m`)
on held-out IDRiD patches: **0.000 Dice at every threshold tested from
0.10 to 0.30** — worse than earlier attempts, which at least showed
some real (if miscalibrated) signal. A raw-score check confirmed the
model isn't dead, just underconfident: ground-truth lesion pixels score
~0.0075 vs. ~0.0036 for background, but the max score anywhere in a
real lesion patch was only ~0.011 — 10-30x below every threshold this
session tried. The CBAM CNN (`buildTrackBNetwork.m`) remains the
active model (`cfg.trackBActiveNetPath`); SegFormer is importable and
trainable end-to-end but not yet competitive.

## Repo layout

```
module1_quality/          image quality scoring (ordinal regression / threshold fallback) + enhancement
module2_segmentation/
  trackA_structures/       unified multi-class structure segmentation — DeepLabV3+ (resnet18) + CBAM + multi-scale attention
  trackB_microaneurysms/   dedicated microaneurysm detection — SegFormer-B0 via importNetworkFromPyTorch (working, fine-tuning pending) + a native CBAM CNN fallback
  legacy_v1_classical/     superseded classical (non-deep-learning) approach, kept for reference only
module3_grading/          rule-based Grade 0/1 + full-range grading CNN (resnet50) + disagreement flagging
module4_explainability/   Grad-CAM, calibrated confidence, lesion-attention overlap, annotated report
common/                   shared utilities: FOV mask, image I/O, metrics
frontend/                 React/TypeScript/Vite browser UI, wired to backend/ for real screening — see frontend/README.md
backend/                  FastAPI bridge between the frontend and the MATLAB pipeline (backend/main.py)
scripts/                  runnable entry points (train_all_models, run_end_to_end_pipeline, app_try_it)
tests/                    smoke tests and diagnostics written while getting each module training for real
docs/                     RUN_GUIDE.md and other project docs
data/                     datasets and trained models (gitignored, see below)
```

## Setup

1. MATLAB R2023a+ with Image Processing, Statistics and Machine
   Learning, Deep Learning, and Computer Vision Toolboxes. A GPU is
   needed to train Module 2 and Module 3 in reasonable time. Track B's
   SegFormer path additionally needs the Deep Learning Toolbox
   Converter for PyTorch Model Format support package (not the ONNX
   one — see above), and Python 3.9+ with `torch>=2.8`, `transformers`
   on whichever machine runs `exportSegformerEager.py` (see
   `docs/RUN_GUIDE.md`).
2. In MATLAB:
   ```matlab
   cd('path/to/dr-screening')
   startup
   ```
3. Datasets go under `data/raw/` — `config()` returns the exact
   expected paths once they're there.

Full training-order instructions are in
[docs/RUN_GUIDE.md](docs/RUN_GUIDE.md).

## Run it

```matlab
startup
train_all_models      % train Modules 1-3, then calibrate Module 4
app_try_it            % GUI: load a fundus image, see the full report
% or headless:
result = run_end_to_end_pipeline('path/to/some_fundus_image.jpg');
```

## Data

Datasets aren't pushed to GitHub — too large, some need licensed
registration. Download and place under `data/raw/<name>/`:

- [IDRiD](https://ieeedataport.org/open-access/indian-diabetic-retinopathy-image-dataset-idrid) → `data/raw/idrid/` (registration required)
- [Messidor-2](https://www.adcis.net/en/third-party/messidor2/) → `data/raw/messidor2/` (registration required, external validation holdout only). The redistributed image set ships with no DR grade labels — real grades for 162 of the locally-available images were sourced from [MAPLES-DR](https://github.com/LIV4D/MAPLES-DR) (Lepetit-Aimon et al., *Nature Scientific Data* 2024) and merged into `data/raw/messidor2/messidor2_grades.csv` (`image_name,dr_grade`, Messidor's standard R0-R3 scale, referable threshold R≥2)
- [Refined IDRiD](https://zenodo.org/records/17615903) → `data/raw/refined_idrid/{Train,Test}/{Images,Labels}/` — trains Module 2 (both tracks)
- [EyeQ](https://github.com/HzFu/EyeQ) → `data/raw/eyeq/` — quality labels for Module 1 (images come from the Kaggle competition below)
- [Diabetic Retinopathy Detection (EyePACS)](https://www.kaggle.com/competitions/diabetic-retinopathy-detection) → the actual images EyeQ's labels reference
- [APTOS 2019](https://www.kaggle.com/c/aptos2019-blindness-detection) → `data/raw/aptos2019/` — trains Module 3
- [DRIVE](https://drive.grand-challenge.org/) → `data/raw/drive/` (optional, vessel-only pretraining)

`config.m` has the exact expected sub-paths for every dataset and every
trained model file.

## Real bugs found and fixed getting this running (worth knowing before you touch the code)

- `pixelLabelDatastore` needs merged-class label IDs as a numeric
  **column** vector (`[8;255]`), not a nested cell (`{8,255}`) — the
  original code errored immediately.
- `deeplabv3plusLayers` already returns a `layerGraph` directly —
  wrapping it in `layerGraph()` again errors.
- Track A's decoder splice point: `dec_relu2` is the *low-level skip
  branch*, not the final decoder feature (traced via
  `lgraph.Connections`, not just layer names) — the real final feature
  before scoring is `dec_relu4`. Splicing attention after `dec_relu2`
  as first written would have silently bypassed the ASPP fusion path
  entirely.
- `diceFocalPixelClassificationLayer`'s loss went `Inf`→`NaN` on
  iteration 1-2 of real training: rotation-augmented label pixels near
  rotated image corners have no valid one-hot class, and `log(0)`
  isn't caught by clipping `Y` alone. Fixed with an explicit per-pixel
  validity mask, verified over 10 epochs of randomized rotation.
  augmentation.
- `fitmnr` in R2023a-R2025a has no `Regularization`/`Lambda`
  name-value pair — `help fitmnr` is the source of truth, not the
  original assumption.
- `augmentedImageDatastore(outputSize, imds, Y)` errors when `imds` is
  an `ImageDatastore` — responses can only be paired with a 4-D
  numeric array or a table.
- GPU OOM at the originally-specified 1024×1024/batch-4 training
  settings on a 6GB laptop GPU — dropped to 512×512/batch-2 for
  Track A.

## Original design vs. what actually runs

Two of the three specified pretrained backbones (ResNet-18 for
Track A, ResNet-50 for Module 3) work exactly as designed once their
support packages are installed — verify with `resnet18('Weights','imagenet')`
etc. Where an environment genuinely couldn't get a support package
installed, `module2_segmentation/trackA_structures/buildTrackANetwork.m`
and `module3_grading/trainGradingCNN.m` both have SqueezeNet-based
substitutes documented inline (SqueezeNet is the only ImageNet-pretrained
network bundled with base Deep Learning Toolbox, no separate
download) — not used in the currently-trained models above, but kept
as a documented fallback path.
