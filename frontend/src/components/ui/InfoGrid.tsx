import React from 'react';

interface InfoGridField {
  label: string;
  value: React.ReactNode;
  emphasis?: 'default' | 'success' | 'warning' | 'danger';
}

interface InfoGridProps {
  fields: InfoGridField[];
  columns?: 2 | 4;
}

const emphasisClasses = {
  default: 'text-slate-900',
  success: 'text-emerald-700',
  warning: 'text-amber-700',
  danger: 'text-rose-700',
};

export const InfoGrid: React.FC<InfoGridProps> = ({ fields, columns = 4 }) => (
  <div className={`grid grid-cols-2 ${columns === 4 ? 'sm:grid-cols-4' : 'sm:grid-cols-2'} gap-4 text-xs text-slate-800`}>
    {fields.map((field) => (
      <div key={field.label}>
        <span className="block text-[11px] text-slate-400">{field.label}</span>
        <span className={`font-semibold ${emphasisClasses[field.emphasis || 'default']}`}>
          {field.value}
        </span>
      </div>
    ))}
  </div>
);
