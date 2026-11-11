import { useEffect, useRef, useState, type FormEvent } from 'react';
import { Bell, CheckCircle2, Search, Send, Users, X } from 'lucide-react';
import { normalizeDraft, validateDraft, type AnnouncementDraft, type AnnouncementRequest, type NotificationRecipient } from '../domain/notifications';
import type { AdminGateway } from '../services/gateway';
import { errorMessage } from '../services/gateway';
import { StatePanel, formatDate } from '../components/ui';

type LoadState<T> = { status: 'loading' } | { status: 'error'; message: string } | { status: 'ready'; data: T };
const stateLabels = { queued: 'Queued', processing: 'Processing', completed: 'Completed', partial: 'Needs review',
  failed: 'Failed', interrupted: 'Interrupted', unknown: 'Unknown' };

export function Notifications({ gateway, demo }: { gateway: AdminGateway; demo: boolean }) {
  const [recipients, setRecipients] = useState<LoadState<NotificationRecipient[]>>({ status: 'loading' });
  const [history, setHistory] = useState<LoadState<AnnouncementRequest[]>>({ status: 'loading' });
  const [retry, setRetry] = useState(0);
  const [title, setTitle] = useState('');
  const [body, setBody] = useState('');
  const [audience, setAudience] = useState<'all' | 'selected'>('selected');
  const [selected, setSelected] = useState<string[]>([]);
  const [search, setSearch] = useState('');
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
    return () => { active = false; stopUsers(); stopHistory(); };
  }, [gateway, retry]);

  useEffect(() => {
    if (confirmation) dialog.current?.showModal();
    else dialog.current?.close();
  }, [confirmation]);

  const users = recipients.status === 'ready' ? recipients.data : [];
  const visible = users.filter((user) => `${user.name} ${user.uid}`.toLowerCase().includes(search.trim().toLowerCase()));
  const selectedUsers = users.filter((user) => selected.includes(user.uid));
  const targetCount = audience === 'all' ? users.length : selectedUsers.length;

  function review(event: FormEvent) {
    event.preventDefault(); setProblem(''); setSuccess('');
    const draft = normalizeDraft({ title, body, audience, recipientUids: selected });
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
      setSuccess(demo ? 'Demo message simulated. No notifications were sent.' : 'Request queued. The backend will process it; track the outcome below.');
      setConfirmation(null); setTitle(''); setBody(''); setSelected([]); operation.current = null;
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
        <div className="compose-footer"><span>{demo ? 'Demo mode · no real messages' : 'Queued securely for the backend worker'}</span><button className="button primary" disabled={sending || recipients.status !== 'ready'} type="submit"><Send size={15} />Review message</button></div>
      </form>
    </section><aside className="notification-preview"><div className="eyebrow">MESSAGE PREVIEW</div><div className="preview-card"><span className="preview-app"><BookIcon />Realtron<span>now</span></span>
      <strong>{previewTitle}</strong><p>{previewBody}</p></div>
      <p className="preview-note">{audience === 'all' ? 'All regular users' : `${targetCount} selected user${targetCount === 1 ? '' : 's'}`} · Saved in the app inbox. Push also requires an active device token.</p>
      <div className="delivery-note"><h3>From web to device</h3><ol><li>Admin submits a request.</li><li>The backend saves each inbox item.</li><li>FCM accepts push attempts for registered devices.</li></ol><p>If the backend is offline, the request stays queued.</p></div>
    </aside></div>
    <section className="analyses-panel announcement-history"><div className="panel-heading"><div className="panel-title"><Bell size={19} /><h2>Recent announcements</h2></div><span className="panel-caption">Last 30 requests</span></div>
      {history.status === 'loading' ? <p role="status" className="history-placeholder">Loading history…</p> : history.status === 'error' ? <StatePanel title="Couldn’t load announcement history" retry={() => setRetry((value) => value + 1)}>{history.message}</StatePanel>
        : history.data.length ? history.data.map((item) => <HistoryItem request={item} key={item.id} />) : <div className="empty-state"><Bell size={26} /><h3>No announcements yet</h3><p>Your submitted messages and processing outcomes will appear here.</p></div>}
    </section>
    <dialog ref={dialog} className="send-dialog" aria-labelledby="send-dialog-title" onCancel={(event) => { if (sending) event.preventDefault(); else setConfirmation(null); }}>
      {confirmation && <><div className="dialog-heading"><h2 id="send-dialog-title">Confirm announcement</h2><button className="icon-button" aria-label="Close confirmation" disabled={sending} onClick={() => setConfirmation(null)}><X size={19} /></button></div>
        <p>{confirmation.audience === 'all' ? `Send to all users (${users.length} currently listed)?` : `Send to ${confirmation.recipientUids.length} selected user${confirmation.recipientUids.length === 1 ? '' : 's'}?`}</p>
        {confirmation.audience === 'selected' && <p className="muted">{users.filter((user) => confirmation.recipientUids.includes(user.uid)).map((user) => user.name).join(', ')}</p>}
        <div className="confirmation-message"><strong>{confirmation.title}</strong><p>{confirmation.body}</p></div>
        <p className="preview-note">{demo ? 'Demo only: no notifications will be sent to real users.' : 'The request cannot be edited after submission. Push availability depends on the recipient’s device.'}</p>
        {problem && <p role="alert" className="form-error">{problem}</p>}
        <div className="dialog-actions"><button className="button secondary" disabled={sending} onClick={() => setConfirmation(null)}>Cancel</button><button className="button primary" disabled={sending} onClick={send}>{sending ? 'Submitting…' : 'Confirm send'}</button></div></>}
    </dialog>
  </>;
}

function BookIcon() { return <Bell size={14} />; }

function HistoryItem({ request }: { request: AnnouncementRequest }) {
  const pending = request.status === 'queued' || request.status === 'processing';
  const counts = request.counts;
  return <article className="announcement-item"><div className="announcement-heading"><div><h3>{request.title}</h3><span>{request.audience === 'all' ? 'All users' : `${request.recipientUids.length} selected user${request.recipientUids.length === 1 ? '' : 's'}`} · {formatDate(request.createdAt, true)}</span></div>
    <span className={`announcement-state announcement-${request.status}`}>{stateLabels[request.status]}</span></div><p className="announcement-body">{request.body}</p>
    {pending ? <p className="announcement-waiting">{request.status === 'queued' ? 'Waiting for the backend worker.' : `${counts.inboxStored} of ${counts.recipients} inbox items stored. Processing…`}</p>
      : <dl className="delivery-counts">{[['Users', counts.recipients], ['Inbox stored', counts.inboxStored], ['FCM accepted · devices', counts.pushAccepted],
        ['Push failed', counts.pushFailed], ['Push uncertain', counts.pushUnknown], ['Without device', counts.withoutDevice], ['Skipped users', counts.skipped], ['Inbox failed', counts.inboxFailed]].map(([label, value]) => <div key={label}><dt>{label}</dt><dd>{value}</dd></div>)}</dl>}
    {request.error && <p className="announcement-error">{request.error}</p>}
    {!pending && <p className="delivery-footnote">FCM acceptance is not confirmation that a device displayed or read the notification.</p>}
  </article>;
}
