export const requiredConfig = {
  VITE_FIREBASE_API_KEY: import.meta.env.VITE_FIREBASE_API_KEY,
  VITE_FIREBASE_AUTH_DOMAIN: import.meta.env.VITE_FIREBASE_AUTH_DOMAIN,
  VITE_FIREBASE_PROJECT_ID: import.meta.env.VITE_FIREBASE_PROJECT_ID,
  VITE_FIREBASE_APP_ID: import.meta.env.VITE_FIREBASE_APP_ID,
};
export const missingConfig = Object.entries(requiredConfig)
  .filter(([, value]) => !value?.trim()).map(([key]) => key);
export const invalidWebAppId = Boolean(requiredConfig.VITE_FIREBASE_APP_ID && !requiredConfig.VITE_FIREBASE_APP_ID.includes(':web:'));
