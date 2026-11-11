import type { AnalysisFeed, AnalysisResults, WeakRule } from '../domain/analysis';
import type { DirectoryUser } from '../domain/users';
import type { ActionDraft, AdminActionRecord } from '../domain/actions';
import type { WorkerStatus } from '../domain/workers';
import type { AnnouncementDraft, AnnouncementRequest, NotificationRecipient } from '../domain/notifications';

export type Unsubscribe = () => void;
export interface AdminUser { uid: string; name: string; email: string | null }
export interface AdminGateway {
  watchAuth(next: (user: AdminUser | null) => void, error: (error: unknown) => void): Unsubscribe;
  watchRole(uid: string, next: (role: 'admin' | 'user') => void, error: (error: unknown) => void): Unsubscribe;
  signIn(): Promise<void>;
  signOut(): Promise<void>;
  watchAnalyses(next: (feed: AnalysisFeed) => void, error: (error: unknown) => void): Unsubscribe;
  getResults(id: string): Promise<AnalysisResults>;
  /** The weak-topic rule from Remote Config, with safe defaults. */
  getWeakRule(): Promise<WeakRule>;
  watchWorkers(next: (workers: WorkerStatus[]) => void, error: (error: unknown) => void): Unsubscribe;
  /** Recent admin actions, newest first. */
  watchActions(next: (actions: AdminActionRecord[]) => void, error: (error: unknown) => void): Unsubscribe;
  /** Creates the request once; retrying the same ID never queues it twice. */
  requestAction(id: string, draft: ActionDraft): Promise<void>;
  /** The admin directory: every profile with its role and account state, never device tokens. */
  watchUsers(next: (users: DirectoryUser[]) => void, error: (error: unknown) => void): Unsubscribe;
  watchRecipients(next: (users: NotificationRecipient[]) => void, error: (error: unknown) => void): Unsubscribe;
  watchAnnouncements(next: (requests: AnnouncementRequest[]) => void, error: (error: unknown) => void): Unsubscribe;
  queueAnnouncement(id: string, draft: AnnouncementDraft): Promise<void>;
}

export function errorMessage(error: unknown): string {
  const code = typeof error === 'object' && error && 'code' in error ? String(error.code) : '';
  const message = typeof error === 'object' && error && 'message' in error ? String(error.message) : '';
  if (code === 'auth/invalid-api-key' || code.includes('api-key-not-valid') ||
      /API_KEY_INVALID|API key not valid/i.test(message)) {
    return 'The Firebase Web API key is invalid. Copy apiKey from Firebase Console into .env.local, restart the dev server and reload this page.';
  }
  if (code === 'auth/operation-not-allowed') return 'Google sign-in is not enabled. Enable Google in Firebase Authentication → Sign-in method.';
  if (code === 'auth/app-not-authorized') return 'This Web app is not authorized to use the configured API key. Check its restrictions and the Firebase Web configuration.';
  if (code.includes('permission-denied')) return 'Access was denied. Check your admin role and the published Firestore Rules.';
  if (code.includes('unavailable') || code.includes('network-request-failed')) return 'Cannot reach Firebase. Check your connection and try again.';
  if (code === 'auth/popup-closed-by-user' || code === 'auth/cancelled-popup-request') return 'Sign-in was cancelled. You can try again.';
  if (code === 'auth/popup-blocked') return 'Your browser blocked the sign-in window. Allow popups for this site and try again.';
  if (code === 'auth/unauthorized-domain') return 'This domain is not enabled for sign-in. Add it in Firebase Authentication → Authorized domains.';
  if (code.startsWith('auth/')) return `Google sign-in failed (${code}). Check the Firebase Authentication setup and try again.`;
  return 'Something could not be loaded. Please try again.';
}
