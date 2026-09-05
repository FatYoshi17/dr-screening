import React from 'react';

interface PrimaryButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  children: React.ReactNode;
  icon?: React.ComponentType<{ className?: string }>;
  fullWidth?: boolean;
  size?: 'normal' | 'large';
}

export const PrimaryButton: React.FC<PrimaryButtonProps> = ({
  children,
  icon: Icon,
  fullWidth = true,
  size = 'large',
  disabled,
  className = '',
  ...props
}) => {
  const heightClass = size === 'large' ? 'min-h-[52px] py-3.5 px-6 text-base font-semibold' : 'min-h-[48px] py-2.5 px-4 text-sm font-medium';
  const widthClass = fullWidth ? 'w-full' : '';

  return (
    <button
      disabled={disabled}
      className={`
        inline-flex items-center justify-center gap-2.5 rounded-xl
        bg-brand-700 text-white shadow-sm border border-brand-800
        hover:bg-brand-800 active:bg-brand-900 active:scale-[0.99]
        focus:outline-none focus:ring-3 focus:ring-brand-500/40 focus:ring-offset-2
        disabled:opacity-50 disabled:cursor-not-allowed disabled:active:scale-100
        transition-colors duration-150 cursor-pointer select-none
        ${heightClass} ${widthClass} ${className}
      `}
      {...props}
    >
      {Icon && <Icon className="w-5 h-5 flex-shrink-0" />}
      <span>{children}</span>
    </button>
  );
};
