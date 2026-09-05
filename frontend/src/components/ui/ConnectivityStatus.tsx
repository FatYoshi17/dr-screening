import React, { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { useConnectivityStore } from '../../stores/connectivityStore';
import { OfflineQueueModal } from './OfflineQueueModal';

export const ConnectivityStatus: React.FC = () => {
  const { t } = useTranslation();
  const { isOnline, isSyncing, pendingCount, demoOverride } = useConnectivityStore();
  const [modalOpen, setModalOpen] = useState(false);

  const isDemo = demoOverride !== 'AUTO';

  return (
    <>
      <button
        type="button"
        onClick={() => setModalOpen(true)}
        className={`inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold border transition-colors cursor-pointer select-none ${
          isOnline
            ? 'bg-emerald-50 text-emerald-800 border-emerald-300 hover:bg-emerald-100'
            : 'bg-amber-50 text-amber-900 border-amber-300 hover:bg-amber-100'
        }`}
        title="Click to view upload queue and connectivity simulator"
        aria-label="Connectivity status"
      >
        <span
          className={`w-2 h-2 rounded-full ${
            isSyncing
              ? 'bg-brand-500 animate-ping'
              : isOnline
              ? 'bg-emerald-600'
              : 'bg-amber-600'
          }`}
        />

        {isDemo && (
          <span className="text-[10px] px-1 py-0.2 bg-slate-200 text-slate-800 rounded font-bold uppercase">
            Demo
          </span>
        )}

        <span>
          {isSyncing
            ? t('app.syncing')
            : isOnline
            ? pendingCount > 0
              ? `${pendingCount} ${t('app.waitingUpload')}`
              : t('app.online')
            : pendingCount > 0
            ? `${t('app.offline')} • ${pendingCount}`
            : t('app.offline')}
        </span>
      </button>

      <OfflineQueueModal isOpen={modalOpen} onClose={() => setModalOpen(false)} />
    </>
  );
};
