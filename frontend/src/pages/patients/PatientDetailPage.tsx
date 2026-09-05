import React, { useEffect, useState } from 'react';
import { useParams, useNavigate, Link } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { patientService } from '../../services/patientService';
import { screeningService } from '../../services/screeningService';
import { useScreeningStore } from '../../stores/screeningStore';
import { PrimaryButton } from '../../components/ui/PrimaryButton';
import { StatusBadge } from '../../components/ui/StatusBadge';
import { FundusImage } from '../../components/ui/FundusImage';
import { PlusCircle, FileText, ArrowRight, UserCheck, Calendar } from 'lucide-react';
import type { PatientRecord, ScreeningRecord } from '../../types';

export const PatientDetailPage: React.FC = () => {
  const { id } = useParams<{ id: string }>();
  const { t } = useTranslation();
  const navigate = useNavigate();
  const startScreening = useScreeningStore((state) => state.startScreening);

  const [patient, setPatient] = useState<PatientRecord | null>(null);
  const [history, setHistory] = useState<ScreeningRecord[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const load = async () => {
      if (!id) return;
      setLoading(true);
      const p = await patientService.getPatientById(id);
      if (p) {
        setPatient(p);
        const scr = await screeningService.getScreeningsForPatient(id);
        setHistory(scr);
      }
      setLoading(false);
    };
    load();
  }, [id]);

  if (loading) {
    return (
      <div className="py-12 text-center text-slate-500 text-sm">
        Loading patient record...
      </div>
    );
  }

  if (!patient) {
    return (
      <div className="bg-white rounded-2xl p-6 border border-slate-200 text-center">
        <p className="text-slate-700 font-bold mb-3">Patient record not found</p>
        <Link to="/patients" className="text-brand-700 font-semibold underline text-sm">
          Return to Patient Directory
        </Link>
      </div>
    );
  }

  const handleStartScreening = () => {
    startScreening(patient);
    navigate('/screening/new');
  };

  return (
    <div className="space-y-5 pb-8">
      {/* Top Patient Summary Card */}
      <div className="bg-white rounded-2xl p-5 border border-slate-200 shadow-2xs">
        <div className="flex items-start justify-between mb-2">
          <div>
            <span className="text-xs font-bold text-brand-700 uppercase tracking-wider block">
              Patient Record
            </span>
            <h1 className="text-xl font-bold text-slate-900 mt-0.5">
              {patient.name}
            </h1>
            <p className="text-xs text-slate-500 font-medium">
              ID: {patient.id} • {patient.age} yrs • {patient.sex}
            </p>
          </div>
          {patient.lastResult && (
            <StatusBadge status={patient.lastResult} size="md" />
          )}
        </div>

        <div className="grid grid-cols-2 gap-2 text-xs py-3 my-2 border-y border-slate-100 text-slate-700">
          <div>
            <span className="text-slate-400 block text-[11px]">Village / Location</span>
            <span className="font-semibold">{patient.village}</span>
          </div>
          <div>
            <span className="text-slate-400 block text-[11px]">Diabetes Status</span>
            <span className="font-semibold">{patient.diabetesStatus.replace('_', ' ')}</span>
          </div>
        </div>

        <div className="mt-3">
          <PrimaryButton
            icon={PlusCircle}
            onClick={handleStartScreening}
            className="min-h-[50px] font-bold"
          >
            Start New Screening
          </PrimaryButton>
        </div>
      </div>

      {/* Screening History Timeline */}
      <div className="bg-white rounded-2xl p-5 border border-slate-200 shadow-2xs">
        <div className="flex items-center gap-2 mb-4 pb-2 border-b border-slate-100">
          <Calendar className="w-4 h-4 text-brand-700" />
          <h2 className="text-sm font-bold text-slate-900 uppercase tracking-wider">
            {t('patient.screeningHistory')} ({history.length})
          </h2>
        </div>

        {history.length === 0 ? (
          <p className="text-xs text-slate-500 py-4 text-center">
            {t('patient.noHistory')}
          </p>
        ) : (
          <div className="space-y-3">
            {history.map((scr) => (
              <div
                key={scr.id}
                className="p-3.5 rounded-xl border border-slate-200 bg-slate-50/70 hover:border-brand-300 transition-colors flex items-center justify-between gap-3"
              >
                <div className="flex items-center gap-3">
                  <FundusImage
                    src={scr.imageUri}
                    alt={`${patient.name} screening`}
                    size="thumb"
                    eye={scr.eye}
                    allowZoom={false}
                  />

                  <div>
                    <div className="flex items-center gap-2">
                      <span className="text-xs font-bold text-slate-900">
                        {scr.eye === 'RIGHT' ? 'Right Eye (OD)' : 'Left Eye (OS)'}
                      </span>
                      <StatusBadge status={scr.resultCategory} size="sm" />
                    </div>
                    <p className="text-[11px] text-slate-500 mt-0.5">
                      {new Date(scr.createdAt).toLocaleDateString(undefined, {
                        year: 'numeric',
                        month: 'short',
                        day: 'numeric'
                      })} • {scr.centreName}
                    </p>
                  </div>
                </div>

                <Link
                  to={`/screening/${scr.id}/report`}
                  className="p-2 rounded-lg bg-white border border-slate-200 text-slate-700 hover:bg-slate-100 text-xs font-semibold flex items-center gap-1"
                >
                  <FileText className="w-3.5 h-3.5" />
                  <span className="hidden sm:inline">Report</span>
                  <ArrowRight className="w-3 h-3" />
                </Link>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
};
