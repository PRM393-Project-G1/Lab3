import { defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react';

const isolatedFirebase = {
  VITE_FIREBASE_API_KEY: '',
  VITE_FIREBASE_AUTH_DOMAIN: '',
  VITE_FIREBASE_PROJECT_ID: '',
  VITE_FIREBASE_APP_ID: '',
};

export default defineConfig(({ mode }) => ({
  plugins: [react()],
  // Browser tests must stay isolated even after a developer fills .env.local.
  define: mode === 'e2e' ? Object.fromEntries(Object.entries(isolatedFirebase)
    .map(([key, value]) => [`import.meta.env.${key}`, JSON.stringify(value)])) : undefined,
  server: { port: 5173, strictPort: true },
  preview: { port: 4173, strictPort: true },
  test: {
    environment: 'jsdom',
    setupFiles: ['./tests/setup.ts'],
    include: ['tests/**/*.test.{ts,tsx}'],
    restoreMocks: true,
    env: isolatedFirebase,
  },
}));
