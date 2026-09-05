import { db } from '../offline/db';
import type { ScreeningRecord, PatientRecord, PendingUploadRecord } from '../types';

export const uploadService = {
  /**
   * Compresses image on client side using HTML Canvas to reduce payload on 2G/3G connections.
   */
  async compressImage(dataUrl: string, maxWidth = 1024, quality = 0.82): Promise<string> {
    return new Promise((resolve) => {
      // If it's a static asset path, no compression needed
      if (dataUrl.startsWith('/') || dataUrl.startsWith('http')) {
        return resolve(dataUrl);
      }

      const img = new Image();
      img.src = dataUrl;
      img.onload = () => {
        const canvas = document.createElement('canvas');
        let width = img.width;
        let height = img.height;

        if (width > maxWidth) {
          height = Math.round((height * maxWidth) / width);
          width = maxWidth;
        }

        canvas.width = width;
        canvas.height = height;
        const ctx = canvas.getContext('2d');
        if (!ctx) return resolve(dataUrl);

        ctx.drawImage(img, 0, 0, width, height);
        resolve(canvas.toDataURL('image/jpeg', quality));
      };
      img.onerror = () => resolve(dataUrl);
    });
  },

  async queueForUpload(screening: ScreeningRecord, patient: PatientRecord): Promise<PendingUploadRecord> {
    const queueItem: PendingUploadRecord = {
      id: `QUEUE-${Date.now()}-${Math.floor(Math.random() * 1000)}`,
      screeningId: screening.id,
      patientId: patient.id,
      patientName: patient.name,
      eye: screening.eye,
      imageUri: screening.imageUri,
      capturedAt: screening.createdAt,
      syncStatus: 'QUEUED',
      retryCount: 0
    };

    await db.pendingUploads.add(queueItem);
    return queueItem;
  },

  async getPendingUploads(): Promise<PendingUploadRecord[]> {
    return db.pendingUploads.where('syncStatus').notEqual('SYNCED').toArray();
  },

  async removeSyncedUpload(id: string): Promise<void> {
    await db.pendingUploads.delete(id);
  }
};
