import React from 'react';

interface SecondaryButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  children: React.ReactNode;
  icon?: React.ComponentType<{ className?: string }>;
  fullWidth?: boolean;
  variant?: 'outline' | 'ghost' | 'danger';
}

export const SecondaryButton: React.FC<SecondaryButtonProps> = ({
  children,
  icon: Icon,
  fullWidth = true,
  variant = 'outline',
  disabled,
  className = '',
  ...props
}) => {
  const variantClasses = {
    outline: 'bg-white text-slate-800 border border-slate-300 hover:bg-slate-50 active:bg-slate-100',
    ghost: 'bg-transparent text-slate-700 hover:bg-slate-100/70 border border-transparent',
    danger: 'bg-rose-50 text-rose-800 border border-rose-200 hover:bg-rose-100',
  }[variant];

  return (
    <button
      disabled={disabled}
      className={`
        inline-flex items-center justify-center gap-2 rounded-xl min-h-[48px] py-3 px-5
        text-base font-medium select-none cursor-pointer
        focus:outline-none focus:ring-3 focus:ring-slate-400/40 focus:ring-offset-2
        disabled:opacity-50 disabled:cursor-not-allowed
        transition-colors duration-150
        ${fullWidth ? 'w-full' : ''} ${variantClasses} ${className}
      `}
      {...props}
    >
      {Icon && <Icon className="w-5 h-5 flex-shrink-0" />}
      <span>{children}</span>
    </button>
  );
};
