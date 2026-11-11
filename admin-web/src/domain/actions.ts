import { date, isRunning, type Analysis, type RawDocument } from './analysis';

export const actionTypes = ['cancelAnalysis', 'retryAnalysis'] as const;
export type ActionType = typeof actionTypes[number];
export interface ActionDraft { type: ActionType; target: string; reason?: string }
export type ActionStatus = 'queued' | 'processing' | 'completed' | 'failed' | 'unknown';
export interface AdminActionRecord {
  id: string; type: ActionType | 'unknown'; target: string; reason: string | null; requestedBy: string;
  createdAt: Date | null; finishedAt: Date | null; status: ActionStatus; result: string | null; error: string | null;
}

export const actionLabels: Record<ActionType | 'unknown', string> = {
  cancelAnalysis: 'Stop analysis', retryAnalysis: 'Run again', unknown: 'Unknown action',
};
export const actionStatusLabels: Record<ActionStatus, string> = {
  queued: 'Waiting for backend', processing: 'In progress', completed: 'Completed', failed: 'Failed', unknown: 'Unknown',
};

const text = (value: unknown) => typeof value === 'string' ? value : null;
export function parseAction(id: string, raw: RawDocument): AdminActionRecord {
  const states: ActionStatus[] = ['queued', 'processing', 'completed', 'failed'];
  return { id, type: actionTypes.includes(raw.type as ActionType) ? raw.type as ActionType : 'unknown',
    target: text(raw.target) ?? '', reason: text(raw.reason), requestedBy: text(raw.requestedBy) ?? '',
    createdAt: date(raw.createdAt), finishedAt: date(raw.finishedAt),
    status: states.includes(raw.status as ActionStatus) ? raw.status as ActionStatus : 'unknown',
    result: text(raw.result), error: text(raw.error) };
}

/** Trims the optional reason and drops it when empty, matching what Firestore Rules accept. */
export function normalizeAction(draft: ActionDraft): ActionDraft {
  const reason = draft.reason?.trim();
  return { type: draft.type, target: draft.target, ...(reason ? { reason } : {}) };
}
export function validateAction(draft: ActionDraft): string | null {
  if (!actionTypes.includes(draft.type)) return 'This action is not supported.';
  if (!/^\d{4}\.\d{4,5}$/.test(draft.target)) return 'This analysis ID is not valid.';
  if ((draft.reason ?? '').trim().length > 200) return 'Keep the reason under 200 characters.';
  return null;
}

export function isPending(action: AdminActionRecord): boolean { return action.status === 'queued' || action.status === 'processing'; }
/** The newest action for one target; the feed is newest first. */
export function latestFor(actions: AdminActionRecord[], target: string): AdminActionRecord | undefined {
  return actions.find((action) => action.target === target);
}

/** Which actions make sense for an analysis in its current state. */
export function availableActions(analysis: Analysis): ActionType[] {
  if (isRunning(analysis)) return ['cancelAnalysis'];
  if (analysis.status === 'failed' || analysis.status === 'cancelled') return ['retryAnalysis'];
  return [];
}

