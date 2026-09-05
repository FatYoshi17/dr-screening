/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        brand: {
          50: '#f0fdfa',
          100: '#ccfbf1',
          200: '#99f6e4',
          300: '#5eead4',
          400: '#2dd4bf',
          500: '#14b8a6',
          600: '#0d9488',
          700: '#0f766e',
          800: '#115e59',
          900: '#134e4a',
          950: '#042f2e',
        },
        surface: {
          ground: '#f8faf9',
          card: '#ffffff',
          subtle: '#f1f5f3',
          border: '#e2e8e5',
        },
        status: {
          routine: {
            text: '#15803d',
            bg: '#dcfce7',
            border: '#86efac',
            icon: '#16a34a'
          },
          review: {
            text: '#b45309',
            bg: '#fef3c7',
            border: '#fde68a',
            icon: '#d97706'
          },
          priority: {
            text: '#b91c1c',
            bg: '#fee2e2',
            border: '#fca5a5',
            icon: '#dc2626'
          },
          retake: {
            text: '#854d0e',
            bg: '#fef9c3',
            border: '#fde047',
            icon: '#ca8a04'
          }
        }
      },
      fontFamily: {
        sans: ['Inter', 'Noto Sans', 'Noto Sans Devanagari', 'system-ui', '-apple-system', 'sans-serif'],
      },
      minHeight: {
        'touch': '48px',
        'touch-lg': '56px',
      },
      minWidth: {
        'touch': '48px',
      }
    },
  },
  plugins: [],
}
