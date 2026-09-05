import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { useAuthStore } from '../../stores/authStore';
import { PrimaryButton } from '../../components/ui/PrimaryButton';
import { LanguageToggle } from '../../components/ui/LanguageToggle';
import { HeartPulse, Stethoscope, Lock, Phone } from 'lucide-react';
import type { UserRole } from '../../types';

export const LoginPage: React.FC = () => {
  const { t } = useTranslation();
  const navigate = useNavigate();
  const login = useAuthStore((state) => state.login);

  const [workerId, setWorkerId] = useState('HW-7401');
  const [pin, setPin] = useState('1234');
  const [selectedRole, setSelectedRole] = useState<UserRole>('HEALTH_WORKER');

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    login(selectedRole, workerId);
    if (selectedRole === 'SPECIALIST') {
      navigate('/specialist');
    } else {
      navigate('/dashboard');
    }
  };

  const handleQuickDemo = (role: UserRole) => {
    setSelectedRole(role);
    if (role === 'SPECIALIST') {
      setWorkerId('DR-ARVIND-01');
      setPin('4321');
      login('SPECIALIST', 'DR-ARVIND-01');
      navigate('/specialist');
    } else {
      setWorkerId('HW-7401');
      setPin('1234');
      login('HEALTH_WORKER', 'HW-7401');
      navigate('/dashboard');
    }
  };

  return (
    <div className="min-h-[85vh] flex flex-col justify-center max-w-sm mx-auto px-4 py-8">
      {/* Top Header with Language selector */}
      <div className="flex justify-end mb-6">
        <LanguageToggle />
      </div>

      <div className="bg-white rounded-2xl border border-slate-200 shadow-sm p-6 sm:p-8">
        {/* Brand Logo & Name */}
        <div className="text-center mb-6">
          <div className="w-14 h-14 rounded-2xl bg-brand-700 mx-auto flex items-center justify-center text-white font-bold text-2xl shadow-sm mb-3">
            DS
          </div>
          <h1 className="text-2xl font-bold text-slate-900 tracking-tight">
            {t('app.name')}
          </h1>
          <p className="text-sm text-slate-600 mt-1">
            {selectedRole === 'SPECIALIST' ? t('app.specialist') : t('app.healthWorker')} Login
          </p>
        </div>

        {/* Role toggle tabs */}
        <div className="grid grid-cols-2 gap-1.5 p-1 bg-slate-100 rounded-xl mb-6">
          <button
            type="button"
            onClick={() => setSelectedRole('HEALTH_WORKER')}
            className={`py-2 px-3 text-xs font-semibold rounded-lg flex items-center justify-center gap-1.5 transition-colors cursor-pointer ${
              selectedRole === 'HEALTH_WORKER'
                ? 'bg-white text-brand-800 shadow-xs'
                : 'text-slate-600 hover:text-slate-900'
            }`}
          >
            <HeartPulse className="w-3.5 h-3.5 text-brand-700" />
            <span>Health Worker</span>
          </button>
          <button
            type="button"
            onClick={() => setSelectedRole('SPECIALIST')}
            className={`py-2 px-3 text-xs font-semibold rounded-lg flex items-center justify-center gap-1.5 transition-colors cursor-pointer ${
              selectedRole === 'SPECIALIST'
                ? 'bg-white text-brand-800 shadow-xs'
                : 'text-slate-600 hover:text-slate-900'
            }`}
          >
            <Stethoscope className="w-3.5 h-3.5 text-indigo-700" />
            <span>Specialist</span>
          </button>
        </div>

        {/* Login Form */}
        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label className="block text-xs font-bold uppercase tracking-wider text-slate-700 mb-1.5">
              {selectedRole === 'SPECIALIST' ? 'Doctor ID / Mobile' : 'Worker ID / Mobile Number'}
            </label>
            <div className="relative">
              <Phone className="w-4 h-4 text-slate-400 absolute left-3.5 top-3.5" />
              <input
                type="text"
                required
                value={workerId}
                onChange={(e) => setWorkerId(e.target.value)}
                placeholder="Enter Mobile or Worker ID"
                className="w-full pl-10 pr-3.5 py-3 rounded-xl border border-slate-300 text-base text-slate-900 focus:outline-none focus:ring-2 focus:ring-brand-600 focus:border-brand-600 min-h-[48px]"
              />
            </div>
          </div>

          <div>
            <label className="block text-xs font-bold uppercase tracking-wider text-slate-700 mb-1.5">
              Security PIN / Password
            </label>
            <div className="relative">
              <Lock className="w-4 h-4 text-slate-400 absolute left-3.5 top-3.5" />
              <input
                type="password"
                required
                value={pin}
                onChange={(e) => setPin(e.target.value)}
                inputMode="numeric"
                placeholder="••••"
                className="w-full pl-10 pr-3.5 py-3 rounded-xl border border-slate-300 text-base text-slate-900 focus:outline-none focus:ring-2 focus:ring-brand-600 focus:border-brand-600 min-h-[48px]"
              />
            </div>
          </div>

          <PrimaryButton type="submit" size="large" className="mt-2">
            Login
          </PrimaryButton>
        </form>

        {/* Quick Demo Shortcuts for SIH Evaluators */}
        <div className="mt-6 pt-4 border-t border-slate-200">
          <p className="text-[11px] font-bold uppercase tracking-wider text-slate-400 text-center mb-2">
            SIH Demo 1-Tap Access
          </p>
          <div className="grid grid-cols-2 gap-2">
            <button
              type="button"
              onClick={() => handleQuickDemo('HEALTH_WORKER')}
              className="px-2.5 py-2 rounded-lg bg-teal-50 hover:bg-teal-100/70 border border-teal-200 text-brand-900 text-xs font-semibold text-center transition-colors cursor-pointer"
            >
              Demo ASHA Worker
            </button>
            <button
              type="button"
              onClick={() => handleQuickDemo('SPECIALIST')}
              className="px-2.5 py-2 rounded-lg bg-indigo-50 hover:bg-indigo-100/70 border border-indigo-200 text-indigo-950 text-xs font-semibold text-center transition-colors cursor-pointer"
            >
              Demo Specialist
            </button>
          </div>
        </div>

        <p className="text-center text-xs text-slate-500 mt-5">
          Having trouble signing in? Contact centre administrator.
        </p>
      </div>
    </div>
  );
};
