import { db } from '../offline/db';
import type { ReferralRecord, ScreeningRecord, PatientRecord } from '../types';

export interface SpecialistCaseDetails {
  referral: ReferralRecord;
  screening: ScreeningRecord;
  patient: PatientRecord;
  history: ScreeningRecord[];
}

export const specialistService = {
  async getTriageCases(): Promise<ReferralRecord[]> {
    const all = await db.referrals.reverse().sortBy('createdAt');
    // Sort Priority cases to the top, then Review, then Routine
    return all.sort((a, b) => {
      const priorityWeight: Record<string, number> = { PRIORITY: 3, REVIEW: 2, ROUTINE: 1 };
      const weightA = priorityWeight[a.priority] || 0;
      const weightB = priorityWeight[b.priority] || 0;
      return weightB - weightA;
    });
  },

  async getCaseDetails(referralId: string): Promise<SpecialistCaseDetails | null> {
    const referral = await db.referrals.get(referralId);
    if (!referral) return null;

    const [screening, patient, history] = await Promise.all([
      db.screenings.get(referral.screeningId),
      db.patients.get(referral.patientId),
      db.screenings.where('patientId').equals(referral.patientId).reverse().sortBy('createdAt')
    ]);

    if (!screening || !patient) return null;

    return {
      referral,
      screening,
      patient,
      history
    };
  },

  async submitReview(
    referralId: string,
    decision: ReferralRecord['specialistDecision'],
    notes: string,
    specialistName: string
  ): Promise<void> {
    const referral = await db.referrals.get(referralId);
    if (!referral) return;

    await db.referrals.update(referralId, {
      status: 'REVIEW_COMPLETED',
      specialistDecision: decision,
      specialistNotes: notes,
      reviewedBy: specialistName,
      reviewedAt: new Date().toISOString()
    });

    await db.screenings.update(referral.screeningId, {
      workflowState: 'SPECIALIST_REVIEWED'
    });
  }
};
