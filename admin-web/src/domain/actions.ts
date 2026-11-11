import { date, isRunning, type Analysis, type RawDocument } from './analysis';
import type { DirectoryUser } from './users';

export const analysisActionTypes = ['cancelAnalysis', 'retryAnalysis', 'hideAnalysis', 'unhideAnalysis', 'deleteAnalysis'] as const;
export const userActionTypes = ['setRole', 'setDisabled'] as const;
export const actionTypes = [...analysisActionTypes, ...userActionTypes] as const;
export type ActionType = typeof actionTypes[number];
export interface ActionDraft { type: ActionType; target: string; reason?: string; role?: 'admin' | 'user'; disabled?: boolean }
export type ActionStatus = 'queued' | 'processing' | 'completed' | 'failed' | 'unknown';
export interface AdminActionRecord {
  id: string; type: ActionType | 'unknown'; target: string; reason: string | null; requestedBy: string;
  role: 'admin' | 'user' | null; disabled: boolean | null;
  createdAt: Date | null; finishedAt: Date | null; status: ActionStatus; result: string | null; error: string | null;
}

export const actionLabels: Record<ActionType | 'unknown', string> = {
  cancelAnalysis: 'Stop analysis', retryAnalysis: 'Run again', hideAnalysis: 'Hide results', unhideAnalysis: 'Show results again',
  deleteAnalysis: 'Delete analysis', setRole: 'Change role', setDisabled: 'Change account access', unknown: 'Unknown action',
};
export const actionStatusLabels: Record<ActionStatus, string> = {
  queued: 'Waiting for backend', processing: 'In progress', completed: 'Completed', failed: 'Failed', unknown: 'Unknown',
};

/** A short name for one request, with the direction for role and access changes. */
export function describeAction(action: Pick<AdminActionRecord, 'type' | 'role' | 'disabled'>): string {
  if (action.type === 'setRole') return action.role === 'admin' ? 'Make admin' : 'Remove admin access';
  if (action.type === 'setDisabled') return action.disabled ? 'Disable account' : 'Enable account';
  return actionLabels[action.type];
}

const text = (value: unknown) => typeof value === 'string' ? value : null;
export function parseAction(id: string, raw: RawDocument): AdminActionRecord {
  const states: ActionStatus[] = ['queued', 'processing', 'completed', 'failed'];
  return { id, type: actionTypes.includes(raw.type as ActionType) ? raw.type as ActionType : 'unknown',
    target: text(raw.target) ?? '', reason: text(raw.reason), requestedBy: text(raw.requestedBy) ?? '',
    role: raw.role === 'admin' || raw.role === 'user' ? raw.role : null, disabled: typeof raw.disabled === 'boolean' ? raw.disabled : null,
    createdAt: date(raw.createdAt), finishedAt: date(raw.finishedAt),
    status: states.includes(raw.status as ActionStatus) ? raw.status as ActionStatus : 'unknown',
    result: text(raw.result), error: text(raw.error) };
}

const isAnalysisAction = (type: ActionType) => (analysisActionTypes as readonly string[]).includes(type);

/** Keeps only the fields Firestore Rules accept for the type, and drops an empty reason. */
export function normalizeAction(draft: ActionDraft): ActionDraft {
  const reason = draft.reason?.trim();
  return { type: draft.type, target: draft.target, ...(reason ? { reason } : {}),
    ...(draft.type === 'setRole' ? { role: draft.role } : {}), ...(draft.type === 'setDisabled' ? { disabled: draft.disabled } : {}) };
}
export function validateAction(draft: ActionDraft, selfUid?: string): string | null {
  if (!actionTypes.includes(draft.type)) return 'This action is not supported.';
  if ((draft.reason ?? '').trim().length > 200) return 'Keep the reason under 200 characters.';
  if (isAnalysisAction(draft.type)) return /^\d{4}\.\d{4,5}$/.test(draft.target) ? null : 'This analysis ID is not valid.';
  if (!draft.target || draft.target.length > 128 || draft.target.includes('/')) return 'This user ID is not valid.';
  if (draft.target === selfUid) return 'You cannot change your own role or account.';
  if (draft.type === 'setRole' && draft.role !== 'admin' && draft.role !== 'user') return 'Choose admin or user.';
  if (draft.type === 'setDisabled' && typeof draft.disabled !== 'boolean') return 'Choose whether to disable or enable the account.';
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
  if (analysis.status === 'done') return analysis.hidden ? ['unhideAnalysis', 'retryAnalysis', 'deleteAnalysis'] : ['hideAnalysis', 'deleteAnalysis'];
  return ['retryAnalysis', 'deleteAnalysis'];
}

/** Role and access changes for another user; the backend applies the same limits. */
export function userActions(user: DirectoryUser, selfUid: string): ActionDraft[] {
  if (user.uid === selfUid) return [];
  if (user.role === 'admin') return [{ type: 'setRole', target: user.uid, role: 'user' }];
  if (user.disabled) return [{ type: 'setDisabled', target: user.uid, disabled: false }];
  return [{ type: 'setRole', target: user.uid, role: 'admin' }, { type: 'setDisabled', target: user.uid, disabled: true }];
}
