import React from 'react';
import { useTranslation } from 'react-i18next';
import { changeLanguage } from '../../i18n';

interface LanguageToggleProps {
  compact?: boolean;
}

export const LanguageToggle: React.FC<LanguageToggleProps> = ({ compact = false }) => {
  const { i18n } = useTranslation();
  const currentLang = i18n.language.startsWith('hi') ? 'hi' : 'en';

  return (
    <div
      className="inline-flex items-center rounded-lg bg-slate-100 p-0.5 border border-slate-300"
      role="radiogroup"
      aria-label="Select Language"
    >
      <button
        type="button"
        role="radio"
        aria-checked={currentLang === 'en'}
        onClick={() => changeLanguage('en')}
        className={`px-2.5 py-1 text-xs font-semibold rounded-md transition-colors cursor-pointer ${
          currentLang === 'en'
            ? 'bg-white text-brand-800 shadow-xs'
            : 'text-slate-600 hover:text-slate-900'
        }`}
      >
        EN
      </button>
      <button
        type="button"
        role="radio"
        aria-checked={currentLang === 'hi'}
        onClick={() => changeLanguage('hi')}
        className={`px-2.5 py-1 text-xs font-semibold rounded-md transition-colors cursor-pointer ${
          currentLang === 'hi'
            ? 'bg-white text-brand-800 shadow-xs'
            : 'text-slate-600 hover:text-slate-900'
        }`}
      >
        हिंदी
      </button>
    </div>
  );
};
