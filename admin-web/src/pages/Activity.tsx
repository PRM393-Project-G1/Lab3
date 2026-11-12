import { useEffect, useMemo, useState } from 'react';
import { Bell, CheckCircle2, Clock3, Download, FileText, History, UserRound, XCircle } from 'lucide-react';
import { Link } from 'react-router-dom';
import type { Analysis } from '../domain/analysis';
import type { AdminActionRecord } from '../domain/actions';
import { auditLog, filterAudit, type AuditEntry, type AuditFilter } from '../domain/audit';
import { downloadCsv, toCsv } from '../domain/csv';
import type { AnnouncementRequest } from '../domain/notifications';
import type { DirectoryUser } from '../domain/users';
import type { AdminGateway } from '../services/gateway';
import { errorMessage } from '../services/gateway';
import { StatePanel, formatDate } from '../components/ui';

type Load<T> = { status: 'loading' } | { status: 'error'; message: string } | { status: 'ready'; data: T };
const filters: { value: AuditFilter; label: string }[] = [
  { value: 'all', label: 'Everything' }, { value: 'analysis', label: 'Analyses' }, { value: 'user', label: 'Users' }, { value: 'announcement', label: 'Announcements' },
];
const kindIcons = { analysis: FileText, user: UserRound, announcement: Bell };
const outcomeLabels: Record<AuditEntry['outcome'], string> = { pending: 'Pending', done: 'Done', failed: 'Failed', cancelled: 'Cancelled' };
const outcomeIcons = { pending: Clock3, done: CheckCircle2, failed: XCircle, cancelled: XCircle };

/** Who did what and when, from the admin action and announcement queues. */
export function Activity({ gateway, demo }: { gateway: AdminGateway; demo: boolean }) {
  const [actions, setActions] = useState<Load<AdminActionRecord[]>>({ status: 'loading' });
  const [announcements, setAnnouncements] = useState<Load<AnnouncementRequest[]>>({ status: 'loading' });
  const [users, setUsers] = useState<DirectoryUser[]>([]);
  const [analyses, setAnalyses] = useState<Analysis[]>([]);
  const [retry, setRetry] = useState(0);
  const [filter, setFilter] = useState<AuditFilter>('all');
  const [actor, setActor] = useState('');
  useEffect(() => {
    let active = true;
    setActions({ status: 'loading' }); setAnnouncements({ status: 'loading' });
    const stops = [
      gateway.watchActions((data) => { if (active) setActions({ status: 'ready', data }); }, (error) => { if (active) setActions({ status: 'error', message: errorMessage(error) }); }),
      gateway.watchAnnouncements((data) => { if (active) setAnnouncements({ status: 'ready', data }); }, (error) => { if (active) setAnnouncements({ status: 'error', message: errorMessage(error) }); }),
      // Names and titles only make entries easier to read.
      gateway.watchUsers((data) => { if (active) setUsers(data); }, () => {}),
      gateway.watchAnalyses((feed) => { if (active) setAnalyses(feed.analyses); }, () => {}),
    ];
    return () => { active = false; stops.forEach((stop) => stop()); };
  }, [gateway, retry]);

  const entries = useMemo(() => actions.status === 'ready' && announcements.status === 'ready' ? auditLog(actions.data, announcements.data) : [], [actions, announcements]);
  const visible = useMemo(() => filterAudit(entries, filter, actor), [entries, filter, actor]);
  const nameOf = (uid: string) => users.find((user) => user.uid === uid)?.name ?? (uid ? `User ${uid.slice(0, 6)}…` : 'Unknown');
  const actors = [...new Set(entries.map((entry) => entry.actor))].sort((a, b) => nameOf(a).localeCompare(nameOf(b)));
  const base = demo ? '/demo' : '';
  const targetLabel = (entry: AuditEntry) => entry.kind === 'analysis' ? analyses.find((a) => a.id === entry.target)?.title ?? `arXiv:${entry.target}`
    : entry.kind === 'user' ? nameOf(entry.target) : entry.target;
  const targetLink = (entry: AuditEntry) => entry.kind === 'analysis' ? `${base}/analyses/${encodeURIComponent(entry.target)}`
    : entry.kind === 'user' ? `${base}/users/${encodeURIComponent(entry.target)}` : null;
  const exportLog = () => downloadCsv(`realtron-admin-activity-${new Date().toISOString().slice(0, 10)}.csv`, toCsv([
    ['Time (UTC)', 'Admin', 'Admin UID', 'Area', 'Action', 'Target', 'Target ID', 'Reason', 'Outcome', 'Details'],
    ...visible.map((entry) => [entry.at?.toISOString() ?? '', nameOf(entry.actor), entry.actor, entry.kind, entry.action, targetLabel(entry),
      entry.kind === 'announcement' ? entry.id : entry.target, entry.reason, outcomeLabels[entry.outcome], entry.detail]),
  ]));
  const failure = actions.status === 'error' ? actions.message : announcements.status === 'error' ? announcements.message : null;

  return <>
    <div className="page-heading"><div><div className="eyebrow">AUDIT</div><h1>Activity log<span className="heading-dot">.</span></h1>
      <p>Every change made from this workspace, who made it and how it ended.</p></div>
      <button className="button secondary" disabled={!visible.length} onClick={exportLog}><Download size={16} />Export CSV</button></div>
    {failure ? <StatePanel title="Couldn’t load the activity log" retry={() => setRetry((value) => value + 1)}>{failure}</StatePanel>
      : actions.status === 'loading' || announcements.status === 'loading' ? <StatePanel title="Loading activity" loading /> :
        <section className="analyses-panel" aria-label="Admin activity">
          <div className="table-toolbar"><div className="filter-list" aria-label="Activity area">{filters.map((item) => <button key={item.value}
            className={`filter-button ${filter === item.value ? 'selected' : ''}`} aria-pressed={filter === item.value} onClick={() => setFilter(item.value)}>
            {item.label} <span>{item.value === 'all' ? entries.length : entries.filter((entry) => entry.kind === item.value).length}</span></button>)}</div>
            <label className="select-label">Admin<select aria-label="Admin" value={actor} onChange={(event) => setActor(event.target.value)}>
              <option value="">All admins</option>{actors.map((uid) => <option key={uid} value={uid}>{nameOf(uid)}</option>)}</select></label></div>
          {visible.length ? <ol className="audit-list">{visible.map((entry) => {
            const Icon = kindIcons[entry.kind];
            const Outcome = outcomeIcons[entry.outcome];
            const link = targetLink(entry);
            return <li key={`${entry.kind}-${entry.id}`} className="audit-entry">
              <span className="audit-icon"><Icon size={16} /></span>
              <div className="audit-body">
                <p><strong>{nameOf(entry.actor)}</strong> · {entry.action} · {link ? <Link to={link}>{targetLabel(entry)}</Link> : <em>{targetLabel(entry)}</em>}</p>
                {entry.reason && <p className="audit-reason">Reason: {entry.reason}</p>}
                {entry.detail && <p className="audit-detail">{entry.detail}</p>}
              </div>
              <div className="audit-meta"><span className={`audit-outcome ${entry.outcome}`}><Outcome size={12} aria-hidden="true" />{outcomeLabels[entry.outcome]}</span>
                <time dateTime={entry.at?.toISOString()}>{formatDate(entry.at, true)}</time></div>
            </li>;
          })}</ol> : <div className="empty-state"><History size={28} /><h3>{entries.length ? 'Nothing matches these filters' : 'No admin activity yet'}</h3>
            <p>{entries.length ? 'Try another area or admin.' : 'Actions and announcements from this workspace will be listed here.'}</p></div>}
          <div className="table-footer"><span>{visible.length} of {entries.length} entries · the latest 100 actions and 30 announcements</span></div>
        </section>}
  </>;
}
