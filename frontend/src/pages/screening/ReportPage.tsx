import React, { useEffect, useState } from 'react';
import { useParams, useNavigate, Link } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { screeningService } from '../../services/screeningService';
import { patientService } from '../../services/patientService';
import { StatusBadge } from '../../components/ui/StatusBadge';
import { FundusImage } from '../../components/ui/FundusImage';
import { ReportSection } from '../../components/ui/ReportSection';
import { InfoGrid } from '../../components/ui/InfoGrid';
import { FindingsTable } from '../../components/ui/FindingsTable';
import { Printer, Share2, ArrowLeft, CheckCircle2, AlertTriangle } from 'lucide-react';
import type { ScreeningRecord, PatientRecord } from '../../types';

const recommendationTone: Record<string, { bg: string; border: string; text: string; icon: React.ReactNode }> = {
  ROUTINE: {
    bg: 'bg-emerald-50', border: 'border-emerald-300', text: 'text-emerald-900',
    icon: <CheckCircle2 className="w-4 h-4 text-emerald-700" />,
  },
  REVIEW: {
    bg: 'bg-amber-50', border: 'border-amber-300', text: 'text-amber-900',
    icon: <AlertTriangle className="w-4 h-4 text-amber-700" />,
  },
  PRIORITY: {
    bg: 'bg-rose-50', border: 'border-rose-300', text: 'text-rose-900',
    icon: <AlertTriangle className="w-4 h-4 text-rose-700" />,
  },
};

const getDemoReportData = (screening: ScreeningRecord): ScreeningRecord => {
  const isPriority = screening.resultCategory === 'PRIORITY';
  const isReview = screening.resultCategory === 'REVIEW';
  const isRetake = screening.resultCategory === 'RETAKE';

  return {
    ...screening,
    qualityFeatures: screening.qualityFeatures?.length ? screening.qualityFeatures : [
      { name: 'Illumination', score: isRetake ? 0.48 : 0.91, assessment: isRetake ? 'Poor' : 'Good' },
      { name: 'Focus / sharpness', score: isRetake ? 0.42 : isReview ? 0.76 : 0.94, assessment: isRetake ? 'Poor' : isReview ? 'Acceptable' : 'Good' },
      { name: 'Field of view', score: isRetake ? 0.56 : 0.89, assessment: isRetake ? 'Acceptable' : 'Good' },
      { name: 'Artifact control', score: isRetake ? 0.45 : 0.93, assessment: isRetake ? 'Poor' : 'Good' },
    ],
    findings: screening.findings?.length ? screening.findings : isPriority ? [
      { lesionType: 'Blot hemorrhages', count: 8, location: 'All quadrants', confidence: 0.94 },
      { lesionType: 'Hard exudates', count: 5, location: 'Posterior pole', confidence: 0.90 },
      { lesionType: 'Neovascularization', count: 1, location: 'Optic disc', confidence: 0.87 },
    ] : isReview ? [
      { lesionType: 'Microaneurysms', count: 4, location: 'Temporal macula', confidence: 0.82 },
      { lesionType: 'Hard exudates', count: 2, location: 'Outside fovea', confidence: 0.76 },
      { lesionType: 'Venous dilation', count: 1, location: 'Inferior arcade', confidence: 0.71 },
    ] : isRetake ? [
      { lesionType: 'Image artifact', count: 1, location: 'Full field', confidence: 0.93 },
    ] : [
      { lesionType: 'No detected lesion', count: 0, location: 'Posterior pole', confidence: 0.96 },
    ],
    severity: screening.severity || {
      icdrGrade: isPriority ? 4 : isReview ? 2 : isRetake ? 5 : 0,
      gradeLabel: isPriority ? 'Proliferative DR' : isReview ? 'Moderate NPDR' : isRetake ? 'Ungradable' : 'No DR',
      referable: isPriority || isReview,
      gradingPathway: 'cnn',
      agreement: !isPriority,
    },
    explainability: screening.explainability || {
      calibratedConfidence: isPriority ? 0.91 : isReview ? 0.82 : isRetake ? 0.68 : 0.95,
      lesionAttentionOverlap: isPriority ? 0.88 : isReview ? 0.74 : isRetake ? 0.41 : 0.92,
      flagged: isPriority || isRetake,
      flagReason: isPriority ? 'High-risk lesion pattern requires specialist confirmation.' : isRetake ? 'Image quality limits reliable lesion localization.' : undefined,
    },
  };
};

export const ReportPage: React.FC = () => {
  const { id } = useParams<{ id: string }>();
  const { t } = useTranslation();
  const navigate = useNavigate();

  const [screening, setScreening] = useState<ScreeningRecord | null>(null);
  const [patient, setPatient] = useState<PatientRecord | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const load = async () => {
      if (!id) return;
      setLoading(true);
      const scr = await screeningService.getScreeningById(id);
      if (scr) {
        setScreening(scr);
        const p = await patientService.getPatientById(scr.patientId);
        if (p) setPatient(p);
      }
      setLoading(false);
    };
    load();
  }, [id]);

  const handlePrint = () => window.print();

  if (loading) {
    return <div className="py-12 text-center text-slate-500 text-sm">Generating screening report...</div>;
  }

  if (!screening || !patient) {
    return (
      <div className="bg-white rounded-2xl p-6 border border-slate-200 text-center">
        <p className="text-slate-700 font-bold mb-3">Report record not found</p>
        <Link to="/dashboard" className="text-brand-700 font-semibold underline text-sm">
          Return to Dashboard
        </Link>
      </div>
    );
  }

  const reportScreening = getDemoReportData(screening);
  const tone = recommendationTone[reportScreening.resultCategory] ?? recommendationTone.ROUTINE;

  return (
    <div className="space-y-4 pb-12">
      {/* Toolbar — hidden during print */}
      <div className="no-print flex items-center justify-between bg-white p-3 rounded-2xl border border-slate-200 shadow-2xs">
        <button type="button" onClick={() => navigate(-1)}
          className="flex items-center gap-1.5 text-xs font-bold text-slate-700 hover:text-slate-900 p-2">
          <ArrowLeft className="w-4 h-4" />
          <span>{t('app.back')}</span>
        </button>
        <div className="flex items-center gap-2">
          {(reportScreening.resultCategory === 'REVIEW' || reportScreening.resultCategory === 'PRIORITY') && (
            <button type="button" onClick={() => navigate(`/referral/new/${reportScreening.id}`)}
              className="px-3 py-2 rounded-xl bg-brand-700 text-white text-xs font-bold flex items-center gap-1.5 hover:bg-brand-800 transition-colors cursor-pointer">
              <Share2 className="w-3.5 h-3.5" />
              <span>{t('report.referPatient')}</span>
            </button>
          )}
          <button type="button" onClick={handlePrint}
            className="px-3.5 py-2 rounded-xl bg-slate-100 hover:bg-slate-200 text-slate-800 text-xs font-bold flex items-center gap-1.5 transition-colors cursor-pointer">
            <Printer className="w-4 h-4" />
            <span>{t('report.print')}</span>
          </button>
        </div>
      </div>

      {/* Printable clinical report */}
      <div className="print-page bg-white rounded-2xl p-6 sm:p-8 border border-slate-300 shadow-xs space-y-7">
        {/* Header */}
        <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center pb-5 border-b-2 border-slate-800 gap-4">
          <div className="flex items-center gap-3">
            <div className="w-12 h-12 rounded-xl bg-brand-800 text-white flex items-center justify-center font-bold text-xl shadow-xs">
              DS
            </div>
            <div>
              <h1 className="text-xl font-extrabold text-slate-900 tracking-tight">{t('report.title')}</h1>
              <p className="text-xs font-semibold text-brand-800">{reportScreening.centreName}</p>
              <p className="text-[11px] text-slate-400 italic">AI-Assisted Automated Fundus Analysis</p>
            </div>
          </div>
          <div className="text-left sm:text-right text-xs text-slate-600 space-y-0.5">
            <p className="font-bold text-slate-900">Report ID: REP-{reportScreening.id}</p>
            <p>Date: {new Date(reportScreening.createdAt).toLocaleDateString()}</p>
            <p>Examined by: {reportScreening.healthWorkerName}</p>
          </div>
        </div>

        {/* Patient demographics */}
        <InfoGrid
          fields={[
            { label: t('report.patientName'), value: patient.name },
            { label: t('report.patientId'), value: patient.id },
            { label: t('report.ageSex'), value: `${patient.age} yrs / ${patient.sex}` },
            { label: t('report.village'), value: patient.village },
          ]}
        />

        {/* Section 1 — Image Quality */}
        {reportScreening.qualityFeatures && (
          <ReportSection number="1" title={t('report.imageQualityAssessment')}>
            <div className="overflow-hidden rounded-xl border border-slate-300">
              <table className="w-full text-xs">
                <thead>
                  <tr className="bg-slate-800 text-white">
                    <th className="text-left font-bold px-3 py-2">{t('report.feature')}</th>
                    <th className="text-left font-bold px-3 py-2">{t('report.score')}</th>
                    <th className="text-left font-bold px-3 py-2">{t('report.assessment')}</th>
                  </tr>
                </thead>
                <tbody>
                  {reportScreening.qualityFeatures.map((f, i) => (
                    <tr key={f.name} className={i % 2 ? 'bg-slate-50' : 'bg-white'}>
                      <td className="px-3 py-2 font-bold text-slate-900">{f.name}</td>
                      <td className="px-3 py-2 text-slate-700">{f.score.toFixed(2)}</td>
                      <td className={`px-3 py-2 font-semibold ${
                        f.assessment === 'Good' ? 'text-emerald-700'
                        : f.assessment === 'Acceptable' ? 'text-amber-700' : 'text-rose-700'
                      }`}>{f.assessment === 'Good' ? t('report.qualityGood') : f.assessment === 'Acceptable' ? t('report.qualityAcceptable') : t('report.qualityPoor')}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            <div className="inline-block px-4 py-1.5 rounded-lg border-2 font-bold text-xs"
              style={{
                borderColor: reportScreening.qualityStatus === 'PASS' ? '#059669' : '#dc2626',
                color: reportScreening.qualityStatus === 'PASS' ? '#059669' : '#dc2626',
                background: reportScreening.qualityStatus === 'PASS' ? '#ecfdf5' : '#fef2f2',
              }}>
              {t('report.overallQuality')}: {reportScreening.qualityStatus === 'PASS' ? t('report.qualityPass') : t('report.qualityReject')}
            </div>
          </ReportSection>
        )}

        {/* Section 2 — Retinal findings */}
        <ReportSection number="2" title={t('report.retinalFindings')}>
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-6 items-start">
            <div className="space-y-2">
              <div className="rounded-xl overflow-hidden border border-slate-300">
                <FundusImage src={reportScreening.imageUri} alt="Report fundus image" size="preview"
                  eye={reportScreening.eye} allowZoom={false} />
              </div>
              <p className="text-[10px] text-slate-400 text-center">
                {reportScreening.eye === 'RIGHT' ? t('report.rightEye') : t('report.leftEye')}
              </p>
            </div>
            {reportScreening.findings && <FindingsTable findings={reportScreening.findings} />}
          </div>
        </ReportSection>

        {/* Section 3 — Severity */}
        {reportScreening.severity && (
          <ReportSection number="3" title={t('report.drSeverityAssessment')}>
            <InfoGrid
              fields={[
                { label: t('report.icdrSeverityGrade'), value: `Grade ${reportScreening.severity.icdrGrade} - ${reportScreening.severity.gradeLabel}` },
                { label: t('report.referableDr'), value: reportScreening.severity.referable ? 'YES' : 'NO', emphasis: reportScreening.severity.referable ? 'danger' : 'success' },
                { label: t('report.gradingPathway'), value: reportScreening.severity.gradingPathway === 'cnn' ? t('report.cnn') : t('report.ruleBased') },
                { label: t('report.ruleCnnAgreement'), value: reportScreening.severity.agreement ? t('report.agree') : t('report.disagreementFlagged'), emphasis: reportScreening.severity.agreement ? 'success' : 'warning' },
              ]}
              columns={4}
            />
          </ReportSection>
        )}

        {/* Section 4 — Explainability */}
        {reportScreening.explainability && (
          <ReportSection number="4" title={t('report.modelConfidenceExplainability')}>
            <InfoGrid
              fields={[
                { label: t('report.calibratedConfidence'), value: `${(reportScreening.explainability.calibratedConfidence * 100).toFixed(0)}%` },
                { label: t('report.lesionAttentionOverlap'), value: reportScreening.explainability.lesionAttentionOverlap.toFixed(2) },
                { label: t('report.reviewFlagStatus'), value: reportScreening.explainability.flagged ? t('report.flagged') : t('report.notFlagged'), emphasis: reportScreening.explainability.flagged ? 'warning' : 'success' },
                { label: t('report.gradCamAttention'), value: reportScreening.explainability.flagged ? t('report.attachedFusion') : t('report.notShownDefault') },
              ]}
              columns={4}
            />
          </ReportSection>
        )}

        {/* Section 5 — Recommendation */}
        <ReportSection number="5" title={t('report.recommendation')}>
          <StatusBadge status={reportScreening.resultCategory} size="lg" />
          <div className={`p-3.5 rounded-xl border ${tone.bg} ${tone.border} mt-2`}>
            <span className="text-[11px] font-bold text-slate-500 uppercase block mb-1">
              {t('report.recommendedPlan')}
            </span>
            <p className={`text-sm font-semibold leading-relaxed ${tone.text}`}>
              {reportScreening.resultRecommendation}
            </p>
          </div>
          <div className="text-xs text-slate-600 space-y-1 bg-teal-50/60 p-3 rounded-xl border border-teal-200 mt-2">
            <div className="font-bold text-brand-900 flex items-center gap-1.5">
              {tone.icon}
              <span>{t('report.protocolVerified')}</span>
            </div>
            <p className="text-[11px] text-slate-700">
              {t('report.protocolDescription')}
            </p>
          </div>
        </ReportSection>

        {/* Disclaimer */}
        <p className="text-[10px] text-slate-400 italic pt-4 border-t border-slate-200 leading-relaxed">
          {t('report.aiDisclaimer')}
        </p>

        {/* Sign-off */}
        <div className="pt-4 flex justify-between items-end text-xs text-slate-600">
          <p className="text-[11px] text-slate-400 max-w-sm">
            {t('report.specialistReferralNote')}
          </p>
          <div className="text-center w-48">
            <div className="border-b border-slate-400 h-10 mb-1" />
            <span className="font-bold text-slate-800 block text-xs">{reportScreening.healthWorkerName}</span>
            <span className="text-[11px] text-slate-500">{t('report.signature')}</span>
          </div>
        </div>
      </div>
    </div>
  );
};