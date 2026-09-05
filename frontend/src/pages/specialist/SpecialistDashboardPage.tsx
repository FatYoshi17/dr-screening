import React, { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { specialistService } from '../../services/specialistService';
import { StatusBadge } from '../../components/ui/StatusBadge';
import { FundusImage } from '../../components/ui/FundusImage';
import { Stethoscope, AlertCircle, Clock, Building, ArrowRight, Filter } from 'lucide-react';
import type { ReferralRecord } from '../../types';

export const SpecialistDashboardPage: React.FC = () => {
  const { t } = useTranslation();
  const [cases, setCases] = useState<ReferralRecord[]>([]);
  const [filter, setFilter] = useState<'ALL' | 'PRIORITY' | 'REVIEW'>('ALL');
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const load = async () => {
      setLoading(true);
      const triage = await specialistService.getTriageCases();
      setCases(triage);
      setLoading(false);
    };
    load();
  }, []);

  const filtered = cases.filter((c) => {
    if (filter === 'PRIORITY') return c.priority === 'PRIORITY';
    if (filter === 'REVIEW') return c.priority === 'REVIEW';
    return true;
  });

  return (
    <div className="space-y-6">
      {/* Triage Overview Banner */}
      <div className="bg-white rounded-2xl p-5 border border-slate-200 shadow-xs flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <div className="flex items-center gap-2 mb-1">
            <Stethoscope className="w-5 h-5 text-indigo-700" />
            <h1 className="text-xl font-extrabold text-slate-900 tracking-tight">
              {t('specialist.title')}
            </h1>
          </div>
          <p className="text-xs text-slate-500">
            Cases referred from rural Primary Health Centres prioritized by clinical urgency.
          </p>
        </div>

        {/* Priority Filter Chips */}
        <div className="flex items-center gap-2">
          <button
            type="button"
            onClick={() => setFilter('ALL')}
            className={`px-3 py-1.5 rounded-xl text-xs font-bold border transition-colors cursor-pointer ${
              filter === 'ALL'
                ? 'bg-slate-900 text-white border-slate-900'
                : 'bg-white text-slate-700 border-slate-300 hover:bg-slate-50'
            }`}
          >
            All Cases ({cases.length})
          </button>
          <button
            type="button"
            onClick={() => setFilter('PRIORITY')}
            className={`px-3 py-1.5 rounded-xl text-xs font-bold border transition-colors cursor-pointer flex items-center gap-1 ${
              filter === 'PRIORITY'
                ? 'bg-rose-700 text-white border-rose-700'
                : 'bg-white text-rose-800 border-rose-200 hover:bg-rose-50'
            }`}
          >
            <AlertCircle className="w-3.5 h-3.5" />
            <span>Priority First</span>
          </button>
          <button
            type="button"
            onClick={() => setFilter('REVIEW')}
            className={`px-3 py-1.5 rounded-xl text-xs font-bold border transition-colors cursor-pointer ${
              filter === 'REVIEW'
                ? 'bg-amber-700 text-white border-amber-700'
                : 'bg-white text-amber-800 border-amber-200 hover:bg-amber-50'
            }`}
          >
            Routine Review
          </button>
        </div>
      </div>

      {/* Case List */}
      {loading ? (
        <div className="py-12 text-center text-slate-500 text-sm">
          Loading specialist queue...
        </div>
      ) : filtered.length === 0 ? (
        <div className="bg-white rounded-2xl p-8 border border-slate-200 text-center text-slate-500 text-sm">
          No triage cases found for this filter.
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          {filtered.map((item) => (
            <div
              key={item.id}
              className={`bg-white rounded-2xl p-5 border-2 shadow-2xs hover:shadow-xs transition-all space-y-4 ${
                item.priority === 'PRIORITY'
                  ? 'border-rose-300 ring-1 ring-rose-200/50'
                  : 'border-slate-200 hover:border-slate-300'
              }`}
            >
              <div className="flex items-start justify-between gap-3">
                <div className="flex items-center gap-3.5">
                  <FundusImage
                    src={item.imageUri}
                    alt={item.patientName}
                    size="thumb"
                    eye={item.eye}
                    allowZoom={true}
                  />

                  <div>
                    <div className="flex items-center gap-2">
                      <h2 className="text-base font-bold text-slate-900">
                        {item.patientName}
                      </h2>
                      <span className="text-xs text-slate-500 font-mono">
                        {item.patientId}
                      </span>
                    </div>

                    <p className="text-xs text-slate-600 mt-0.5">
                      {item.patientAge} yrs • {item.patientSex} • Village {item.village}
                    </p>

                    <div className="mt-1.5 flex items-center gap-2">
                      <StatusBadge status={item.priority} size="sm" />
                      <span className="text-[11px] font-semibold text-slate-700 bg-slate-100 px-2 py-0.5 rounded">
                        {item.eye === 'RIGHT' ? 'Right Eye (OD)' : 'Left Eye (OS)'}
                      </span>
                    </div>
                  </div>
                </div>

                <span
                  className={`text-[11px] px-2 py-1 rounded-full font-bold uppercase tracking-wider ${
                    item.status === 'REVIEW_COMPLETED'
                      ? 'bg-emerald-100 text-emerald-800'
                      : 'bg-amber-100 text-amber-800'
                  }`}
                >
                  {item.status === 'REVIEW_COMPLETED' ? 'Reviewed' : 'Waiting'}
                </span>
              </div>

              {/* Referral Reason Summary */}
              <div className="p-3 bg-slate-50 rounded-xl border border-slate-200 text-xs text-slate-700 leading-relaxed">
                <span className="font-bold text-slate-900 block mb-0.5">
                  Referral Indication:
                </span>
                <p>{item.referralReason}</p>
                {item.healthWorkerNotes && (
                  <p className="text-[11px] text-slate-500 mt-1 italic">
                    Worker Note: "{item.healthWorkerNotes}"
                  </p>
                )}
              </div>

              {/* Origin PHC & Review Button */}
              <div className="flex items-center justify-between pt-1 text-xs">
                <span className="text-slate-500 flex items-center gap-1 truncate max-w-[200px]">
                  <Building className="w-3.5 h-3.5 flex-shrink-0" />
                  <span>Rampur PHC</span>
                </span>

                <Link
                  to={`/specialist/case/${item.id}`}
                  className="px-4 py-2 rounded-xl bg-indigo-700 hover:bg-indigo-800 text-white font-bold flex items-center gap-1.5 transition-colors cursor-pointer shadow-2xs"
                >
                  <span>{t('specialist.reviewCase')}</span>
                  <ArrowRight className="w-3.5 h-3.5" />
                </Link>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
};
