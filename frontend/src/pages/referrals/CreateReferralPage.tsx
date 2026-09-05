import React, { useEffect, useState } from 'react';
import { useParams, useNavigate, Link } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { screeningService } from '../../services/screeningService';
import { patientService } from '../../services/patientService';
import { referralService } from '../../services/referralService';
import { PrimaryButton } from '../../components/ui/PrimaryButton';
import { SecondaryButton } from '../../components/ui/SecondaryButton';
import { StickyActionBar } from '../../components/ui/StickyActionBar';
import { StatusBadge } from '../../components/ui/StatusBadge';
import { FundusImage } from '../../components/ui/FundusImage';
import { Building2, CheckCircle2, ArrowRight, Share2, AlertCircle } from 'lucide-react';
import type { ScreeningRecord, PatientRecord, ReferralRecord } from '../../types';

export const CreateReferralPage: React.FC = () => {
  const { screeningId } = useParams<{ screeningId: string }>();
  const { t } = useTranslation();
  const navigate = useNavigate();

  const [screening, setScreening] = useState<ScreeningRecord | null>(null);
  const [patient, setPatient] = useState<PatientRecord | null>(null);
  const [loading, setLoading] = useState(true);

  // Form state
  const [specialistCentre, setSpecialistCentre] = useState('District Hospital Ophthalmology Ward');
  const [referralReason, setReferralReason] = useState('');
  const [healthWorkerNotes, setHealthWorkerNotes] = useState('');
  const [submittedReferral, setSubmittedReferral] = useState<ReferralRecord | null>(null);
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    const load = async () => {
      if (!screeningId) return;
      setLoading(true);
      const scr = await screeningService.getScreeningById(screeningId);
      if (scr) {
        setScreening(scr);
        const p = await patientService.getPatientById(scr.patientId);
        if (p) {
          setPatient(p);
          setReferralReason(
            scr.resultCategory === 'PRIORITY'
              ? 'Priority tertiary evaluation: Severe diabetic retinopathy findings detected during rural screening.'
              : 'Specialist review: Microvascular changes (microaneurysms/exudates) require ophthalmologist assessment.'
          );
        }
      }
      setLoading(false);
    };
    load();
  }, [screeningId]);

  const handleSubmitReferral = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!screening || !patient) return;

    setSubmitting(true);
    const newRef = await referralService.createReferral({
      screeningId: screening.id,
      patientId: patient.id,
      patientName: patient.name,
      patientAge: patient.age,
      patientSex: patient.sex,
      village: patient.village,
      priority: screening.resultCategory === 'PRIORITY' ? 'PRIORITY' : 'REVIEW',
      eye: screening.eye,
      imageUri: screening.imageUri,
      specialistCentre,
      referralReason,
      healthWorkerNotes: healthWorkerNotes || undefined
    });

    setSubmittedReferral(newRef);
    setSubmitting(false);
  };

  if (loading) {
    return (
      <div className="py-12 text-center text-slate-500 text-sm">
        Loading referral details...
      </div>
    );
  }

  if (!screening || !patient) {
    return (
      <div className="bg-white rounded-2xl p-6 border border-slate-200 text-center">
        <p className="text-slate-700 font-bold mb-3">Screening record not found</p>
        <Link to="/dashboard" className="text-brand-700 font-semibold underline text-sm">
          Return to Dashboard
        </Link>
      </div>
    );
  }

  // SUCCESS CONFIRMATION STATE
  if (submittedReferral) {
    return (
      <div className="bg-white rounded-2xl p-6 sm:p-8 border border-slate-200 shadow-sm text-center space-y-4 max-w-md mx-auto my-6">
        <div className="w-16 h-16 rounded-full bg-emerald-50 text-emerald-600 border-2 border-emerald-200 flex items-center justify-center mx-auto shadow-xs">
          <CheckCircle2 className="w-9 h-9" />
        </div>

        <h1 className="text-2xl font-extrabold text-slate-900 tracking-tight">
          {t('referral.successTitle')}
        </h1>

        <div className="p-3.5 bg-slate-50 rounded-xl border border-slate-200 text-center">
          <span className="text-[11px] font-bold uppercase tracking-wider text-slate-500 block">
            {t('referral.refNumber')}
          </span>
          <span className="text-xl font-black text-brand-800 tracking-wider">
            {submittedReferral.id}
          </span>
        </div>

        <p className="text-sm text-slate-600 leading-relaxed">
          {t('referral.successDesc')} The hospital team has been notified.
        </p>

        <div className="pt-3 space-y-2">
          <PrimaryButton
            onClick={() => navigate('/referrals')}
            className="w-full"
            icon={Share2}
          >
            {t('referral.viewReferrals')}
          </PrimaryButton>

          <SecondaryButton
            onClick={() => navigate('/dashboard')}
            className="w-full"
          >
            {t('upload.backToDashboard')}
          </SecondaryButton>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-4 pb-24">
      {/* Header */}
      <div className="bg-white rounded-2xl p-4 border border-slate-200 shadow-2xs">
        <span className="text-xs font-bold text-brand-700 uppercase tracking-wider block">
          Remote Specialist Referral
        </span>
        <h1 className="text-lg font-bold text-slate-900 mt-0.5">
          {t('referral.createTitle')}
        </h1>
        <p className="text-xs text-slate-500 mt-1">
          {t('referral.prefilledNotice')}
        </p>
      </div>

      {/* Auto-prefilled Patient & Screening Summary */}
      <div className="bg-white rounded-2xl p-4 border border-slate-200 shadow-2xs">
        <div className="flex items-start justify-between gap-3">
          <div className="flex items-center gap-3">
            <FundusImage
              src={screening.imageUri}
              alt={patient.name}
              size="thumb"
              eye={screening.eye}
              allowZoom={true}
            />
            <div>
              <h2 className="font-bold text-base text-slate-900 leading-tight">
                {patient.name}
              </h2>
              <p className="text-xs text-slate-500">
                {patient.id} • {patient.age} yrs • {patient.village}
              </p>
              <div className="mt-1 flex items-center gap-2">
                <StatusBadge status={screening.resultCategory} size="sm" />
                <span className="text-[11px] text-slate-600 font-medium">
                  {screening.eye === 'RIGHT' ? 'Right Eye' : 'Left Eye'}
                </span>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Referral Form */}
      <form onSubmit={handleSubmitReferral} className="bg-white rounded-2xl p-5 border border-slate-200 shadow-xs space-y-4">
        {/* Destination Facility */}
        <div>
          <label className="block text-xs font-bold uppercase tracking-wider text-slate-700 mb-1.5">
            {t('referral.facility')} <span className="text-rose-600">*</span>
          </label>
          <div className="relative">
            <Building2 className="w-4 h-4 text-slate-400 absolute left-3.5 top-3.5" />
            <select
              value={specialistCentre}
              onChange={(e) => setSpecialistCentre(e.target.value)}
              className="w-full pl-10 pr-4 py-3 rounded-xl border border-slate-300 text-sm text-slate-900 bg-white focus:outline-none focus:ring-2 focus:ring-brand-600 min-h-[48px]"
            >
              <option value="District Hospital Ophthalmology Ward">
                District Hospital Ophthalmology Ward (Sitapur)
              </option>
              <option value="Sitapur Eye Hospital">
                Sitapur Eye Hospital (Tertiary Retina Centre)
              </option>
              <option value="Community Health Centre Eye Clinic">
                Community Health Centre (CHC Eye Clinic)
              </option>
            </select>
          </div>
        </div>

        {/* Reason */}
        <div>
          <label className="block text-xs font-bold uppercase tracking-wider text-slate-700 mb-1.5">
            {t('referral.reason')} <span className="text-rose-600">*</span>
          </label>
          <textarea
            required
            rows={3}
            value={referralReason}
            onChange={(e) => setReferralReason(e.target.value)}
            className="w-full px-3.5 py-2.5 rounded-xl border border-slate-300 text-sm text-slate-900 focus:outline-none focus:ring-2 focus:ring-brand-600"
          />
        </div>

        {/* Optional Notes */}
        <div>
          <label className="block text-xs font-bold uppercase tracking-wider text-slate-700 mb-1.5">
            {t('referral.notes')}
          </label>
          <textarea
            rows={2}
            value={healthWorkerNotes}
            onChange={(e) => setHealthWorkerNotes(e.target.value)}
            placeholder="e.g. Patient reports blurred vision for 2 weeks, HbA1c 9.2%"
            className="w-full px-3.5 py-2.5 rounded-xl border border-slate-300 text-sm text-slate-900 focus:outline-none focus:ring-2 focus:ring-brand-600"
          />
        </div>

        <p className="text-[11px] text-slate-500 flex items-center gap-1.5">
          <AlertCircle className="w-3.5 h-3.5 text-brand-700 flex-shrink-0" />
          <span>Patient fundus images and screening history will be securely linked.</span>
        </p>
      </form>

      {/* Sticky Bottom Action */}
      <StickyActionBar>
        <SecondaryButton
          type="button"
          onClick={() => navigate(-1)}
          className="flex-1"
        >
          {t('app.cancel')}
        </SecondaryButton>

        <PrimaryButton
          type="button"
          disabled={submitting}
          onClick={handleSubmitReferral}
          className="flex-2"
          icon={Share2}
        >
          {submitting ? 'Submitting...' : t('referral.submit')}
        </PrimaryButton>
      </StickyActionBar>
    </div>
  );
};
