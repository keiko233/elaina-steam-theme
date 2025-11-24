/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./src/**/*.{ts,tsx,js,jsx,scss,css}",
  ],
  corePlugins: {
    preflight: false, // Disable base styles to avoid affecting Steam's original styles
  },
};
