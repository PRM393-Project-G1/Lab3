import { useCallback, useEffect, useMemo, useState } from 'react';
import { ArrowLeft, ArrowUpRight, BookOpen, ChevronDown, Clock3, FileText, GitBranch, Sparkles } from 'lucide-react';
import { Link, useLocation, useParams } from 'react-router-dom';
import { buildTopicTree, referenceStatuses, type AnalysisResults, type ReferenceStatus, type TopicNode } from '../domain/analysis';
import type { AdminGateway } from '../services/gateway';
import { errorMessage } from '../services/gateway';
import { ReferenceBadge, StatePanel, StatusBadge, formatDate } from '../components/ui';
import { AnalysisActions } from '../components/AnalysisActions';

type ResultState = { status: 'loading' } | { status: 'ready'; id: string; results: AnalysisResults } | { status: 'error'; id: string; message: string };
const labels: Record<string, string> = { references: 'Reading references', verify: 'Verifying references', fabrication: 'Checking fabrication', fulltext: 'Collecting full text', topics: 'Extracting topics' };

export function AnalysisDetail({ gateway }: { gateway: AdminGateway }) {
  const { analysisId = '' } = useParams();
  const location = useLocation();
  const [state, setState] = useState<ResultState>({ status: 'loading' });
  const [retry, setRetry] = useState(0);
  const reload = useCallback(() => setRetry((value) => value + 1), []);
  const [referenceFilter, setReferenceFilter] = useState<ReferenceStatus | 'all'>('all');
  const [tab, setTab] = useState<'topics' | 'references'>('topics');
  useEffect(() => {
    let active = true;
    setState({ status: 'loading' });
    setReferenceFilter('all');
    setTab('topics');
    if (!/^\d{4}\.\d{4,5}$/.test(analysisId)) {
      setState({ status: 'error', id: analysisId, message: 'This analysis ID is not valid.' });
      return () => { active = false; };
    }
    gateway.getResults(analysisId).then((results) => {
      if (active) setState({ status: 'ready', id: analysisId, results });
    }).catch((error) => {
      if (active) setState({ status: 'error', id: analysisId,
        message: error && typeof error === 'object' && 'code' in error && error.code === 'not-found' ? 'This analysis could not be found.' : errorMessage(error) });
    });
    return () => { active = false; };
  }, [gateway, analysisId, retry]);
  const results = state.status === 'ready' && state.id === analysisId ? state.results : null;
  const roots = useMemo(() => results ? buildTopicTree(results.topics, results.references, results.weakRule) : [], [results]);
  // This page is two segments below the workspace root; absolute links retain demo isolation.
  const base = location.pathname.startsWith('/demo/') ? '/demo' : '/';
  const backLink = <Link to={base} className="back-link"><ArrowLeft size={16} />Back to analyses</Link>;
  if (state.status === 'loading' || ('id' in state && state.id !== analysisId)) return <>{backLink}<StatePanel title="Loading analysis" loading /></>;
  if (state.status === 'error') return <>{backLink}<StatePanel title="Couldn’t open analysis" retry={() => setRetry((value) => value + 1)}>{state.message}</StatePanel></>;
  if (!results) return backLink;
  const { analysis, references, weakRule } = results;
  const sortedRefs = [...references].filter((ref) => referenceFilter === 'all' || ref.status === referenceFilter)
    .sort((a, b) => referenceStatuses.indexOf(a.status) - referenceStatuses.indexOf(b.status) || a.index - b.index);
  return <>
    {backLink}
    <div className="detail-heading"><div className="eyebrow">PAPER ANALYSIS</div><div className="detail-status"><code>arXiv:{analysis.id}</code><StatusBadge status={analysis.status} /></div>
      <h1>{analysis.title}</h1><p>{analysis.authors.join(', ') || 'Authors unavailable'}</p>
      <div className="detail-meta"><span><Clock3 size={15} />Requested {formatDate(analysis.createdAt, true)}</span>
        {analysis.aiAssisted !== null && <span><Sparkles size={15} />{analysis.aiAssisted ? 'AI-assisted check' : 'Standard check'}</span>}
        <a href={`https://arxiv.org/abs/${encodeURIComponent(analysis.id)}`} target="_blank" rel="noopener noreferrer">Open on arXiv<ArrowUpRight size={15} /></a></div>
    </div>
    {analysis.status !== 'done' ? <section className="detail-panel"><h2>Analysis status</h2>
      {analysis.status === 'processing' ? <><p>{labels[analysis.stage] || 'Processing paper'} · {analysis.progress}%</p><progress max={100} value={analysis.progress} aria-label="Analysis progress" /></>
        : <p>{analysis.status === 'queued' ? 'This paper is waiting for a processing slot.' : analysis.status === 'cancelled' ? 'This analysis was stopped.'
          : analysis.status === 'failed' ? analysis.error || 'The analysis failed without an additional error message.' : 'This record has an unknown status.'}</p>}
      <p className="muted">Return to the overview for live status updates.</p></section> : <>
      <section className="detail-panel reference-summary"><div className="panel-title"><FileText size={19} /><h2>Reference verification</h2><span className="count-pill">{analysis.totalRefs}</span></div>
        <div className="status-bar" aria-label="Reference status distribution">{referenceStatuses.map((status) => analysis.counts[status] > 0 && <div key={status} className={`bar-${status}`}
          style={{ flex: analysis.counts[status] }} title={`${status}: ${analysis.counts[status]}`} />)}</div>
        <div className="status-legend">{referenceStatuses.map((status) => <span key={status}><ReferenceBadge status={status} /><strong>{analysis.counts[status]}</strong></span>)}</div>
      </section>
      <div className="detail-tabs" aria-label="Result sections"><button className={tab === 'topics' ? 'selected' : ''} aria-pressed={tab === 'topics'} onClick={() => setTab('topics')}><GitBranch size={17} />Topics<span>{results.topics.length}</span></button>
        <button className={tab === 'references' ? 'selected' : ''} aria-pressed={tab === 'references'} onClick={() => setTab('references')}><BookOpen size={17} />References<span>{references.length}</span></button></div>
      {tab === 'topics' ? <section className="detail-panel"><div className="panel-heading"><h2>What this paper stands on</h2><span className="panel-caption">Topic hierarchy</span></div>
        <p className="muted">Weak: at least {weakRule.minRefs} references, with ≥ {Math.round(weakRule.threshold * 100)}% marked Error or Hallucinated.</p>
        {roots.length ? <ul className="topic-tree">{roots.map((node) => <TopicBranch key={node.id} node={node} />)}</ul> : <p>No topics were extracted for this paper.</p>}
        <p className="detail-note">“Weak” describes reference issues in a topic. It does not establish that the paper’s conclusions are wrong.</p>
      </section> : <section className="detail-panel"><div className="panel-heading"><h2>Reference list</h2><label className="select-label">Status<select aria-label="Reference status" value={referenceFilter} onChange={(event) => setReferenceFilter(event.target.value as ReferenceStatus | 'all')}>
        <option value="all">All statuses</option>{referenceStatuses.map((status) => <option key={status} value={status}>{status}</option>)}</select></label></div>
        {sortedRefs.length ? <div className="reference-list">{sortedRefs.map((ref) => <details key={ref.id} className="reference-item"><summary><span className="reference-index">{String(ref.index).padStart(2, '0')}</span>
          <div><h3>{ref.title}</h3><p>{[ref.authors.join(', '), ref.year].filter(Boolean).join(' · ') || 'Metadata unavailable'}</p></div><ReferenceBadge status={ref.status} /><ChevronDown size={16} /></summary>
          <div className="reference-content">{ref.hallucination && <p>{ref.hallucination}</p>}{ref.issues.length ? ref.issues.map((issue, index) => <div className="reference-issue" key={index}><strong>{issue.type}</strong><p>{issue.message}</p>
            {(issue.cited !== null || issue.actual !== null) && <dl><div><dt>Cited</dt><dd>{issue.cited ?? '—'}</dd></div><div><dt>Actual</dt><dd>{issue.actual ?? '—'}</dd></div></dl>}</div>) : <p>No issue details were recorded for this reference.</p>}
            {ref.url && <a href={ref.url} target="_blank" rel="noopener noreferrer">Open source<ArrowUpRight size={14} /></a>}</div>
        </details>)}</div> : <p>No references match this status.</p>}
      </section>}
    </>}
    <AnalysisActions gateway={gateway} analysis={analysis} onSettled={reload} />
  </>;
}

function TopicBranch({ node }: { node: TopicNode }) {
  return <li><div className="topic-row"><span className="topic-symbol"><GitBranch size={17} /></span><strong>{node.term}</strong>
    <span className="topic-count">{node.total} refs</span>{node.isWeak && <span className="weak-badge">Weak</span>}</div>
    {node.children.length > 0 && <ul>{node.children.map((child) => <TopicBranch key={child.id} node={child} />)}</ul>}</li>;
}
