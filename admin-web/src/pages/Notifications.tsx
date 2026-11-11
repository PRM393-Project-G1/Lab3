import { useEffect, useRef, useState, type FormEvent } from 'react';
import { Bell, CalendarClock, CheckCircle2, Eye, Link2, Search, Send, Users, X } from 'lucide-react';
import type { Analysis } from '../domain/analysis';
import { isScheduled, normalizeDraft, readRate, scheduleLimits, validateDraft, type AnnouncementDraft, type AnnouncementRequest, type NotificationRecipient } from '../domain/notifications';
import type { AdminGateway } from '../services/gateway';
import { errorMessage } from '../services/gateway';
import { StatePanel, formatDate } from '../components/ui';
import { WorkerNotice } from '../components/SystemIndicator';
import type { SystemStatus } from '../hooks/useWorkers';

type LoadState<T> = { status: 'loading' } | { status: 'error'; message: string } | { status: 'ready'; data: T };
const stateLabels = { queued: 'Queued', processing: 'Processing', completed: 'Completed', partial: 'Needs review',
  failed: 'Failed', interrupted: 'Interrupted', cancelled: 'Cancelled', unknown: 'Unknown' };
/** The value a datetime-local input expects, in the viewer's time zone. */
function localInput(value: Date): string {
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${value.getFullYear()}-${pad(value.getMonth() + 1)}-${pad(value.getDate())}T${pad(value.getHours())}:${pad(value.getMinutes())}`;
}

export function Notifications({ gateway, demo, system }: { gateway: AdminGateway; demo: boolean; system: SystemStatus }) {
  const [recipients, setRecipients] = useState<LoadState<NotificationRecipient[]>>({ status: 'loading' });
  const [history, setHistory] = useState<LoadState<AnnouncementRequest[]>>({ status: 'loading' });
  const [retry, setRetry] = useState(0);
  const [title, setTitle] = useState('');
  const [body, setBody] = useState('');
  const [audience, setAudience] = useState<'all' | 'selected'>('selected');
  const [selected, setSelected] = useState<string[]>([]);
  const [search, setSearch] = useState('');
  const [paper, setPaper] = useState('');
  const [timing, setTiming] = useState<'now' | 'later'>('now');
  const [when, setWhen] = useState('');
  const [papers, setPapers] = useState<Analysis[]>([]);
  const [problem, setProblem] = useState('');
  const [success, setSuccess] = useState('');
  const [confirmation, setConfirmation] = useState<AnnouncementDraft | null>(null);
  const [sending, setSending] = useState(false);
  const inFlight = useRef(false);
  const operation = useRef<{ fingerprint: string; id: string } | null>(null);
  const dialog = useRef<HTMLDialogElement>(null);

  useEffect(() => {
    let active = true;
    setRecipients({ status: 'loading' }); setHistory({ status: 'loading' });
    const stopUsers = gateway.watchRecipients((data) => { if (active) setRecipients({ status: 'ready', data }); },
      (error) => { if (active) setRecipients({ status: 'error', message: errorMessage(error) }); });
    const stopHistory = gateway.watchAnnouncements((data) => { if (active) setHistory({ status: 'ready', data }); },
      (error) => { if (active) setHistory({ status: 'error', message: errorMessage(error) }); });
    // Papers to link are optional, so a failed feed only leaves the picker empty.
    const stopPapers = gateway.watchAnalyses((feed) => { if (active) setPapers(feed.analyses); }, () => {});
    return () => { active = false; stopUsers(); stopHistory(); stopPapers(); };
  }, [gateway, retry]);

  useEffect(() => {
    if (confirmation) dialog.current?.showModal();
    else dialog.current?.close();
  }, [confirmation]);

  const users = recipients.status === 'ready' ? recipients.data : [];
  const visible = users.filter((user) => `${user.name} ${user.uid}`.toLowerCase().includes(search.trim().toLowerCase()));
  const selectedUsers = users.filter((user) => selected.includes(user.uid));
  const targetCount = audience === 'all' ? users.length : selectedUsers.length;
  const linkable = papers.filter((item) => item.status === 'done' && !item.hidden)
    .sort((a, b) => (b.createdAt?.getTime() ?? 0) - (a.createdAt?.getTime() ?? 0));
  const titleOf = (id: string | undefined) => papers.find((item) => item.id === id)?.title ?? (id ? `arXiv:${id}` : '');

  function review(event: FormEvent) {
    event.preventDefault(); setProblem(''); setSuccess('');
    if (timing === 'later' && !when) { setProblem('Choose a delivery time.'); return; }
    const draft = normalizeDraft({ title, body, audience, recipientUids: selected, analysisId: paper,
      ...(timing === 'later' ? { sendAt: new Date(when) } : {}) });
    const validation = validateDraft(draft);
    if (validation) { setProblem(validation); return; }
    if (!users.length) { setProblem('No users have been synced yet. Start the backend notification worker first.'); return; }
    if (audience === 'selected' && selectedUsers.length !== draft.recipientUids.length) {
      setProblem('Some selected users are no longer available. Update your selection.'); return;
    }
    setConfirmation(draft);
  }

  async function send() {
    if (!confirmation || inFlight.current) return;
    inFlight.current = true; setSending(true); setProblem('');
    const fingerprint = JSON.stringify(confirmation);
    if (operation.current?.fingerprint !== fingerprint) operation.current = { fingerprint, id: crypto.randomUUID() };
    try {
      await gateway.queueAnnouncement(operation.current.id, confirmation);
      setSuccess(confirmation.sendAt ? `Message scheduled for ${formatDate(confirmation.sendAt, true)}. You can cancel it below until then.`
        : demo ? 'Demo message simulated. No notifications were sent.' : 'Request queued. The backend will process it; track the outcome below.');
      setConfirmation(null); setTitle(''); setBody(''); setSelected([]); setPaper(''); setTiming('now'); setWhen(''); operation.current = null;
    } catch (error) {
      // Keep this operation ID so retry after a lost acknowledgement cannot create a duplicate.
      setProblem(errorMessage(error));
    } finally { inFlight.current = false; setSending(false); }
  }

  const previewTitle = title.trim() || 'Your notification title';
  const previewBody = body.trim() || 'Write a short update for your users. It will appear in their in-app inbox and, where available, as a push notification.';
  return <>
    <div className="page-heading"><div><div className="eyebrow">KEEP USERS INFORMED</div><h1>Notifications<span className="heading-dot">.</span></h1>
      <p>Send a short update to everyone, or just the people you choose.</p></div><span className="workspace-badge"><Bell size={14} />Admin announcements</span></div>
    <WorkerNotice system={system} name="notifications">{(when) => `${when}. New messages stay queued and the recipient list stops updating until it runs again.`}</WorkerNotice>
    {success && <div className="send-success" role="status"><CheckCircle2 size={17} />{success}</div>}
    {problem && !confirmation && <p role="alert" className="form-error">{problem}</p>}
    <div className="notification-grid"><section className="detail-panel compose-panel"><h2>Compose a message</h2>
      <form onSubmit={review}>
        <fieldset className="audience-options"><legend>Recipients</legend>
          <label className={audience === 'selected' ? 'selected' : ''}><input type="radio" name="audience" value="selected" checked={audience === 'selected'} onChange={() => setAudience('selected')} /><span><strong>Selected users</strong><small>Choose who receives this message</small></span></label>
          <label className={audience === 'all' ? 'selected' : ''}><input type="radio" name="audience" value="all" checked={audience === 'all'} onChange={() => setAudience('all')} /><span><strong>All users</strong><small>Every regular user at processing time</small></span></label>
        </fieldset>
        {recipients.status === 'loading' ? <p role="status" className="muted">Loading recipients…</p> : recipients.status === 'error' ? <div className="recipient-error"><p role="alert">{recipients.message}</p><button type="button" className="button secondary" onClick={() => setRetry((value) => value + 1)}>Retry recipients</button></div>
          : !users.length ? <div className="notice">No users synced yet. Run the backend notification worker to populate the recipient list.</div>
            : audience === 'selected' ? <div className="recipient-picker"><div className="recipient-picker-heading"><span>{selectedUsers.length} selected / {users.length} users</span>
              <button type="button" className="plain-button" disabled={!selected.length} onClick={() => setSelected([])}>Clear selection</button></div>
              <div className="search-field"><Search size={16} /><input aria-label="Search notification recipients" placeholder="Search name or UID…" value={search} onChange={(event) => setSearch(event.target.value)} /></div>
              <div className="recipient-list">{visible.map((user) => <label className="recipient-row" key={user.uid}><input type="checkbox" checked={selected.includes(user.uid)}
                disabled={!selected.includes(user.uid) && selected.length >= 100}
                onChange={(event) => setSelected((previous) => event.target.checked ? [...previous, user.uid] : previous.filter((uid) => uid !== user.uid))} />
                <span><strong>{user.name}</strong><code>{user.uid}</code></span><small>{user.hasDevice ? 'Push available' : 'Inbox only'}</small></label>)}
                {!visible.length && <p className="muted">No matching users.</p>}</div></div>
              : <div className="audience-summary"><Users size={17} /><span>{users.length} users currently listed. New users may also be included when the backend processes this request.</span></div>}
        <label className="form-label" htmlFor="notification-title">Title<span>{title.length}/80</span></label>
        <input className="form-input" id="notification-title" value={title} maxLength={80} placeholder="A quick update from Realtron" onChange={(event) => setTitle(event.target.value)} />
        <label className="form-label" htmlFor="notification-body">Message<span>{body.length}/500</span></label>
        <textarea className="form-input message-input" id="notification-body" value={body} maxLength={500} rows={5} placeholder="What would you like users to know?" onChange={(event) => setBody(event.target.value)} />
        <label className="form-label" htmlFor="notification-paper">Link to a paper<span>Optional · tapping opens its overview</span></label>
        <select className="form-input" id="notification-paper" value={paper} onChange={(event) => setPaper(event.target.value)}>
          <option value="">No link</option>{linkable.map((item) => <option key={item.id} value={item.id}>{item.title} · arXiv:{item.id}</option>)}</select>
        <fieldset className="audience-options timing-options"><legend>Delivery</legend>
          <label className={timing === 'now' ? 'selected' : ''}><input type="radio" name="timing" value="now" checked={timing === 'now'} onChange={() => setTiming('now')} /><span><strong>Send now</strong><small>As soon as the worker picks it up</small></span></label>
          <label className={timing === 'later' ? 'selected' : ''}><input type="radio" name="timing" value="later" checked={timing === 'later'} onChange={() => {
            setTiming('later'); if (!when) setWhen(localInput(new Date(Date.now() + 3600000)));
          }} /><span><strong>Schedule</strong><small>Up to {scheduleLimits.maxDays} days ahead</small></span></label>
        </fieldset>
        {timing === 'later' && <><label className="form-label" htmlFor="notification-when">Deliver at<span>Your local time</span></label>
          {/* Bounds are checked on review, with one message, rather than by the browser. */}
          <input className="form-input" id="notification-when" type="datetime-local" value={when} onChange={(event) => setWhen(event.target.value)} /></>}
        <div className="compose-footer"><span>{demo ? 'Demo mode · no real messages' : 'Queued securely for the backend worker'}</span><button className="button primary" disabled={sending || recipients.status !== 'ready'} type="submit"><Send size={15} />Review message</button></div>
      </form>
    </section><aside className="notification-preview"><div className="eyebrow">MESSAGE PREVIEW</div><div className="preview-card"><span className="preview-app"><BookIcon />Realtron<span>now</span></span>
      <strong>{previewTitle}</strong><p>{previewBody}</p>{paper && <span className="preview-link"><Link2 size={12} />Opens {titleOf(paper)}</span>}</div>
      <p className="preview-note">{audience === 'all' ? 'All regular users' : `${targetCount} selected user${targetCount === 1 ? '' : 's'}`} · Saved in the app inbox. Push also requires an active device token.</p>
      <div className="delivery-note"><h3>From web to device</h3><ol><li>Admin submits a request.</li><li>The backend saves each inbox item.</li><li>FCM accepts push attempts for registered devices.</li></ol><p>If the backend is offline, the request stays queued.</p></div>
    </aside></div>
    <section className="analyses-panel announcement-history"><div className="panel-heading"><div className="panel-title"><Bell size={19} /><h2>Recent announcements</h2></div><span className="panel-caption">Last 30 requests</span></div>
      {history.status === 'loading' ? <p role="status" className="history-placeholder">Loading history…</p> : history.status === 'error' ? <StatePanel title="Couldn’t load announcement history" retry={() => setRetry((value) => value + 1)}>{history.message}</StatePanel>
        : history.data.length ? history.data.map((item) => <HistoryItem request={item} key={item.id} paperTitle={titleOf(item.analysisId)} gateway={gateway} />) : <div className="empty-state"><Bell size={26} /><h3>No announcements yet</h3><p>Your submitted messages and processing outcomes will appear here.</p></div>}
    </section>
    <dialog ref={dialog} className="send-dialog" aria-labelledby="send-dialog-title" onCancel={(event) => { if (sending) event.preventDefault(); else setConfirmation(null); }}>
      {confirmation && <><div className="dialog-heading"><h2 id="send-dialog-title">Confirm announcement</h2><button className="icon-button" aria-label="Close confirmation" disabled={sending} onClick={() => setConfirmation(null)}><X size={19} /></button></div>
        <p>{confirmation.audience === 'all' ? `Send to all users (${users.length} currently listed)?` : `Send to ${confirmation.recipientUids.length} selected user${confirmation.recipientUids.length === 1 ? '' : 's'}?`}</p>
        {confirmation.sendAt && <p className="schedule-note"><CalendarClock size={15} />Delivered at {formatDate(confirmation.sendAt, true)}. Until then you can cancel it.</p>}
        {confirmation.audience === 'selected' && <p className="muted">{users.filter((user) => confirmation.recipientUids.includes(user.uid)).map((user) => user.name).join(', ')}</p>}
        <div className="confirmation-message"><strong>{confirmation.title}</strong><p>{confirmation.body}</p>{confirmation.analysisId && <p className="muted">Tapping it opens {titleOf(confirmation.analysisId)}.</p>}</div>
        <p className="preview-note">{demo ? 'Demo only: no notifications will be sent to real users.' : 'The request cannot be edited after submission. Push availability depends on the recipient’s device.'}</p>
        {problem && <p role="alert" className="form-error">{problem}</p>}
        <div className="dialog-actions"><button className="button secondary" disabled={sending} onClick={() => setConfirmation(null)}>Cancel</button><button className="button primary" disabled={sending} onClick={send}>{sending ? 'Submitting…' : confirmation.sendAt ? 'Schedule message' : 'Confirm send'}</button></div></>}
    </dialog>
  </>;
}

function BookIcon() { return <Bell size={14} />; }

/** Opened in the app inbox, as a thin meter with the numbers beside it. */
function ReadMeter({ request }: { request: AnnouncementRequest }) {
  const rate = readRate(request);
  if (rate === null) return <p className="read-meter pending">Opened in the app: counted every 15 minutes during the first week.</p>;
  return <div className="read-meter" role="group" aria-label={`Opened in the app by ${request.readCount} of ${request.counts.inboxStored} recipients`}>
    <span className="read-label"><Eye size={13} />Opened in the app</span>
    <span className="read-track" aria-hidden="true"><span style={{ width: `${rate * 100}%` }} /></span>
    <strong>{request.readCount} of {request.counts.inboxStored} · {Math.round(rate * 100)}%</strong>
  </div>;
}

function HistoryItem({ request, paperTitle, gateway }: { request: AnnouncementRequest; paperTitle: string; gateway: AdminGateway }) {
  const [confirming, setConfirming] = useState(false);
  const [busy, setBusy] = useState(false);
  const [failure, setFailure] = useState('');
  const pending = request.status === 'queued' || request.status === 'processing';
  const scheduled = isScheduled(request);
  const counts = request.counts;
  async function cancel() {
    setBusy(true); setFailure('');
    try { await gateway.cancelAnnouncement(request.id); setConfirming(false); }
    catch (error) { setFailure(errorMessage(error)); }
    finally { setBusy(false); }
  }
  return <article className="announcement-item"><div className="announcement-heading"><div><h3>{request.title}</h3><span>{request.audience === 'all' ? 'All users' : `${request.recipientUids.length} selected user${request.recipientUids.length === 1 ? '' : 's'}`} · {formatDate(request.createdAt, true)}</span></div>
    <span className={`announcement-state announcement-${scheduled ? 'scheduled' : request.status}`}>{scheduled ? 'Scheduled' : stateLabels[request.status]}</span></div><p className="announcement-body">{request.body}</p>
    {request.analysisId && <p className="announcement-link"><Link2 size={13} />Opens {paperTitle}</p>}
    {request.status === 'cancelled' ? <p className="announcement-waiting">Cancelled before sending. No one received it.</p>
      : pending ? <p className="announcement-waiting">{scheduled ? <><CalendarClock size={13} />Scheduled for {formatDate(request.sendAt ?? null, true)}. You can cancel it until then.</>
        : request.status === 'queued' ? 'Waiting for the backend worker.' : `${counts.inboxStored} of ${counts.recipients} inbox items stored. Processing…`}</p>
      : <dl className="delivery-counts">{[['Users', counts.recipients], ['Inbox stored', counts.inboxStored], ['FCM accepted · devices', counts.pushAccepted],
        ['Push failed', counts.pushFailed], ['Push uncertain', counts.pushUnknown], ['Without device', counts.withoutDevice], ['Skipped users', counts.skipped], ['Inbox failed', counts.inboxFailed]].map(([label, value]) => <div key={label}><dt>{label}</dt><dd>{value}</dd></div>)}</dl>}
    {request.status === 'queued' && (confirming ? <div className="cancel-confirm"><span>Cancel this message? Nobody will receive it.</span>
      <button className="button secondary" disabled={busy} onClick={() => setConfirming(false)}>Keep it</button>
      <button className="button danger" disabled={busy} onClick={cancel}>{busy ? 'Cancelling…' : 'Cancel message'}</button></div>
      : <button className="plain-button cancel-link" onClick={() => setConfirming(true)}>Cancel this message</button>)}
    {failure && <p role="alert" className="form-error">{failure}</p>}
    {request.error && <p className="announcement-error">{request.error}</p>}
    {(request.status === 'completed' || request.status === 'partial') && <ReadMeter request={request} />}
    {!pending && request.status !== 'cancelled' && <p className="delivery-footnote">FCM acceptance is not confirmation that a device displayed or read the notification.</p>}
  </article>;
}
