import Dexie, { type Table } from 'dexie';
import type { PatientRecord, ScreeningRecord, PendingUploadRecord, ReferralRecord } from '../types';

export class DrishtiSetuDB extends Dexie {
  patients!: Table<PatientRecord, string>;
  screenings!: Table<ScreeningRecord, string>;
  pendingUploads!: Table<PendingUploadRecord, string>;
  referrals!: Table<ReferralRecord, string>;

  constructor() {
    super('DrishtiSetuDB');
    this.version(1).stores({
      patients: 'id, name, village, phone, createdAt, lastScreeningDate',
      screenings: 'id, patientId, workflowState, resultCategory, createdAt, synced',
      pendingUploads: 'id, screeningId, patientId, syncStatus, retryCount, capturedAt',
      referrals: 'id, screeningId, patientId, priority, status, createdAt',
    });
  }
}

export const db = new DrishtiSetuDB();

// Initial Mock Seed Data for SIH demonstration
export async function initializeDatabaseSeed() {
  const patientCount = await db.patients.count();
  if (patientCount > 0) return; // Already seeded

  const demoPatients: PatientRecord[] = [
    {
      id: 'DR-2026-01842',
      name: 'Kamla Devi',
      age: 58,
      sex: 'Female',
      village: 'Rampur',
      phone: '9876543210',
      diabetesStatus: 'KNOWN_DIABETES',
      createdAt: '2026-08-28T09:30:00Z',
      lastScreeningDate: '2026-09-03T10:15:00Z',
      lastResult: 'REVIEW'
    },
    {
      id: 'DR-2026-01843',
      name: 'Ram Prasad Sharma',
      age: 64,
      sex: 'Male',
      village: 'Kalyanpur',
      phone: '9812345678',
      diabetesStatus: 'KNOWN_DIABETES',
      createdAt: '2026-08-30T11:20:00Z',
      lastScreeningDate: '2026-09-04T09:45:00Z',
      lastResult: 'PRIORITY'
    },
    {
      id: 'DR-2026-01844',
      name: 'Geeta Bai',
      age: 49,
      sex: 'Female',
      village: 'Fatehpur',
      phone: '9988776655',
      diabetesStatus: 'RECENTLY_DIAGNOSED',
      createdAt: '2026-09-01T08:15:00Z',
      lastScreeningDate: '2026-09-02T14:30:00Z',
      lastResult: 'ROUTINE'
    },
    {
      id: 'DR-2026-01845',
      name: 'Mohan Lal Verma',
      age: 52,
      sex: 'Male',
      village: 'Rampur',
      phone: '9765432109',
      diabetesStatus: 'SUSPECTED',
      createdAt: '2026-09-02T10:00:00Z',
      lastScreeningDate: undefined,
      lastResult: undefined
    }
  ];

  await db.patients.bulkAdd(demoPatients);

  const demoScreenings: ScreeningRecord[] = [
    {
      id: 'SCR-2026-09101',
      patientId: 'DR-2026-01842',
      eye: 'RIGHT',
      imageUri: '/src/assets/demo/fundus-review.jpg',
      imageKey: 'fundus-review',
      qualityStatus: 'PASS',
      workflowState: 'REFERRED',
      resultCategory: 'REVIEW',
      resultRecommendation: 'Specialist review recommended. Moderate microvascular lesions noted in perifoveal area.',
      createdAt: '2026-09-03T10:15:00Z',
      synced: true,
      centreName: 'Rampur Primary Health Centre',
      healthWorkerName: 'Suman ASHA',
      isDemoSample: true,
      aiDetails: {
        modelVersion: 'DrishtiNet-v2.1-Rural',
        decisionSupportText: 'Microaneurysms and hard exudates detected in upper temporal quadrant.',
        confidenceIndicator: 'Moderate',
        findings: ['Microaneurysms (3-5 foci)', 'Hard Exudates (<500μm from fovea)', 'Vasculature caliber normal'],
        explainabilityBox: { x: 55, y: 35, width: 25, height: 30 },
        timestamp: '2026-09-03T10:15:24Z'
      }
    },
    {
      id: 'SCR-2026-09102',
      patientId: 'DR-2026-01843',
      eye: 'LEFT',
      imageUri: '/src/assets/demo/fundus-priority.jpg',
      imageKey: 'fundus-priority',
      qualityStatus: 'PASS',
      workflowState: 'REFERRED',
      resultCategory: 'PRIORITY',
      resultRecommendation: 'Immediate priority specialist evaluation recommended. Widespread blot hemorrhages and cotton-wool patches observed.',
      createdAt: '2026-09-04T09:45:00Z',
      synced: true,
      centreName: 'Rampur Primary Health Centre',
      healthWorkerName: 'Suman ASHA',
      isDemoSample: true,
      aiDetails: {
        modelVersion: 'DrishtiNet-v2.1-Rural',
        decisionSupportText: 'High density retinal hemorrhages with macular threat requiring expedited tertiary referral.',
        confidenceIndicator: 'High',
        findings: ['Extensive blot hemorrhages in all 4 quadrants', 'Macular hard exudate ring', 'Neovascularization suspicious near optic disc'],
        explainabilityBox: { x: 30, y: 25, width: 45, height: 50 },
        timestamp: '2026-09-04T09:45:18Z'
      }
    },
    {
      id: 'SCR-2026-09103',
      patientId: 'DR-2026-01844',
      eye: 'RIGHT',
      imageUri: '/src/assets/demo/fundus-good.jpg',
      imageKey: 'fundus-good',
      qualityStatus: 'PASS',
      workflowState: 'COMPLETED',
      resultCategory: 'ROUTINE',
      resultRecommendation: 'No concerning retinal abnormalities detected. Patient advised to maintain glycemic control and return in 12 months for routine screening.',
      createdAt: '2026-09-02T14:30:00Z',
      synced: true,
      centreName: 'Rampur Primary Health Centre',
      healthWorkerName: 'Suman ASHA',
      isDemoSample: true,
      aiDetails: {
        modelVersion: 'DrishtiNet-v2.1-Rural',
        decisionSupportText: 'Normal retinal vasculature and clear foveal avascular zone.',
        confidenceIndicator: 'High',
        findings: ['Normal optic nerve cup-to-disc ratio (0.3)', 'Clear macula without exudate', 'Healthy arteriolar branching'],
        timestamp: '2026-09-02T14:30:12Z'
      }
    }
  ];

  await db.screenings.bulkAdd(demoScreenings);

  const demoReferrals: ReferralRecord[] = [
    {
      id: 'REF-2026-00142',
      screeningId: 'SCR-2026-09101',
      patientId: 'DR-2026-01842',
      patientName: 'Kamla Devi',
      patientAge: 58,
      patientSex: 'Female',
      village: 'Rampur',
      priority: 'REVIEW',
      eye: 'RIGHT',
      imageUri: '/src/assets/demo/fundus-review.jpg',
      specialistCentre: 'District Hospital Ophthalmology Ward',
      referralReason: 'Diabetic retinopathy screening flagged for specialist review (microaneurysms detected).',
      healthWorkerNotes: 'Patient has had type 2 diabetes for 7 years. Complaining of occasional blurriness in right eye.',
      status: 'WAITING_FOR_SPECIALIST',
      createdAt: '2026-09-03T10:20:00Z'
    },
    {
      id: 'REF-2026-00143',
      screeningId: 'SCR-2026-09102',
      patientId: 'DR-2026-01843',
      patientName: 'Ram Prasad Sharma',
      patientAge: 64,
      patientSex: 'Male',
      village: 'Kalyanpur',
      priority: 'PRIORITY',
      eye: 'LEFT',
      imageUri: '/src/assets/demo/fundus-priority.jpg',
      specialistCentre: 'District Hospital Ophthalmology Ward',
      referralReason: 'Urgent priority referral: Extensive retinal hemorrhages and macular exudates.',
      healthWorkerNotes: 'Patient reports rapid reduction in central vision over past 3 weeks. Fast-track requested.',
      status: 'WAITING_FOR_SPECIALIST',
      createdAt: '2026-09-04T09:50:00Z'
    }
  ];

  await db.referrals.bulkAdd(demoReferrals);
}
