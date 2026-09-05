import React, { Suspense, lazy } from 'react';
import { createBrowserRouter, Navigate } from 'react-router-dom';
import { LandingLayout } from '../layouts/LandingLayout';
import { AppLayout } from '../layouts/AppLayout';
import { SpecialistLayout } from '../layouts/SpecialistLayout';

// Loading fallback component
const PageLoader = () => (
  <div className="min-h-[50vh] flex flex-col items-center justify-center p-6 text-slate-500">
    <div className="w-8 h-8 border-3 border-brand-700 border-t-transparent rounded-full animate-spin mb-3" />
    <span className="text-xs font-semibold">Loading DrishtiSetu...</span>
  </div>
);

// Route-based Lazy Loading for strict code-splitting
// Landing page with Framer Motion lives strictly in its own isolated chunk
const LandingPage = lazy(() => import('../pages/landing/LandingPage').then(m => ({ default: m.LandingPage })));
const LoginPage = lazy(() => import('../pages/auth/LoginPage').then(m => ({ default: m.LoginPage })));
const DashboardPage = lazy(() => import('../pages/dashboard/DashboardPage').then(m => ({ default: m.DashboardPage })));
const PatientListPage = lazy(() => import('../pages/patients/PatientListPage').then(m => ({ default: m.PatientListPage })));
const NewPatientPage = lazy(() => import('../pages/patients/NewPatientPage').then(m => ({ default: m.NewPatientPage })));
const PatientDetailPage = lazy(() => import('../pages/patients/PatientDetailPage').then(m => ({ default: m.PatientDetailPage })));
const ScreeningStartPage = lazy(() => import('../pages/screening/ScreeningStartPage').then(m => ({ default: m.ScreeningStartPage })));
const CaptureGuidePage = lazy(() => import('../pages/screening/CaptureGuidePage').then(m => ({ default: m.CaptureGuidePage })));
const CapturePage = lazy(() => import('../pages/screening/CapturePage').then(m => ({ default: m.CapturePage })));
const QualityPage = lazy(() => import('../pages/screening/QualityPage').then(m => ({ default: m.QualityPage })));
const UploadPage = lazy(() => import('../pages/screening/UploadPage').then(m => ({ default: m.UploadPage })));
const ResultPage = lazy(() => import('../pages/screening/ResultPage').then(m => ({ default: m.ResultPage })));
const ReportPage = lazy(() => import('../pages/screening/ReportPage').then(m => ({ default: m.ReportPage })));
const CreateReferralPage = lazy(() => import('../pages/referrals/CreateReferralPage').then(m => ({ default: m.CreateReferralPage })));
const ReferralListPage = lazy(() => import('../pages/referrals/ReferralListPage').then(m => ({ default: m.ReferralListPage })));
const SpecialistDashboardPage = lazy(() => import('../pages/specialist/SpecialistDashboardPage').then(m => ({ default: m.SpecialistDashboardPage })));
const SpecialistCasePage = lazy(() => import('../pages/specialist/SpecialistCasePage').then(m => ({ default: m.SpecialistCasePage })));

export const router = createBrowserRouter([
  // 1. Public Landing Experience
  {
    path: '/',
    element: <LandingLayout />,
    children: [
      {
        index: true,
        element: (
          <Suspense fallback={<PageLoader />}>
            <LandingPage />
          </Suspense>
        ),
      },
    ],
  },

  // 2. Auth
  {
    path: '/login',
    element: (
      <Suspense fallback={<PageLoader />}>
        <LoginPage />
      </Suspense>
    ),
  },

  // 3. Operational App (Health Worker Primary)
  {
    element: <AppLayout />,
    children: [
      {
        path: '/dashboard',
        element: (
          <Suspense fallback={<PageLoader />}>
            <DashboardPage />
          </Suspense>
        ),
      },
      {
        path: '/patients',
        element: (
          <Suspense fallback={<PageLoader />}>
            <PatientListPage />
          </Suspense>
        ),
      },
      {
        path: '/patients/new',
        element: (
          <Suspense fallback={<PageLoader />}>
            <NewPatientPage />
          </Suspense>
        ),
      },
      {
        path: '/patient/:id',
        element: (
          <Suspense fallback={<PageLoader />}>
            <PatientDetailPage />
          </Suspense>
        ),
      },
      {
        path: '/screening/new',
        element: (
          <Suspense fallback={<PageLoader />}>
            <ScreeningStartPage />
          </Suspense>
        ),
      },
      {
        path: '/screening/:id/guide',
        element: (
          <Suspense fallback={<PageLoader />}>
            <CaptureGuidePage />
          </Suspense>
        ),
      },
      {
        path: '/screening/:id/capture',
        element: (
          <Suspense fallback={<PageLoader />}>
            <CapturePage />
          </Suspense>
        ),
      },
      {
        path: '/screening/:id/quality',
        element: (
          <Suspense fallback={<PageLoader />}>
            <QualityPage />
          </Suspense>
        ),
      },
      {
        path: '/screening/:id/upload',
        element: (
          <Suspense fallback={<PageLoader />}>
            <UploadPage />
          </Suspense>
        ),
      },
      {
        path: '/screening/:id/result',
        element: (
          <Suspense fallback={<PageLoader />}>
            <ResultPage />
          </Suspense>
        ),
      },
      {
        path: '/screening/:id/report',
        element: (
          <Suspense fallback={<PageLoader />}>
            <ReportPage />
          </Suspense>
        ),
      },
      {
        path: '/referral/new/:screeningId',
        element: (
          <Suspense fallback={<PageLoader />}>
            <CreateReferralPage />
          </Suspense>
        ),
      },
      {
        path: '/referrals',
        element: (
          <Suspense fallback={<PageLoader />}>
            <ReferralListPage />
          </Suspense>
        ),
      },
    ],
  },

  // 4. Specialist Workstation (Desktop / Clinic Focused)
  {
    path: '/specialist',
    element: <SpecialistLayout />,
    children: [
      {
        index: true,
        element: (
          <Suspense fallback={<PageLoader />}>
            <SpecialistDashboardPage />
          </Suspense>
        ),
      },
      {
        path: 'case/:id',
        element: (
          <Suspense fallback={<PageLoader />}>
            <SpecialistCasePage />
          </Suspense>
        ),
      },
    ],
  },

  // 5. Catch-all fallback
  {
    path: '*',
    element: <Navigate to="/dashboard" replace />,
  },
]);
