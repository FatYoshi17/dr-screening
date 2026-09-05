"""
backend/main.py - Web API bridging the frontend to the real MATLAB pipeline.

The frontend (DR-SCREENING-WEBPORTAL) originally had screeningService.ts
return hardcoded demo data ("SIH demo reliability") with no real backend
at all. This is that backend: accepts an uploaded fundus image (+
optional patient context), invokes MATLAB's run_end_to_end_pipeline.m
via run_pipeline_api.m, and returns results shaped to match the
frontend's existing TypeScript types so screeningService.ts only needs
its data source swapped, not its shape.

MATLAB has no persistent-process API readily available here (no
confirmed MATLAB Engine API for Python install matching this Python
version), so each request shells out to `matlab -batch` directly -
slow (MATLAB's own startup overhead, ~10-20s) but simple and robust,
appropriate for this project's actual scale (a demo/prototype
deployment, not a high-throughput service).

Run:
    pip install fastapi uvicorn python-multipart
    python -m uvicorn backend.main:app --reload --port 8000
(from the dr-screening repo root, so relative paths resolve correctly)
"""
import json
import subprocess
import tempfile
import uuid
from pathlib import Path

from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse

REPO_ROOT = Path(__file__).resolve().parent.parent
RESULTS_DIR = REPO_ROOT / "data" / "results_api"
RESULTS_DIR.mkdir(parents=True, exist_ok=True)

MATLAB_EXE = r"C:\Program Files\MATLAB\R2025b\bin\matlab.exe"
MATLAB_TIMEOUT_SECONDS = 300

app = FastAPI(title="DR Screening API")

# Vite's default dev server port; add the deployed frontend's origin
# here too once this moves past local development.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:5173", "http://127.0.0.1:5173"],
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.post("/api/screen")
async def screen_image(image: UploadFile = File(...), patientInfo: str = Form("{}")):
    """Run the full DR screening pipeline on an uploaded fundus image."""
    request_id = uuid.uuid4().hex[:12]
    work_dir = RESULTS_DIR / request_id
    work_dir.mkdir(parents=True, exist_ok=True)

    image_path = work_dir / f"input{Path(image.filename or 'image.jpg').suffix or '.jpg'}"
    with open(image_path, "wb") as f:
        f.write(await image.read())

    try:
        json.loads(patientInfo)
    except json.JSONDecodeError:
        raise HTTPException(status_code=400, detail="patientInfo must be valid JSON")

    # Written to a file rather than passed as a -batch argument: Python's
    # subprocess argument-joining on Windows re-escapes embedded double
    # quotes when building the single command-line string MATLAB
    # receives, corrupting JSON passed inline.
    patient_info_path = work_dir / "patient_info.json"
    patient_info_path.write_text(patientInfo)

    output_json_path = work_dir / "result.json"

    matlab_cmd = (
        f"run_pipeline_api('{_escape(str(image_path))}', "
        f"'{_escape(str(patient_info_path))}', '{_escape(str(output_json_path))}')"
    )

    try:
        proc = subprocess.run(
            [MATLAB_EXE, "-batch", matlab_cmd],
            cwd=str(REPO_ROOT),
            capture_output=True,
            text=True,
            timeout=MATLAB_TIMEOUT_SECONDS,
        )
    except subprocess.TimeoutExpired:
        raise HTTPException(status_code=504, detail="Pipeline timed out")

    if not output_json_path.exists():
        raise HTTPException(
            status_code=500,
            detail=f"Pipeline produced no result. stdout: {proc.stdout[-2000:]} stderr: {proc.stderr[-2000:]}",
        )

    result = json.loads(output_json_path.read_text())
    if result.get("status") == "ERROR":
        raise HTTPException(status_code=500, detail=result.get("errorMessage", "Unknown pipeline error"))

    result["requestId"] = request_id
    return result


@app.get("/api/report/{request_id}")
async def get_report(request_id: str):
    """Fetch the annotated PDF report for a previous /api/screen call."""
    work_dir = RESULTS_DIR / request_id
    result_path = work_dir / "result.json"
    if not result_path.exists():
        raise HTTPException(status_code=404, detail="Unknown request id")
    result = json.loads(result_path.read_text())
    report_file_name = result.get("reportFileName")
    if not report_file_name:
        raise HTTPException(status_code=404, detail="No report for this request (image was rejected at quality check)")
    report_path = REPO_ROOT / "results" / report_file_name
    if not report_path.exists():
        raise HTTPException(status_code=404, detail="Report file not found on disk")
    return FileResponse(report_path, media_type="application/pdf", filename=report_file_name)


def _escape(s: str) -> str:
    """Escape single quotes for embedding into a MATLAB single-quoted string literal."""
    return s.replace("'", "''")
