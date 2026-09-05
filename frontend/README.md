# Frontend — DrishtiSetu (React + TypeScript + Vite)

A React/TypeScript/Vite offline-first PWA for ASHA-worker-led fundus
screening, wired to the real MATLAB pipeline via `../backend/main.py`.
Originally built as a standalone UI (with hardcoded demo scenarios for
fast, offline-safe demoing); real captures now hit the actual trained
models instead of scripted responses.

## Running it against the real pipeline

1. Start the backend (from the repo root, not this folder):
   ```
   pip install -r backend/requirements.txt
   python -m uvicorn backend.main:app --reload --port 8000
   ```
   This shells out to `matlab -batch` per request - each real screening
   takes ~10-30s (MATLAB's own startup overhead), not instant like the
   demo scenarios below.

2. Start this frontend:
   ```
   cd frontend
   npm install
   npm run dev
   ```
   Opens at `http://localhost:5173`. `dxApiClient.ts`'s `API_BASE` is
   hardcoded to `http://localhost:8000` for local dev - update it if
   the backend moves.

3. Log in with the "Demo ASHA Worker" quick-access button, register a
   patient (diabetes control/duration/HbA1c are optional but feed
   directly into the generated report's first page), and either:
   - **Choose Sample** - one of five bundled demo fundus images,
     answered instantly by hardcoded logic in `screeningService.ts`
     (`DEMO_KEYS`) - no backend call, works offline, for fast demoing.
   - **Camera / Upload** - a real photo. This goes to the real backend
     and produces a real result, including a real downloadable PDF
     report (`GET /api/report/:requestId`).

## Architecture note

MATLAB has no public web-hosting story of its own (`MATLAB Web App
Server` / `MATLAB Production Server` are separate licensed products).
The bridge is a plain FastAPI service that shells out to
`matlab -batch` per request rather than holding a persistent MATLAB
Engine session - simpler and more robust given no confirmed MATLAB
Engine API for Python install, and appropriate for this project's
actual scale (a demo/prototype, not a high-throughput service). See
`../scripts/run_pipeline_api.m` for the MATLAB-side adapter that maps
pipeline output onto this frontend's existing TypeScript types
(`src/types/index.ts`).

## Original Vite template notes

This project uses `@vitejs/plugin-react` (Oxc) with Oxlint. See
[Vite's React plugin docs](https://github.com/vitejs/vite-plugin-react/blob/main/packages/plugin-react)
and the [Oxlint rules documentation](https://oxc.rs/docs/guide/usage/linter/rules)
for details on the toolchain itself.
