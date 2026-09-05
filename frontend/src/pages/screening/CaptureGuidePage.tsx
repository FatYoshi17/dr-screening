import React, { useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { useScreeningStore } from '../../stores/screeningStore';
import { PrimaryButton } from '../../components/ui/PrimaryButton';
import { SecondaryButton } from '../../components/ui/SecondaryButton';
import { StepIndicator } from '../../components/ui/StepIndicator';
import { StickyActionBar } from '../../components/ui/StickyActionBar';
import { User, Crosshair, Eye, Camera, CheckCircle2, Lightbulb, ArrowRight } from 'lucide-react';

export const CaptureGuidePage: React.FC = () => {
  const { id } = useParams<{ id: string }>();
  const { t } = useTranslation();
  const navigate = useNavigate();
  const { patient, eye } = useScreeningStore();

  const [currentStep, setCurrentStep] = useState(1);
  const totalSteps = 5;

  const steps = [
    {
      title: t('capture.step1Title'),
      desc: t('capture.step1Desc'),
      tip: t('capture.step1Tip'),
      icon: User,
    },
    {
      title: t('capture.step2Title'),
      desc: t('capture.step2Desc'),
      tip: t('capture.step2Tip'),
      icon: Crosshair,
    },
    {
      title: t('capture.step3Title'),
      desc: t('capture.step3Desc'),
      tip: t('capture.step3Tip'),
      icon: Eye,
    },
    {
      title: t('capture.step4Title'),
      desc: t('capture.step4Desc'),
      tip: t('capture.step4Tip'),
      icon: Camera,
    },
    {
      title: t('capture.step5Title'),
      desc: t('capture.step5Desc'),
      tip: t('capture.step5Tip'),
      icon: CheckCircle2,
    },
  ];

  const active = steps[currentStep - 1];
  const StepIcon = active.icon;

  const handleNext = () => {
    if (currentStep < totalSteps) {
      setCurrentStep(currentStep + 1);
    } else {
      navigate(`/screening/${id || patient?.id || 'new'}/capture`);
    }
  };

  const handleSkip = () => {
    navigate(`/screening/${id || patient?.id || 'new'}/capture`);
  };

  return (
    <div className="pb-24 space-y-4">
      {/* Patient header */}
      <div className="flex items-center justify-between text-xs text-slate-600 bg-white p-3 rounded-xl border border-slate-200">
        <span className="font-bold text-slate-900">{patient?.name || 'Screening'}</span>
        <span className="font-semibold text-brand-700">
          {eye === 'RIGHT' ? t('capture.rightEye') : t('capture.leftEye')}
        </span>
      </div>

      <StepIndicator
        currentStep={currentStep}
        totalSteps={totalSteps}
        title={t('capture.guidanceTitle')}
      />

      {/* Current Step Card */}
      <div className="bg-white rounded-2xl p-6 sm:p-8 border border-slate-200 shadow-xs text-center flex flex-col items-center">
        {/* Step Icon Illustration Circle */}
        <div className="w-20 h-20 sm:w-24 sm:h-24 rounded-full bg-teal-50 border-2 border-brand-200 flex items-center justify-center text-brand-700 mb-5 shadow-2xs">
          <StepIcon className="w-10 h-10 sm:w-12 sm:h-12" />
        </div>

        <h2 className="text-xl sm:text-2xl font-bold text-slate-900 tracking-tight mb-2">
          {active.title}
        </h2>

        <p className="text-base text-slate-700 max-w-sm mx-auto leading-relaxed mb-6">
          {active.desc}
        </p>

        {/* Actionable Clinical Tip Box */}
        <div className="w-full max-w-sm p-3.5 rounded-xl bg-amber-50/80 border border-amber-200 text-left flex items-start gap-2.5">
          <Lightbulb className="w-5 h-5 text-amber-700 flex-shrink-0 mt-0.5" />
          <p className="text-xs text-amber-950 font-medium leading-normal">
            {active.tip}
          </p>
        </div>
      </div>

      {/* Sticky Bottom Actions */}
      <StickyActionBar>
        <SecondaryButton
          onClick={handleSkip}
          className="flex-1"
        >
          Skip Guidance
        </SecondaryButton>

        <PrimaryButton
          onClick={handleNext}
          className="flex-2"
          icon={ArrowRight}
        >
          {currentStep === totalSteps ? 'Ready to Capture' : t('app.next')}
        </PrimaryButton>
      </StickyActionBar>
    </div>
  );
};
