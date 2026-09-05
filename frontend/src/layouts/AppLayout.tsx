import React, { useEffect } from 'react';
import { Outlet } from 'react-router-dom';
import { AppHeader } from '../components/ui/AppHeader';
import { BottomNavigation } from '../components/ui/BottomNavigation';
import { useConnectivityStore } from '../stores/connectivityStore';
import { initializeDatabaseSeed } from '../offline/db';

export const AppLayout: React.FC = () => {
  const initListeners = useConnectivityStore((state) => state.initListeners);

  useEffect(() => {
    // Seed initial demo data in Dexie.js
    initializeDatabaseSeed();
    // Start listening to online/offline network changes
    const cleanup = initListeners();
    return cleanup;
  }, [initListeners]);

  return (
    <div className="min-h-screen bg-surface-ground flex flex-col antialiased text-slate-900 pb-20 sm:pb-8">
      <AppHeader />

      <main className="flex-1 w-full max-w-md mx-auto px-4 py-4 sm:max-w-2xl sm:px-6">
        <Outlet />
      </main>

      <BottomNavigation />
    </div>
  );
};
