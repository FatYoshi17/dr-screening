import React, { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { referralService } from '../../services/referralService';
import { StatusBadge } from '../../components/ui/StatusBadge';
import { FundusImage } from '../../components/ui/FundusImage';
import { Share2, Clock, CheckCircle2, Building, Eye, AlertCircle } from 'lucide-react';
import type { ReferralRecord } from '../../types';

export const ReferralListPage: React.FC = () => {
  const { t } = useTranslation();
  const [activeTab, setActiveTab] = useState<'PENDING' | 'REVIEWED' | 'ALL'>('PENDING');
  const [referrals, setReferrals] = useState<ReferralRecord[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const load = async () => {
      setLoading(true);
      const all = await referralService.getReferrals();
      setReferrals(all);
      setLoading(false);
    };
    load();
  }, []);

  const filtered = referrals.filter((r) => {
    if (activeTab === 'PENDING') return r.status === 'WAITING_FOR_SPECIALIST';
    if (activeTab === 'REVIEWED') return r.status === 'REVIEW_COMPLETED';
    return true;
  });

  return (
    <div className="space-y-4 pb-8">
      {/* Header */}
      <div className="bg-white rounded-2xl p-4 border border-slate-200 shadow-2xs">
        <div className="flex items-center gap-2 mb-1">
          <Share2 className="w-5 h-5 text-brand-700" />
          <h1 className="text-lg font-bold text-slate-900">
            Specialist Referrals
          </h1>
        </div>
        <p className="text-xs text-slate-500">
          Track cases sent to district ophthalmology centres for clinical evaluation.
        </p>
      </div>

      {/* Tabs */}
      <div className="grid grid-cols-3 gap-1.5 p-1 bg-slate-200/80 rounded-xl">
        <button
          type="button"
          onClick={() => setActiveTab('PENDING')}
          className={`py-2 text-xs font-bold rounded-lg transition-colors cursor-pointer text-center ${
            activeTab === 'PENDING'
              ? 'bg-white text-brand-800 shadow-xs'
              : 'text-slate-600 hover:text-slate-900'
          }`}
        >
          {t('referral.tabs.pending')}
        </button>
        <button
          type="button"
          onClick={() => setActiveTab('REVIEWED')}
          className={`py-2 text-xs font-bold rounded-lg transition-colors cursor-pointer text-center ${
            activeTab === 'REVIEWED'
              ? 'bg-white text-brand-800 shadow-xs'
              : 'text-slate-600 hover:text-slate-900'
          }`}
        >
          {t('referral.tabs.reviewed')}
        </button>
        <button
          type="button"
          onClick={() => setActiveTab('ALL')}
          className={`py-2 text-xs font-bold rounded-lg transition-colors cursor-pointer text-center ${
            activeTab === 'ALL'
              ? 'bg-white text-brand-800 shadow-xs'
              : 'text-slate-600 hover:text-slate-900'
          }`}
        >
          All ({referrals.length})
        </button>
      </div>

      {/* List */}
      <div className="space-y-3">
        {loading ? (
          <div className="py-10 text-center text-slate-500 text-sm">
            Loading referrals...
          </div>
        ) : filtered.length === 0 ? (
          <div className="bg-white rounded-2xl p-8 border border-slate-200 text-center space-y-2">
            <CheckCircle2 className="w-8 h-8 text-slate-400 mx-auto" />
            <p className="text-sm font-semibold text-slate-700">No referrals in this view</p>
            <p className="text-xs text-slate-500">Cases flagged as Review or Priority will appear here.</p>
          </div>
        ) : (
          filtered.map((item) => (
            <div
              key={item.id}
              className="bg-white rounded-2xl p-4 border border-slate-200 shadow-2xs hover:border-brand-300 transition-colors space-y-3"
            >
              <div className="flex items-start justify-between gap-3">
                <div className="flex items-center gap-3">
                  <FundusImage
                    src={item.imageUri}
                    alt={item.patientName}
                    size="thumb"
                    eye={item.eye}
                    allowZoom={true}
                  />
                  <div>
                    <h2 className="text-base font-bold text-slate-900 leading-tight">
                      {item.patientName}
                    </h2>
                    <p className="text-xs text-slate-500 mt-0.5">
                      {item.patientId} • {item.patientAge} yrs • {item.village}
                    </p>
                    <div className="mt-1 flex items-center gap-2">
                      <StatusBadge status={item.priority} size="sm" />
                      <span className="text-[11px] text-slate-500 flex items-center gap-1">
                        <Clock className="w-3 h-3" />
                        Sent {new Date(item.createdAt).toLocaleDateString()}
                      </span>
                    </div>
                  </div>
                </div>

                <span
                  className={`text-xs px-2.5 py-1 rounded-full font-bold uppercase tracking-wider ${
                    item.status === 'REVIEW_COMPLETED'
                      ? 'bg-emerald-100 text-emerald-800'
                      : 'bg-amber-100 text-amber-800'
                  }`}
                >
                  {item.status === 'REVIEW_COMPLETED' ? 'Reviewed' : 'Waiting'}
                </span>
              </div>

              {/* Destination Hospital */}
              <div className="flex items-center gap-1.5 text-xs text-slate-600 bg-slate-50 p-2 rounded-xl">
                <Building className="w-3.5 h-3.5 text-slate-500 flex-shrink-0" />
                <span className="truncate">{item.specialistCentre}</span>
              </div>

              {/* Specialist notes if reviewed */}
              {item.status === 'REVIEW_COMPLETED' && item.specialistNotes && (
                <div className="p-3 bg-emerald-50/70 border border-emerald-200 rounded-xl text-xs space-y-1">
                  <span className="font-bold text-emerald-950 block">
                    Specialist Clinical Recommendation ({item.reviewedBy}):
                  </span>
                  <p className="text-emerald-900 font-medium">
                    {item.specialistNotes}
                  </p>
                </div>
              )}

              {/* View details */}
              <div className="pt-1 flex justify-end">
                <Link
                  to={`/specialist/case/${item.id}`}
                  className="px-4 py-2 rounded-xl bg-slate-100 hover:bg-brand-50 hover:text-brand-800 text-slate-800 font-bold text-xs transition-colors flex items-center gap-1.5"
                >
                  <Eye className="w-3.5 h-3.5" />
                  <span>Inspect Case</span>
                </Link>
              </div>
            </div>
          ))
        )}
      </div>
    </div>
  );
};
