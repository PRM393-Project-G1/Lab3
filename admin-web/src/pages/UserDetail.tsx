import { useCallback, useEffect, useMemo, useState } from 'react';
import { ArrowLeft, Ban, CalendarDays, Clock3, ShieldCheck, ShieldOff, Smartphone, UserCheck } from 'lucide-react';
import { Link, useLocation, useParams } from 'react-router-dom';
import type { Analysis } from '../domain/analysis';
import { userActions } from '../domain/actions';
import { activityByUser, type DirectoryUser } from '../domain/users';
import { timeAgo } from '../domain/workers';
import type { AdminGateway } from '../services/gateway';
import { errorMessage } from '../services/gateway';
import { StatePanel, StatusBadge, formatDate } from '../components/ui';
import { ActionPanel, type ActionOption } from '../components/ActionPanel';
import { RoleBadge } from './Users';

type Load = { status: 'loading' } | { status: 'error'; message: string } | { status: 'ready'; users: DirectoryUser[] };

function options(user: DirectoryUser, selfUid: string): ActionOption[] {
  return userActions(user, selfUid).map((draft) => draft.type === 'setRole'
    ? draft.role === 'admin'
      ? { draft, icon: ShieldCheck, confirm: 'Make admin', question: `Give ${user.name} admin access? They can then open this workspace, see every user and analysis, and take every action here.` }
      : { draft, icon: ShieldOff, confirm: 'Remove admin access', question: `Remove ${user.name}'s admin access? Their open workspace closes at once; their app keeps working as a regular user.` }
    : draft.disabled
      ? { draft, icon: Ban, danger: true, confirm: 'Disable account', question: `Disable ${user.name}'s account? They are signed out within an hour, cannot sign in again, and the backend refuses their requests. Their data stays.` }
      : { draft, icon: UserCheck, confirm: 'Enable account', question: `Enable ${user.name}'s account? They can sign in again.` });
}

/** One user: profile, their analyses, and role or access changes. */
export function UserDetail({ gateway, selfUid }: { gateway: AdminGateway; selfUid: string }) {
  const { uid = '' } = useParams();
  const location = useLocation();
  const [state, setState] = useState<Load>({ status: 'loading' });
  const [analyses, setAnalyses] = useState<Analysis[]>([]);
  const [retry, setRetry] = useState(0);
  useEffect(() => {
    let active = true;
    setState({ status: 'loading' });
    const stopUsers = gateway.watchUsers((users) => { if (active) setState({ status: 'ready', users }); },
      (error) => { if (active) setState({ status: 'error', message: errorMessage(error) }); });
    const stopAnalyses = gateway.watchAnalyses((feed) => { if (active) setAnalyses(feed.analyses); }, () => {});
    return () => { active = false; stopUsers(); stopAnalyses(); };
  }, [gateway, retry]);
  // The directory is live, so a settled action shows up on its own.
  const settled = useCallback(() => {}, []);
  const base = location.pathname.startsWith('/demo/') ? '/demo' : '';
  const theirs = useMemo(() => analyses.filter((a) => a.requestedBy === uid)
    .sort((a, b) => (b.createdAt?.getTime() ?? 0) - (a.createdAt?.getTime() ?? 0)), [analyses, uid]);
  const backLink = <Link to={`${base}/users`} className="back-link"><ArrowLeft size={16} />Back to users</Link>;
  if (state.status === 'loading') return <>{backLink}<StatePanel title="Loading user" loading /></>;
  if (state.status === 'error') return <>{backLink}<StatePanel title="Couldn’t load user" retry={() => setRetry((value) => value + 1)}>{state.message}</StatePanel></>;
  const user = state.users.find((item) => item.uid === uid);
  if (!user) return <>{backLink}<StatePanel title="User not found">This profile is not in the directory. It may have been deleted.</StatePanel></>;
  const activity = activityByUser(theirs).get(uid);
  const now = new Date();
  return <>
    {backLink}
    <div className="detail-heading"><div className="eyebrow">USER</div><div className="detail-status"><code>{user.uid}</code><RoleBadge user={user} /></div>
      <h1>{user.name}</h1><p>{user.email ?? 'No email on record'}</p>
      <div className="detail-meta"><span><CalendarDays size={15} />Joined {formatDate(user.createdAt, true)}</span>
        <span><Clock3 size={15} />Last sign-in {timeAgo(user.lastSignInAt, now)}</span>
        <span><Smartphone size={15} />{user.hasDevice ? 'Push device registered' : 'No push device'}</span></div>
    </div>
    <ActionPanel gateway={gateway} target={user.uid} options={options(user, selfUid)} onSettled={settled}
      footnote={user.uid === selfUid ? <p className="muted">This is your account. Another admin has to change your role or access.</p> : undefined} />
    <section className="detail-panel" aria-labelledby="user-analyses-title"><div className="insight-heading"><h2 id="user-analyses-title">Their analyses</h2>
      <span className="panel-caption">{activity ? `${activity.total} requested · ${activity.done} completed · ${activity.failed} failed` : 'None yet'}</span></div>
      {theirs.length ? <ul className="user-analyses">{theirs.map((analysis) => <li key={analysis.id}>
        <Link to={`${base}/analyses/${encodeURIComponent(analysis.id)}`} className="paper-title">{analysis.title}</Link>
        <span className="user-analysis-meta"><StatusBadge status={analysis.status} /><code>arXiv:{analysis.id}</code><span>{formatDate(analysis.createdAt)}</span></span>
      </li>)}</ul> : <p className="muted">Analyses this user requests will appear here. Only the latest requester of a paper is recorded.</p>}
    </section>
  </>;
}
