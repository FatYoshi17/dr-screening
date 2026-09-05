import React, { useEffect, useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { useAuthStore } from '../../stores/authStore';
import { useConnectivityStore } from '../../stores/connectivityStore';
import { db } from '../../offline/db';
import { PrimaryButton } from '../../components/ui/PrimaryButton';
import { StatusBadge } from '../../components/ui/StatusBadge';
import { OfflineQueueModal } from '../../components/ui/OfflineQueueModal';
import { PlusCircle, Wifi, WifiOff, AlertCircle, ArrowRight, Clock, Users } from 'lucide-react';
import type { ReferralRecord } from '../../types';

export const DashboardPage: React.FC = () => {
  const { t } = useTranslation();
  const navigate = useNavigate();
  const user = useAuthStore((state) => state.user);
  const { isOnline, pendingCount } = useConnectivityStore();

  const [queueModalOpen, setQueueModalOpen] = useState(false);
  const [attentionItems, setAttentionItems] = useState<ReferralRecord[]>([]);

  useEffect(() => {
    // Load urgent referral cases requiring health worker attention
    const loadAttention = async () => {
      const pendingReferrals = await db.referrals
        .where('status')
        .equals('WAITING_FOR_SPECIALIST')
        .reverse()
        .sortBy('createdAt');
      setAttentionItems(pendingReferrals.slice(0, 3));
    };
    loadAttention();
  }, []);

  return (
    <div className="space-y-5 pb-6">
      {/* Greeting & Health Centre Banner */}
      <div className="bg-white rounded-2xl p-4 sm:p-5 border border-slate-200 shadow-xs">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-xl sm:text-2xl font-bold text-slate-900 tracking-tight">
              {t('dashboard.greeting')}, {user?.name?.split(' ')[0] || 'Worker'}
            </h1>
            <p className="text-sm font-medium text-brand-800 mt-0.5">
              {user?.centreName || t('dashboard.centre')}
            </p>
          </div>
          <Link
            to="/patients"
            className="p-2.5 rounded-xl bg-slate-100 text-slate-700 hover:bg-slate-200 transition-colors"
            title="Patient Directory"
          >
            <Users className="w-5 h-5" />
          </Link>
        </div>

        {/* DOMINANT PRIMARY ACTION */}
        <div className="mt-4">
          <PrimaryButton
            size="large"
            icon={PlusCircle}
            onClick={() => navigate('/screening/new')}
            className="text-base sm:text-lg font-bold min-h-[56px] shadow-sm"
          >
            {t('dashboard.startNewScreening')}
          </PrimaryButton>
        </div>
      </div>

      {/* TODAY'S SCREENINGS (4 Compact Numbers - No charts) */}
      <section aria-labelledby="today-screenings-heading">
        <div className="flex items-center justify-between mb-2.5 px-1">
          <h2 id="today-screenings-heading" className="text-sm font-bold text-slate-900 uppercase tracking-wider">
            {t('dashboard.todayScreenings')}
          </h2>
          <span className="text-xs text-slate-500 font-medium">35 Total</span>
        </div>

        <div className="grid grid-cols-2 gap-2.5 sm:grid-cols-4">
          {/* Routine Card */}
          <div className="bg-emerald-50/70 border border-emerald-200/80 rounded-xl p-3 flex flex-col justify-between min-h-[84px]">
            <span className="text-xs font-semibold text-emerald-800 flex items-center gap-1">
              <span>✓</span> {t('status.routine')}
            </span>
            <span className="text-2xl sm:text-3xl font-extrabold text-emerald-950">24</span>
          </div>

          {/* Review Card */}
          <div className="bg-amber-50/70 border border-amber-200/80 rounded-xl p-3 flex flex-col justify-between min-h-[84px]">
            <span className="text-xs font-semibold text-amber-900 flex items-center gap-1">
              <span>!</span> {t('status.review')}
            </span>
            <span className="text-2xl sm:text-3xl font-extrabold text-amber-950">6</span>
          </div>

          {/* Priority Card */}
          <div className="bg-rose-50/70 border border-rose-200/80 rounded-xl p-3 flex flex-col justify-between min-h-[84px]">
            <span className="text-xs font-semibold text-rose-900 flex items-center gap-1">
              <span>!!</span> {t('status.priority')}
            </span>
            <span className="text-2xl sm:text-3xl font-extrabold text-rose-950">2</span>
          </div>

          {/* Retake Card */}
          <div className="bg-yellow-50/70 border border-yellow-300 rounded-xl p-3 flex flex-col justify-between min-h-[84px]">
            <span className="text-xs font-semibold text-yellow-900 flex items-center gap-1">
              <span>↻</span> {t('status.retake')}
            </span>
            <span className="text-2xl sm:text-3xl font-extrabold text-yellow-950">3</span>
          </div>
        </div>
      </section>

      {/* PENDING UPLOADS / OFFLINE STATUS BANNER */}
      <section aria-labelledby="sync-status-heading">
        <div
          className={`rounded-2xl p-4 border flex items-center justify-between ${
            isOnline
              ? pendingCount > 0
                ? 'bg-amber-50/90 border-amber-200'
                : 'bg-white border-slate-200'
              : 'bg-amber-50/90 border-amber-300'
          }`}
        >
          <div className="flex items-center gap-3">
            <div
              className={`w-10 h-10 rounded-xl flex items-center justify-center ${
                isOnline
                  ? pendingCount > 0
                    ? 'bg-amber-100 text-amber-800'
                    : 'bg-emerald-100 text-emerald-800'
                  : 'bg-amber-100 text-amber-800'
              }`}
            >
              {isOnline ? (
                <Wifi className="w-5 h-5" />
              ) : (
                <WifiOff className="w-5 h-5" />
              )}
            </div>

            <div>
              <div className="text-sm font-bold text-slate-900">
                {isOnline
                  ? pendingCount > 0
                    ? `${pendingCount} ${t('app.waitingUpload')}`
                    : t('app.online')
                  : `${t('app.offline')} • ${pendingCount} waiting`}
              </div>
              <p className="text-xs text-slate-600">
                {isOnline
                  ? pendingCount > 0
                    ? 'Ready for cloud processing'
                    : t('dashboard.allSynced')
                  : 'Screenings are safely saved in local memory'}
              </p>
            </div>
          </div>

          <button
            type="button"
            onClick={() => setQueueModalOpen(true)}
            className="px-3 py-2 rounded-xl text-xs font-bold border border-slate-300 bg-white hover:bg-slate-50 text-slate-800 transition-colors shadow-2xs"
          >
            {t('dashboard.viewQueue')}
          </button>
        </div>
      </section>

      {/* CASES REQUIRING ATTENTION */}
      <section aria-labelledby="requires-attention-heading">
        <div className="flex items-center justify-between mb-2.5 px-1">
          <div className="flex items-center gap-1.5">
            <AlertCircle className="w-4 h-4 text-rose-700" />
            <h2 id="requires-attention-heading" className="text-sm font-bold text-slate-900 uppercase tracking-wider">
              {t('dashboard.requiresAttention')}
            </h2>
          </div>
          <Link to="/referrals" className="text-xs font-semibold text-brand-700 hover:underline">
            View All
          </Link>
        </div>

        <div className="space-y-2.5">
          {attentionItems.length === 0 ? (
            <div className="bg-white rounded-xl p-4 border border-slate-200 text-center text-xs text-slate-500">
              {t('dashboard.noAttentionNeeded')}
            </div>
          ) : (
            attentionItems.map((item) => (
              <div
                key={item.id}
                className="bg-white rounded-xl p-3.5 border border-slate-200 shadow-2xs hover:border-slate-300 transition-colors flex items-center justify-between gap-3"
              >
                <div>
                  <div className="flex items-center gap-2">
                    <span className="font-bold text-sm text-slate-900">{item.patientName}</span>
                    <span className="text-xs text-slate-500">{item.patientId}</span>
                  </div>
                  <div className="flex items-center gap-2 mt-1">
                    <StatusBadge status={item.priority} size="sm" />
                    <span className="text-xs text-slate-500 flex items-center gap-1">
                      <Clock className="w-3 h-3" />
                      {t('dashboard.pendingReferral')}
                    </span>
                  </div>
                </div>

                <Link
                  to={`/referrals`}
                  className="px-3 py-1.5 rounded-lg bg-slate-100 hover:bg-brand-50 hover:text-brand-800 text-slate-700 text-xs font-bold transition-colors inline-flex items-center gap-1"
                >
                  <span>{t('app.view')}</span>
                  <ArrowRight className="w-3.5 h-3.5" />
                </Link>
              </div>
            ))
          )}
        </div>
      </section>

      {/* Offline Queue Inspector Modal */}
      <OfflineQueueModal isOpen={queueModalOpen} onClose={() => setQueueModalOpen(false)} />
    </div>
  );
};
