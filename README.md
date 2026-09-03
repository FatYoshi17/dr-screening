# DR Screening

MATLAB pipeline for diabetic retinopathy screening from fundus photos —
image quality assessment, dual-track lesion/structure segmentation,
severity grading, and explainability. Built for the MathWorks
"Explainable AI for Diabetic Retinopathy Screening in Rural India"
problem statement (SIH26038) — full context in
[PROJECT_BRIEF.md](PROJECT_BRIEF.md).

## Setup

1. MATLAB R2023a+ with Image Processing, Statistics and Machine
   Learning, Deep Learning, and Computer Vision Toolboxes, plus the
   Deep Learning Toolbox Converter for ONNX Model Format add-on.
   A GPU is needed to train Module 2 and Module 3 in reasonable time.
2. In MATLAB:
   ```matlab
   cd('path/to/dr-screening')
   startup
   ```
3. Datasets go under `data/raw/` (see below) — `config()` returns the
   exact paths once they're there.

**Full instructions for training every module and trying the pipeline
are in [docs/RUN_GUIDE.md](docs/RUN_GUIDE.md) — start there.**

## Run it

```matlab
startup
train_all_models      % train Modules 1-3, then calibrate Module 4 (see RUN_GUIDE.md)
app_try_it            % GUI: load a fundus image, see the full report
% or headless:
result = run_end_to_end_pipeline('path/to/some_fundus_image.jpg');
```

## Structure

Organized by module, matching the architecture end to end:

```
src/module1_quality/                        image quality scoring (ordinal regression) + enhancement
src/module2_segmentation/
  trackA_structures/                        unified multi-class structure/lesion segmentation (DeepLabv3+ / ResNet18 + CBAM + multi-scale attention)
  trackB_microaneurysms/                    dedicated microaneurysm detection (SegFormer-B0, ONNX-imported)
  legacy_v1_classical/                      superseded classical (non-deep-learning) Module 2 approach, kept for reference
src/module3_grading/                        rule-based Grade 0/1 + full-range grading CNN + disagreement flagging
src/module4_explainability/                 Grad-CAM, calibrated confidence, lesion-attention overlap, annotated report
src/common/                                 shared utilities: FOV mask, image I/O, metrics
scripts/                                    runnable entry points (train_all_models, run_end_to_end_pipeline, app_try_it)
docs/                                       RUN_GUIDE.md and other project docs
data/raw/                                   datasets (gitignored - see below)
data/models/                                trained model files (gitignored)
```

## Data

Datasets aren't pushed to GitHub — too large, and some need licensed
registration. Download and place them under `data/raw/<name>/`:

- [IDRiD](https://ieeedataport.org/open-access/indian-diabetic-retinopathy-image-dataset-idrid) → `data/raw/idrid/` (registration required)
- [Messidor-2](https://www.adcis.net/en/third-party/messidor2/) → `data/raw/messidor2/` (registration required, external validation holdout only)
- [Refined IDRiD](https://zenodo.org/records/17615903) → `data/raw/refined_idrid/{Train,Test}/{Images,Labels}/` — used to train Module 2 (Track A + Track B)
- [EyeQ](https://github.com/HzFu/EyeQ) → `data/raw/eyeq/` — used to train Module 1
- [APTOS 2019](https://www.kaggle.com/c/aptos2019-blindness-detection) → `data/raw/aptos2019/` — used to train Module 3
- [DRIVE](https://drive.grand-challenge.org/) → `data/raw/drive/`

`config.m` has the exact expected sub-paths for every dataset and every
trained model file once they exist.
