import React, { useRef } from 'react';
import { Link } from 'react-router-dom';
import { motion, useScroll, useTransform, useReducedMotion } from 'framer-motion';
import { useTranslation } from 'react-i18next';
import {
  Eye,
  ShieldCheck,
  WifiOff,
  Languages,
  History,
  FileCheck,
  Share2,
  Stethoscope,
  CheckCircle2,
  AlertTriangle,
  AlertCircle,
  RefreshCw,
  ArrowRight,
  ChevronDown,
  UserCheck,
  Camera,
  UploadCloud
} from 'lucide-react';
import { StatusBadge } from '../../components/ui/StatusBadge';

export const LandingPage: React.FC = () => {
  const { t } = useTranslation();
  const shouldReduceMotion = useReducedMotion();

  // Scroll tracking for guided vertical workflow
  const workflowRef = useRef<HTMLDivElement>(null);
  const { scrollYProgress } = useScroll({
    target: workflowRef,
    offset: ['start center', 'end center'],
  });

  const pathLength = useTransform(scrollYProgress, [0, 1], [0, 1]);

  const workflowSteps = [
    {
      num: 1,
      title: 'Find or Register Patient',
      desc: 'Quick 30-second mobile entry with demographic details and diabetes history.',
      icon: UserCheck,
    },
    {
      num: 2,
      title: 'Capture Retinal Image',
      desc: 'Guided step-by-step alignment with pupil and portable fundus camera.',
      icon: Camera,
    },
    {
      num: 3,
      title: 'Check Image Quality',
      desc: 'Instant computer-vision check ensuring optic disc and retina are clear.',
      icon: Eye,
    },
    {
      num: 4,
      title: 'Upload or Save Offline',
      desc: 'Transmits seamlessly when online, or safely saves in local IndexedDB if offline.',
      icon: UploadCloud,
    },
    {
      num: 5,
      title: 'Cloud-Assisted Screening',
      desc: 'Deep learning model screens for microaneurysms, hemorrhages, and exudates.',
      icon: ShieldCheck,
    },
    {
      num: 6,
      title: 'Receive Priority Result',
      desc: 'Categorized clearly into Routine, Review, Priority, or Retake Image.',
      icon: AlertTriangle,
    },
    {
      num: 7,
      title: 'Generate Screening Report',
      desc: 'Bilingual printable PDF summary for patient records and village follow-up.',
      icon: FileCheck,
    },
    {
      num: 8,
      title: 'Refer When Required',
      desc: 'One-tap prefilled referral to the nearest district tele-ophthalmology hospital.',
      icon: Share2,
    },
    {
      num: 9,
      title: 'Specialist Reviews the Case',
      desc: 'Ophthalmologist reviews high-resolution fundus images and confirms care plan.',
      icon: Stethoscope,
    },
  ];

  return (
    <div className="space-y-20 sm:space-y-28 pb-20 overflow-hidden">
      {/* ================= SECTION 1: HERO ================= */}
      <section className="pt-12 sm:pt-20 px-4 sm:px-6 max-w-5xl mx-auto text-center">
        <div className="inline-flex items-center gap-2 px-3 py-1.5 rounded-full bg-teal-50 border border-brand-200 text-brand-900 text-xs font-semibold mb-6">
          <span className="w-2 h-2 rounded-full bg-brand-600 animate-pulse" />
          <span>Smart India Hackathon 2026 • Rural Healthcare Utility</span>
        </div>

        <h1 className="text-3xl sm:text-5xl md:text-6xl font-extrabold text-slate-900 tracking-tight leading-[1.15] max-w-4xl mx-auto">
          Eye screening closer to <span className="text-brand-700">every village.</span>
        </h1>

        <p className="mt-5 text-base sm:text-xl text-slate-600 max-w-2xl mx-auto leading-relaxed">
          Helping rural health workers capture retinal images, screen patients, maintain histories, and connect priority cases with eye specialists — even with unreliable internet.
        </p>

        <p className="mt-3 text-xs font-semibold text-slate-500 uppercase tracking-wider">
          Designed for rural primary health centres and community screening programmes
        </p>

        {/* Hero CTAs */}
        <div className="mt-8 flex flex-col sm:flex-row items-center justify-center gap-3 sm:gap-4 max-w-md mx-auto">
          <a
            href="#workflow"
            className="w-full sm:w-auto px-6 py-3.5 rounded-xl bg-white border border-slate-300 hover:bg-slate-50 text-slate-800 font-bold text-sm transition-colors shadow-2xs inline-flex items-center justify-center gap-2"
          >
            <span>See how it works</span>
            <ChevronDown className="w-4 h-4" />
          </a>

          <Link
            to="/login"
            className="w-full sm:w-auto px-6 py-3.5 rounded-xl bg-brand-700 hover:bg-brand-800 text-white font-bold text-sm transition-colors shadow-sm inline-flex items-center justify-center gap-2"
          >
            <span>Health Worker Login</span>
            <ArrowRight className="w-4 h-4" />
          </Link>
        </div>

        {/* Lightweight Illustrative Mockup Visual */}
        <div className="mt-12 sm:mt-16 max-w-3xl mx-auto bg-white rounded-3xl p-5 sm:p-7 border border-slate-200 shadow-md">
          <div className="grid grid-cols-1 sm:grid-cols-4 gap-3 items-center text-left text-xs">
            {/* 1. Patient Card */}
            <div className="p-3 bg-slate-50 rounded-xl border border-slate-200">
              <span className="text-[10px] text-slate-400 font-bold uppercase">1. Patient</span>
              <p className="font-bold text-slate-900 text-sm mt-0.5">Kamla Devi</p>
              <p className="text-slate-500 text-[11px]">58y / F • Rampur PHC</p>
            </div>

            {/* 2. Screening */}
            <div className="p-3 bg-teal-50/70 rounded-xl border border-teal-200">
              <span className="text-[10px] text-brand-700 font-bold uppercase">2. Fundus Exam</span>
              <p className="font-bold text-slate-900 text-sm mt-0.5">Right Eye (OD)</p>
              <p className="text-brand-800 text-[11px]">Quality Verified ✓</p>
            </div>

            {/* 3. Result */}
            <div className="p-3 bg-amber-50/70 rounded-xl border border-amber-200">
              <span className="text-[10px] text-amber-800 font-bold uppercase">3. Result</span>
              <p className="font-bold text-amber-950 text-sm mt-0.5">! REVIEW</p>
              <p className="text-amber-800 text-[11px]">Specialist Triage</p>
            </div>

            {/* 4. Referral */}
            <div className="p-3 bg-indigo-50/70 rounded-xl border border-indigo-200">
              <span className="text-[10px] text-indigo-700 font-bold uppercase">4. Tele-Referral</span>
              <p className="font-bold text-indigo-950 text-sm mt-0.5">District Hospital</p>
              <p className="text-indigo-700 text-[11px]">Ophthalmologist Queue</p>
            </div>
          </div>
        </div>
      </section>

      {/* ================= SECTION 2: WHY THIS MATTERS ================= */}
      <section className="px-4 sm:px-6 max-w-4xl mx-auto">
        <div className="text-center mb-10">
          <span className="text-xs font-bold uppercase tracking-wider text-brand-700">Access Gap</span>
          <h2 className="text-2xl sm:text-4xl font-extrabold text-slate-900 tracking-tight mt-1">
            Bridging the Rural Retinal Care Distance
          </h2>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          {/* Before Column */}
          <div className="bg-rose-50/50 rounded-2xl p-6 border border-rose-200 space-y-4">
            <h3 className="text-base font-bold text-rose-950 flex items-center gap-2">
              <span className="w-2.5 h-2.5 rounded-full bg-rose-600" />
              Without DrishtiSetu (Traditional Process)
            </h3>

            <div className="space-y-3 text-xs sm:text-sm text-slate-700">
              <div className="p-3 bg-white/80 rounded-xl border border-rose-100 font-medium">
                1. Rural patient with diabetes experiences subtle unmonitored changes
              </div>
              <div className="text-center text-slate-400">↓</div>
              <div className="p-3 bg-white/80 rounded-xl border border-rose-100 font-medium">
                2. Nearest ophthalmologist is 40–80 km away at district centre
              </div>
              <div className="text-center text-slate-400">↓</div>
              <div className="p-3 bg-white/80 rounded-xl border border-rose-100 font-medium">
                3. Screening delayed until irreversible visual impairment occurs
              </div>
              <div className="text-center text-slate-400">↓</div>
              <div className="p-3 bg-rose-100/90 rounded-xl border border-rose-300 font-bold text-rose-900">
                4. High risk of preventable diabetic blindness
              </div>
            </div>
          </div>

          {/* With Platform Column */}
          <div className="bg-teal-50/50 rounded-2xl p-6 border border-brand-200 space-y-4">
            <h3 className="text-base font-bold text-brand-950 flex items-center gap-2">
              <span className="w-2.5 h-2.5 rounded-full bg-brand-600" />
              With DrishtiSetu (Village-First Screening)
            </h3>

            <div className="space-y-3 text-xs sm:text-sm text-slate-700">
              <div className="p-3 bg-white/80 rounded-xl border border-brand-100 font-medium">
                1. Local ASHA/PHC worker screens patient at village health sub-centre
              </div>
              <div className="text-center text-slate-400">↓</div>
              <div className="p-3 bg-white/80 rounded-xl border border-brand-100 font-medium">
                2. On-device quality check ensures usable retinal photography
              </div>
              <div className="text-center text-slate-400">↓</div>
              <div className="p-3 bg-white/80 rounded-xl border border-brand-100 font-medium">
                3. Cloud model prioritizes cases: Routine, Review, or Priority
              </div>
              <div className="text-center text-slate-400">↓</div>
              <div className="p-3 bg-teal-100/90 rounded-xl border border-brand-300 font-bold text-brand-950">
                4. Remote ophthalmologist reviews case & fast-tracks treatment
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* ================= SECTION 3: SCROLL WORKFLOW (CENTERPIECE) ================= */}
      <section id="workflow" ref={workflowRef} className="px-4 sm:px-6 max-w-3xl mx-auto">
        <div className="text-center mb-12">
          <span className="text-xs font-bold uppercase tracking-wider text-brand-700">Guided Workflow</span>
          <h2 className="text-2xl sm:text-4xl font-extrabold text-slate-900 tracking-tight mt-1">
            From Village Screening to Specialist Care
          </h2>
          <p className="text-sm sm:text-base text-slate-600 mt-2">
            One simple guided workflow. No AI expertise required by the health worker.
          </p>
        </div>

        {/* Vertical Stepper Container with Progressive SVG Line */}
        <div className="relative pl-8 sm:pl-16 space-y-8">
          {/* Vertical progress line background */}
          <div className="absolute left-3.5 sm:left-7 top-4 bottom-4 w-1 bg-slate-200 rounded-full" />

          {/* Animated drawing line (Framer Motion) */}
          {!shouldReduceMotion ? (
            <motion.div
              style={{ scaleY: pathLength, originY: 0 }}
              className="absolute left-3.5 sm:left-7 top-4 bottom-4 w-1 bg-brand-700 rounded-full"
            />
          ) : (
            <div className="absolute left-3.5 sm:left-7 top-4 bottom-4 w-1 bg-brand-700 rounded-full" />
          )}

          {workflowSteps.map((step) => {
            const Icon = step.icon;
            return (
              <div
                key={step.num}
                className="relative flex items-start gap-4 group"
              >
                {/* Node Circle */}
                <div className="absolute -left-8 sm:-left-16 w-8 h-8 sm:w-9 sm:h-9 rounded-full bg-white border-2 border-brand-700 flex items-center justify-center text-brand-700 font-bold text-xs sm:text-sm shadow-xs z-10">
                  {step.num}
                </div>

                {/* Step Card Content */}
                <div className="flex-1 bg-white rounded-2xl p-4 sm:p-5 border border-slate-200 shadow-2xs hover:border-brand-300 transition-colors">
                  <div className="flex items-center gap-2.5 mb-1.5">
                    <Icon className="w-5 h-5 text-brand-700" />
                    <h3 className="text-base font-bold text-slate-900">
                      {step.title}
                    </h3>
                  </div>
                  <p className="text-xs sm:text-sm text-slate-600 leading-relaxed">
                    {step.desc}
                  </p>
                </div>
              </div>
            );
          })}
        </div>
      </section>

      {/* ================= SECTION 4: DESIGNED FOR RURAL SCREENING ================= */}
      <section className="px-4 sm:px-6 max-w-5xl mx-auto">
        <div className="text-center mb-10">
          <span className="text-xs font-bold uppercase tracking-wider text-brand-700">Capabilities</span>
          <h2 className="text-2xl sm:text-4xl font-extrabold text-slate-900 tracking-tight mt-1">
            Built Specifically for Rural India
          </h2>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
          <div className="bg-white rounded-2xl p-5 border border-slate-200 shadow-2xs space-y-2">
            <WifiOff className="w-6 h-6 text-amber-600" />
            <h3 className="text-base font-bold text-slate-900">Works with Weak Internet</h3>
            <p className="text-xs text-slate-600 leading-relaxed">
              Screenings can be saved locally in IndexedDB and uploaded when 2G/3G connectivity returns.
            </p>
          </div>

          <div className="bg-white rounded-2xl p-5 border border-slate-200 shadow-2xs space-y-2">
            <Languages className="w-6 h-6 text-brand-700" />
            <h3 className="text-base font-bold text-slate-900">Local-Language Interface</h3>
            <p className="text-xs text-slate-600 leading-relaxed">
              Full English and authentic Hindi (Devanagari) dictionaries with instant 1-tap switching.
            </p>
          </div>

          <div className="bg-white rounded-2xl p-5 border border-slate-200 shadow-2xs space-y-2">
            <History className="w-6 h-6 text-indigo-700" />
            <h3 className="text-base font-bold text-slate-900">Patient History</h3>
            <p className="text-xs text-slate-600 leading-relaxed">
              Previous screenings and images remain linked to the patient ID for longitudinal tracking.
            </p>
          </div>

          <div className="bg-white rounded-2xl p-5 border border-slate-200 shadow-2xs space-y-2">
            <FileCheck className="w-6 h-6 text-emerald-700" />
            <h3 className="text-base font-bold text-slate-900">Action-Based Results</h3>
            <p className="text-xs text-slate-600 leading-relaxed">
              Clear clinical actions: Routine, Review, Priority, or Retake Image. No confusing percentages.
            </p>
          </div>

          <div className="bg-white rounded-2xl p-5 border border-slate-200 shadow-2xs space-y-2 sm:col-span-2 lg:col-span-1">
            <Share2 className="w-6 h-6 text-brand-700" />
            <h3 className="text-base font-bold text-slate-900">Specialist Tele-Referral</h3>
            <p className="text-xs text-slate-600 leading-relaxed">
              Instantly transmit priority cases to district hospital ophthalmology departments for remote review.
            </p>
          </div>
        </div>
      </section>

      {/* ================= SECTION 5: OFFLINE-FIRST SHOWCASE ================= */}
      <section className="px-4 sm:px-6 max-w-3xl mx-auto">
        <div className="bg-slate-900 text-white rounded-3xl p-6 sm:p-8 shadow-lg border border-slate-800">
          <div className="flex items-center gap-2.5 text-amber-400 text-xs font-bold uppercase tracking-wider mb-2">
            <WifiOff className="w-4 h-4" />
            <span>Offline-First Guarantee</span>
          </div>

          <h2 className="text-2xl sm:text-3xl font-bold tracking-tight text-white mb-2">
            No network? Continue screening.
          </h2>

          <p className="text-xs sm:text-sm text-slate-300 mb-6 leading-relaxed">
            In remote villages with zero mobile signal, health workers continue patient registration, capture, and quality checks. Nothing is blocked or lost.
          </p>

          {/* Interactive Phone Simulation Card */}
          <div className="bg-slate-950 rounded-2xl p-4 sm:p-5 border border-slate-800 space-y-3 font-sans">
            <div className="flex items-center justify-between pb-2 border-b border-slate-800 text-xs">
              <span className="flex items-center gap-2 text-amber-400 font-bold">
                <span className="w-2 h-2 rounded-full bg-amber-500 animate-pulse" />
                ○ Offline • 3 screenings waiting for upload
              </span>
              <span className="text-slate-500">IndexedDB Active</span>
            </div>

            <div className="space-y-2 text-xs">
              <div className="p-2.5 bg-slate-900 rounded-xl flex items-center justify-between">
                <div>
                  <span className="font-bold text-white">Patient DR-2026-01842 (Kamla Devi)</span>
                  <span className="text-[11px] text-slate-400 block">Right Eye • Review flagged</span>
                </div>
                <span className="text-emerald-400 font-bold">Saved locally ✓</span>
              </div>

              <div className="p-2.5 bg-slate-900 rounded-xl flex items-center justify-between">
                <div>
                  <span className="font-bold text-white">Patient DR-2026-01843 (Ram Prasad)</span>
                  <span className="text-[11px] text-slate-400 block">Left Eye • Priority flagged</span>
                </div>
                <span className="text-emerald-400 font-bold">Saved locally ✓</span>
              </div>
            </div>

            <div className="pt-2 flex items-center justify-between text-[11px] text-slate-400">
              <span>When connectivity returns:</span>
              <span className="text-brand-400 font-semibold">Auto-Syncing 2 of 3...</span>
            </div>
          </div>
        </div>
      </section>

      {/* ================= SECTION 6: PRIORITY SYSTEM ================= */}
      <section className="px-4 sm:px-6 max-w-5xl mx-auto">
        <div className="text-center mb-10">
          <span className="text-xs font-bold uppercase tracking-wider text-brand-700">Triage Model</span>
          <h2 className="text-2xl sm:text-4xl font-extrabold text-slate-900 tracking-tight mt-1">
            Standardized Four-Tier Priority System
          </h2>
          <p className="text-xs sm:text-sm text-slate-600 mt-2">
            Never communicates status through color alone. Every badge pairs icon, color, and unambiguous clinical guidance.
          </p>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-3 gap-4 mb-4">
          {/* Routine */}
          <div className="bg-emerald-50/80 rounded-2xl p-5 border border-emerald-300 space-y-2">
            <StatusBadge status="ROUTINE" size="lg" />
            <p className="text-xs text-slate-700 font-medium pt-1">
              "No concerning abnormality detected during screening."
            </p>
            <div className="text-[11px] font-bold text-emerald-900 pt-2 border-t border-emerald-200">
              Next step: Continue routine 12-month follow-up.
            </div>
          </div>

          {/* Review */}
          <div className="bg-amber-50/80 rounded-2xl p-5 border border-amber-300 space-y-2">
            <StatusBadge status="REVIEW" size="lg" />
            <p className="text-xs text-slate-700 font-medium pt-1">
              "Microvascular changes detected. Specialist review recommended."
            </p>
            <div className="text-[11px] font-bold text-amber-950 pt-2 border-t border-amber-200">
              Next step: Refer for remote ophthalmologist triage.
            </div>
          </div>

          {/* Priority */}
          <div className="bg-rose-50/80 rounded-2xl p-5 border border-rose-300 space-y-2">
            <StatusBadge status="PRIORITY" size="lg" />
            <p className="text-xs text-slate-700 font-medium pt-1">
              "Severe retinal hemorrhages or macular threat detected."
            </p>
            <div className="text-[11px] font-bold text-rose-950 pt-2 border-t border-rose-200">
              Next step: Expedite in-person hospital evaluation.
            </div>
          </div>
        </div>

        {/* Retake separately to make sure it is not confused with disease */}
        <div className="bg-yellow-50/80 rounded-2xl p-4 border border-yellow-300 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3">
          <div className="space-y-1">
            <StatusBadge status="RETAKE" size="md" />
            <p className="text-xs text-slate-700">
              <strong>Retake Image:</strong> The photo is underexposed or blurred. This is an <em>image quality issue</em>, not a medical result.
            </p>
          </div>
          <span className="text-xs font-bold text-yellow-900 bg-white px-3 py-1 rounded-lg border border-yellow-300 whitespace-nowrap">
            Action: Re-align & Capture Again
          </span>
        </div>
      </section>

      {/* ================= SECTION 7: CLINICAL TRUST ================= */}
      <section className="px-4 sm:px-6 max-w-4xl mx-auto">
        <div className="bg-white rounded-3xl p-6 sm:p-10 border border-slate-200 shadow-sm text-center space-y-6">
          <div className="w-14 h-14 rounded-2xl bg-teal-50 border border-brand-200 flex items-center justify-center text-brand-700 mx-auto">
            <ShieldCheck className="w-8 h-8" />
          </div>

          <div>
            <h2 className="text-2xl sm:text-3xl font-extrabold text-slate-900 tracking-tight">
              AI assists. Specialists decide.
            </h2>
            <p className="text-sm sm:text-base text-slate-600 max-w-xl mx-auto mt-2 leading-relaxed">
              This platform supports rural screening and clinical prioritization. It does not replace an ophthalmologist or provide a final clinical diagnosis.
            </p>
          </div>

          <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 text-xs font-bold text-slate-800">
            <div className="p-3 rounded-xl bg-slate-50 border border-slate-200">
              1. Community Screening
            </div>
            <div className="p-3 rounded-xl bg-slate-50 border border-slate-200">
              2. Cloud Prioritization
            </div>
            <div className="p-3 rounded-xl bg-indigo-50 border border-indigo-200 text-indigo-900">
              3. Specialist Review
            </div>
            <div className="p-3 rounded-xl bg-teal-50 border border-teal-200 text-brand-900">
              4. Human Clinical Care
            </div>
          </div>
        </div>
      </section>

      {/* ================= SECTION 8: FINAL CTA ================= */}
      <section className="px-4 sm:px-6 max-w-4xl mx-auto text-center space-y-6">
        <h2 className="text-3xl sm:text-4xl font-extrabold text-slate-900 tracking-tight">
          Ready to begin rural screening?
        </h2>
        <p className="text-sm sm:text-base text-slate-600 max-w-md mx-auto">
          Sign in to the operational portal to test the health worker workflow or review cases as an ophthalmologist.
        </p>

        <div className="flex flex-col sm:flex-row items-center justify-center gap-3 max-w-sm mx-auto">
          <Link
            to="/login"
            className="w-full px-6 py-4 rounded-xl bg-brand-700 hover:bg-brand-800 text-white font-bold text-base transition-colors shadow-sm"
          >
            Health Worker Login
          </Link>
          <Link
            to="/specialist"
            className="w-full px-6 py-4 rounded-xl bg-white border border-slate-300 hover:bg-slate-50 text-slate-800 font-bold text-base transition-colors shadow-2xs"
          >
            Specialist Review
          </Link>
        </div>
      </section>
    </div>
  );
};
