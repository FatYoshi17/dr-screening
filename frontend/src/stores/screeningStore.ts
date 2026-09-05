import { create } from 'zustand';
import type {
  PatientRecord,
  ScreeningWorkflowState,
  ScreeningResultCategory,
  QualityStatus,
  ScreeningRecord
} from '../types';

interface ScreeningSessionState {
  patient: PatientRecord | null;
  eye: 'RIGHT' | 'LEFT';
  imageUri: string | null;
  imageKey: string | null;
  qualityStatus: QualityStatus | null;
  qualityReason: string | null;
  qualityTip: string | null;
  workflowState: ScreeningWorkflowState;
  resultCategory: ScreeningResultCategory | null;
  resultRecommendation: string | null;
  aiDetails: ScreeningRecord['aiDetails'] | null;

  // Actions
  startScreening: (patient: PatientRecord) => void;
  setEye: (eye: 'RIGHT' | 'LEFT') => void;
  setImage: (uri: string, key?: string) => void;
  setQualityResult: (status: QualityStatus, reason?: string, tip?: string) => void;
  setScreeningResult: (
    category: ScreeningResultCategory,
    recommendation: string,
    aiDetails?: ScreeningRecord['aiDetails']
  ) => void;
  setWorkflowState: (state: ScreeningWorkflowState) => void;
  resetScreening: () => void;
}

export const useScreeningStore = create<ScreeningSessionState>((set) => ({
  patient: null,
  eye: 'RIGHT',
  imageUri: null,
  imageKey: null,
  qualityStatus: null,
  qualityReason: null,
  qualityTip: null,
  workflowState: 'DRAFT',
  resultCategory: null,
  resultRecommendation: null,
  aiDetails: null,

  startScreening: (patient) =>
    set({
      patient,
      eye: 'RIGHT',
      imageUri: null,
      imageKey: null,
      qualityStatus: null,
      qualityReason: null,
      qualityTip: null,
      workflowState: 'DRAFT',
      resultCategory: null,
      resultRecommendation: null,
      aiDetails: null,
    }),

  setEye: (eye) => set({ eye }),

  setImage: (uri, key) =>
    set({
      imageUri: uri,
      imageKey: key || 'custom-capture',
      workflowState: 'CAPTURED',
    }),

  setQualityResult: (status, reason, tip) =>
    set({
      qualityStatus: status,
      qualityReason: reason || null,
      qualityTip: tip || null,
      workflowState: status === 'PASS' ? 'QUALITY_PASSED' : 'RETAKE_REQUIRED',
    }),

  setScreeningResult: (category, recommendation, aiDetails) =>
    set({
      resultCategory: category,
      resultRecommendation: recommendation,
      aiDetails: aiDetails || null,
      workflowState: 'COMPLETED',
    }),

  setWorkflowState: (state) => set({ workflowState: state }),

  resetScreening: () =>
    set({
      patient: null,
      eye: 'RIGHT',
      imageUri: null,
      imageKey: null,
      qualityStatus: null,
      qualityReason: null,
      qualityTip: null,
      workflowState: 'DRAFT',
      resultCategory: null,
      resultRecommendation: null,
      aiDetails: null,
    }),
}));
