import { useEffect, useRef, useState, type FormEvent } from 'react';
import { CircleStop, RotateCcw, ShieldAlert } from 'lucide-react';
import { formatMinutes, stalledFor, type Analysis } from '../domain/analysis';
import { actionLabels, actionStatusLabels, availableActions, isPending, latestFor, type ActionType, type AdminActionRecord } from '../domain/actions';
import type { AdminGateway } from '../services/gateway';
import { errorMessage } from '../services/gateway';
import { formatDate } from './ui';

const prompts: Record<ActionType, { question: string; confirm: string; icon: typeof CircleStop }> = {
  cancelAnalysis: { question: 'Stop this analysis now? The requester’s app will show it as stopped by an administrator.', confirm: 'Stop analysis', icon: CircleStop },
  retryAnalysis: { question: 'Run this analysis again with its original requester and settings? They get the usual notification when it finishes.', confirm: 'Run again', icon: RotateCcw },
};

/** Queues admin actions for one analysis and follows their outcome. `onSettled` reloads the page data. */
export function AnalysisActions({ gateway, analysis, onSettled }: { gateway: AdminGateway; analysis: Analysis; onSettled: () => void }) {
  const [actions, setActions] = useState<AdminActionRecord[] | null>(null);
  const [loadError, setLoadError] = useState('');
  const [confirming, setConfirming] = useState<ActionType | null>(null);
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

  const latest = actions ? latestFor(actions, analysis.id) : undefined;
  const pending = latest ? isPending(latest) : false;
  useEffect(() => {
    if (!latest) return;
    if (isPending(latest)) waiting.current.add(latest.id);
    else if (waiting.current.delete(latest.id)) onSettled();
  }, [latest, onSettled]);

  async function submit(event: FormEvent) {
    event.preventDefault();
    if (!confirming || sending) return;
    const draft = { type: confirming, target: analysis.id, reason };
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

  const stalled = stalledFor(analysis, new Date());
  const available = availableActions(analysis);
  if (!available.length && !latest) return null;
  return <section className="detail-panel admin-actions" aria-labelledby="admin-actions-title">
    <h2 id="admin-actions-title">Admin actions</h2>
    {stalled !== null && <p className="stall-warning"><ShieldAlert size={16} />No progress for {formatMinutes(stalled)}. The backend may have stopped or the job may be stuck; you can stop it and run it again.</p>}
    {confirming ? <form className="action-confirm" onSubmit={submit}>
      <p>{prompts[confirming].question}</p>
      <label className="form-label" htmlFor="action-reason">Reason for the log<span>Optional · {reason.length}/200</span></label>
      <input id="action-reason" className="form-input" maxLength={200} value={reason} onChange={(event) => setReason(event.target.value)} placeholder="e.g. No progress for an hour" />
      {problem && <p role="alert" className="form-error">{problem}</p>}
      <div className="dialog-actions"><button type="button" className="button secondary" disabled={sending} onClick={() => { setConfirming(null); setProblem(''); }}>Keep as is</button>
        <button type="submit" className="button primary" disabled={sending}>{sending ? 'Queuing…' : prompts[confirming].confirm}</button></div>
    </form> : available.length > 0 && <div className="action-buttons">{available.map((type) => {
      const Icon = prompts[type].icon;
      return <button key={type} className="button secondary" disabled={pending || actions === null} onClick={() => setConfirming(type)}><Icon size={15} />{actionLabels[type]}</button>;
    })}</div>}
    {loadError && <p role="alert" className="form-error">{loadError}</p>}
    {latest && <p className={`action-status action-${latest.status}`} role="status">
      <strong>{actionLabels[latest.type]}</strong> · {actionStatusLabels[latest.status]} · {formatDate(latest.createdAt, true)}
      {pending ? '. The backend picks up requests within a few seconds while it is online.' : latest.error ? `. ${latest.error}` : latest.result ? `. ${latest.result}` : ''}
    </p>}
  </section>;
}
