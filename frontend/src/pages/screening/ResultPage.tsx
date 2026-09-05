import React, { useEffect, useState } from 'react';
import { useNavigate, useParams, Link } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { useScreeningStore } from '../../stores/screeningStore';
import { screeningService } from '../../services/screeningService';
import { patientService } from '../../services/patientService';
import { PrimaryButton } from '../../components/ui/PrimaryButton';
import { SecondaryButton } from '../../components/ui/SecondaryButton';
import { StickyActionBar } from '../../components/ui/StickyActionBar';
import { StatusBadge } from '../../components/ui/StatusBadge';
import { FundusImage } from '../../components/ui/FundusImage';
import {
  CheckCircle,
  AlertTriangle,
  AlertCircle,
  RefreshCw,
  FileText,
  Share2,
  Calendar,
  Eye,
  Info
} from 'lucide-react';
import type { ScreeningRecord, PatientRecord } from '../../types';

export const ResultPage: React.FC = () => {
  const { id } = useParams<{ id: string }>();
  const { t } = useTranslation();
  const navigate = useNavigate();
  const store = useScreeningStore();

  const [screening, setScreening] = useState<ScreeningRecord | null>(null);
  const [patient, setPatient] = useState<PatientRecord | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const load = async () => {
      setLoading(true);
      // Try to load from DB if id is provided
      if (id && id !== 'new') {
        const scr = await screeningService.getScreeningById(id);
        if (scr) {
          setScreening(scr);
          const p = await patientService.getPatientById(scr.patientId);
          if (p) setPatient(p);
          setLoading(false);
          return;
        }
      }

      // Otherwise fallback to store state
      if (store.patient && store.resultCategory) {
        setPatient(store.patient);
        setScreening({
          id: id || 'SCR-2026-09105',
          patientId: store.patient.id,
          eye: store.eye,
          imageUri: store.imageUri || '/src/assets/demo/fundus-review.jpg',
          imageKey: store.imageKey || 'fundus-review',
          qualityStatus: store.qualityStatus || 'PASS',
          workflowState: store.workflowState,
          resultCategory: store.resultCategory,
          resultRecommendation: store.resultRecommendation || 'Follow up recommended.',
          createdAt: new Date().toISOString(),
          synced: true,
          centreName: 'Rampur Primary Health Centre',
          healthWorkerName: 'Suman ASHA',
          isDemoSample: true,
          aiDetails: store.aiDetails || undefined
        });
      }
      setLoading(false);
    };
    load();
  }, [id, store]);

  if (loading) {
    return (
      <div className="py-12 text-center text-slate-500 text-sm">
        Loading screening result...
      </div>
    );
  }

  if (!screening || !patient) {
    return (
      <div className="bg-white rounded-2xl p-6 border border-slate-200 text-center">
        <p className="text-slate-700 font-bold mb-3">Screening result not found</p>
        <Link to="/dashboard" className="text-brand-700 font-semibold underline text-sm">
          Return to Dashboard
        </Link>
      </div>
    );
  }

  const category = screening.resultCategory;

  const resultTheme = {
    ROUTINE: {
      bg: 'bg-emerald-50/80',
      border: 'border-emerald-300',
      icon: CheckCircle,
      iconColor: 'text-emerald-700',
      title: t('status.routine'),
      description: t('status.routineDesc'),
      action: t('status.routineNext'),
    },
    REVIEW: {
      bg: 'bg-amber-50/80',
      border: 'border-amber-300',
      icon: AlertTriangle,
      iconColor: 'text-amber-700',
      title: t('status.review'),
      description: t('status.reviewDesc'),
      action: t('status.reviewNext'),
    },
    PRIORITY: {
      bg: 'bg-rose-50/80',
      border: 'border-rose-300',
      icon: AlertCircle,
      iconColor: 'text-rose-700',
      title: t('status.priority'),
      description: t('status.priorityDesc'),
      action: t('status.priorityNext'),
    },
    RETAKE: {
      bg: 'bg-yellow-50/80',
      border: 'border-yellow-400',
      icon: RefreshCw,
      iconColor: 'text-yellow-800',
      title: t('status.retake'),
      description: t('status.retakeDesc'),
      action: t('status.retakeNext'),
    },
  }[category];

  const ResultIcon = resultTheme.icon;

  const handleGenerateReport = () => {
    navigate(`/screening/${screening.id}/report`);
  };

  const handleCreateReferral = () => {
    navigate(`/referral/new/${screening.id}`);
  };

  const handleRetake = () => {
    navigate(`/screening/${patient.id}/capture`);
  };

  return (
    <div className="space-y-4 pb-24">
      {/* Patient & Exam Metadata */}
      <div className="bg-white rounded-2xl p-4 border border-slate-200 shadow-2xs">
        <div className="flex items-start justify-between">
          <div>
            <span className="text-xs font-bold text-slate-500 uppercase tracking-wider block">
              {t('result.title')}
            </span>
            <h1 className="text-lg font-bold text-slate-900 mt-0.5">
              {patient.name}
            </h1>
            <p className="text-xs text-slate-500">
              ID: {patient.id} • {patient.age} yrs • {patient.sex}
            </p>
          </div>

          <div className="text-right">
            <span className="text-xs font-bold text-slate-700 block">
              {screening.eye === 'RIGHT' ? 'Right Eye (OD)' : 'Left Eye (OS)'}
            </span>
            <span className="text-[11px] text-slate-500 flex items-center gap-1 justify-end mt-0.5">
              <Calendar className="w-3 h-3" />
              {new Date(screening.createdAt).toLocaleDateString()}
            </span>
          </div>
        </div>
      </div>

      {/* Main Result Card */}
      <div className={`rounded-2xl p-6 border-2 shadow-xs text-center flex flex-col items-center ${resultTheme.bg} ${resultTheme.border}`}>
        {/* Status Icon */}
        <div className={`w-16 h-16 rounded-full bg-white flex items-center justify-center shadow-2xs mb-3 ${resultTheme.iconColor}`}>
          <ResultIcon className="w-9 h-9" />
        </div>

        {/* Title */}
        <h2 className="text-2xl font-extrabold tracking-tight text-slate-900">
          {resultTheme.title}
        </h2>

        {/* Clinical Plain-Language Meaning */}
        <p className="text-sm font-semibold text-slate-800 max-w-sm mx-auto mt-2 leading-relaxed">
          {resultTheme.description}
        </p>

        {/* Actionable Next Step Box */}
        <div className="mt-4 p-3.5 rounded-xl bg-white/90 border border-slate-200/80 text-left w-full max-w-sm">
          <span className="text-[10px] font-bold uppercase tracking-wider text-slate-500 block mb-0.5">
            Recommended Action
          </span>
          <p className="text-xs font-bold text-slate-900 leading-normal">
            {screening.resultRecommendation || resultTheme.action}
          </p>
        </div>

        {/* Non-diagnostic safety disclaimer */}
        <div className="mt-4 flex items-center gap-1.5 text-[11px] text-slate-600 max-w-xs text-left">
          <Info className="w-3.5 h-3.5 text-slate-500 flex-shrink-0" />
          <span>{t('result.nonDiagnosticNotice')}</span>
        </div>
      </div>

      {/* Fundus Preview Thumbnail */}
      <div className="bg-white rounded-2xl p-4 border border-slate-200 shadow-2xs flex items-center justify-between">
        <div className="flex items-center gap-3">
          <FundusImage
            src={screening.imageUri}
            alt={`${patient.name} screening photo`}
            size="thumb"
            eye={screening.eye}
            allowZoom={true}
          />
          <div>
            <span className="text-xs font-bold text-slate-900 block">
              Captured Fundus View
            </span>
            <span className="text-[11px] text-slate-500">
              Verified clear quality • Ready for specialist review
            </span>
          </div>
        </div>

        <StatusBadge status={category} size="sm" showLabel={false} />
      </div>

      {/* Sticky Bottom Actions */}
      <StickyActionBar>
        {category === 'ROUTINE' && (
          <PrimaryButton
            onClick={handleGenerateReport}
            className="w-full"
            icon={FileText}
          >
            {t('result.generateReport')}
          </PrimaryButton>
        )}

        {category === 'REVIEW' && (
          <>
            <SecondaryButton
              onClick={handleGenerateReport}
              className="flex-1"
              icon={FileText}
            >
              {t('result.generateReport')}
            </SecondaryButton>

            <PrimaryButton
              onClick={handleCreateReferral}
              className="flex-2"
              icon={Share2}
            >
              {t('result.referForReview')}
            </PrimaryButton>
          </>
        )}

        {category === 'PRIORITY' && (
          <>
            <SecondaryButton
              onClick={handleGenerateReport}
              className="flex-1"
              icon={FileText}
            >
              {t('result.generateReport')}
            </SecondaryButton>

            <PrimaryButton
              onClick={handleCreateReferral}
              className="flex-2 bg-rose-700 hover:bg-rose-800 border-rose-800 text-white"
              icon={AlertCircle}
            >
              {t('result.createPriorityReferral')}
            </PrimaryButton>
          </>
        )}

        {category === 'RETAKE' && (
          <PrimaryButton
            onClick={handleRetake}
            className="w-full"
            icon={RefreshCw}
          >
            {t('result.captureAgain')}
          </PrimaryButton>
        )}
      </StickyActionBar>
    </div>
  );
};
