import React, { useState } from 'react';
import { useNavigate, useLocation, Link } from 'react-router-dom';
import { ArrowLeft, User, LogOut, Stethoscope, HeartPulse, ChevronDown } from 'lucide-react';
import { useTranslation } from 'react-i18next';
import { useAuthStore } from '../../stores/authStore';
import { ConnectivityStatus } from './ConnectivityStatus';
import { LanguageToggle } from './LanguageToggle';

interface AppHeaderProps {
  title?: string;
  showBack?: boolean;
}

export const AppHeader: React.FC<AppHeaderProps> = ({ title, showBack = false }) => {
  const { t } = useTranslation();
  const navigate = useNavigate();
  const location = useLocation();
  const { user, login, logout } = useAuthStore();
  const [profileOpen, setProfileOpen] = useState(false);

  // Determine if back button should be shown automatically
  const canGoBack = showBack || (location.pathname !== '/dashboard' && location.pathname !== '/specialist' && location.pathname !== '/login');

  return (
    <header className="sticky top-0 z-40 bg-white/95 backdrop-blur-xs border-b border-slate-200">
      <div className="max-w-4xl mx-auto px-3.5 py-2.5 sm:px-4 sm:py-3 flex items-center justify-between">
        {/* Left: Back button or Logo */}
        <div className="flex items-center gap-2.5">
          {canGoBack ? (
            <button
              type="button"
              onClick={() => navigate(-1)}
              className="p-2 -ml-1.5 rounded-lg text-slate-700 hover:bg-slate-100 active:bg-slate-200 transition-colors touch-target flex items-center justify-center cursor-pointer"
              aria-label={t('app.back')}
            >
              <ArrowLeft className="w-5 h-5 text-slate-800" />
            </button>
          ) : null}

          <Link to={user?.role === 'SPECIALIST' ? '/specialist' : '/dashboard'} className="flex items-center gap-2 select-none group">
            <div className="w-8 h-8 rounded-lg bg-brand-700 flex items-center justify-center text-white font-bold text-sm shadow-xs">
              <span className="tracking-tighter">DS</span>
            </div>
            <div>
              <span className="font-bold text-base sm:text-lg text-slate-900 tracking-tight block leading-tight group-hover:text-brand-700 transition-colors">
                {title || t('app.name')}
              </span>
              <span className="text-[10px] text-slate-500 block leading-tight">
                {user?.centreName || 'Rural Screening Portal'}
              </span>
            </div>
          </Link>
        </div>

        {/* Right: Connectivity, Language, Profile */}
        <div className="flex items-center gap-2 sm:gap-3">
          <ConnectivityStatus />
          <LanguageToggle />

          {/* Profile & Switcher */}
          <div className="relative">
            <button
              type="button"
              onClick={() => setProfileOpen(!profileOpen)}
              className="flex items-center gap-1 p-1.5 rounded-lg border border-slate-200 hover:bg-slate-50 text-slate-700 transition-colors cursor-pointer"
              aria-label="User profile and role menu"
            >
              <div className="w-6 h-6 rounded-full bg-brand-100 text-brand-800 flex items-center justify-center text-xs font-bold">
                {user?.name ? user.name[0] : 'U'}
              </div>
              <ChevronDown className="w-3.5 h-3.5 text-slate-500" />
            </button>

            {profileOpen && (
              <div
                className="absolute right-0 mt-2 w-64 bg-white rounded-xl shadow-lg border border-slate-200 py-2 z-50"
                onClick={() => setProfileOpen(false)}
              >
                <div className="px-3.5 py-2 border-b border-slate-100">
                  <p className="text-xs text-slate-500 font-medium">Logged in as</p>
                  <p className="text-sm font-bold text-slate-900">{user?.name}</p>
                  <p className="text-xs text-brand-700 font-medium">{user?.centreName}</p>
                </div>

                <div className="py-1">
                  <p className="px-3.5 py-1 text-[10px] font-bold uppercase text-slate-400">
                    Switch Demo Persona
                  </p>
                  <button
                    type="button"
                    onClick={() => {
                      login('HEALTH_WORKER');
                      navigate('/dashboard');
                    }}
                    className={`w-full px-3.5 py-2 text-left text-xs flex items-center gap-2 hover:bg-slate-50 ${
                      user?.role === 'HEALTH_WORKER' ? 'text-brand-800 font-bold bg-teal-50/50' : 'text-slate-700'
                    }`}
                  >
                    <HeartPulse className="w-4 h-4 text-brand-700" />
                    <div>
                      <div>Suman ASHA</div>
                      <div className="text-[10px] text-slate-500">Health Worker • Rampur PHC</div>
                    </div>
                  </button>

                  <button
                    type="button"
                    onClick={() => {
                      login('SPECIALIST');
                      navigate('/specialist');
                    }}
                    className={`w-full px-3.5 py-2 text-left text-xs flex items-center gap-2 hover:bg-slate-50 ${
                      user?.role === 'SPECIALIST' ? 'text-brand-800 font-bold bg-teal-50/50' : 'text-slate-700'
                    }`}
                  >
                    <Stethoscope className="w-4 h-4 text-indigo-700" />
                    <div>
                      <div>Dr. Arvind Rao</div>
                      <div className="text-[10px] text-slate-500">Ophthalmologist • District Hospital</div>
                    </div>
                  </button>
                </div>

                <div className="border-t border-slate-100 pt-1">
                  <button
                    type="button"
                    onClick={() => {
                      logout();
                      navigate('/login');
                    }}
                    className="w-full px-3.5 py-2 text-left text-xs text-rose-700 font-medium hover:bg-rose-50 flex items-center gap-2"
                  >
                    <LogOut className="w-3.5 h-3.5" />
                    {t('app.logout')}
                  </button>
                </div>
              </div>
            )}
          </div>
        </div>
      </div>
    </header>
  );
};
