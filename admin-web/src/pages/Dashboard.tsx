import { useCallback, useEffect, useMemo, useState } from 'react';
import { ArrowDown, ArrowRight, BookOpen, CheckCheck, ChevronLeft, ChevronRight, CircleAlert, Clock3, Download, FileText, RefreshCw, Search, X } from 'lucide-react';
import { Link } from 'react-router-dom';
import { filterAnalyses, isRunning, summarize, type AnalysisFeed, type AnalysisFilter, type CheckMode } from '../domain/analysis';
import { analysesCsv, downloadCsv } from '../domain/csv';
import type { AdminGateway } from '../services/gateway';
import { errorMessage } from '../services/gateway';
import { StatePanel, StatusBadge, formatDate } from '../components/ui';
import { useCompactLayout } from '../hooks/useCompactLayout';

const pageSize = 8;
const filters: { value: AnalysisFilter; label: string }[] = [
  { value: 'all', label: 'All analyses' }, { value: 'done', label: 'Completed' },
  { value: 'running', label: 'Running' }, { value: 'failed', label: 'Failed' },
  { value: 'cancelled', label: 'Cancelled' }, { value: 'unknown', label: 'Unknown' },
];
type FeedState = { status: 'loading' } | { status: 'error'; message: string } | { status: 'ready'; feed: AnalysisFeed };

export function Dashboard({ gateway, demo }: { gateway: AdminGateway; demo: boolean }) {
  const compact = useCompactLayout();
  const [state, setState] = useState<FeedState>({ status: 'loading' });
  const [retry, setRetry] = useState(0);
  const [query, setQuery] = useState('');
  const [filter, setFilter] = useState<AnalysisFilter>('all');
  const [requestedPage, setPage] = useState(1);
  const [requester, setRequester] = useState('');
  const [mode, setMode] = useState<CheckMode>('all');
  const [names, setNames] = useState<Map<string, string>>(new Map());
  useEffect(() => {
    let active = true;
    setState({ status: 'loading' });
    const stop = gateway.watchAnalyses((feed) => {
      if (active) setState({ status: 'ready', feed });
    }, (error) => { if (active) setState({ status: 'error', message: errorMessage(error) }); });
    // Names are a convenience: without the directory, requesters show as short UIDs.
    const stopNames = gateway.watchRecipients((users) => { if (active) setNames(new Map(users.map((user) => [user.uid, user.name]))); }, () => {});
    return () => { active = false; stop(); stopNames(); };
  }, [gateway, retry]);

  const analyses = state.status === 'ready' ? state.feed.analyses : [];
  const summary = useMemo(() => summarize(analyses), [analyses]);
  const nameOf = useCallback((uid: string | null) => uid ? names.get(uid) ?? `User ${uid.slice(0, 6)}…` : 'Unknown requester', [names]);
  const requesters = useMemo(() => {
    const tally = new Map<string, number>();
    analyses.forEach((a) => { if (a.requestedBy) tally.set(a.requestedBy, (tally.get(a.requestedBy) ?? 0) + 1); });
    return [...tally].map(([uid, count]) => ({ uid, count, name: nameOf(uid) })).sort((a, b) => a.name.localeCompare(b.name));
  }, [analyses, nameOf]);
  const visible = useMemo(() => filterAnalyses(analyses, query, filter, { requester, mode }), [analyses, query, filter, requester, mode]);
  const pages = Math.max(1, Math.ceil(visible.length / pageSize));
  const page = Math.min(requestedPage, pages);
  const rows = visible.slice((page - 1) * pageSize, page * pageSize);
  const refresh = () => setRetry((value) => value + 1);
  const clear = () => { setQuery(''); setFilter('all'); setRequester(''); setMode('all'); setPage(1); };
  const exportCsv = () => downloadCsv(`realtron-analyses-${new Date().toISOString().slice(0, 10)}.csv`, analysesCsv(visible, nameOf));
  const metrics = [
    { title: 'Total analyses', value: summary.total, icon: FileText, note: 'Across the workspace', tone: 'navy' },
    { title: 'Completed', value: summary.done, icon: CheckCheck, note: 'Results ready to review', tone: 'green' },
    { title: 'Running', value: summary.running, icon: Clock3, note: 'Queued & processing', tone: 'amber' },
    { title: 'Failed', value: summary.failed, icon: CircleAlert, note: 'Need a closer look', tone: 'red' },
  ];

  return <>
    <div className="page-heading"><div><div className="eyebrow">WORKSPACE OVERVIEW</div>
      <h1>Analysis overview<span className="heading-dot">.</span></h1>
      <p>One place to follow every paper, from queue to results.</p></div>
      <button className="button secondary" disabled={state.status === 'loading'} onClick={refresh}><RefreshCw size={16} />Refresh</button>
    </div>
    {state.status === 'loading' ? <div className="loading-dashboard" role="status" aria-label="Loading analyses">
      <div className="metrics">{[0, 1, 2, 3].map((item) => <div className="metric skeleton" key={item} />)}</div>
      <div className="skeleton skeleton-table" />
    </div> : state.status === 'error' ? <StatePanel title="Couldn’t load analyses" retry={refresh}>{state.message}</StatePanel> : <>
      <div className="metrics">{metrics.map(({ title, value, icon: Icon, note, tone }) => <section className="metric" key={title} aria-label={`${title}: ${value}`}>
        <div className="metric-top"><span>{title}</span><span className={`metric-icon ${tone}`}><Icon size={18} /></span></div>
        <strong>{value.toLocaleString('en')}</strong><span className="metric-note">{note}</span>
      </section>)}</div>
      {!demo && state.feed.fromCache && <div className="notice">Showing cached data. Live updates will resume when the connection is restored.</div>}
      <section className="analyses-panel" aria-label="Paper analyses">
        <div className="panel-heading"><div className="panel-title"><BookOpen size={19} /><h2>Paper analyses</h2><span className="count-pill">{summary.total}</span></div>
          <span className="panel-caption">Newest first</span></div>
        <div className="table-toolbar"><div className="filter-list" aria-label="Analysis status">
          {filters.filter((item) => item.value !== 'unknown' || analyses.some((a) => a.status === 'unknown')).map((item) => {
            const count = item.value === 'all' ? summary.total : analyses.filter((a) => item.value === 'running' ? isRunning(a) : a.status === item.value).length;
            return <button key={item.value} className={`filter-button ${filter === item.value ? 'selected' : ''}`}
              aria-pressed={filter === item.value} onClick={() => { setFilter(item.value); setPage(1); }}>{item.label}{' '}<span>{count}</span></button>;
          })}</div>
          <div className="search-field"><Search size={17} aria-hidden="true" /><input aria-label="Search title or arXiv ID" placeholder="Search title or arXiv ID…"
            value={query} onChange={(event) => { setQuery(event.target.value); setPage(1); }} />
            {query && <button aria-label="Clear search" onClick={() => { setQuery(''); setPage(1); }}><X size={15} /></button>}</div>
        </div>
        <div className="table-scope">
          <label className="select-label">Requested by<select aria-label="Requested by" value={requester} onChange={(event) => { setRequester(event.target.value); setPage(1); }}>
            <option value="">All requesters</option>{requesters.map((item) => <option key={item.uid} value={item.uid}>{item.name} ({item.count})</option>)}</select></label>
          <label className="select-label">Check mode<select aria-label="Check mode" value={mode} onChange={(event) => { setMode(event.target.value as CheckMode); setPage(1); }}>
            <option value="all">All modes</option><option value="ai">AI-assisted</option><option value="standard">Standard</option></select></label>
          <button className="button secondary export-button" disabled={!visible.length} onClick={exportCsv}
            aria-label={`Export CSV (${visible.length} ${visible.length === 1 ? 'analysis' : 'analyses'})`}><Download size={15} />Export CSV</button>
        </div>
        {rows.length ? compact ? <div className="mobile-analysis-list">{rows.map((analysis) => <article className="mobile-analysis-card" key={analysis.id}>
          <div className="mobile-card-meta"><code>arXiv:{analysis.id}</code><StatusBadge status={analysis.status} /></div>
          <Link to={`analyses/${encodeURIComponent(analysis.id)}`} className="paper-title">{analysis.title}</Link>
          <p className="mobile-card-author">{analysis.authors[0] ? `${analysis.authors[0]}${analysis.authors.length > 1 ? ' et al.' : ''}` : 'Authors unavailable'}</p>
          {analysis.status === 'processing' && <div className="row-progress"><progress max={100} value={analysis.progress} aria-label={`Analysis progress for ${analysis.id}`} /><span>{analysis.progress}%</span></div>}
          <div className="mobile-card-footer"><span>{analysis.status === 'done' ? `${analysis.totalRefs} references` : 'Results pending'}<span aria-hidden="true"> · </span>{formatDate(analysis.createdAt)}</span>
            <Link to={`analyses/${encodeURIComponent(analysis.id)}`} className="row-action" aria-label={`View ${analysis.title}`}><ArrowRight size={18} /></Link></div>
        </article>)}</div> : <div className="table-scroll"><table><thead><tr>
          <th scope="col" className="paper-column">PAPER</th><th scope="col">STATUS</th><th scope="col">REFERENCES</th>
          <th scope="col"><span className="column-label">REQUESTED <ArrowDown size={12} /></span></th><th scope="col"><span className="sr-only">Action</span></th>
        </tr></thead><tbody>{rows.map((analysis) => <tr key={analysis.id}>
          <td><div className="paper-cell"><span className="paper-icon"><FileText size={19} /></span><div>
            <Link to={`analyses/${encodeURIComponent(analysis.id)}`} className="paper-title">{analysis.title}</Link>
            <div className="paper-subtitle"><code>arXiv:{analysis.id}</code><span aria-hidden="true">·</span>
              <span>{analysis.authors[0] ? `${analysis.authors[0]}${analysis.authors.length > 1 ? ' et al.' : ''}` : 'Authors unavailable'}</span></div>
          </div></div></td>
          <td><StatusBadge status={analysis.status} />{analysis.status === 'processing' && <div className="row-progress"><progress aria-label={`Analysis progress for ${analysis.id}`} max={100} value={analysis.progress} /><span>{analysis.progress}%</span></div>}</td>
          <td className="references-cell">{analysis.status === 'done' ? <><strong>{analysis.totalRefs}</strong><span>references</span></> : <span className="muted">—</span>}</td>
          <td className="date-cell">{formatDate(analysis.createdAt)}<span>{[analysis.createdAt?.getFullYear(), analysis.requestedBy && `by ${nameOf(analysis.requestedBy)}`].filter(Boolean).join(' · ')}</span></td>
          <td><Link to={`analyses/${encodeURIComponent(analysis.id)}`} className="row-action" aria-label={`View ${analysis.title}`}><ArrowRight size={18} /></Link></td>
        </tr>)}</tbody></table></div> : <div className="empty-state"><Search size={30} /><h3>{summary.total ? 'No matching analyses' : 'Your workspace is ready'}</h3>
          <p>{summary.total ? 'Try another title, arXiv ID, status or requester.' : 'Analyses will appear here when a user checks a paper.'}</p>
          {summary.total > 0 && <button className="button secondary" onClick={clear}>Clear filters</button>}</div>}
        <div className="table-footer"><span>{visible.length ? `${(page - 1) * pageSize + 1}–${Math.min(page * pageSize, visible.length)}` : '0'} of {visible.length} analyses{visible.length !== summary.total ? ` · ${summary.total} total` : ''}</span>
          <div className="pagination"><button aria-label="Previous page" disabled={page <= 1} onClick={() => setPage(page - 1)}><ChevronLeft size={16} /></button>
            <span>Page {page} of {pages}</span><button aria-label="Next page" disabled={page >= pages} onClick={() => setPage(page + 1)}><ChevronRight size={16} /></button></div></div>
      </section>
      <p className="workspace-footnote"><span className="small-dot" />{demo ? 'Sample workspace · No changes are saved to Firebase' : 'Results are shared across Realtron · Updates appear automatically'}</p>
    </>}
  </>;
}
