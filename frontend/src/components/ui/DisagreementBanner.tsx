import React from 'react';
import { useTranslation } from 'react-i18next';
import { AlertTriangle } from 'lucide-react';

interface DisagreementBannerProps {
  reason?: string;
}

// Shown only when the rule-based and CNN grading pathways disagree
// (explainability.flagged) - matches generateAnnotatedReport.m's PDF
// banner (red background, not the InfoGrid's amber text treatment used
// elsewhere), since this is the case where automated opinions genuinely
// conflict and a specialist needs to see both, not a single blended number.
export const DisagreementBanner: React.FC<DisagreementBannerProps> = ({ reason }) => {
  const { t } = useTranslation();
  return (
    <div className="flex items-start gap-2 p-3.5 rounded-xl border border-rose-300 bg-rose-50 mt-2">
      <AlertTriangle className="w-5 h-5 text-rose-600 flex-shrink-0 mt-0.5" />
      <div>
        <p className="text-sm font-bold text-rose-900">
          {t('report.disagreementBannerTitle')}
        </p>
        <p className="text-xs text-rose-800 mt-0.5">
          {reason || t('report.disagreementBannerDefault')}
        </p>
      </div>
    </div>
  );
};
