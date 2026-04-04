/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        'gw-blue': '#0066CC',
        'deep-navy': '#002B54',
        'teal-accent': '#00A4A4',
        'orange-warning': '#FF6B35',
        'red-alert': '#DC3545',
        'light-gray': '#F8F9FA',
      },
      fontFamily: {
        sans: ['Inter', 'sans-serif'],
        mono: ['SF Mono', 'ui-monospace', 'monospace'],
      },
    },
  },
  plugins: [],
}
