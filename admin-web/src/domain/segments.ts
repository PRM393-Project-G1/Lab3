import { isRunning, type Analysis } from './analysis';
import type { NotificationRecipient } from './notifications';
import type { DirectoryUser } from './users';

export interface Segment { key: string; label: string; description: string; uids: string[] }

/**
 * Ready-made recipient groups built from data the admin web already reads.
 * Only regular users are candidates, since announcements never reach admins.
 */
export function recipientSegments(recipients: NotificationRecipient[], users: DirectoryUser[], analyses: Analysis[], now = new Date()): Segment[] {
  const latest = new Map<string, Analysis>();
  const running = new Set<string>();
  for (const analysis of analyses) {
    if (!analysis.requestedBy) continue;
    if (isRunning(analysis)) running.add(analysis.requestedBy);
    const current = latest.get(analysis.requestedBy);
    if (!current || (analysis.createdAt?.getTime() ?? 0) > (current.createdAt?.getTime() ?? 0)) latest.set(analysis.requestedBy, analysis);
  }
  const lastSignIn = new Map(users.map((user) => [user.uid, user.lastSignInAt]));
  const cutoff = now.getTime() - 30 * 86400000;
  const pick = (test: (uid: string, recipient: NotificationRecipient) => boolean) =>
    recipients.filter((recipient) => test(recipient.uid, recipient)).map((recipient) => recipient.uid);
  return [
    { key: 'last-failed', label: 'Last analysis failed', description: 'Their most recent request ended in an error',
      uids: pick((uid) => latest.get(uid)?.status === 'failed') },
    { key: 'running', label: 'Analysis in progress', description: 'A request is still queued or processing', uids: pick((uid) => running.has(uid)) },
    { key: 'never', label: 'No analyses yet', description: 'Signed up but never checked a paper', uids: pick((uid) => !latest.has(uid)) },
    { key: 'inactive', label: 'Away for 30 days', description: 'Last sign-in more than 30 days ago',
      uids: pick((uid) => { const seen = lastSignIn.get(uid); return !!seen && seen.getTime() < cutoff; }) },
    { key: 'push', label: 'Has push device', description: 'Gets a push as well as the inbox item', uids: pick((_uid, recipient) => recipient.hasDevice) },
  ];
}
