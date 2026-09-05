import { db } from '../offline/db';
import type {
  ScreeningRecord,
  ScreeningResultCategory,
  QualityStatus,
  QualityFeature,
  LesionFinding,
  SeverityAssessment,
  Explainability
} from '../types';
import { dxApiClient, type PatientContext, type DxApiResult } from './dxApiClient';

export const DEMO_KEYS = ['fundus-good', 'fundus-poor-blur', 'fundus-poor-dark', 'fundus-priority', 'fundus-review'];

// Real captures need exactly one MATLAB pipeline invocation per image, not
// two (quality check, then full analysis). The quality step below runs the
// real backend and caches the full result here; analyzeScreening reuses it
// instead of calling again, keyed on the same imageDataUrl.
let cachedRealResult: { imageDataUrl: string; result: DxApiResult } | null = null;

async function runRealPipelineOnce(imageDataUrl: string, patientContext?: PatientContext): Promise<DxApiResult> {
  if (cachedRealResult && cachedRealResult.imageDataUrl === imageDataUrl) {
    return cachedRealResult.result;
  }
  const result = await dxApiClient.screen(imageDataUrl, patientContext || {});
  cachedRealResult = { imageDataUrl, result };
  return result;
}

export const screeningService = {
  async evaluateImageQuality(
    imageKey?: string,
    imageDataUrl?: string,
    patientContext?: PatientContext
  ): Promise<{
    status: QualityStatus;
    reason?: string;
    tip?: string;
  }> {
    // Real captures: actually run the pipeline's quality gate (Module 1)
    // instead of assuming a pass - a photo that isn't even a fundus image
    // (wrong body part, wrong framing) must not be told it "looks good".
    // The result is cached so the later analyzeScreening call for the same
    // image reuses it rather than invoking MATLAB a second time.
    if (imageDataUrl && (!imageKey || !DEMO_KEYS.includes(imageKey))) {
      try {
        const result = await runRealPipelineOnce(imageDataUrl, patientContext);
        if (result.qualityStatus === 'FAIL') {
          return {
            status: 'FAIL',
            reason: result.qualityReason || 'Image quality is insufficient for reliable screening.',
            tip: 'Retake the photo with the retina centered, well lit, and in focus.'
          };
        }
        return {
          status: 'PASS',
          reason: result.qualityReason
        };
      } catch {
        // Backend unreachable - do not claim a check that never ran.
        return {
          status: 'FAIL',
          reason: 'Could not verify image quality (screening service unavailable).',
          tip: 'Check your connection to the screening backend and try again.'
        };
      }
    }
    // Deterministic evaluation for SIH demo reliability
    if (imageKey === 'fundus-poor-dark') {
      return {
        status: 'FAIL',
        reason: 'The image appears too dark. Retinal blood vessels are obscured by inadequate illumination.',
        tip: 'Adjust the camera light output and ensure patient is seated in a dim environment.'
      };
    }
    if (imageKey === 'fundus-poor-blur') {
      return {
        status: 'FAIL',
        reason: 'The image appears blurred. Motion blur or optical defocus detected across the macula.',
        tip: 'Ask the patient to keep still, hold the camera steady, and refocus on the optic disc.'
      };
    }
    return {
      status: 'PASS',
      reason: 'Retina, optic disc, and blood vessels are clearly visible for screening.'
    };
  },

  async analyzeScreening(
    imageKey: string | undefined,
    _eye: 'RIGHT' | 'LEFT',
    imageDataUrl?: string,
    patientContext?: PatientContext
  ): Promise<{
    resultCategory: ScreeningResultCategory;
    recommendation: string;
    aiDetails?: ScreeningRecord['aiDetails'];
    requestId?: string;
    // Real-pipeline-only fields (undefined for demo scenarios): the
    // actual data ReportPage.tsx needs to render a real report instead
    // of falling back to its own hardcoded demo findings/severity.
    qualityFeatures?: QualityFeature[];
    findings?: LesionFinding[];
    severity?: SeverityAssessment;
    explainability?: Explainability;
    segmentationImageUrl?: string;
    gradCamImageUrl?: string;
  }> {
    // Real capture (not one of the bundled demo assets): reuse the result
    // from the quality step's real pipeline call if it already ran for
    // this exact image, instead of invoking MATLAB a second time.
    if (imageDataUrl && (!imageKey || !DEMO_KEYS.includes(imageKey))) {
      const result = await runRealPipelineOnce(imageDataUrl, patientContext);
      const confidenceIndicator =
        result.explainability?.reliabilityCategory === 'Reliable' ? 'High'
        : result.explainability?.reliabilityCategory === 'Moderate' ? 'Moderate'
        : 'Borderline';
      return {
        resultCategory: result.resultCategory,
        recommendation: result.resultRecommendation,
        requestId: result.requestId,
        qualityFeatures: result.qualityFeatures,
        findings: result.findings?.map((f) => ({
          lesionType: f.lesionType,
          count: f.count,
          confidence: f.confidence
        })),
        severity: result.severity,
        explainability: result.explainability,
        segmentationImageUrl: result.requestId ? dxApiClient.segmentationImageUrl(result.requestId) : undefined,
        gradCamImageUrl: result.requestId ? dxApiClient.gradCamImageUrl(result.requestId) : undefined,
        aiDetails: {
          modelVersion: 'DR-Screening-Pipeline-v1 (CBAM)',
          decisionSupportText: result.explainability?.flagReason
            || (result.severity ? `${result.severity.gradeLabel} (Grade ${result.severity.icdrGrade})` : result.qualityReason || ''),
          confidenceIndicator,
          findings: (result.findings || []).map(
            (f) => `${f.lesionType}${f.count > 1 ? ` (${f.count})` : ''}`
          ),
          timestamp: new Date().toISOString()
        }
      };
    }

    // Deterministic demo scenarios based on image
    if (imageKey === 'fundus-priority') {
      return {
        resultCategory: 'PRIORITY',
        recommendation: 'Priority specialist evaluation recommended within 1-2 weeks. Widespread blot hemorrhages and hard exudates.',
        aiDetails: {
          modelVersion: 'DrishtiNet-v2.1-Rural',
          decisionSupportText: 'High probability of severe diabetic retinopathy. Immediate tertiary consultation recommended.',
          confidenceIndicator: 'High',
          findings: ['Extensive blot and flame hemorrhages in all quadrants', 'Clinically significant macular edema suspicion', 'Neovascular proliferation near disc'],
          explainabilityBox: { x: 30, y: 25, width: 45, height: 50 },
          timestamp: new Date().toISOString()
        }
      };
    }

    if (imageKey === 'fundus-review') {
      return {
        resultCategory: 'REVIEW',
        recommendation: 'Specialist review recommended. Microaneurysms and early microvascular abnormalities detected.',
        aiDetails: {
          modelVersion: 'DrishtiNet-v2.1-Rural',
          decisionSupportText: 'Features consistent with non-proliferative diabetic retinopathy. Remote ophthalmologist confirmation suggested.',
          confidenceIndicator: 'Moderate',
          findings: ['Isolated microaneurysms (< 5 visible)', 'Small hard exudates outside central fovea', 'Mild venous dilation'],
          explainabilityBox: { x: 55, y: 35, width: 25, height: 30 },
          timestamp: new Date().toISOString()
        }
      };
    }

    if (imageKey === 'fundus-poor-dark' || imageKey === 'fundus-poor-blur') {
      return {
        resultCategory: 'RETAKE',
        recommendation: 'Image quality is insufficient to evaluate retinal health. Capture again.',
        aiDetails: {
          modelVersion: 'DrishtiNet-v2.1-Rural',
          decisionSupportText: 'Retake required due to optical degradation.',
          confidenceIndicator: 'Borderline',
          findings: ['Unacceptable signal-to-noise ratio', 'Optic disc boundaries indistinct'],
          timestamp: new Date().toISOString()
        }
      };
    }

    // Default healthy / routine
    return {
      resultCategory: 'ROUTINE',
      recommendation: 'No concerning retinal abnormality detected during screening. Continue annual screening follow-up.',
      aiDetails: {
        modelVersion: 'DrishtiNet-v2.1-Rural',
        decisionSupportText: 'Retina appears within normal limits for diabetic screening protocol.',
        confidenceIndicator: 'High',
        findings: ['Clear optic nerve head', 'Normal retinal arterioles and venules', 'Intact macular reflex'],
        timestamp: new Date().toISOString()
      }
    };
  },

  async saveScreening(record: Omit<ScreeningRecord, 'id' | 'createdAt'>): Promise<ScreeningRecord> {
    const count = await db.screenings.count();
    const id = `SCR-2026-${String(count + 9104).padStart(5, '0')}`;
    const newScreening: ScreeningRecord = {
      ...record,
      id,
      createdAt: new Date().toISOString()
    };

    await db.screenings.add(newScreening);
    return newScreening;
  },

  async getScreeningsForPatient(patientId: string): Promise<ScreeningRecord[]> {
    return db.screenings
      .where('patientId')
      .equals(patientId)
      .reverse()
      .sortBy('createdAt');
  },

  async getScreeningById(id: string): Promise<ScreeningRecord | undefined> {
    return db.screenings.get(id);
  }
};
