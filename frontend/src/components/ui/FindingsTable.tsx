import React from 'react';
import { useTranslation } from 'react-i18next';
import type { LesionFinding } from '../../types';

interface FindingsTableProps {
  findings: LesionFinding[];
}

const confidenceClass = (confidence: number) => {
  if (confidence >= 0.85) return 'text-emerald-700';
  if (confidence >= 0.7) return 'text-amber-700';
  return 'text-rose-700';
};

export const FindingsTable: React.FC<FindingsTableProps> = ({ findings }) => {
  const { t } = useTranslation();

  return <div className="overflow-x-auto rounded-lg border border-slate-200">
    <table className="w-full text-left text-xs">
      <thead className="bg-slate-100 text-[10px] uppercase tracking-wide text-slate-500">
        <tr>
          <th className="px-3 py-2 font-bold">{t('report.lesionType')}</th>
          <th className="px-3 py-2 font-bold">{t('report.count')}</th>
          <th className="px-3 py-2 font-bold">{t('report.location')}</th>
          <th className="px-3 py-2 font-bold">{t('report.confidence')}</th>
        </tr>
      </thead>
      <tbody className="divide-y divide-slate-200 bg-white text-slate-800">
        {findings.map((finding, index) => (
          <tr key={`${finding.lesionType}-${finding.location || 'unspecified'}-${index}`}>
            <td className="px-3 py-2 font-semibold">{finding.lesionType}</td>
            <td className="px-3 py-2">{finding.count}</td>
            <td className="px-3 py-2">{finding.location || 'Not specified'}</td>
            <td className={`px-3 py-2 font-bold ${confidenceClass(finding.confidence)}`}>
              {Math.round(finding.confidence * 100)}%
            </td>
          </tr>
        ))}
      </tbody>
    </table>
  </div>;
};
