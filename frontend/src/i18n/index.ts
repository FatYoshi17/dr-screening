import i18n from 'i18next';
import { initReactI18next } from 'react-i18next';
import en from './en.json';
import hi from './hi.json';

const savedLang = localStorage.getItem('drishti_lang') || 'en';

i18n
  .use(initReactI18next)
  .init({
    resources: {
      en: { translation: en },
      hi: { translation: hi },
    },
    lng: savedLang,
    fallbackLng: 'en',
    interpolation: {
      escapeValue: false, // React already escapes values
    },
  });

export const changeLanguage = (lng: 'en' | 'hi') => {
  i18n.changeLanguage(lng);
  localStorage.setItem('drishti_lang', lng);
};

export default i18n;
