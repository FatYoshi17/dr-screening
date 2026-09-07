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
| **Module 1** — image quality | Trained (ordinal logistic regression, EyeQ) + a deterministic fundus-plausibility gate ahead of it (`checkFundusPlausibility.m`) | Correctly rejects non-fundus photos (FOV coverage > 0.95, e.g. an external eye/eyebrow close-up) that the trained model alone did not catch |
| **Module 2, Track A** — structures (OD, vessels, EX, HE, IRMA, NV, CWS...) | Trained (resnet18 DeepLabV3+, 80 epochs) | ~95% pixel accuracy (train). Held-out per-class Dice (IDRiD segmentation test, n=27): **EX 0.416, HE 0.296, CWS 0.507**. IRMA/NV: not evaluable — IDRiD has no ground truth for either class |
| **Module 2, Track B** — microaneurysms | CBAM CNN is the active model (`cfg.trackBActiveNetPath`), ~0.36 mean Dice on held-out IDRiD patches. A SegFormer-B0 alternative is importable and trainable but scored 0.000 Dice on held-out patches after fine-tuning — not currently competitive | See `module2_segmentation/trackB_microaneurysms/evaluateTrackBCheckpoint.m` |
| **Module 3** — severity grading | Trained (resnet50 + GeM pooling, 30 epochs) | Referable-DR (grade≥2) sensitivity/specificity via `evaluate_referable_dr.m`: **IDRiD held-out, n=101 — sens 0.778, spec 0.842**; **Messidor-2 external, n=162 — sens 0.762, spec 0.922**. Full per-image predictions in `results/evaluate_referable_dr_results.mat` |
| **Module 4** — explainability (Grad-CAM, calibration) | Code complete and wired into every real report | Calibrated confidence, lesion-attention overlap, and disagreement flagging are live in both the MATLAB PDF and the web report |
| **Module 5** — capacity planning | Analytical M/M/c queueing model (`module5_capacity_planning/capacity_planning.m`) connecting `scalability_cost_projection.pdf`'s real tier data to a concrete GPU/server-count recommendation | Pilot: 1 server, Growth: 1 server, Scale: 2 servers to keep burst-load utilization ≤80% |
| **Frontend** | Built and wired to the real pipeline via `backend/` — see [frontend/README.md](frontend/README.md) | Real captures produce real grades/reports, not demo data; a separate fast `/api/quality-check` endpoint runs Module 1 alone so the quality check doesn't pay for the full grading pipeline |

## Repo layout

```
module1_quality/            image quality scoring (ordinal regression / threshold fallback) + enhancement
module2_segmentation/
  trackA_structures/         unified multi-class structure segmentation — DeepLabV3+ (resnet18) + CBAM + multi-scale attention
  trackB_microaneurysms/     dedicated microaneurysm detection — CBAM CNN (active) + a SegFormer-B0 alternative
  legacy_v1_classical/       superseded classical (non-deep-learning) approach, kept for reference only
module3_grading/            rule-based Grade 0/1 + full-range grading CNN (resnet50) + disagreement flagging
module4_explainability/     Grad-CAM, calibrated confidence, lesion-attention overlap, annotated report
module5_capacity_planning/  M/M/c queueing analysis connecting deployment tier data to a GPU/server-count recommendation
common/                     shared utilities: FOV mask, image I/O, metrics
frontend/                   React/TypeScript/Vite browser UI, wired to backend/ for real screening — see frontend/README.md
backend/                    FastAPI bridge between the frontend and the MATLAB pipeline (backend/main.py)
scripts/                    runnable entry points (train_all_models, run_end_to_end_pipeline, evaluate_referable_dr, app_try_it)
tests/                      smoke tests and diagnostics
docs/                       RUN_GUIDE.md and other project docs
data/                       datasets and trained models (gitignored, see below)
```

## Setup

1. MATLAB R2023a+ with Image Processing, Statistics and Machine
   Learning, Deep Learning, and Computer Vision Toolboxes. A GPU is
   needed to train Module 2 and Module 3 in reasonable time.
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
% evaluation:
evaluate_referable_dr()      % Module 3 sensitivity/specificity, held-out + external
evaluate_trackA_dice()       % Module 2 Track A per-class Dice
capacity_planning()          % Module 5 deployment capacity recommendation
```

## Data

Datasets aren't pushed to GitHub — too large, some need licensed
registration. Download and place under `data/raw/<name>/`:

- [IDRiD](https://ieeedataport.org/open-access/indian-diabetic-retinopathy-image-dataset-idrid) → `data/raw/idrid/` (registration required)
- [Messidor-2](https://www.adcis.net/en/third-party/messidor2/) → `data/raw/messidor2/` (registration required, external validation holdout). The redistributed image set ships with no DR grade labels — real grades for 162 of the locally-available images were sourced from [MAPLES-DR](https://github.com/LIV4D/MAPLES-DR) (Lepetit-Aimon et al., *Nature Scientific Data* 2024) and merged into `data/raw/messidor2/messidor2_grades.csv` (`image_name,dr_grade`, Messidor's standard R0-R3 scale, referable threshold R≥2)
- [Refined IDRiD](https://zenodo.org/records/17615903) → `data/raw/refined_idrid/{Train,Test}/{Images,Labels}/` — trains Module 2 (both tracks)
- [EyeQ](https://github.com/HzFu/EyeQ) → `data/raw/eyeq/` — quality labels for Module 1 (images come from the Kaggle competition below)
- [Diabetic Retinopathy Detection (EyePACS)](https://www.kaggle.com/competitions/diabetic-retinopathy-detection) → the actual images EyeQ's labels reference
- [APTOS 2019](https://www.kaggle.com/c/aptos2019-blindness-detection) → `data/raw/aptos2019/` — trains Module 3
- [DRIVE](https://drive.grand-challenge.org/) → `data/raw/drive/` (optional, vessel-only pretraining)

`config.m` has the exact expected sub-paths for every dataset and every
trained model file.
