import { useEffect, useRef, useState, type FormEvent, type ReactNode } from 'react';
import type { LucideIcon } from 'lucide-react';
import { actionStatusLabels, describeAction, isPending, latestFor, type ActionDraft, type AdminActionRecord } from '../domain/actions';
import type { AdminGateway } from '../services/gateway';
import { errorMessage } from '../services/gateway';
import { formatDate } from './ui';

export interface ActionOption { draft: ActionDraft; question: string; confirm: string; icon: LucideIcon; danger?: boolean }

/**
 * Queues admin actions for one target and follows their outcome. Each request is
 * confirmed first, can carry a reason for the log, and `onSettled` reloads the
 * page data when a request made here finishes.
 */
export function ActionPanel({ gateway, target, options, notice, onSettled, footnote }: {
  gateway: AdminGateway; target: string; options: ActionOption[]; notice?: ReactNode; onSettled: () => void; footnote?: ReactNode;
}) {
  const [actions, setActions] = useState<AdminActionRecord[] | null>(null);
  const [loadError, setLoadError] = useState('');
  const [confirming, setConfirming] = useState<ActionOption | null>(null);
  const [reason, setReason] = useState('');
  const [problem, setProblem] = useState('');
  const [sending, setSending] = useState(false);
  const operation = useRef<{ key: string; id: string } | null>(null);
  const waiting = useRef(new Set<string>());
  useEffect(() => {
    let active = true;
    const stop = gateway.watchActions((list) => { if (active) { setActions(list); setLoadError(''); } },
      (error) => { if (active) setLoadError(errorMessage(error)); });
    return () => { active = false; stop(); };
  }, [gateway]);

  const latest = actions ? latestFor(actions, target) : undefined;
  const pending = latest ? isPending(latest) : false;
  useEffect(() => {
    if (!latest) return;
    if (isPending(latest)) waiting.current.add(latest.id);
    else if (waiting.current.delete(latest.id)) onSettled();
  }, [latest, onSettled]);

  async function submit(event: FormEvent) {
    event.preventDefault();
    if (!confirming || sending) return;
    const draft = { ...confirming.draft, reason };
    const key = JSON.stringify(draft);
    // A retry after a lost acknowledgement reuses the ID, so the action is queued once.
    if (operation.current?.key !== key) operation.current = { key, id: crypto.randomUUID() };
    setSending(true); setProblem('');
    try {
      await gateway.requestAction(operation.current.id, draft);
      waiting.current.add(operation.current.id);
      operation.current = null; setConfirming(null); setReason('');
    } catch (error) { setProblem(errorMessage(error)); }
    finally { setSending(false); }
  }

  if (!options.length && !latest && !notice && !footnote) return null;
  return <section className="detail-panel admin-actions" aria-labelledby={`actions-${target}`}>
    <h2 id={`actions-${target}`}>Admin actions</h2>
    {notice}
    {confirming ? <form className="action-confirm" onSubmit={submit}>
      <p>{confirming.question}</p>
      <label className="form-label" htmlFor="action-reason">Reason for the log<span>Optional · {reason.length}/200</span></label>
      <input id="action-reason" className="form-input" maxLength={200} value={reason} onChange={(event) => setReason(event.target.value)} placeholder="Why are you doing this?" />
      {problem && <p role="alert" className="form-error">{problem}</p>}
      <div className="dialog-actions"><button type="button" className="button secondary" disabled={sending} onClick={() => { setConfirming(null); setProblem(''); }}>Keep as is</button>
        <button type="submit" className={`button ${confirming.danger ? 'danger' : 'primary'}`} disabled={sending}>{sending ? 'Queuing…' : confirming.confirm}</button></div>
    </form> : options.length > 0 && <div className="action-buttons">{options.map((option) => {
      const Icon = option.icon;
      return <button key={describeAction({ type: option.draft.type, role: option.draft.role ?? null, disabled: option.draft.disabled ?? null })}
        className={`button secondary ${option.danger ? 'danger-outline' : ''}`} disabled={pending || actions === null} onClick={() => setConfirming(option)}>
        <Icon size={15} />{describeAction({ type: option.draft.type, role: option.draft.role ?? null, disabled: option.draft.disabled ?? null })}</button>;
    })}</div>}
    {footnote}
    {loadError && <p role="alert" className="form-error">{loadError}</p>}
    {latest && <p className={`action-status action-${latest.status}`} role="status">
      <strong>{describeAction(latest)}</strong> · {actionStatusLabels[latest.status]} · {formatDate(latest.createdAt, true)}
      {pending ? '. The backend picks up requests within a few seconds while it is online.' : latest.error ? `. ${latest.error}` : latest.result ? `. ${latest.result}` : ''}
    </p>}
  </section>;
}
