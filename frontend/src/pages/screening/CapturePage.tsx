import React, { useState, useRef } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { useScreeningStore } from '../../stores/screeningStore';
import { DEMO_KEYS } from '../../services/screeningService';
import { PrimaryButton } from '../../components/ui/PrimaryButton';
import { SecondaryButton } from '../../components/ui/SecondaryButton';
import { StickyActionBar } from '../../components/ui/StickyActionBar';
import { FundusImage } from '../../components/ui/FundusImage';
import { Camera, RefreshCw, Check, Upload, ChevronDown, ChevronUp, Image as ImageIcon } from 'lucide-react';

export const CapturePage: React.FC = () => {
  const { id } = useParams<{ id: string }>();
  const { t } = useTranslation();
  const navigate = useNavigate();
  const { patient, eye, setEye, setImage, imageUri, imageKey } = useScreeningStore();

  const fileInputRef = useRef<HTMLInputElement>(null);
  const [demoDrawerOpen, setDemoDrawerOpen] = useState(false);
  const [examplesOpen, setExamplesOpen] = useState(false);

  // Pre-configured realistic demo choices for SIH evaluation
  const demoSamples = [
    { key: 'fundus-good', label: 'Good Quality (Routine)', src: '/src/assets/demo/fundus-good.jpg' },
    { key: 'fundus-review', label: 'Moderate DR (Review)', src: '/src/assets/demo/fundus-review.jpg' },
    { key: 'fundus-priority', label: 'Severe DR (Priority)', src: '/src/assets/demo/fundus-priority.jpg' },
    { key: 'fundus-poor-dark', label: 'Poor Light (Retake)', src: '/src/assets/demo/fundus-poor-dark.jpg' },
    { key: 'fundus-poor-blur', label: 'Motion Blur (Retake)', src: '/src/assets/demo/fundus-poor-blur.jpg' },
  ];

  // Default image if none chosen yet
  const currentImageUri = imageUri || '/src/assets/demo/fundus-review.jpg';
  const currentImageKey = imageKey || 'fundus-review';

  const handleSelectSample = (sample: typeof demoSamples[0]) => {
    setImage(sample.src, sample.key);
    setDemoDrawerOpen(false);
  };

  const handleFileUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      const reader = new FileReader();
      reader.onload = () => {
        if (typeof reader.result === 'string') {
          setImage(reader.result, 'custom-upload');
        }
      };
      reader.readAsDataURL(file);
    }
  };

  const handleUseThisImage = () => {
    if (!imageUri) {
      setImage(currentImageUri, currentImageKey);
    }
    navigate(`/screening/${id || patient?.id || 'new'}/quality`);
  };

  return (
    <div className="space-y-4 pb-24">
      {/* Patient & Eye Identity Header */}
      <div className="bg-white rounded-2xl p-4 border border-slate-200 shadow-2xs">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-base font-bold text-slate-900 leading-tight">
              {patient?.name || 'Patient'}
            </h1>
            <p className="text-xs text-slate-500">
              ID: {patient?.id} • {patient?.age} yrs
            </p>
          </div>

          {/* Eye Switcher */}
          <div className="flex bg-slate-100 p-1 rounded-xl border border-slate-200">
            <button
              type="button"
              onClick={() => setEye('RIGHT')}
              className={`px-3 py-1 text-xs font-bold rounded-lg transition-colors cursor-pointer ${
                eye === 'RIGHT' ? 'bg-brand-700 text-white shadow-2xs' : 'text-slate-600'
              }`}
            >
              Right (OD)
            </button>
            <button
              type="button"
              onClick={() => setEye('LEFT')}
              className={`px-3 py-1 text-xs font-bold rounded-lg transition-colors cursor-pointer ${
                eye === 'LEFT' ? 'bg-brand-700 text-white shadow-2xs' : 'text-slate-600'
              }`}
            >
              Left (OS)
            </button>
          </div>
        </div>
      </div>

      {/* Main Retinal Image Capture & Viewport */}
      <div className="bg-white rounded-2xl p-4 border border-slate-200 shadow-xs flex flex-col items-center">
        <div className="w-full flex justify-between items-center mb-3">
          <span className="text-xs font-bold uppercase tracking-wider text-slate-700">
            Retinal Viewport
          </span>
          <span className="text-xs text-slate-500 font-medium">
            {eye === 'RIGHT' ? t('capture.rightEye') : t('capture.leftEye')}
          </span>
        </div>

        {/* Live / Preview Image */}
        <FundusImage
          src={currentImageUri}
          alt={`Retinal capture of ${patient?.name || 'patient'}`}
          size="preview"
          eye={eye}
          isDemoSample={DEMO_KEYS.includes(currentImageKey)}
          className="mb-4"
        />

        {/* Action buttons under viewport */}
        <div className="w-full grid grid-cols-2 gap-2 mb-2">
          {/* Native camera trigger or simulated capture */}
          <button
            type="button"
            onClick={() => fileInputRef.current?.click()}
            className="p-3 rounded-xl border border-slate-300 bg-slate-50 hover:bg-slate-100 text-slate-800 font-bold text-xs flex items-center justify-center gap-1.5 transition-colors cursor-pointer min-h-[48px]"
          >
            <Camera className="w-4 h-4 text-brand-700" />
            <span>Camera / Upload</span>
          </button>

          {/* Quick SIH Sample Selector */}
          <button
            type="button"
            onClick={() => setDemoDrawerOpen(!demoDrawerOpen)}
            className="p-3 rounded-xl border border-brand-300 bg-teal-50/70 hover:bg-teal-100/60 text-brand-900 font-bold text-xs flex items-center justify-center gap-1.5 transition-colors cursor-pointer min-h-[48px]"
          >
            <ImageIcon className="w-4 h-4 text-brand-700" />
            <span>Choose Sample</span>
          </button>

          {/* Hidden native camera/file input */}
          <input
            ref={fileInputRef}
            type="file"
            accept="image/*"
            capture="environment"
            onChange={handleFileUpload}
            className="hidden"
          />
        </div>

        {/* SIH Sample Chooser Drawer */}
        {demoDrawerOpen && (
          <div className="w-full mt-2 p-3 bg-slate-50 rounded-xl border border-slate-200">
            <p className="text-xs font-bold text-slate-700 mb-2">
              Select Deterministic SIH Demo Image:
            </p>
            <div className="space-y-1.5">
              {demoSamples.map((s) => (
                <button
                  key={s.key}
                  type="button"
                  onClick={() => handleSelectSample(s)}
                  className={`w-full p-2 text-left rounded-lg text-xs font-medium border flex items-center justify-between transition-colors ${
                    currentImageKey === s.key
                      ? 'bg-brand-700 text-white border-brand-800'
                      : 'bg-white text-slate-800 border-slate-200 hover:bg-slate-100'
                  }`}
                >
                  <span>{s.label}</span>
                  {currentImageKey === s.key && <Check className="w-3.5 h-3.5" />}
                </button>
              ))}
            </div>
          </div>
        )}

        {/* Quality Example Disclosure Accordion */}
        <div className="w-full mt-3 border-t border-slate-100 pt-3">
          <button
            type="button"
            onClick={() => setExamplesOpen(!examplesOpen)}
            className="w-full flex items-center justify-between text-xs font-semibold text-slate-600 hover:text-slate-900 p-1"
          >
            <span>See image capture examples</span>
            {examplesOpen ? <ChevronUp className="w-4 h-4" /> : <ChevronDown className="w-4 h-4" />}
          </button>

          {examplesOpen && (
            <div className="mt-2 text-xs text-slate-600 space-y-2 bg-slate-50 p-3 rounded-xl border border-slate-200">
              <div className="flex items-center gap-2 text-emerald-800 font-semibold">
                <span className="w-2 h-2 rounded-full bg-emerald-600" />
                <span>Good: Clear optic disc, distinct branching vessels, no glare.</span>
              </div>
              <div className="flex items-center gap-2 text-amber-800 font-semibold">
                <span className="w-2 h-2 rounded-full bg-amber-600" />
                <span>Poor: Dark background, blurred vessels, reflections over macula.</span>
              </div>
            </div>
          )}
        </div>
      </div>

      {/* Sticky Bottom Actions */}
      <StickyActionBar>
        <SecondaryButton
          onClick={() => setDemoDrawerOpen(true)}
          className="flex-1"
          icon={RefreshCw}
        >
          {t('capture.captureAgain')}
        </SecondaryButton>

        <PrimaryButton
          onClick={handleUseThisImage}
          className="flex-2"
          icon={Check}
        >
          {t('capture.useThisImage')}
        </PrimaryButton>
      </StickyActionBar>
    </div>
  );
};
