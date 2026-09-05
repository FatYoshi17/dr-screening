// Real backend client for the MATLAB DR-screening pipeline (backend/main.py
// in the dr-screening repo). Only real (non-demo) captures go through
// this - the four bundled demo assets keep their deterministic scripted
// responses in screeningService.ts for fast, offline-safe demoing.

const API_BASE = 'http://localhost:8000';

export interface PatientContext {
  diabetesControl?: 'Controlled' | 'Uncontrolled';
  diabetesDurationYears?: number;
  hba1c?: number;
  patientId?: string;
}

export interface DxApiResult {
  status: 'GRADED' | 'REJECTED' | 'ERROR';
  requestId?: string;
  qualityStatus: 'PASS' | 'FAIL';
  qualityReason?: string;
  qualityFeatures?: Array<{ name: string; score: number; assessment: 'Good' | 'Acceptable' | 'Poor' }>;
  findings?: Array<{ lesionType: string; count: number; confidence: number }>;
  severity?: {
    icdrGrade: number;
    gradeLabel: string;
    referable: boolean;
    gradingPathway: 'rule-based' | 'cnn';
    agreement: boolean;
  };
  explainability?: {
    calibratedConfidence: number;
    reliabilityCategory: 'Reliable' | 'Moderate' | 'Low';
    lesionAttentionOverlap: number;
    flagged: boolean;
    flagReason: string;
  };
  resultCategory: 'ROUTINE' | 'REVIEW' | 'PRIORITY' | 'RETAKE';
  resultRecommendation: string;
  reportFileName?: string;
  segmentationImageFileName?: string;
  gradCamImageFileName?: string;
}

export interface QualityCheckResult {
  qualityStatus: 'PASS' | 'FAIL';
  qualityReason?: string;
  qualityFeatures?: Array<{ name: string; score: number; assessment: 'Good' | 'Acceptable' | 'Poor' }>;
}

async function dataUrlToBlob(dataUrl: string): Promise<Blob> {
  const res = await fetch(dataUrl);
  return res.blob();
}

export const dxApiClient = {
  /** Fast path for the Quality Verification screen: Module 1 (quality gate) only, not the full grading pipeline - seconds instead of the ~20-40s a full /api/screen call takes. */
  async checkQuality(imageDataUrl: string): Promise<QualityCheckResult> {
    const blob = await dataUrlToBlob(imageDataUrl);
    const formData = new FormData();
    formData.append('image', blob, 'capture.jpg');

    const response = await fetch(`${API_BASE}/api/quality-check`, {
      method: 'POST',
      body: formData
    });

    if (!response.ok) {
      const detail = await response.text();
      throw new Error(`Quality-check backend error (${response.status}): ${detail}`);
    }
    return response.json();
  },

  /** Runs the full pipeline (quality + segmentation + grading + explainability) on a captured/uploaded image. imageDataUrl must be a data: URL (from canvas/file capture), not a static asset path. */
  async screen(imageDataUrl: string, patientContext: PatientContext): Promise<DxApiResult> {
    const blob = await dataUrlToBlob(imageDataUrl);
    const formData = new FormData();
    formData.append('image', blob, 'capture.jpg');
    formData.append('patientInfo', JSON.stringify(patientContext));

    const response = await fetch(`${API_BASE}/api/screen`, {
      method: 'POST',
      body: formData
    });

    if (!response.ok) {
      const detail = await response.text();
      throw new Error(`Screening backend error (${response.status}): ${detail}`);
    }
    return response.json();
  },

  reportUrl(requestId: string): string {
    return `${API_BASE}/api/report/${requestId}`;
  },

  segmentationImageUrl(requestId: string): string {
    return `${API_BASE}/api/image/${requestId}/segmentation`;
  },

  gradCamImageUrl(requestId: string): string {
    return `${API_BASE}/api/image/${requestId}/gradcam`;
  }
};
