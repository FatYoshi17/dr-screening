import { db } from '../offline/db';
import type { PatientRecord } from '../types';

export const patientService = {
  async searchPatients(query: string): Promise<PatientRecord[]> {
    const q = query.trim().toLowerCase();
    if (!q) {
      return db.patients.reverse().toArray();
    }

    return db.patients
      .filter((p) => {
        const matchName = p.name.toLowerCase().includes(q);
        const matchId = p.id.toLowerCase().includes(q);
        const matchPhone = p.phone ? p.phone.includes(q) : false;
        const matchVillage = p.village.toLowerCase().includes(q);
        return matchName || matchId || matchPhone || matchVillage;
      })
      .toArray();
  },

  async getPatientById(id: string): Promise<PatientRecord | undefined> {
    return db.patients.get(id);
  },

  async registerPatient(data: Omit<PatientRecord, 'id' | 'createdAt'>): Promise<PatientRecord> {
    const count = await db.patients.count();
    const id = `DR-2026-${String(count + 1845).padStart(5, '0')}`;
    const newPatient: PatientRecord = {
      ...data,
      id,
      createdAt: new Date().toISOString(),
    };

    await db.patients.add(newPatient);
    return newPatient;
  },

  async updatePatientLastScreening(patientId: string, resultCategory: PatientRecord['lastResult']): Promise<void> {
    await db.patients.update(patientId, {
      lastScreeningDate: new Date().toISOString(),
      lastResult: resultCategory
    });
  }
};
