# DR Screening

MATLAB pipeline for diabetic retinopathy screening from fundus photos —
image quality assessment + enhancement, and structure/lesion
segmentation. Built for the MathWorks "Explainable AI for Diabetic
Retinopathy Screening in Rural India" problem statement — full context
in [PROJECT_BRIEF.md](PROJECT_BRIEF.md).

## Setup

1. MATLAB with the Image Processing Toolbox.
2. In MATLAB:
   ```matlab
   cd('path/to/dr-screening')
   startup
   ```
3. Datasets go under `data/raw/` (see below) — `config()` returns the
   exact paths once they're there.

## Run it

```matlab
startup
run_pipeline_single_image   % end-to-end demo on one image (synthetic if no dataset configured)
run_full_evaluation(cfg.idridSegImagesTrain)   % batch run + a metrics CSV
```

## Structure

```
src/module1_quality/       image quality scoring + enhancement (CLAHE, illumination norm, denoise)
src/module2_segmentation/  optic disc/fovea, vessels, exudates, hemorrhages, microaneurysms
src/common/                shared utilities: FOV mask, image I/O, sensitivity/specificity metrics
scripts/                   runnable entry points
data/raw/                  datasets (gitignored - see below)
```

## Data

Datasets aren't pushed to GitHub — too large, and some need licensed
registration. Download and place them under `data/raw/<name>/`:

- [IDRiD](https://ieeedataport.org/open-access/indian-diabetic-retinopathy-image-dataset-idrid) → `data/raw/idrid/` (registration required)
- [Messidor-2](https://www.adcis.net/en/third-party/messidor2/) → `data/raw/messidor2/` (registration required)
- [APTOS 2019](https://www.kaggle.com/c/aptos2019-blindness-detection) → `data/raw/aptos2019/`
- [DRIVE](https://drive.grand-challenge.org/) → `data/raw/drive/`
- [Refined IDRiD](https://zenodo.org/records/17615903) → `data/raw/refined_idrid/{Train,Test}/{Images,Labels}/` — 12-class
  unified segmentation masks (background, VH, retina, fovea, vessel, OD, EX, IRMA, HE, NV, CWS, MA
  as single-channel PNGs, pixel values per the paper's Table 2) for the same 81 IDRiD segmentation
  images. Adds vessel/fovea/IRMA/NV annotations that original IDRiD never had. See
  `results/samples/idrid17_original_vs_refined.png` for a side-by-side on one real image.

`config.m` has the exact expected sub-paths for IDRiD and Refined IDRiD once they're downloaded.
