import { date, type RawDocument } from './analysis';

export interface NotificationRecipient { uid: string; name: string; hasDevice: boolean }
export interface AnnouncementDraft { title: string; body: string; audience: 'all' | 'selected'; recipientUids: string[] }
export type AnnouncementStatus = 'queued' | 'processing' | 'completed' | 'partial' | 'failed' | 'interrupted' | 'unknown';
export interface AnnouncementCounts {
  recipients: number; inboxStored: number; pushAccepted: number; pushFailed: number;
  pushUnknown: number; withoutDevice: number; skipped: number; inboxFailed: number;
}
export interface AnnouncementRequest extends AnnouncementDraft {
  id: string; requestedBy: string; createdAt: Date | null; status: AnnouncementStatus;
  counts: AnnouncementCounts; error: string | null;
}

export function normalizeDraft(draft: AnnouncementDraft): AnnouncementDraft {
  return { title: draft.title.trim(), body: draft.body.trim(), audience: draft.audience,
    recipientUids: draft.audience === 'all' ? [] : [...new Set(draft.recipientUids)].sort() };
}
export function validateDraft(raw: AnnouncementDraft): string | null {
  const draft = normalizeDraft(raw);
  if (!draft.title || draft.title.length > 80) return 'Enter a title with 1–80 characters.';
  if (!draft.body || draft.body.length > 500) return 'Enter a message with 1–500 characters.';
  if (draft.audience === 'selected' && !draft.recipientUids.length) return 'Select at least one user.';
  if (draft.recipientUids.length > 100) return 'Select at most 100 users per message.';
  return null;
}
export function parseAnnouncement(id: string, raw: RawDocument): AnnouncementRequest {
  const counts = raw.counts && typeof raw.counts === 'object' ? raw.counts as Record<string, unknown> : {};
  const number = (key: string) => typeof counts[key] === 'number' && Number.isFinite(counts[key]) ? Math.max(0, counts[key] as number) : 0;
  const states = ['queued', 'processing', 'completed', 'partial', 'failed', 'interrupted'];
  return { id, title: typeof raw.title === 'string' ? raw.title : 'Untitled message',
    body: typeof raw.body === 'string' ? raw.body : '', audience: raw.audience === 'selected' ? 'selected' : 'all',
    recipientUids: Array.isArray(raw.recipientUids) ? raw.recipientUids.filter((uid): uid is string => typeof uid === 'string') : [],
    requestedBy: typeof raw.requestedBy === 'string' ? raw.requestedBy : '', createdAt: date(raw.createdAt),
    status: states.includes(raw.status as string) ? raw.status as AnnouncementStatus : 'unknown',
    error: typeof raw.error === 'string' ? raw.error : null,
    counts: { recipients: number('recipients'), inboxStored: number('inboxStored'), pushAccepted: number('pushAccepted'),
      pushFailed: number('pushFailed'), pushUnknown: number('pushUnknown'), withoutDevice: number('withoutDevice'), skipped: number('skipped'), inboxFailed: number('inboxFailed') },
  };
}
