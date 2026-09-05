import React from 'react';
import { NavLink } from 'react-router-dom';
import { Home, Users, PlusCircle, Share2 } from 'lucide-react';
import { useTranslation } from 'react-i18next';

export const BottomNavigation: React.FC = () => {
  const { t } = useTranslation();

  const navItems = [
    {
      to: '/dashboard',
      label: t('nav.home'),
      icon: Home,
    },
    {
      to: '/patients',
      label: t('nav.patients'),
      icon: Users,
    },
    {
      to: '/screening/new',
      label: t('nav.newScreening'),
      icon: PlusCircle,
      prominent: true,
    },
    {
      to: '/referrals',
      label: t('nav.referrals'),
      icon: Share2,
    },
  ];

  return (
    <nav
      className="fixed bottom-0 left-0 right-0 z-40 bg-white/95 backdrop-blur-xs border-t border-slate-200 pb-safe shadow-[0_-2px_10px_rgba(0,0,0,0.05)] sm:hidden"
      aria-label="Main Navigation"
    >
      <div className="max-w-md mx-auto grid grid-cols-4 items-center h-16 px-1">
        {navItems.map((item) => {
          const Icon = item.icon;
          return (
            <NavLink
              key={item.to}
              to={item.to}
              className={({ isActive }) => `
                flex flex-col items-center justify-center h-full touch-target transition-colors
                ${
                  item.prominent
                    ? isActive
                      ? 'text-brand-800 font-bold'
                      : 'text-brand-700 font-semibold'
                    : isActive
                    ? 'text-brand-800 font-bold'
                    : 'text-slate-600 hover:text-slate-900 font-medium'
                }
              `}
            >
              {({ isActive }) => (
                <>
                  <div
                    className={`p-1 rounded-lg ${
                      item.prominent
                        ? isActive
                          ? 'bg-brand-100 text-brand-800 ring-1 ring-brand-300'
                          : 'bg-brand-50 text-brand-700'
                        : isActive
                        ? 'bg-teal-50'
                        : ''
                    }`}
                  >
                    <Icon className={`w-5 h-5 ${item.prominent ? 'w-5.5 h-5.5' : ''}`} />
                  </div>
                  <span className="text-[11px] leading-tight tracking-tight mt-0.5">
                    {item.label}
                  </span>
                </>
              )}
            </NavLink>
          );
        })}
      </div>
    </nav>
  );
};
