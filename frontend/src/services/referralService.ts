import { db } from '../offline/db';
import type { ReferralRecord } from '../types';

export const referralService = {
  async createReferral(data: Omit<ReferralRecord, 'id' | 'createdAt' | 'status'>): Promise<ReferralRecord> {
    const count = await db.referrals.count();
    const id = `REF-2026-${String(count + 144).padStart(5, '0')}`;
    const newReferral: ReferralRecord = {
      ...data,
      id,
      status: 'WAITING_FOR_SPECIALIST',
      createdAt: new Date().toISOString()
    };

    await db.referrals.add(newReferral);

    // Also update screening state to REFERRED
    await db.screenings.update(data.screeningId, {
      workflowState: 'REFERRED'
    });

    return newReferral;
  },

  async getReferrals(statusFilter?: ReferralRecord['status']): Promise<ReferralRecord[]> {
    if (statusFilter) {
      return db.referrals.where('status').equals(statusFilter).reverse().sortBy('createdAt');
    }
    return db.referrals.reverse().sortBy('createdAt');
  },

  async getReferralById(id: string): Promise<ReferralRecord | undefined> {
    return db.referrals.get(id);
  }
};
