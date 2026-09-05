import React, { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { useScreeningStore } from '../../stores/screeningStore';
import { screeningService, DEMO_KEYS } from '../../services/screeningService';
import { PrimaryButton } from '../../components/ui/PrimaryButton';
import { SecondaryButton } from '../../components/ui/SecondaryButton';
import { StickyActionBar } from '../../components/ui/StickyActionBar';
import { FundusImage } from '../../components/ui/FundusImage';
import { CheckCircle2, AlertTriangle, ArrowRight, RefreshCw, Eye, Lightbulb } from 'lucide-react';
import type { QualityStatus } from '../../types';

export const QualityPage: React.FC = () => {
  const { id } = useParams<{ id: string }>();
  const { t } = useTranslation();
  const navigate = useNavigate();
  const {
    patient,
    eye,
    imageUri,
    imageKey,
    setQualityResult,
    qualityStatus,
    qualityReason,
    qualityTip
  } = useScreeningStore();

  const [evaluating, setEvaluating] = useState(true);

  const isDemoSample = !!imageKey && DEMO_KEYS.includes(imageKey);

  useEffect(() => {
    const check = async () => {
      setEvaluating(true);
      // Demo scenarios: simulate a fast on-device check for consistent
      // pacing. Real captures run the actual pipeline's quality gate below,
      // which takes as long as it takes - no artificial delay.
      if (isDemoSample) {
        await new Promise((res) => setTimeout(res, 350));
      }
      const res = await screeningService.evaluateImageQuality(
        imageKey || undefined,
        isDemoSample ? undefined : imageUri || undefined,
        patient
          ? {
              patientId: patient.id,
              diabetesControl: patient.diabetesControl,
              diabetesDurationYears: patient.diabetesDurationYears,
              hba1c: patient.hba1c
            }
          : undefined
      );
      setQualityResult(res.status, res.reason, res.tip);
      setEvaluating(false);
    };
    check();
  }, [imageKey, imageUri, isDemoSample, patient, setQualityResult]);

  const handleContinue = () => {
    navigate(`/screening/${id || patient?.id || 'new'}/upload`);
  };

  const handleRetake = () => {
    navigate(`/screening/${id || patient?.id || 'new'}/capture`);
  };

  const isPass = qualityStatus === 'PASS';

  return (
    <div className="space-y-4 pb-24">
      {/* Patient info */}
      <div className="bg-white rounded-2xl p-4 border border-slate-200 shadow-2xs flex items-center justify-between">
        <div>
          <span className="text-xs font-bold text-slate-500 uppercase">Quality Verification</span>
          <h1 className="text-base font-bold text-slate-900 leading-tight">
            {patient?.name} • {eye === 'RIGHT' ? 'Right Eye (OD)' : 'Left Eye (OS)'}
          </h1>
        </div>
        <span className="text-xs font-semibold text-slate-600 bg-slate-100 px-2.5 py-1 rounded-lg">
          Step 4 of 5
        </span>
      </div>

      {/* Quality Assessment Card */}
      <div className="bg-white rounded-2xl p-5 border border-slate-200 shadow-xs flex flex-col items-center">
        {/* Retinal Thumbnail / Image preview */}
        {imageUri && (
          <div className="w-full max-w-xs mb-5">
            <FundusImage
              src={imageUri}
              alt="Quality evaluation preview"
              size="preview"
              eye={eye}
              isDemoSample={isDemoSample}
              allowZoom={true}
            />
          </div>
        )}

        {evaluating ? (
          <div className="py-6 text-center space-y-3">
            <div className="w-10 h-10 border-3 border-brand-700 border-t-transparent rounded-full animate-spin mx-auto" />
            <p className="text-sm font-semibold text-slate-700">
              {t('quality.checking')}
            </p>
          </div>
        ) : isPass ? (
          /* PASS STATE */
          <div className="w-full text-center space-y-3">
            <div className="w-16 h-16 rounded-full bg-emerald-50 text-emerald-600 border-2 border-emerald-200 flex items-center justify-center mx-auto shadow-2xs">
              <CheckCircle2 className="w-8 h-8" />
            </div>

            <h2 className="text-xl font-bold text-emerald-950">
              {t('quality.passTitle')}
            </h2>

            <p className="text-sm text-slate-600 max-w-sm mx-auto leading-relaxed">
              {qualityReason || t('quality.passDesc')}
            </p>

            {isDemoSample && (
              <div className="p-3 bg-emerald-50/60 rounded-xl border border-emerald-200 text-xs text-emerald-900 font-medium text-left flex items-center gap-2">
                <Eye className="w-4 h-4 text-emerald-700 flex-shrink-0" />
                <span>Optic disc, retinal arterioles, and foveal landmarks are distinct.</span>
              </div>
            )}
          </div>
        ) : (
          /* FAIL / RETAKE STATE */
          <div className="w-full text-center space-y-3">
            <div className="w-16 h-16 rounded-full bg-amber-50 text-amber-600 border-2 border-amber-300 flex items-center justify-center mx-auto shadow-2xs">
              <AlertTriangle className="w-8 h-8" />
            </div>

            <h2 className="text-xl font-bold text-amber-950">
              {t('quality.failTitle')}
            </h2>

            <p className="text-sm text-slate-700 max-w-sm mx-auto leading-relaxed">
              {qualityReason || 'The retinal structures cannot be evaluated with sufficient confidence.'}
            </p>

            {qualityTip && (
              <div className="p-3.5 bg-amber-50 rounded-xl border border-amber-200 text-left flex items-start gap-2.5">
                <Lightbulb className="w-5 h-5 text-amber-700 flex-shrink-0 mt-0.5" />
                <p className="text-xs text-amber-950 font-medium">
                  {qualityTip}
                </p>
              </div>
            )}
          </div>
        )}
      </div>

      {/* Sticky Bottom Actions */}
      <StickyActionBar>
        {isPass ? (
          <>
            <SecondaryButton
              onClick={handleRetake}
              className="flex-1"
              icon={RefreshCw}
            >
              {t('capture.captureAgain')}
            </SecondaryButton>

            <PrimaryButton
              onClick={handleContinue}
              className="flex-2"
              icon={ArrowRight}
            >
              {t('quality.continue')}
            </PrimaryButton>
          </>
        ) : (
          <PrimaryButton
            onClick={handleRetake}
            className="w-full"
            icon={RefreshCw}
          >
            {t('capture.captureAgain')}
          </PrimaryButton>
        )}
      </StickyActionBar>
    </div>
  );
};
