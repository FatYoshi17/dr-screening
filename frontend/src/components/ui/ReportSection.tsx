import React from 'react';

interface ReportSectionProps {
  number: string;
  title: string;
  children: React.ReactNode;
}

export const ReportSection: React.FC<ReportSectionProps> = ({ number, title, children }) => (
  <section className="space-y-3">
    <div className="flex items-center gap-3 border-b-2 border-slate-800 pb-2">
      <span className="flex h-7 w-7 shrink-0 items-center justify-center rounded bg-brand-800 text-xs font-bold text-white">
        {number}
      </span>
      <h2 className="text-xs font-extrabold uppercase tracking-wider text-slate-800">{title}</h2>
    </div>
    {children}
  </section>
);
