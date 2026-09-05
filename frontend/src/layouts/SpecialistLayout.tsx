import React, { useEffect } from 'react';
import { Outlet, Link } from 'react-router-dom';
import { AppHeader } from '../components/ui/AppHeader';
import { initializeDatabaseSeed } from '../offline/db';
import { useConnectivityStore } from '../stores/connectivityStore';
import { Stethoscope, ShieldCheck } from 'lucide-react';
import { useTranslation } from 'react-i18next';

export const SpecialistLayout: React.FC = () => {
  const { t } = useTranslation();
  const initListeners = useConnectivityStore((state) => state.initListeners);

  useEffect(() => {
    initializeDatabaseSeed();
    const cleanup = initListeners();
    return cleanup;
  }, [initListeners]);

  return (
    <div className="min-h-screen bg-slate-100 flex flex-col antialiased text-slate-900">
      <AppHeader title="DrishtiSetu • Specialist" />

      {/* Specialist clinic sub-banner */}
      <div className="bg-indigo-950 text-indigo-100 px-4 py-2 border-b border-indigo-900">
        <div className="max-w-6xl mx-auto flex items-center justify-between text-xs">
          <div className="flex items-center gap-2">
            <Stethoscope className="w-4 h-4 text-indigo-400" />
            <span className="font-semibold text-white">
              Specialist Clinical Triage Station
            </span>
            <span className="hidden sm:inline text-indigo-300">
              • District Hospital Tele-Ophthalmology Department
            </span>
          </div>

          <div className="flex items-center gap-3">
            <span className="inline-flex items-center gap-1 text-[11px] text-indigo-200">
              <ShieldCheck className="w-3.5 h-3.5 text-emerald-400" />
              Decision Support Verified
            </span>
            <Link
              to="/dashboard"
              className="text-[11px] underline text-indigo-300 hover:text-white"
            >
              Switch to Health Worker View
            </Link>
          </div>
        </div>
      </div>

      <main className="flex-1 w-full max-w-6xl mx-auto px-4 py-6 sm:px-6">
        <Outlet />
      </main>
    </div>
  );
};
