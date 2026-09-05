import React, { useEffect, useState } from 'react';
import { X, Wifi, WifiOff, RefreshCw, CheckCircle2, Clock, Smartphone } from 'lucide-react';
import { useTranslation } from 'react-i18next';
import { useConnectivityStore } from '../../stores/connectivityStore';
import { db } from '../../offline/db';
import type { PendingUploadRecord, ConnectivityOverride } from '../../types';

interface OfflineQueueModalProps {
  isOpen: boolean;
  onClose: () => void;
}

export const OfflineQueueModal: React.FC<OfflineQueueModalProps> = ({ isOpen, onClose }) => {
  const { t } = useTranslation();
  const {
    isOnline,
    isSyncing,
    demoOverride,
    pendingCount,
    setDemoOverride,
    syncPendingQueue,
  } = useConnectivityStore();

  const [pendingItems, setPendingItems] = useState<PendingUploadRecord[]>([]);

  const loadItems = async () => {
    const items = await db.pendingUploads.where('syncStatus').notEqual('SYNCED').toArray();
    setPendingItems(items);
  };

  useEffect(() => {
    if (isOpen) {
      loadItems();
    }
  }, [isOpen, pendingCount, isSyncing]);

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 bg-slate-900/60 backdrop-blur-xs flex items-center justify-center p-4">
      <div className="bg-white w-full max-w-md rounded-2xl shadow-xl border border-slate-200 overflow-hidden flex flex-col max-h-[90vh]">
        {/* Header */}
        <div className="p-4 border-b border-slate-200 flex items-center justify-between bg-slate-50">
          <div className="flex items-center gap-2.5">
            {isOnline ? (
              <Wifi className="w-5 h-5 text-emerald-600" />
            ) : (
              <WifiOff className="w-5 h-5 text-amber-600" />
            )}
            <h2 className="text-base font-bold text-slate-900">
              {t('dashboard.pendingUploads')}
            </h2>
          </div>
          <button
            type="button"
            onClick={onClose}
            className="p-1.5 rounded-lg text-slate-500 hover:text-slate-800 hover:bg-slate-200/60 transition-colors"
            aria-label="Close"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Content */}
        <div className="p-4 overflow-y-auto space-y-4 flex-1">
          {/* Status summary banner */}
          <div
            className={`p-3 rounded-xl border flex items-center justify-between ${
              isOnline
                ? 'bg-emerald-50 border-emerald-200 text-emerald-900'
                : 'bg-amber-50 border-amber-200 text-amber-900'
            }`}
          >
            <div className="flex items-center gap-2 text-sm font-medium">
              <span className={`w-2.5 h-2.5 rounded-full ${isOnline ? 'bg-emerald-500' : 'bg-amber-500'}`} />
              <span>
                {isOnline
                  ? isSyncing
                    ? t('app.syncing')
                    : `${t('app.online')} • ${pendingCount === 0 ? t('dashboard.allSynced') : `${pendingCount} ${t('app.waitingUpload')}`}`
                  : `${t('app.offline')} • ${pendingCount} ${t('app.waitingUpload')}`}
              </span>
            </div>

            {isOnline && pendingCount > 0 && (
              <button
                type="button"
                onClick={syncPendingQueue}
                disabled={isSyncing}
                className="px-3 py-1 text-xs font-semibold rounded-lg bg-brand-700 text-white hover:bg-brand-800 disabled:opacity-50 inline-flex items-center gap-1.5 cursor-pointer"
              >
                <RefreshCw className={`w-3.5 h-3.5 ${isSyncing ? 'animate-spin' : ''}`} />
                {t('app.retry')}
              </button>
            )}
          </div>

          {/* Pending items list */}
          <div className="space-y-2.5">
            <h3 className="text-xs font-bold uppercase tracking-wider text-slate-500">
              {t('dashboard.pendingUploads')} ({pendingItems.length})
            </h3>

            {pendingItems.length === 0 ? (
              <div className="py-6 text-center text-slate-500 flex flex-col items-center gap-2">
                <CheckCircle2 className="w-8 h-8 text-emerald-500" />
                <p className="text-sm">{t('dashboard.allSynced')}</p>
              </div>
            ) : (
              pendingItems.map((item) => (
                <div
                  key={item.id}
                  className="p-3 rounded-xl border border-slate-200 bg-slate-50/70 flex items-center justify-between"
                >
                  <div className="flex items-center gap-3">
                    <Clock className="w-5 h-5 text-amber-600 flex-shrink-0" />
                    <div>
                      <div className="text-sm font-semibold text-slate-900">
                        {item.patientName} ({item.patientId})
                      </div>
                      <div className="text-xs text-slate-500">
                        {item.eye === 'RIGHT' ? 'Right Eye' : 'Left Eye'} • {new Date(item.capturedAt).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                      </div>
                    </div>
                  </div>
                  <span className="text-xs px-2 py-0.5 rounded font-medium bg-amber-100 text-amber-800">
                    {item.syncStatus}
                  </span>
                </div>
              ))
            )}
          </div>

          {/* SIH Demo Mode Simulator Box */}
          <div className="mt-4 p-3.5 rounded-xl bg-teal-50/60 border border-teal-200 text-slate-800">
            <div className="flex items-center gap-2 mb-2">
              <Smartphone className="w-4 h-4 text-brand-700" />
              <span className="text-xs font-bold uppercase tracking-wider text-brand-900">
                SIH Jury Demonstration Control
              </span>
            </div>
            <p className="text-xs text-slate-600 mb-3">
              Simulate rural 2G/3G connectivity drops to evaluate offline IndexedDB persistence and auto-recovery.
            </p>

            <div className="grid grid-cols-2 gap-2">
              <button
                type="button"
                onClick={() => setDemoOverride('AUTO')}
                className={`px-3 py-2 text-xs font-semibold rounded-lg border text-center transition-colors ${
                  demoOverride === 'AUTO'
                    ? 'bg-white border-brand-700 text-brand-800 shadow-xs'
                    : 'bg-slate-100 border-slate-300 text-slate-600 hover:bg-white'
                }`}
              >
                Auto (Browser Online)
              </button>
              <button
                type="button"
                onClick={() => setDemoOverride('FORCE_OFFLINE')}
                className={`px-3 py-2 text-xs font-semibold rounded-lg border text-center transition-colors ${
                  demoOverride === 'FORCE_OFFLINE'
                    ? 'bg-amber-600 border-amber-700 text-white shadow-xs'
                    : 'bg-slate-100 border-slate-300 text-slate-600 hover:bg-white'
                }`}
              >
                Simulate Offline
              </button>
              <button
                type="button"
                onClick={() => setDemoOverride('FORCE_ONLINE')}
                className={`px-3 py-2 text-xs font-semibold rounded-lg border text-center transition-colors ${
                  demoOverride === 'FORCE_ONLINE'
                    ? 'bg-emerald-600 border-emerald-700 text-white shadow-xs'
                    : 'bg-slate-100 border-slate-300 text-slate-600 hover:bg-white'
                }`}
              >
                Restore Online
              </button>
              <button
                type="button"
                onClick={() => setDemoOverride('FORCE_SYNCING')}
                className={`px-3 py-2 text-xs font-semibold rounded-lg border text-center transition-colors ${
                  demoOverride === 'FORCE_SYNCING'
                    ? 'bg-brand-700 border-brand-800 text-white shadow-xs'
                    : 'bg-slate-100 border-slate-300 text-slate-600 hover:bg-white'
                }`}
              >
                Trigger Syncing
              </button>
            </div>
          </div>
        </div>

        {/* Footer */}
        <div className="p-3 border-t border-slate-200 bg-slate-50 flex justify-end">
          <button
            type="button"
            onClick={onClose}
            className="px-4 py-2 text-sm font-semibold text-slate-700 bg-white border border-slate-300 rounded-lg hover:bg-slate-100"
          >
            Close
          </button>
        </div>
      </div>
    </div>
  );
};
