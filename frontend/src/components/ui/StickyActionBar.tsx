import React from 'react';

interface StickyActionBarProps {
  children: React.ReactNode;
  className?: string;
}

export const StickyActionBar: React.FC<StickyActionBarProps> = ({ children, className = '' }) => {
  return (
    <div
      className={`
        sticky bottom-0 left-0 right-0 z-30
        bg-white/95 backdrop-blur-sm border-t border-slate-200
        p-3.5 pb-safe sm:p-4 shadow-[0_-4px_12px_rgba(0,0,0,0.04)]
        ${className}
      `}
    >
      <div className="max-w-md mx-auto flex gap-3 items-center">
        {children}
      </div>
    </div>
  );
};
