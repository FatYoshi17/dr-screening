import React from 'react';
import { useNavigate } from 'react-router-dom';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { useTranslation } from 'react-i18next';
import { patientService } from '../../services/patientService';
import { useScreeningStore } from '../../stores/screeningStore';
import { PrimaryButton } from '../../components/ui/PrimaryButton';
import { SecondaryButton } from '../../components/ui/SecondaryButton';
import { StickyActionBar } from '../../components/ui/StickyActionBar';
import { ArrowRight, Save, UserCheck } from 'lucide-react';
import type { DiabetesStatus } from '../../types';

const patientSchema = z.object({
  name: z.string().min(2, "Enter patient's full name."),
  age: z.coerce.number().min(1, "Enter patient's age.").max(120, 'Enter a valid age.'),
  sex: z.enum(['Female', 'Male', 'Other'], { required_error: 'Select patient sex.' }),
  village: z.string().min(2, "Enter village or locality name."),
  phone: z.string().optional(),
  diabetesStatus: z.enum(
    ['KNOWN_DIABETES', 'RECENTLY_DIAGNOSED', 'SUSPECTED', 'NO_DIABETES'],
    { required_error: 'Select diabetes history.' }
  ),
  diabetesControl: z.enum(['Controlled', 'Uncontrolled']).optional(),
  diabetesDurationYears: z.coerce.number().min(0).max(80).optional(),
  hba1c: z.coerce.number().min(3).max(20).optional()
});

type PatientFormData = z.infer<typeof patientSchema>;

export const NewPatientPage: React.FC = () => {
  const { t } = useTranslation();
  const navigate = useNavigate();
  const startScreening = useScreeningStore((state) => state.startScreening);

  const {
    register,
    handleSubmit,
    setValue,
    watch,
    formState: { errors, isSubmitting }
  } = useForm<PatientFormData>({
    resolver: zodResolver(patientSchema),
    defaultValues: {
      name: '',
      age: undefined,
      sex: 'Female',
      village: 'Rampur',
      phone: '',
      diabetesStatus: 'KNOWN_DIABETES'
    }
  });

  const selectedSex = watch('sex');
  const selectedDiabetes = watch('diabetesStatus');
  const selectedControl = watch('diabetesControl');

  const onSaveAndScreen = async (data: PatientFormData) => {
    const saved = await patientService.registerPatient(data);
    startScreening(saved);
    navigate('/screening/new');
  };

  const onSaveOnly = async (data: PatientFormData) => {
    const saved = await patientService.registerPatient(data);
    navigate(`/patient/${saved.id}`);
  };

  return (
    <div className="pb-24">
      <div className="bg-white rounded-2xl p-5 border border-slate-200 shadow-xs mb-6">
        <div className="flex items-center gap-2 mb-4 pb-3 border-b border-slate-100">
          <UserCheck className="w-5 h-5 text-brand-700" />
          <h1 className="text-xl font-bold text-slate-900 tracking-tight">
            {t('patient.registerNew')}
          </h1>
        </div>

        <form id="patient-form" className="space-y-4">
          {/* Full Name */}
          <div>
            <label className="block text-xs font-bold uppercase tracking-wider text-slate-700 mb-1">
              {t('patient.name')} <span className="text-rose-600">*</span>
            </label>
            <input
              type="text"
              {...register('name')}
              placeholder="e.g. Shanti Devi"
              className="w-full px-3.5 py-3 rounded-xl border border-slate-300 text-base text-slate-900 focus:outline-none focus:ring-2 focus:ring-brand-600 min-h-[48px]"
            />
            {errors.name && (
              <p className="text-xs text-rose-600 font-medium mt-1">{errors.name.message}</p>
            )}
          </div>

          {/* Age and Sex (Compact Single Row or Cards) */}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <label className="block text-xs font-bold uppercase tracking-wider text-slate-700 mb-1">
                {t('patient.age')} <span className="text-rose-600">*</span>
              </label>
              <input
                type="number"
                inputMode="numeric"
                {...register('age')}
                placeholder="e.g. 54"
                className="w-full px-3.5 py-3 rounded-xl border border-slate-300 text-base text-slate-900 focus:outline-none focus:ring-2 focus:ring-brand-600 min-h-[48px]"
              />
              {errors.age && (
                <p className="text-xs text-rose-600 font-medium mt-1">{errors.age.message}</p>
              )}
            </div>

            <div>
              <label className="block text-xs font-bold uppercase tracking-wider text-slate-700 mb-1">
                {t('patient.sex')} <span className="text-rose-600">*</span>
              </label>
              <div className="grid grid-cols-3 gap-1.5">
                {(['Female', 'Male', 'Other'] as const).map((s) => (
                  <button
                    key={s}
                    type="button"
                    onClick={() => setValue('sex', s)}
                    className={`py-3 text-xs font-bold rounded-xl border text-center transition-colors cursor-pointer min-h-[48px] ${
                      selectedSex === s
                        ? 'bg-brand-700 text-white border-brand-800 shadow-2xs'
                        : 'bg-slate-50 text-slate-700 border-slate-200 hover:bg-slate-100'
                    }`}
                  >
                    {s === 'Female' ? t('patient.female') : s === 'Male' ? t('patient.male') : t('patient.other')}
                  </button>
                ))}
              </div>
            </div>
          </div>

          {/* Village */}
          <div>
            <label className="block text-xs font-bold uppercase tracking-wider text-slate-700 mb-1">
              {t('patient.village')} <span className="text-rose-600">*</span>
            </label>
            <input
              type="text"
              {...register('village')}
              placeholder="e.g. Rampur"
              className="w-full px-3.5 py-3 rounded-xl border border-slate-300 text-base text-slate-900 focus:outline-none focus:ring-2 focus:ring-brand-600 min-h-[48px]"
            />
            {errors.village && (
              <p className="text-xs text-rose-600 font-medium mt-1">{errors.village.message}</p>
            )}
          </div>

          {/* Mobile Phone (Optional) */}
          <div>
            <label className="block text-xs font-bold uppercase tracking-wider text-slate-700 mb-1">
              {t('patient.phone')}
            </label>
            <input
              type="tel"
              inputMode="tel"
              {...register('phone')}
              placeholder="e.g. 9876543210"
              className="w-full px-3.5 py-3 rounded-xl border border-slate-300 text-base text-slate-900 focus:outline-none focus:ring-2 focus:ring-brand-600 min-h-[48px]"
            />
          </div>

          {/* Diabetes History (Selection Cards) */}
          <div>
            <label className="block text-xs font-bold uppercase tracking-wider text-slate-700 mb-2">
              {t('patient.diabetesStatus')} <span className="text-rose-600">*</span>
            </label>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
              {[
                { id: 'KNOWN_DIABETES' as DiabetesStatus, label: t('patient.knownDiabetes') },
                { id: 'RECENTLY_DIAGNOSED' as DiabetesStatus, label: t('patient.recentlyDiagnosed') },
                { id: 'SUSPECTED' as DiabetesStatus, label: t('patient.suspected') },
                { id: 'NO_DIABETES' as DiabetesStatus, label: t('patient.noDiabetes') },
              ].map((item) => (
                <button
                  key={item.id}
                  type="button"
                  onClick={() => setValue('diabetesStatus', item.id)}
                  className={`p-3 text-left rounded-xl border transition-colors cursor-pointer min-h-[48px] ${
                    selectedDiabetes === item.id
                      ? 'bg-teal-50/80 border-brand-600 text-brand-950 font-bold shadow-2xs'
                      : 'bg-slate-50 border-slate-200 text-slate-700 hover:bg-slate-100 font-medium'
                  }`}
                >
                  <div className="text-xs">{item.label}</div>
                </button>
              ))}
            </div>
          </div>

          {/* Diabetes control / duration / HbA1c - clinical context for the report's first page */}
          {selectedDiabetes !== 'NO_DIABETES' && (
            <>
              <div>
                <label className="block text-xs font-bold uppercase tracking-wider text-slate-700 mb-2">
                  Diabetes Control
                </label>
                <div className="grid grid-cols-2 gap-2">
                  {(['Controlled', 'Uncontrolled'] as const).map((c) => (
                    <button
                      key={c}
                      type="button"
                      onClick={() => setValue('diabetesControl', c)}
                      className={`py-3 text-xs font-bold rounded-xl border text-center transition-colors cursor-pointer min-h-[48px] ${
                        selectedControl === c
                          ? 'bg-brand-700 text-white border-brand-800 shadow-2xs'
                          : 'bg-slate-50 text-slate-700 border-slate-200 hover:bg-slate-100'
                      }`}
                    >
                      {c}
                    </button>
                  ))}
                </div>
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div>
                  <label className="block text-xs font-bold uppercase tracking-wider text-slate-700 mb-1">
                    Duration of Diabetes (years)
                  </label>
                  <input
                    type="number"
                    inputMode="numeric"
                    {...register('diabetesDurationYears')}
                    placeholder="e.g. 8"
                    className="w-full px-3.5 py-3 rounded-xl border border-slate-300 text-base text-slate-900 focus:outline-none focus:ring-2 focus:ring-brand-600 min-h-[48px]"
                  />
                </div>
                <div>
                  <label className="block text-xs font-bold uppercase tracking-wider text-slate-700 mb-1">
                    HbA1c (%)
                  </label>
                  <input
                    type="number"
                    step="0.1"
                    inputMode="decimal"
                    {...register('hba1c')}
                    placeholder="e.g. 9.2"
                    className="w-full px-3.5 py-3 rounded-xl border border-slate-300 text-base text-slate-900 focus:outline-none focus:ring-2 focus:ring-brand-600 min-h-[48px]"
                  />
                </div>
              </div>
            </>
          )}
        </form>
      </div>

      {/* Sticky Bottom Actions */}
      <StickyActionBar>
        <SecondaryButton
          type="button"
          disabled={isSubmitting}
          onClick={handleSubmit(onSaveOnly)}
          className="flex-1"
          icon={Save}
        >
          {t('patient.saveOnly')}
        </SecondaryButton>

        <PrimaryButton
          type="button"
          disabled={isSubmitting}
          onClick={handleSubmit(onSaveAndScreen)}
          className="flex-2"
          icon={ArrowRight}
        >
          {t('patient.saveAndScreen')}
        </PrimaryButton>
      </StickyActionBar>
    </div>
  );
};
