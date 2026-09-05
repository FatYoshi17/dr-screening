import React from 'react';
import { useTranslation } from 'react-i18next';

interface StepIndicatorProps {
  currentStep: number;
  totalSteps: number;
  title?: string;
}

export const StepIndicator: React.FC<StepIndicatorProps> = ({
  currentStep,
  totalSteps,
  title,
}) => {
  const { t } = useTranslation();
  const percentage = Math.round((currentStep / totalSteps) * 100);

  return (
    <div className="w-full mb-4">
      <div className="flex justify-between items-center text-xs font-semibold text-slate-600 mb-1.5">
        <span>{t('app.stepOf', { current: currentStep, total: totalSteps })}</span>
        {title && <span className="text-slate-900 font-medium">{title}</span>}
      </div>
      <div className="w-full bg-slate-200 h-2 rounded-full overflow-hidden" role="progressbar" aria-valuenow={currentStep} aria-valuemin={1} aria-valuemax={totalSteps}>
        <div
          className="bg-brand-700 h-full rounded-full transition-all duration-300 ease-out"
          style={{ width: `${percentage}%` }}
        />
      </div>
    </div>
  );
};
