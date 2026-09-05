import React from 'react';
import { Outlet, Link } from 'react-router-dom';
import { LanguageToggle } from '../components/ui/LanguageToggle';
import { LogIn } from 'lucide-react';
import { useTranslation } from 'react-i18next';

export const LandingLayout: React.FC = () => {
  const { t } = useTranslation();

  return (
    <div className="min-h-screen bg-surface-ground flex flex-col antialiased text-slate-900">
      {/* Minimal Landing Header */}
      <header className="sticky top-0 z-40 bg-white/90 backdrop-blur-md border-b border-slate-200">
        <div className="max-w-6xl mx-auto px-4 py-3.5 sm:px-6 flex items-center justify-between">
          {/* Logo + Name */}
          <Link to="/" className="flex items-center gap-2.5">
            <div className="w-9 h-9 rounded-xl bg-brand-700 flex items-center justify-center text-white font-bold text-base shadow-xs">
              <span className="tracking-tight">DS</span>
            </div>
            <div>
              <span className="font-bold text-lg sm:text-xl text-slate-900 tracking-tight block leading-tight">
                {t('app.name')}
              </span>
              <span className="text-[11px] text-slate-500 block leading-tight">
                Smart India Hackathon 2026
              </span>
            </div>
          </Link>

          {/* Right: Language toggle + Login CTA */}
          <div className="flex items-center gap-3 sm:gap-4">
            <LanguageToggle />

            <Link
              to="/login"
              className="inline-flex items-center gap-2 px-4 py-2 rounded-xl text-sm font-semibold bg-brand-700 text-white hover:bg-brand-800 active:scale-95 transition-all shadow-xs"
            >
              <LogIn className="w-4 h-4" />
              <span>Login</span>
            </Link>
          </div>
        </div>
      </header>

      {/* Main Content */}
      <main className="flex-1">
        <Outlet />
      </main>

      {/* Clean Footer */}
      <footer className="bg-white border-t border-slate-200 py-8 px-4 sm:px-6">
        <div className="max-w-6xl mx-auto flex flex-col sm:flex-row items-center justify-between gap-4 text-xs text-slate-500">
          <div>
            <span className="font-semibold text-slate-800">{t('app.name')}</span> • Low-Bandwidth Rural Eye Screening Platform (SIH 2026)
          </div>
          <div className="text-center sm:text-right text-slate-400">
            For screening and clinical decision support. Final diagnosis remains human-led by an ophthalmologist.
          </div>
        </div>
      </footer>
    </div>
  );
};
