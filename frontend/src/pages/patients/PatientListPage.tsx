import React, { useEffect, useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { Search, UserPlus, ArrowRight, Clock, AlertCircle } from 'lucide-react';
import { useTranslation } from 'react-i18next';
import { patientService } from '../../services/patientService';
import { useScreeningStore } from '../../stores/screeningStore';
import { StatusBadge } from '../../components/ui/StatusBadge';
import type { PatientRecord } from '../../types';

export const PatientListPage: React.FC = () => {
  const { t } = useTranslation();
  const navigate = useNavigate();
  const startScreening = useScreeningStore((state) => state.startScreening);

  const [query, setQuery] = useState('');
  const [patients, setPatients] = useState<PatientRecord[]>([]);
  const [loading, setLoading] = useState(true);

  const loadPatients = async () => {
    setLoading(true);
    const data = await patientService.searchPatients(query);
    setPatients(data);
    setLoading(false);
  };

  useEffect(() => {
    loadPatients();
  }, [query]);

  const handleSelectPatient = (patient: PatientRecord) => {
    startScreening(patient);
    navigate('/screening/new');
  };

  return (
    <div className="space-y-4 pb-6">
      {/* Top Search Bar */}
      <div className="bg-white rounded-2xl p-4 border border-slate-200 shadow-2xs">
        <h1 className="text-lg font-bold text-slate-900 mb-3">
          {t('patient.findPatient')}
        </h1>

        <div className="relative mb-3">
          <Search className="w-5 h-5 text-slate-400 absolute left-3.5 top-3.5" />
          <input
            type="text"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder={t('patient.searchPlaceholder')}
            className="w-full pl-11 pr-4 py-3 rounded-xl border border-slate-300 text-base text-slate-900 placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-brand-600 focus:border-brand-600 min-h-[48px]"
          />
        </div>

        <Link
          to="/patients/new"
          className="w-full py-3 px-4 rounded-xl bg-teal-50 border border-brand-300 text-brand-900 font-bold text-sm flex items-center justify-center gap-2 hover:bg-teal-100/70 transition-colors"
        >
          <UserPlus className="w-4 h-4" />
          <span>{t('patient.registerNew')}</span>
        </Link>
      </div>

      {/* Patient Results List */}
      <div className="space-y-3">
        <div className="flex justify-between items-center px-1">
          <span className="text-xs font-bold uppercase tracking-wider text-slate-500">
            Patients ({patients.length})
          </span>
        </div>

        {loading ? (
          <div className="py-8 text-center text-slate-500 text-sm">
            Loading patient records...
          </div>
        ) : patients.length === 0 ? (
          <div className="bg-white rounded-xl p-8 border border-slate-200 text-center space-y-3">
            <AlertCircle className="w-10 h-10 text-slate-400 mx-auto" />
            <p className="text-sm font-semibold text-slate-700">No patient record found</p>
            <Link
              to="/patients/new"
              className="inline-flex items-center gap-1.5 px-4 py-2 rounded-xl bg-brand-700 text-white text-xs font-bold"
            >
              <UserPlus className="w-3.5 h-3.5" />
              <span>{t('patient.registerNew')}</span>
            </Link>
          </div>
        ) : (
          patients.map((patient) => (
            <div
              key={patient.id}
              className="bg-white rounded-xl p-4 border border-slate-200 shadow-2xs hover:border-brand-300 transition-colors"
            >
              <div className="flex items-start justify-between gap-2 mb-2">
                <div>
                  <h3 className="font-bold text-base text-slate-900 leading-snug">
                    {patient.name}
                  </h3>
                  <p className="text-xs text-slate-500 font-medium mt-0.5">
                    {patient.id} • {patient.age} yrs • {patient.sex} • {patient.village}
                  </p>
                </div>

                {patient.lastResult && (
                  <StatusBadge status={patient.lastResult} size="sm" />
                )}
              </div>

              {/* Patient Diabetes metadata */}
              <div className="flex items-center gap-3 text-xs text-slate-600 mb-3 pt-1 border-t border-slate-100">
                <span className="px-2 py-0.5 rounded bg-slate-100 text-slate-700 font-medium">
                  {patient.diabetesStatus.replace('_', ' ')}
                </span>
                {patient.lastScreeningDate && (
                  <span className="flex items-center gap-1 text-slate-500 text-[11px]">
                    <Clock className="w-3 h-3" />
                    {new Date(patient.lastScreeningDate).toLocaleDateString()}
                  </span>
                )}
              </div>

              {/* Actions */}
              <div className="grid grid-cols-2 gap-2 pt-1">
                <Link
                  to={`/patient/${patient.id}`}
                  className="py-2.5 px-3 rounded-xl border border-slate-200 bg-slate-50 text-slate-800 text-xs font-bold text-center hover:bg-slate-100 transition-colors flex items-center justify-center gap-1"
                >
                  <span>{t('app.view')} Profile</span>
                </Link>

                <button
                  type="button"
                  onClick={() => handleSelectPatient(patient)}
                  className="py-2.5 px-3 rounded-xl bg-brand-700 text-white text-xs font-bold text-center hover:bg-brand-800 transition-colors flex items-center justify-center gap-1 cursor-pointer"
                >
                  <span>Screen Eye</span>
                  <ArrowRight className="w-3.5 h-3.5" />
                </button>
              </div>
            </div>
          ))
        )}
      </div>
    </div>
  );
};
