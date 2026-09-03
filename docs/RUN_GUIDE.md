# Run Guide — Modules 1–4, end to end

This code was written without access to a MATLAB installation (the environment that generated it has none), so **none of it has been executed or debugged**. It's built carefully against documented MATLAB/Deep Learning Toolbox APIs and the architecture this project settled on, but expect to fix small syntax/API issues on first run — treat this as a strong first draft, not verified-working code. Report anything that breaks and it can get fixed.

## 1. Requirements

- MATLAB R2023a or later (needed for `fitmnr` with `ModelType="ordinal"`, used in Module 1)
- Toolboxes: Image Processing, Statistics and Machine Learning, Deep Learning, Computer Vision (for `deeplabv3plusLayers`, `pixelLabelDatastore`), Deep Learning Toolbox Converter for ONNX Model Format (Add-On, needed for Track B's SegFormer import)
- A GPU, for Module 2 (both tracks) and Module 3 — none of this trains in reasonable time on CPU alone
- Python 3.9+ with `torch`, `transformers`, `onnx` installed, but **only** on whichever machine runs `exportSegformerONNX.py` — this is the one deliberate step outside MATLAB (see Module 2 Track B's own docs for why)

## 2. Datasets you need to get first

| Dataset | Used by | Where |
|---|---|---|
| Refined IDRiD | Module 2, both tracks | Already in `data/raw/refined_idrid/` in this repo |
| EyeQ | Module 1 | github.com/HzFu/EyeQ — download images + labels CSV, put under `data/raw/eyeq/` |
| APTOS 2019 | Module 3 | kaggle.com/competitions/aptos2019-blindness-detection — `train_images/` + `train.csv` under `data/raw/aptos2019/` |
| Messidor-2 | External validation only, not training | Already in `data/raw/messidor2/` in this repo |

## 3. Training order

Run `scripts/train_all_models.m` top to bottom, or do it stage by stage:

1. **Module 1** — `trainOrdinalQualityModel(eyeQImageDir, eyeQLabelsCsv)`. Seconds to minutes, CPU is fine. Saves `data/models/module1_quality_model.mat`.
2. **Module 2, Track A** — `trainTrackA(config())`. Hours on a GPU. Saves `data/models/trackA_net.mat`.
3. **Module 2, Track B** — two steps:
   - On a machine with PyTorch: `python exportSegformerONNX.py --out segformer_ma.onnx`
   - In MATLAB: `importSegformerMATLAB('segformer_ma.onnx')` then `trainTrackB(config())`. Hours on a GPU. Saves `data/models/trackB_segformer_net.mat`.
4. **Module 3** — `trainGradingCNN(aptosImageDir, aptosLabelsCsv)`. Hours on a GPU. Saves `data/models/module3_grading_cnn.mat`.
5. **Module 4 calibration** — after Module 3 is trained, run its validation split back through `predictGradingCNN`, record which predictions were correct, then:
   ```matlab
   calibParams = fitConfidenceCalibration(rawConfidences, wasCorrect);
   save('data/models/module4_confidence_calibration.mat', 'calibParams');
   ```
   This isn't automated in `train_all_models.m` since it depends on exactly how you split your validation set in step 4 — do it right after training Module 3 while that split is still in memory.

## 4. Trying it

Once all five stages above are done:

```matlab
startup
app_try_it   % GUI: load an image, see the full report
```

or headless, one image at a time:

```matlab
startup
result = run_end_to_end_pipeline('path/to/some_fundus_image.jpg');
```

## 5. Why there's no public web link

Real hosting — a URL anyone can click — needs MATLAB Web App Server or MATLAB Production Server, both separate licensed products not assumed to be part of this setup. `app_try_it.m` is the realistic substitute: a local, interactive GUI you run in your own MATLAB, which is what "hosted and running" turns into once no MATLAB, no GPU, and nothing trained were the actual starting constraints.

## 6. If something's wrong

This is real, complete code for every module — not stubs — but genuinely untested end to end. The most likely failure points, roughly in order of likelihood:

- Custom layer `predict` methods (`cbamLayer.m`, `multiScaleAttentionLayer.m`, `gemPoolingLayer.m`) — dlarray dimension/format handling is the easiest thing to get subtly wrong without a MATLAB session to check against.
- `buildTrackANetwork.m`'s exact layer names (`'dec_relu2'`, `'scorer'`, etc.) from `deeplabv3plusLayers` — these come from MATLAB's documented output structure but should be double-checked with `analyzeNetwork` or `lgraph.Layers` against your installed toolbox version, since layer naming can shift between MATLAB releases.
- `trainGradingCNN.m`'s `resnet50` layer names (`'input_1'`, `'activation_49_relu'`) — same caveat, verify against your MATLAB version.

If a layer name doesn't match, `lgraph.Layers` (prints every layer's name) is the fastest way to find the current correct one.
