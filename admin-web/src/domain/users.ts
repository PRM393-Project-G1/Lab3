import { date, isRunning, type Analysis, type RawDocument } from './analysis';

/** One row of `adminUserDirectory`: a backend projection without device tokens. */
export interface DirectoryUser {
  uid: string; name: string; email: string | null; role: 'admin' | 'user'; disabled: boolean;
  hasDevice: boolean; createdAt: Date | null; lastSignInAt: Date | null;
}
export type UserFilter = 'all' | 'admin' | 'user' | 'disabled';

export function parseUser(uid: string, raw: RawDocument): DirectoryUser {
  return { uid, name: typeof raw.displayName === 'string' && raw.displayName.trim() ? raw.displayName : 'Unnamed user',
    email: typeof raw.email === 'string' ? raw.email : null, role: raw.role === 'admin' ? 'admin' : 'user',
    disabled: raw.disabled === true, hasDevice: raw.hasDevice === true,
    createdAt: date(raw.createdAt), lastSignInAt: date(raw.lastSignInAt) };
}

export interface UserActivity { total: number; done: number; failed: number; running: number; last: Date | null }
/** Analyses each user's requests started, keyed by UID. */
export function activityByUser(analyses: Analysis[]): Map<string, UserActivity> {
  const result = new Map<string, UserActivity>();
  for (const analysis of analyses) {
    if (!analysis.requestedBy) continue;
    const entry = result.get(analysis.requestedBy) ?? { total: 0, done: 0, failed: 0, running: 0, last: null };
    entry.total++;
    if (analysis.status === 'done') entry.done++;
    else if (analysis.status === 'failed') entry.failed++;
    else if (isRunning(analysis)) entry.running++;
    if (analysis.createdAt && (!entry.last || analysis.createdAt > entry.last)) entry.last = analysis.createdAt;
    result.set(analysis.requestedBy, entry);
  }
  return result;
}

export function filterUsers(users: DirectoryUser[], query: string, filter: UserFilter): DirectoryUser[] {
  const text = query.trim().toLowerCase();
  return users.filter((user) => (filter === 'all' || (filter === 'disabled' ? user.disabled : user.role === filter && !user.disabled)) &&
    (!text || `${user.name} ${user.email ?? ''} ${user.uid}`.toLowerCase().includes(text)))
    .sort((a, b) => Number(b.role === 'admin') - Number(a.role === 'admin') || a.name.localeCompare(b.name) || a.uid.localeCompare(b.uid));
}
