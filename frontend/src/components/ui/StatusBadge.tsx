import React from 'react';
import { CheckCircle, AlertTriangle, AlertCircle, RefreshCw } from 'lucide-react';
import { useTranslation } from 'react-i18next';
import type { ScreeningResultCategory } from '../../types';

interface StatusBadgeProps {
  status: ScreeningResultCategory;
  size?: 'sm' | 'md' | 'lg';
  showLabel?: boolean;
  className?: string;
}

export const StatusBadge: React.FC<StatusBadgeProps> = ({
  status,
  size = 'md',
  showLabel = true,
  className = '',
}) => {
  const { t } = useTranslation();

  const config = {
    ROUTINE: {
      label: t('status.routine'),
      icon: CheckCircle,
      bg: 'bg-emerald-50',
      text: 'text-emerald-800',
      border: 'border-emerald-300',
      symbol: '✓',
    },
    REVIEW: {
      label: t('status.review'),
      icon: AlertTriangle,
      bg: 'bg-amber-50',
      text: 'text-amber-900',
      border: 'border-amber-300',
      symbol: '!',
    },
    PRIORITY: {
      label: t('status.priority'),
      icon: AlertCircle,
      bg: 'bg-rose-50',
      text: 'text-rose-900',
      border: 'border-rose-300',
      symbol: '!!',
    },
    RETAKE: {
      label: t('status.retake'),
      icon: RefreshCw,
      bg: 'bg-yellow-50',
      text: 'text-yellow-900',
      border: 'border-yellow-400',
      symbol: '↻',
    },
  }[status];

  const sizeClasses = {
    sm: 'text-xs px-2 py-0.5 gap-1 font-medium',
    md: 'text-sm px-2.5 py-1 gap-1.5 font-semibold',
    lg: 'text-base px-3.5 py-1.5 gap-2 font-bold',
  }[size];

  const IconComponent = config.icon;

  return (
    <span
      className={`inline-flex items-center rounded-md border ${config.bg} ${config.text} ${config.border} ${sizeClasses} ${className}`}
      role="status"
      aria-label={`${config.label} status`}
    >
      <IconComponent className={size === 'sm' ? 'w-3.5 h-3.5' : size === 'lg' ? 'w-5 h-5' : 'w-4 h-4'} />
      {showLabel && <span>{config.label}</span>}
    </span>
  );
};
