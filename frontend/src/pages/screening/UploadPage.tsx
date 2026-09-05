import React, { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { useScreeningStore } from '../../stores/screeningStore';
import { useConnectivityStore } from '../../stores/connectivityStore';
import { screeningService, DEMO_KEYS as DEMO_ASSET_KEYS } from '../../services/screeningService';
import { uploadService } from '../../services/uploadService';
import { patientService } from '../../services/patientService';
import { PrimaryButton } from '../../components/ui/PrimaryButton';
import { SecondaryButton } from '../../components/ui/SecondaryButton';
import { StickyActionBar } from '../../components/ui/StickyActionBar';
import { Wifi, WifiOff, CheckCircle2, ShieldCheck, ArrowRight, RefreshCw } from 'lucide-react';

export const UploadPage: React.FC = () => {
  const { id } = useParams<{ id: string }>();
  const { t } = useTranslation();
  const navigate = useNavigate();
  const {
    patient,
    eye,
    imageUri,
    imageKey,
    qualityStatus,
    setScreeningResult,
    setWorkflowState
  } = useScreeningStore();
  const { isOnline, refreshPendingCount } = useConnectivityStore();

  const [progress, setProgress] = useState(15);
  const [stage, setStage] = useState<'INITIALIZING' | 'OPTIMIZING' | 'TRANSMITTING' | 'ANALYZING' | 'DONE' | 'OFFLINE_SAVED' | 'FAILED'>('INITIALIZING');
  const [createdScreeningId, setCreatedScreeningId] = useState<string>('');

  useEffect(() => {
    let timer: NodeJS.Timeout;

    const processFlow = async () => {
      if (!patient || !imageUri) {
        navigate('/dashboard');
        return;
      }

      // Step 1: Compress image on device (reducing 5MB raw capture to ~120KB)
      setStage('OPTIMIZING');
      setProgress(35);
      const optimizedImage = await uploadService.compressImage(imageUri);

      // Analyze via the real pipeline (or deterministic demo data for
      // the bundled demo assets - see screeningService.ts)
      const ai = await screeningService.analyzeScreening(imageKey || undefined, eye, imageUri, {
        patientId: patient.id,
        diabetesControl: patient.diabetesControl,
        diabetesDurationYears: patient.diabetesDurationYears,
        hba1c: patient.hba1c
      });
      setScreeningResult(ai.resultCategory, ai.recommendation, ai.aiDetails);

      if (isOnline) {
        // ONLINE FLOW
        setStage('TRANSMITTING');
        setProgress(65);

        timer = setTimeout(async () => {
          setProgress(85);
          setStage('ANALYZING');

          // Save completed screening to Dexie
          const saved = await screeningService.saveScreening({
            patientId: patient.id,
            eye,
            imageUri: optimizedImage,
            imageKey,
            qualityStatus: qualityStatus || 'PASS',
            workflowState: 'COMPLETED',
            resultCategory: ai.resultCategory,
            resultRecommendation: ai.recommendation,
            synced: true,
            centreName: 'Rampur Primary Health Centre',
            healthWorkerName: 'Suman ASHA',
            isDemoSample: !imageKey || DEMO_ASSET_KEYS.includes(imageKey),
            aiDetails: ai.aiDetails,
            qualityFeatures: ai.qualityFeatures,
            findings: ai.findings,
            severity: ai.severity,
            explainability: ai.explainability,
            segmentationImageUrl: ai.segmentationImageUrl,
            gradCamImageUrl: ai.gradCamImageUrl
          });

          await patientService.updatePatientLastScreening(patient.id, ai.resultCategory);
          setCreatedScreeningId(saved.id);
          setProgress(100);
          setStage('DONE');
        }, 900);
      } else {
        // OFFLINE FLOW: Save to Dexie and add to pending upload queue!
        setStage('OFFLINE_SAVED');
        setProgress(100);

        const saved = await screeningService.saveScreening({
          patientId: patient.id,
          eye,
          imageUri: optimizedImage,
          imageKey,
          qualityStatus: qualityStatus || 'PASS',
          workflowState: 'SAVED_LOCALLY',
          resultCategory: ai.resultCategory,
          resultRecommendation: ai.recommendation,
          synced: false,
          centreName: 'Rampur Primary Health Centre',
          healthWorkerName: 'Suman ASHA',
          isDemoSample: !imageKey || DEMO_ASSET_KEYS.includes(imageKey),
          aiDetails: ai.aiDetails,
          qualityFeatures: ai.qualityFeatures,
          findings: ai.findings,
          severity: ai.severity,
          explainability: ai.explainability,
          segmentationImageUrl: ai.segmentationImageUrl,
          gradCamImageUrl: ai.gradCamImageUrl
        });

        // Add to pending queue
        await uploadService.queueForUpload(saved, patient);
        await refreshPendingCount();
        await patientService.updatePatientLastScreening(patient.id, ai.resultCategory);
        setCreatedScreeningId(saved.id);
        setWorkflowState('SAVED_LOCALLY');
      }
    };

    processFlow();

    return () => clearTimeout(timer);
  }, [isOnline, imageUri, patient]);

  const handleGoToResult = () => {
    navigate(`/screening/${createdScreeningId || id || 'new'}/result`);
  };

  return (
    <div className="space-y-4 pb-24">
      {/* Header Banner */}
      <div className="bg-white rounded-2xl p-4 border border-slate-200 shadow-2xs flex items-center justify-between">
        <div>
          <span className="text-xs font-bold text-slate-500 uppercase">Transmission & Analysis</span>
          <h1 className="text-base font-bold text-slate-900 leading-tight">
            {patient?.name} ({patient?.id})
          </h1>
        </div>
        <span className={`text-xs font-bold px-2.5 py-1 rounded-lg flex items-center gap-1.5 ${
          isOnline ? 'bg-emerald-50 text-emerald-800' : 'bg-amber-50 text-amber-900'
        }`}>
          {isOnline ? <Wifi className="w-3.5 h-3.5" /> : <WifiOff className="w-3.5 h-3.5" />}
          <span>{isOnline ? t('app.online') : t('app.offline')}</span>
        </span>
      </div>

      {/* Main Status Card */}
      <div className="bg-white rounded-2xl p-6 sm:p-8 border border-slate-200 shadow-xs text-center flex flex-col items-center">
        {isOnline ? (
          /* ONLINE FLOW */
          stage === 'DONE' ? (
            <div className="space-y-4 w-full">
              <div className="w-16 h-16 rounded-full bg-emerald-50 text-emerald-600 border-2 border-emerald-200 flex items-center justify-center mx-auto">
                <CheckCircle2 className="w-9 h-9" />
              </div>
              <h2 className="text-xl font-bold text-slate-900">
                Screening Completed
              </h2>
              <p className="text-sm text-slate-600 max-w-sm mx-auto">
                Retinal fundus image safely processed and synchronized with the health centre portal.
              </p>
            </div>
          ) : (
            <div className="space-y-4 w-full">
              <div className="w-14 h-14 rounded-full bg-teal-50 text-brand-700 flex items-center justify-center mx-auto">
                <div className="w-7 h-7 border-3 border-brand-700 border-t-transparent rounded-full animate-spin" />
              </div>

              <div>
                <h2 className="text-xl font-bold text-slate-900">
                  {t('upload.onlineTitle')}
                </h2>
                <p className="text-sm text-slate-600 mt-1">
                  {t('upload.onlineDesc')}
                </p>
              </div>

              {/* Progress Bar */}
              <div className="w-full max-w-xs mx-auto space-y-1.5">
                <div className="w-full bg-slate-100 h-2.5 rounded-full overflow-hidden border border-slate-200">
                  <div
                    className="bg-brand-700 h-full rounded-full transition-all duration-300 ease-out"
                    style={{ width: `${progress}%` }}
                  />
                </div>
                <div className="text-xs font-semibold text-slate-500 text-right">
                  {progress}%
                </div>
              </div>

              {/* Checklist */}
              <div className="max-w-xs mx-auto text-left text-xs space-y-2 pt-2 border-t border-slate-100 text-slate-700">
                <div className="flex items-center gap-2 text-emerald-800 font-semibold">
                  <CheckCircle2 className="w-4 h-4 text-emerald-600" />
                  <span>Image quality checked</span>
                </div>
                <div className="flex items-center gap-2 text-emerald-800 font-semibold">
                  <CheckCircle2 className="w-4 h-4 text-emerald-600" />
                  <span>Low-bandwidth image compressed</span>
                </div>
                <div className="flex items-center gap-2 text-brand-800 font-bold">
                  <span className="w-2 h-2 rounded-full bg-brand-600 animate-pulse" />
                  <span>Cloud screening analysis in progress</span>
                </div>
              </div>
            </div>
          )
        ) : (
          /* OFFLINE FLOW */
          <div className="space-y-4 w-full">
            <div className="w-16 h-16 rounded-full bg-amber-50 text-amber-700 border-2 border-amber-300 flex items-center justify-center mx-auto shadow-2xs">
              <ShieldCheck className="w-9 h-9" />
            </div>

            <div>
              <h2 className="text-xl font-bold text-slate-900">
                {t('upload.offlineTitle')}
              </h2>
              <p className="text-sm text-slate-700 mt-2 max-w-sm mx-auto leading-relaxed">
                {t('upload.offlineDesc')}
              </p>
            </div>

            <div className="p-3.5 bg-amber-50/80 rounded-xl border border-amber-200 text-xs font-semibold text-amber-950 text-left max-w-sm mx-auto space-y-1">
              <div className="flex items-center gap-2">
                <span className="w-2 h-2 rounded-full bg-amber-600" />
                <span>Screening data preserved in device IndexedDB.</span>
              </div>
              <p className="text-[11px] text-amber-800 font-normal">
                You will not need to re-screen the patient or retake the image.
              </p>
            </div>
          </div>
        )}
      </div>

      {/* Sticky Bottom Actions */}
      <StickyActionBar>
        {isOnline ? (
          <PrimaryButton
            disabled={stage !== 'DONE'}
            onClick={handleGoToResult}
            className="w-full"
            icon={ArrowRight}
          >
            {t('upload.viewResults')}
          </PrimaryButton>
        ) : (
          <>
            <SecondaryButton
              onClick={() => navigate('/dashboard')}
              className="flex-1"
            >
              {t('upload.backToDashboard')}
            </SecondaryButton>

            <PrimaryButton
              onClick={handleGoToResult}
              className="flex-1"
              icon={ArrowRight}
            >
              {t('upload.viewResults')}
            </PrimaryButton>
          </>
        )}
      </StickyActionBar>
    </div>
  );
};
