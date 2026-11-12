import { date, type RawDocument } from './analysis';

export interface NotificationRecipient { uid: string; name: string; hasDevice: boolean }
export interface AnnouncementDraft {
  title: string; body: string; audience: 'all' | 'selected'; recipientUids: string[];
  /** A paper the message opens when tapped. */
  analysisId?: string;
  /** When to deliver; absent means as soon as the worker sees it. */
  sendAt?: Date;
}
export type AnnouncementStatus = 'queued' | 'processing' | 'completed' | 'partial' | 'failed' | 'interrupted' | 'cancelled' | 'unknown';
export interface AnnouncementCounts {
  recipients: number; inboxStored: number; pushAccepted: number; pushFailed: number;
  pushUnknown: number; withoutDevice: number; skipped: number; inboxFailed: number;
}
export interface AnnouncementRequest extends AnnouncementDraft {
  id: string; requestedBy: string; createdAt: Date | null; status: AnnouncementStatus;
  counts: AnnouncementCounts; error: string | null;
  /** Inbox items opened in the app, counted by the worker every 15 minutes for a week. */
  readCount: number | null; readCheckedAt: Date | null;
}

export function normalizeDraft(draft: AnnouncementDraft): AnnouncementDraft {
  const analysisId = draft.analysisId?.trim();
  return { title: draft.title.trim(), body: draft.body.trim(), audience: draft.audience,
    recipientUids: draft.audience === 'all' ? [] : [...new Set(draft.recipientUids)].sort(), ...(analysisId ? { analysisId } : {}),
    ...(draft.sendAt instanceof Date ? { sendAt: draft.sendAt } : {}) };
}
/** Scheduling bounds, matching Firestore Rules with a margin for the time it takes to submit. */
export const scheduleLimits = { minMinutes: 5, maxDays: 30 } as const;
export function validateDraft(raw: AnnouncementDraft, now = new Date()): string | null {
  const draft = normalizeDraft(raw);
  if (!draft.title || draft.title.length > 80) return 'Enter a title with 1–80 characters.';
  if (!draft.body || draft.body.length > 500) return 'Enter a message with 1–500 characters.';
  if (draft.audience === 'selected' && !draft.recipientUids.length) return 'Select at least one user.';
  if (draft.recipientUids.length > 100) return 'Select at most 100 users per message.';
  if (draft.analysisId !== undefined && !/^\d{4}\.\d{4,5}$/.test(draft.analysisId)) return 'Choose a valid paper to link.';
  if (draft.sendAt) {
    const ahead = draft.sendAt.getTime() - now.getTime();
    if (Number.isNaN(ahead)) return 'Choose a delivery time.';
    if (ahead < scheduleLimits.minMinutes * 60000) return `Schedule at least ${scheduleLimits.minMinutes} minutes ahead, or send now.`;
    if (ahead > scheduleLimits.maxDays * 86400000 - 3600000) return `Schedule within the next ${scheduleLimits.maxDays} days.`;
  }
  return null;
}
export function parseAnnouncement(id: string, raw: RawDocument): AnnouncementRequest {
  const counts = raw.counts && typeof raw.counts === 'object' ? raw.counts as Record<string, unknown> : {};
  const number = (key: string) => typeof counts[key] === 'number' && Number.isFinite(counts[key]) ? Math.max(0, counts[key] as number) : 0;
  const states = ['queued', 'processing', 'completed', 'partial', 'failed', 'interrupted', 'cancelled'];
  return { id, title: typeof raw.title === 'string' ? raw.title : 'Untitled message',
    body: typeof raw.body === 'string' ? raw.body : '', audience: raw.audience === 'selected' ? 'selected' : 'all',
    recipientUids: Array.isArray(raw.recipientUids) ? raw.recipientUids.filter((uid): uid is string => typeof uid === 'string') : [],
    ...(typeof raw.analysisId === 'string' ? { analysisId: raw.analysisId } : {}),
    ...(date(raw.sendAt) ? { sendAt: date(raw.sendAt)! } : {}),
    requestedBy: typeof raw.requestedBy === 'string' ? raw.requestedBy : '', createdAt: date(raw.createdAt),
    status: states.includes(raw.status as string) ? raw.status as AnnouncementStatus : 'unknown',
    error: typeof raw.error === 'string' ? raw.error : null,
    readCount: typeof raw.readCount === 'number' && Number.isFinite(raw.readCount) ? Math.max(0, raw.readCount) : null,
    readCheckedAt: date(raw.readCheckedAt),
    counts: { recipients: number('recipients'), inboxStored: number('inboxStored'), pushAccepted: number('pushAccepted'),
      pushFailed: number('pushFailed'), pushUnknown: number('pushUnknown'), withoutDevice: number('withoutDevice'), skipped: number('skipped'), inboxFailed: number('inboxFailed') },
  };
}

/** Queued for later and not yet due. */
export function isScheduled(request: AnnouncementRequest, now = new Date()): boolean {
  return request.status === 'queued' && !!request.sendAt && request.sendAt > now;
}

/** Share of stored inbox items that were opened, or null before the first count. */
export function readRate(request: AnnouncementRequest): number | null {
  return request.readCount === null || !request.counts.inboxStored ? null : Math.min(1, request.readCount / request.counts.inboxStored);
}
