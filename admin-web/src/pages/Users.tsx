import { useEffect, useMemo, useState } from 'react';
import { ArrowRight, Ban, Search, ShieldCheck, Smartphone, UserRound, Users as UsersIcon, X } from 'lucide-react';
import { Link } from 'react-router-dom';
import type { Analysis } from '../domain/analysis';
import { activityByUser, filterUsers, type DirectoryUser, type UserFilter } from '../domain/users';
import { timeAgo } from '../domain/workers';
import type { AdminGateway } from '../services/gateway';
import { errorMessage } from '../services/gateway';
import { StatePanel, useRowLink } from '../components/ui';
import { useCompactLayout } from '../hooks/useCompactLayout';

type Load<T> = { status: 'loading' } | { status: 'error'; message: string } | { status: 'ready'; data: T };
const filters: { value: UserFilter; label: string }[] = [
  { value: 'all', label: 'All users' }, { value: 'admin', label: 'Admins' }, { value: 'user', label: 'Regular' }, { value: 'disabled', label: 'Disabled' },
];

export function RoleBadge({ user }: { user: DirectoryUser }) {
  if (user.disabled) return <span className="user-badge disabled"><Ban size={12} aria-hidden="true" />Disabled</span>;
  return user.role === 'admin' ? <span className="user-badge admin"><ShieldCheck size={12} aria-hidden="true" />Admin</span>
    : <span className="user-badge"><UserRound size={12} aria-hidden="true" />User</span>;
}

/** Directory of every profile with its role, account state and analysis activity. */
export function Users({ gateway, demo }: { gateway: AdminGateway; demo: boolean }) {
  const compact = useCompactLayout();
  const rowLink = useRowLink();
  const [users, setUsers] = useState<Load<DirectoryUser[]>>({ status: 'loading' });
  const [analyses, setAnalyses] = useState<Analysis[]>([]);
  const [retry, setRetry] = useState(0);
  const [query, setQuery] = useState('');
  const [filter, setFilter] = useState<UserFilter>('all');
  useEffect(() => {
    let active = true;
    setUsers({ status: 'loading' });
    const stopUsers = gateway.watchUsers((data) => { if (active) setUsers({ status: 'ready', data }); },
      (error) => { if (active) setUsers({ status: 'error', message: errorMessage(error) }); });
    // Activity counts are a convenience; the list stands without them.
    const stopAnalyses = gateway.watchAnalyses((feed) => { if (active) setAnalyses(feed.analyses); }, () => {});
    return () => { active = false; stopUsers(); stopAnalyses(); };
  }, [gateway, retry]);

  const all = useMemo(() => users.status === 'ready' ? users.data : [], [users]);
  const activity = useMemo(() => activityByUser(analyses), [analyses]);
  const visible = useMemo(() => filterUsers(all, query, filter), [all, query, filter]);
  const now = new Date();
  const base = demo ? '/demo' : '';
  const counts = { all: all.length, admin: all.filter((u) => u.role === 'admin' && !u.disabled).length,
    user: all.filter((u) => u.role === 'user' && !u.disabled).length, disabled: all.filter((u) => u.disabled).length };
  const usage = (uid: string) => {
    const item = activity.get(uid);
    return item ? `${item.total} ${item.total === 1 ? 'analysis' : 'analyses'}${item.failed ? ` · ${item.failed} failed` : ''}` : 'No analyses';
  };

  return <>
    <div className="page-heading"><div><div className="eyebrow">PEOPLE</div><h1>Users<span className="heading-dot">.</span></h1>
      <p>Who uses Realtron, what they analyze, and who can administer it.</p></div></div>
    {users.status === 'loading' ? <StatePanel title="Loading users" loading />
      : users.status === 'error' ? <StatePanel title="Couldn’t load users" retry={() => setRetry((value) => value + 1)}>{users.message}</StatePanel> : <>
        <div className="metrics">{[
          { title: 'People', value: counts.all, note: 'Profiles in the directory', icon: UsersIcon, tone: 'accent' },
          { title: 'Admins', value: counts.admin, note: 'Can open this workspace', icon: ShieldCheck, tone: 'green' },
          { title: 'Disabled', value: counts.disabled, note: 'Cannot sign in', icon: Ban, tone: 'red' },
          { title: 'With push', value: all.filter((u) => u.hasDevice).length, note: 'A registered device', icon: Smartphone, tone: 'amber' },
        ].map(({ title, value, note, icon: Icon, tone }) => <section className="metric" key={title} aria-label={`${title}: ${value}`}>
          <div className="metric-top"><span>{title}</span><span className={`metric-icon ${tone}`}><Icon size={18} /></span></div>
          <strong>{value.toLocaleString('en')}</strong><span className="metric-note">{note}</span></section>)}</div>
        {!all.length ? <div className="notice">No profiles synced yet. The backend notification worker builds this list about once a minute.</div> : null}
        <section className="analyses-panel" aria-label="Users">
          <div className="table-toolbar"><div className="filter-list" aria-label="User filter">{filters.map((item) => <button key={item.value}
            className={`filter-button ${filter === item.value ? 'selected' : ''}`} aria-pressed={filter === item.value} onClick={() => setFilter(item.value)}>
            {item.label} <span>{counts[item.value]}</span></button>)}</div>
            <div className="search-field"><Search size={17} aria-hidden="true" /><input aria-label="Search name, email or UID" placeholder="Search name, email or UID…"
              value={query} onChange={(event) => setQuery(event.target.value)} />
              {query && <button aria-label="Clear search" onClick={() => setQuery('')}><X size={15} /></button>}</div></div>
          {!visible.length ? <div className="empty-state"><Search size={28} /><h3>No matching users</h3><p>Try another name, email or filter.</p></div>
            : compact ? <div className="mobile-analysis-list">{visible.map((user) => <article className="mobile-analysis-card" key={user.uid}>
              <div className="mobile-card-meta"><code>{user.email ?? user.uid}</code><RoleBadge user={user} /></div>
              <Link to={`${base}/users/${encodeURIComponent(user.uid)}`} className="paper-title">{user.name}</Link>
              <div className="mobile-card-footer"><span>{usage(user.uid)}</span>
                <Link to={`${base}/users/${encodeURIComponent(user.uid)}`} className="row-action" aria-label={`View ${user.name}`}><ArrowRight size={18} /></Link></div>
            </article>)}</div>
              : <div className="table-scroll"><table><thead><tr><th scope="col" className="paper-column">USER</th><th scope="col">ROLE</th>
                <th scope="col">ACTIVITY</th><th scope="col">LAST SIGN-IN</th><th scope="col"><span className="sr-only">Action</span></th></tr></thead>
                <tbody>{visible.map((user) => <tr key={user.uid} className="clickable-row" onClick={rowLink(`${base}/users/${encodeURIComponent(user.uid)}`)}>
                  <td><div className="paper-cell"><span className="paper-icon"><UserRound size={19} /></span><div>
                    <Link to={`${base}/users/${encodeURIComponent(user.uid)}`} className="paper-title">{user.name}</Link>
                    <div className="paper-subtitle"><span>{user.email ?? 'No email on record'}</span>{user.hasDevice && <><span aria-hidden="true">·</span><span>Push device</span></>}</div>
                  </div></div></td>
                  <td><RoleBadge user={user} /></td>
                  <td className="references-cell">{usage(user.uid)}</td>
                  <td className="date-cell">{timeAgo(user.lastSignInAt, now)}</td>
                  <td><Link to={`${base}/users/${encodeURIComponent(user.uid)}`} className="row-action" aria-label={`View ${user.name}`}><ArrowRight size={18} /></Link></td>
                </tr>)}</tbody></table></div>}
          <div className="table-footer"><span>{visible.length} of {all.length} people</span></div>
        </section>
      </>}
  </>;
}
