import { analysisActionTypes, describeAction, type AdminActionRecord } from './actions';
import type { AnnouncementRequest } from './notifications';

export type AuditKind = 'analysis' | 'user' | 'announcement';
export type AuditFilter = 'all' | AuditKind;
export interface AuditEntry {
  id: string; kind: AuditKind; at: Date | null; actor: string; action: string;
  /** What the action was about: an analysis ID, a user ID, or the message title. */
  target: string; reason: string | null;
  outcome: 'pending' | 'done' | 'failed' | 'cancelled'; detail: string | null;
}

const announcementOutcome: Record<AnnouncementRequest['status'], AuditEntry['outcome']> = {
  queued: 'pending', processing: 'pending', completed: 'done', partial: 'done', failed: 'failed', interrupted: 'failed', cancelled: 'cancelled', unknown: 'failed',
};

/**
 * One timeline of what admins did, newest first. Clients can only create these
 * records (or cancel a queued announcement), so nobody can rewrite one; changes made
 * directly in the Firebase Console bypass them and do not appear here.
 */
export function auditLog(actions: AdminActionRecord[], announcements: AnnouncementRequest[]): AuditEntry[] {
  const fromActions: AuditEntry[] = actions.map((action) => ({
    id: action.id, kind: (analysisActionTypes as readonly string[]).includes(action.type) ? 'analysis' : 'user',
    at: action.createdAt, actor: action.requestedBy, action: describeAction(action), target: action.target, reason: action.reason,
    outcome: action.status === 'completed' ? 'done' : action.status === 'failed' || action.status === 'unknown' ? 'failed' : 'pending',
    detail: action.error ?? action.result,
  }));
  const fromAnnouncements: AuditEntry[] = announcements.map((request) => ({
    id: request.id, kind: 'announcement', at: request.createdAt, actor: request.requestedBy,
    action: request.sendAt ? 'Schedule announcement' : 'Send announcement', target: request.title, reason: null,
    outcome: announcementOutcome[request.status],
    detail: request.status === 'cancelled' ? 'Cancelled before sending.'
      : `${request.audience === 'all' ? 'All users' : `${request.recipientUids.length} selected users`}${request.error ? ` · ${request.error}` : ''}`,
  }));
  return [...fromActions, ...fromAnnouncements].sort((a, b) => (b.at?.getTime() ?? 0) - (a.at?.getTime() ?? 0) || a.id.localeCompare(b.id));
}

export function filterAudit(entries: AuditEntry[], filter: AuditFilter, actor: string): AuditEntry[] {
  return entries.filter((entry) => (filter === 'all' || entry.kind === filter) && (!actor || entry.actor === actor));
}
