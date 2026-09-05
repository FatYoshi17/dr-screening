import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { useScreeningStore } from '../../stores/screeningStore';
import { patientService } from '../../services/patientService';
import { PrimaryButton } from '../../components/ui/PrimaryButton';
import { SecondaryButton } from '../../components/ui/SecondaryButton';
import { StickyActionBar } from '../../components/ui/StickyActionBar';
import { Eye, User, ArrowRight, Check } from 'lucide-react';
import type { PatientRecord } from '../../types';

export const ScreeningStartPage: React.FC = () => {
  const { t } = useTranslation();
  const navigate = useNavigate();
  const { patient, eye, setPatient, setEye } = useScreeningStore();

  const [patients, setPatients] = useState<PatientRecord[]>([]);

  useEffect(() => {
    // If no patient selected yet, fetch recent patients to allow 1-tap select
    if (!patient) {
      patientService.searchPatients('').then((list) => {
        setPatients(list);
        if (list.length > 0) {
          setPatient(list[0]); // Default to Kamla Devi for smooth flow
        }
      });
    }
  }, [patient, setPatient]);

  return (
    <div className="space-y-5 pb-24">
      {/* Step Indicator Header */}
      <div className="bg-white rounded-2xl p-5 border border-slate-200 shadow-xs">
        <span className="text-xs font-bold uppercase tracking-wider text-brand-700 block mb-1">
          New Retinal Screening
        </span>
        <h1 className="text-xl font-bold text-slate-900 tracking-tight">
          Select Patient & Eye
        </h1>

        {/* Selected Patient Banner */}
        {patient ? (
          <div className="mt-4 p-4 rounded-xl bg-teal-50/70 border border-brand-200">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2.5">
                <div className="w-10 h-10 rounded-full bg-brand-700 text-white flex items-center justify-center font-bold text-sm">
                  <User className="w-5 h-5" />
                </div>
                <div>
                  <div className="text-base font-bold text-slate-900">{patient.name}</div>
                  <div className="text-xs text-slate-600">
                    ID: {patient.id} • {patient.age} yrs • {patient.sex} • {patient.village}
                  </div>
                </div>
              </div>
              <button
                type="button"
                onClick={() => navigate('/patients')}
                className="text-xs text-brand-800 font-bold underline p-1"
              >
                Change
              </button>
            </div>
          </div>
        ) : (
          <div className="mt-4 p-4 rounded-xl bg-slate-50 border border-slate-200 text-center">
            <p className="text-sm text-slate-600 mb-2">No patient currently selected</p>
            <button
              type="button"
              onClick={() => navigate('/patients')}
              className="px-4 py-2 rounded-lg bg-brand-700 text-white text-xs font-bold"
            >
              Select from Patient List
            </button>
          </div>
        )}
      </div>

      {/* Eye Selector Cards */}
      <div className="bg-white rounded-2xl p-5 border border-slate-200 shadow-xs">
        <h2 className="text-sm font-bold uppercase tracking-wider text-slate-700 mb-3">
          {t('capture.selectEye')}
        </h2>

        <div className="grid grid-cols-2 gap-3">
          {/* Right Eye (OD) */}
          <button
            type="button"
            onClick={() => setEye('RIGHT')}
            className={`p-4 rounded-xl border text-center transition-all cursor-pointer min-h-[96px] flex flex-col items-center justify-center gap-1.5 ${
              eye === 'RIGHT'
                ? 'bg-teal-50/90 border-brand-600 text-brand-950 font-bold shadow-2xs ring-2 ring-brand-500/30'
                : 'bg-slate-50 border-slate-200 text-slate-700 hover:bg-slate-100 font-medium'
            }`}
          >
            <div className="flex items-center gap-1.5">
              <Eye className="w-5 h-5 text-brand-700" />
              <span className="text-base">{t('capture.rightEye')}</span>
            </div>
            <span className="text-[11px] text-slate-500">Oculus Dexter</span>
            {eye === 'RIGHT' && (
              <span className="inline-flex items-center gap-0.5 text-[10px] text-brand-800 font-bold mt-1">
                <Check className="w-3 h-3" /> Selected
              </span>
            )}
          </button>

          {/* Left Eye (OS) */}
          <button
            type="button"
            onClick={() => setEye('LEFT')}
            className={`p-4 rounded-xl border text-center transition-all cursor-pointer min-h-[96px] flex flex-col items-center justify-center gap-1.5 ${
              eye === 'LEFT'
                ? 'bg-teal-50/90 border-brand-600 text-brand-950 font-bold shadow-2xs ring-2 ring-brand-500/30'
                : 'bg-slate-50 border-slate-200 text-slate-700 hover:bg-slate-100 font-medium'
            }`}
          >
            <div className="flex items-center gap-1.5">
              <Eye className="w-5 h-5 text-brand-700" />
              <span className="text-base">{t('capture.leftEye')}</span>
            </div>
            <span className="text-[11px] text-slate-500">Oculus Sinister</span>
            {eye === 'LEFT' && (
              <span className="inline-flex items-center gap-0.5 text-[10px] text-brand-800 font-bold mt-1">
                <Check className="w-3 h-3" /> Selected
              </span>
            )}
          </button>
        </div>
      </div>

      {/* Sticky Bottom Actions */}
      <StickyActionBar>
        <SecondaryButton
          onClick={() => navigate('/dashboard')}
          className="flex-1"
        >
          {t('app.cancel')}
        </SecondaryButton>

        <PrimaryButton
          disabled={!patient}
          onClick={() => navigate(`/screening/${patient?.id || 'new'}/guide`)}
          className="flex-2"
          icon={ArrowRight}
        >
          {t('app.next')}: Image Guidance
        </PrimaryButton>
      </StickyActionBar>
    </div>
  );
};
