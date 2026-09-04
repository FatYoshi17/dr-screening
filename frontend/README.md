# Frontend — planned, not yet built

This folder is a placeholder. No frontend code exists here yet.

**Why:** MATLAB has no built-in public web-hosting story (`MATLAB Web App
Server` / `MATLAB Production Server` are separate licensed products,
not assumed to be available here — see the root `README.md`). The plan
for a real browser-facing UI is a thin bridge (e.g. a small FastAPI
service using the MATLAB Engine API for Python) that calls the actual
`.m` functions in `module1_quality/` through `module4_explainability/`
directly — no reimplementation of the screening logic outside MATLAB,
Python only moves bytes between a browser and MATLAB.

**Status:** on hold while Module 2's Track B (`module2_segmentation/trackB_microaneurysms/`)
finishes its own dependency work — see the root README's "Current
status" section for exactly where things stand.

**Until this exists:** the local MATLAB GUI (`scripts/app_try_it.m`) is
the working "try it" experience — see the root README.
