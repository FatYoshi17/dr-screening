import { create } from 'zustand';
import { db } from '../offline/db';
import type { ConnectivityOverride } from '../types';

interface ConnectivityState {
  realOnline: boolean;
  demoOverride: ConnectivityOverride;
  isOnline: boolean;
  isSyncing: boolean;
  pendingCount: number;
  setDemoOverride: (mode: ConnectivityOverride) => void;
  refreshPendingCount: () => Promise<number>;
  syncPendingQueue: () => Promise<void>;
  initListeners: () => () => void;
}

export const useConnectivityStore = create<ConnectivityState>((set, get) => ({
  realOnline: typeof window !== 'undefined' ? window.navigator.onLine : true,
  demoOverride: 'AUTO',
  isOnline: typeof window !== 'undefined' ? window.navigator.onLine : true,
  isSyncing: false,
  pendingCount: 0,

  setDemoOverride: (mode: ConnectivityOverride) => {
    const real = get().realOnline;
    let effectiveOnline = real;
    let syncing = false;

    if (mode === 'FORCE_ONLINE') {
      effectiveOnline = true;
    } else if (mode === 'FORCE_OFFLINE') {
      effectiveOnline = false;
    } else if (mode === 'FORCE_SYNCING') {
      effectiveOnline = true;
      syncing = true;
    }

    set({ demoOverride: mode, isOnline: effectiveOnline, isSyncing: syncing });

    // If switched to online and has pending items, auto-trigger sync!
    if (effectiveOnline && get().pendingCount > 0) {
      get().syncPendingQueue();
    }
  },

  refreshPendingCount: async () => {
    try {
      const count = await db.pendingUploads.where('syncStatus').notEqual('SYNCED').count();
      set({ pendingCount: count });
      return count;
    } catch {
      return 0;
    }
  },

  syncPendingQueue: async () => {
    const { isOnline, isSyncing } = get();
    if (!isOnline || isSyncing) return;

    set({ isSyncing: true });

    try {
      const pendingItems = await db.pendingUploads.where('syncStatus').notEqual('SYNCED').toArray();
      if (pendingItems.length === 0) {
        set({ isSyncing: false, pendingCount: 0 });
        return;
      }

      for (const item of pendingItems) {
        // Step 1: Mark UPLOADING
        await db.pendingUploads.update(item.id, { syncStatus: 'UPLOADING' });
        // Simulate low-bandwidth transfer delay (800ms)
        await new Promise((res) => setTimeout(res, 800));

        // Step 2: Mark PROCESSING / SYNCED
        await db.pendingUploads.update(item.id, {
          syncStatus: 'SYNCED',
          lastAttemptAt: new Date().toISOString()
        });

        // Update screening record in DB
        await db.screenings.update(item.screeningId, {
          synced: true,
          workflowState: 'COMPLETED'
        });
      }

      // Refresh count
      const remaining = await db.pendingUploads.where('syncStatus').notEqual('SYNCED').count();
      set({ isSyncing: false, pendingCount: remaining });
    } catch (e) {
      console.error('Sync failed', e);
      set({ isSyncing: false });
    }
  },

  initListeners: () => {
    const handleOnline = () => {
      set({ realOnline: true });
      if (get().demoOverride === 'AUTO') {
        set({ isOnline: true });
        get().syncPendingQueue();
      }
    };

    const handleOffline = () => {
      set({ realOnline: false });
      if (get().demoOverride === 'AUTO') {
        set({ isOnline: false });
      }
    };

    window.addEventListener('online', handleOnline);
    window.addEventListener('offline', handleOffline);

    // Initial count
    get().refreshPendingCount();

    return () => {
      window.removeEventListener('online', handleOnline);
      window.removeEventListener('offline', handleOffline);
    };
  }
}));
