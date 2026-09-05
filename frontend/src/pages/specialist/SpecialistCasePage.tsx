import React, { useEffect, useState } from 'react';
import { useParams, useNavigate, Link } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { specialistService, type SpecialistCaseDetails } from '../../services/specialistService';
import { useAuthStore } from '../../stores/authStore';
import { StatusBadge } from '../../components/ui/StatusBadge';
import { FundusImage } from '../../components/ui/FundusImage';
import { PrimaryButton } from '../../components/ui/PrimaryButton';
import { SecondaryButton } from '../../components/ui/SecondaryButton';
import {
  Stethoscope,
  ArrowLeft,
  Calendar,
  CheckCircle2,
  RefreshCw,
  Cpu,
  ChevronDown,
  ChevronUp,
  Building,
  User,
  ShieldCheck,
  AlertTriangle
} from 'lucide-react';

export const SpecialistCasePage: React.FC = () => {
  const { id } = useParams<{ id: string }>();
  const { t } = useTranslation();
  const navigate = useNavigate();
  const user = useAuthStore((state) => state.user);

  const [data, setData] = useState<SpecialistCaseDetails | null>(null);
  const [loading, setLoading] = useState(true);

  // Review form
  const [specialistNotes, setSpecialistNotes] = useState('');
  const [decision, setDecision] = useState<'CONFIRMED' | 'RETAKE_REQUESTED' | 'FOLLOWUP_PRESCRIBED'>('CONFIRMED');
  const [showAiDetails, setShowAiDetails] = useState(true);
  const [reviewSubmitted, setReviewSubmitted] = useState(false);
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    const load = async () => {
      if (!id) return;
      setLoading(true);
      const res = await specialistService.getCaseDetails(id);
      if (res) {
        setData(res);
        if (res.referral.specialistNotes) {
          setSpecialistNotes(res.referral.specialistNotes);
        }
        if (res.referral.status === 'REVIEW_COMPLETED') {
          setReviewSubmitted(true);
        }
      }
      setLoading(false);
    };
    load();
  }, [id]);

  const handleSubmitReview = async () => {
    if (!id || !user) return;
    setSubmitting(true);
    await specialistService.submitReview(
      id,
      decision,
      specialistNotes || 'Clinical evaluation confirmed. Patient advised to attend district retina clinic for dilated OCT exam.',
      user.name
    );
    setSubmitting(false);
    setReviewSubmitted(true);
  };

  if (loading) {
    return (
      <div className="py-12 text-center text-slate-500 text-sm">
        Loading specialist case review...
      </div>
    );
  }

  if (!data) {
    return (
      <div className="bg-white rounded-2xl p-8 border border-slate-200 text-center max-w-md mx-auto">
        <p className="text-slate-700 font-bold mb-3">Case not found</p>
        <Link to="/specialist" className="text-indigo-700 font-semibold underline text-sm">
          Return to Triage Queue
        </Link>
      </div>
    );
  }

  const { referral, screening, patient, history } = data;

  return (
    <div className="space-y-5 pb-12">
      {/* Top Back Navigation Bar */}
      <div className="flex items-center justify-between">
        <Link
          to="/specialist"
          className="inline-flex items-center gap-1.5 text-xs font-bold text-slate-700 hover:text-slate-950 p-1"
        >
          <ArrowLeft className="w-4 h-4" />
          <span>Back to Triage Queue</span>
        </Link>

        <span className="text-xs font-mono font-bold text-slate-500">
          Referral Ref: {referral.id}
        </span>
      </div>

      {/* Review Completed Confirmation Banner */}
      {reviewSubmitted && (
        <div className="p-4 rounded-2xl bg-emerald-50 border border-emerald-300 flex items-center justify-between gap-3 text-emerald-900">
          <div className="flex items-center gap-2.5">
            <CheckCircle2 className="w-5 h-5 text-emerald-600 flex-shrink-0" />
            <div>
              <span className="font-bold text-sm block">Specialist Review Submitted</span>
              <span className="text-xs text-emerald-800">
                Recommendations transmitted to Rampur Primary Health Centre.
              </span>
            </div>
          </div>
          <span className="text-xs px-2.5 py-1 rounded-lg font-bold bg-emerald-200 text-emerald-900">
            Completed
          </span>
        </div>
      )}

      {/* Main Workstation: 2-Column on Desktop, Stacked on Mobile */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6 items-start">
        {/* LEFT COLUMN: Fundus Visual Inspection & AI Decision Support (7 cols) */}
        <div className="lg:col-span-7 space-y-5">
          {/* Fundus Image Canvas Card */}
          <div className="bg-white rounded-2xl p-5 border border-slate-200 shadow-xs space-y-4">
            <div className="flex items-center justify-between">
              <div>
                <h2 className="text-sm font-bold uppercase tracking-wider text-slate-700">
                  {t('specialist.fundusView')}
                </h2>
                <span className="text-xs text-slate-500">
                  {screening.eye === 'RIGHT' ? 'Right Eye (OD)' : 'Left Eye (OS)'} • {screening.centreName}
                </span>
              </div>
              <StatusBadge status={screening.resultCategory} size="sm" />
            </div>

            {/* High-res Viewport with interactive zoom */}
            <div className="w-full flex justify-center">
              <FundusImage
                src={screening.imageUri}
                alt={`Fundus examination of ${patient.name}`}
                size="full"
                eye={screening.eye}
                isDemoSample={screening.isDemoSample}
                allowZoom={true}
              />
            </div>

            {/* Image Quality Metadata */}
            <div className="p-3 bg-slate-50 rounded-xl border border-slate-200 flex items-center justify-between text-xs">
              <div className="flex items-center gap-2">
                <span className="font-semibold text-slate-700">Quality Check:</span>
                <span className="font-bold text-emerald-700">
                  {screening.qualityStatus === 'PASS' ? 'Pass (High Diagnostic Quality)' : 'Insufficient'}
                </span>
              </div>
              <span className="text-[11px] text-slate-400">
                Compressed for 2G/3G • Original preserved
              </span>
            </div>
          </div>

          {/* AI Decision Support Disclosure (Specialist Exclusive) */}
          <div className="bg-white rounded-2xl p-5 border border-slate-200 shadow-xs space-y-3">
            <button
              type="button"
              onClick={() => setShowAiDetails(!showAiDetails)}
              className="w-full flex items-center justify-between text-left cursor-pointer"
            >
              <div className="flex items-center gap-2 text-indigo-900 font-bold text-sm">
                <Cpu className="w-4 h-4 text-indigo-700" />
                <span>{t('specialist.aiDetailsToggle')}</span>
              </div>
              {showAiDetails ? <ChevronUp className="w-4 h-4 text-slate-500" /> : <ChevronDown className="w-4 h-4 text-slate-500" />}
            </button>

            {showAiDetails && screening.aiDetails && (
              <div className="pt-2 border-t border-slate-100 text-xs space-y-3">
                <div className="grid grid-cols-2 gap-2 p-3 bg-indigo-50/60 rounded-xl border border-indigo-100 text-slate-800">
                  <div>
                    <span className="text-slate-500 block text-[11px]">Model Architecture</span>
                    <span className="font-bold">{screening.aiDetails.modelVersion}</span>
                  </div>
                  <div>
                    <span className="text-slate-500 block text-[11px]">Decision Confidence</span>
                    <span className="font-bold text-indigo-900">{screening.aiDetails.confidenceIndicator}</span>
                  </div>
                </div>

                <div>
                  <span className="font-bold text-slate-800 block mb-1">
                    Detected Pathological Foci:
                  </span>
                  <ul className="space-y-1 text-slate-700">
                    {screening.aiDetails.findings.map((f, i) => (
                      <li key={i} className="flex items-center gap-1.5 font-medium">
                        <span className="w-1.5 h-1.5 rounded-full bg-indigo-600" />
                        <span>{f}</span>
                      </li>
                    ))}
                  </ul>
                </div>

                <div className="p-3 bg-amber-50 rounded-xl border border-amber-200 text-[11px] text-amber-950 flex items-start gap-2">
                  <ShieldCheck className="w-4 h-4 text-amber-700 flex-shrink-0 mt-0.5" />
                  <span>{t('specialist.aiDisclaimer')}</span>
                </div>
              </div>
            )}
          </div>
        </div>

        {/* RIGHT COLUMN: Patient Info, History, & Doctor Review Submission (5 cols) */}
        <div className="lg:col-span-5 space-y-5">
          {/* Patient Details Card */}
          <div className="bg-white rounded-2xl p-5 border border-slate-200 shadow-xs space-y-3">
            <div className="flex items-center gap-2 pb-2 border-b border-slate-100">
              <User className="w-4 h-4 text-slate-500" />
              <h2 className="text-xs font-bold uppercase tracking-wider text-slate-700">
                {t('specialist.patientInfo')}
              </h2>
            </div>

            <div>
              <h3 className="text-lg font-bold text-slate-900 leading-tight">
                {patient.name}
              </h3>
              <p className="text-xs text-slate-500 font-mono">
                ID: {patient.id} • {patient.age} yrs • {patient.sex}
              </p>
            </div>

            <div className="grid grid-cols-2 gap-2 text-xs py-2 border-y border-slate-100 text-slate-700">
              <div>
                <span className="text-slate-400 block text-[11px]">Location</span>
                <span className="font-semibold">{patient.village}</span>
              </div>
              <div>
                <span className="text-slate-400 block text-[11px]">Diabetes History</span>
                <span className="font-semibold">{patient.diabetesStatus.replace('_', ' ')}</span>
              </div>
            </div>

            {/* Health worker referral context */}
            <div className="text-xs text-slate-700 space-y-1">
              <span className="font-bold text-slate-900 block">
                Primary Health Centre Notes:
              </span>
              <p className="p-2.5 bg-slate-50 rounded-lg border border-slate-200 italic">
                "{referral.referralReason}"
              </p>
            </div>
          </div>

          {/* Historical Screenings */}
          <div className="bg-white rounded-2xl p-5 border border-slate-200 shadow-xs space-y-3">
            <div className="flex items-center gap-2 pb-2 border-b border-slate-100">
              <Calendar className="w-4 h-4 text-slate-500" />
              <h2 className="text-xs font-bold uppercase tracking-wider text-slate-700">
                Patient Screening History ({history.length})
              </h2>
            </div>

            <div className="space-y-2">
              {history.map((h) => (
                <div
                  key={h.id}
                  className="p-2.5 rounded-xl border border-slate-200 bg-slate-50 flex items-center justify-between text-xs"
                >
                  <div>
                    <span className="font-bold text-slate-900 block">
                      {h.eye === 'RIGHT' ? 'Right Eye (OD)' : 'Left Eye (OS)'}
                    </span>
                    <span className="text-[11px] text-slate-500">
                      {new Date(h.createdAt).toLocaleDateString()}
                    </span>
                  </div>
                  <StatusBadge status={h.resultCategory} size="sm" />
                </div>
              ))}
            </div>
          </div>

          {/* Specialist Clinical Review Submission Card */}
          <div className="bg-white rounded-2xl p-5 border-2 border-indigo-200 shadow-xs space-y-4">
            <div className="flex items-center gap-2 pb-2 border-b border-slate-100">
              <Stethoscope className="w-5 h-5 text-indigo-700" />
              <h2 className="text-sm font-bold text-slate-900">
                {t('specialist.clinicalNotes')}
              </h2>
            </div>

            {/* Decision selector */}
            <div>
              <label className="block text-xs font-bold uppercase tracking-wider text-slate-700 mb-1.5">
                Clinical Recommendation Action
              </label>
              <div className="space-y-2">
                <button
                  type="button"
                  onClick={() => setDecision('CONFIRMED')}
                  className={`w-full p-2.5 rounded-xl border text-xs font-bold text-left flex items-center justify-between transition-colors ${
                    decision === 'CONFIRMED'
                      ? 'bg-indigo-700 text-white border-indigo-800'
                      : 'bg-slate-50 text-slate-700 border-slate-200 hover:bg-slate-100'
                  }`}
                >
                  <span>{t('specialist.confirmAction')}</span>
                  {decision === 'CONFIRMED' && <CheckCircle2 className="w-4 h-4" />}
                </button>

                <button
                  type="button"
                  onClick={() => setDecision('FOLLOWUP_PRESCRIBED')}
                  className={`w-full p-2.5 rounded-xl border text-xs font-bold text-left flex items-center justify-between transition-colors ${
                    decision === 'FOLLOWUP_PRESCRIBED'
                      ? 'bg-indigo-700 text-white border-indigo-800'
                      : 'bg-slate-50 text-slate-700 border-slate-200 hover:bg-slate-100'
                  }`}
                >
                  <span>{t('specialist.sendRecommendation')}</span>
                  {decision === 'FOLLOWUP_PRESCRIBED' && <CheckCircle2 className="w-4 h-4" />}
                </button>

                <button
                  type="button"
                  onClick={() => setDecision('RETAKE_REQUESTED')}
                  className={`w-full p-2.5 rounded-xl border text-xs font-bold text-left flex items-center justify-between transition-colors ${
                    decision === 'RETAKE_REQUESTED'
                      ? 'bg-yellow-600 text-white border-yellow-700'
                      : 'bg-slate-50 text-slate-700 border-slate-200 hover:bg-slate-100'
                  }`}
                >
                  <span>{t('specialist.requestRetakeAction')}</span>
                  {decision === 'RETAKE_REQUESTED' && <RefreshCw className="w-4 h-4" />}
                </button>
              </div>
            </div>

            {/* Doctor notes */}
            <div>
              <label className="block text-xs font-bold uppercase tracking-wider text-slate-700 mb-1.5">
                Specialist Notes / Prescription for Health Worker
              </label>
              <textarea
                rows={3}
                value={specialistNotes}
                onChange={(e) => setSpecialistNotes(e.target.value)}
                placeholder="e.g. Confirming non-proliferative DR with macular threat. Schedule patient for in-person dilated fundoscopy and OCT within 14 days."
                className="w-full px-3 py-2 text-xs rounded-xl border border-slate-300 text-slate-900 focus:outline-none focus:ring-2 focus:ring-indigo-600"
              />
            </div>

            <PrimaryButton
              onClick={handleSubmitReview}
              disabled={submitting}
              className="w-full bg-indigo-700 hover:bg-indigo-800 border-indigo-800"
            >
              {submitting ? 'Saving Review...' : 'Submit Clinical Evaluation'}
            </PrimaryButton>
          </div>
        </div>
      </div>
    </div>
  );
};
