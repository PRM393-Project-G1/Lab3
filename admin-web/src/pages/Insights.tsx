import { useEffect, useMemo, useState, type ReactNode } from 'react';
import { BarChart3, CircleAlert, Clock3, FileText, GitBranch, RefreshCw, ShieldAlert, TrendingUp } from 'lucide-react';
import { type AnalysisFeed, type ReferenceStatus, type WeakRule } from '../domain/analysis';
import { activity, durations, failureReasons, formatDuration, formatPercent, inRange, insightRanges, outcomes, referenceTotals, weakTopics, type InsightRange } from '../domain/insights';
import type { AdminGateway } from '../services/gateway';
import { errorMessage } from '../services/gateway';
import { StatePanel } from '../components/ui';
import { BarList, ColumnChart, SegmentedBar } from '../components/charts';

type FeedState = { status: 'loading' } | { status: 'error'; message: string } | { status: 'ready'; feed: AnalysisFeed };

/** Validated as a set for adjacent-pair color-vision separation; legend, labels and table carry identity too. */
export const referenceColors: Record<ReferenceStatus, { label: string; color: string; darkText?: boolean }> = {
  hallucinated: { label: 'Hallucinated', color: '#6250d6' }, error: { label: 'Error', color: '#d03b3b' },
  warning: { label: 'Warning', color: '#fab219', darkText: true }, unverified: { label: 'Unverified', color: '#a9b1bf', darkText: true },
  verified: { label: 'Verified', color: '#0ca30c' },
};
const defaultWeakRule: WeakRule = { threshold: 0.5, minRefs: 3 };
const dayFormat = new Intl.DateTimeFormat('en', { month: 'short', day: 'numeric' });

export function Insights({ gateway, demo }: { gateway: AdminGateway; demo: boolean }) {
  const [state, setState] = useState<FeedState>({ status: 'loading' });
  const [retry, setRetry] = useState(0);
  const [range, setRange] = useState<InsightRange>('30d');
  const [rule, setRule] = useState<WeakRule>(defaultWeakRule);
  useEffect(() => {
    let active = true;
    setState({ status: 'loading' });
    const stop = gateway.watchAnalyses((feed) => { if (active) setState({ status: 'ready', feed }); },
      (error) => { if (active) setState({ status: 'error', message: errorMessage(error) }); });
    gateway.getWeakRule().then((value) => { if (active) setRule(value); }).catch(() => {});
    return () => { active = false; stop(); };
  }, [gateway, retry]);

  const all = useMemo(() => state.status === 'ready' ? state.feed.analyses : [], [state]);
  const scoped = useMemo(() => inRange(all, range), [all, range]);
  const result = useMemo(() => ({ outcome: outcomes(scoped), references: referenceTotals(scoped), timing: durations(scoped),
    reasons: failureReasons(scoped), trend: activity(scoped, range), weak: weakTopics(scoped, rule) }), [scoped, range, rule]);
  const rangeLabel = insightRanges.find((item) => item.value === range)!.label.toLowerCase();
  const base = demo ? '/demo' : '';

  return <>
    <div className="page-heading"><div><div className="eyebrow">WORKSPACE INSIGHTS</div>
      <h1>Insights<span className="heading-dot">.</span></h1>
      <p>How analyses and reference checks are trending across Realtron.</p></div>
      <button className="button secondary" disabled={state.status === 'loading'} onClick={() => setRetry((value) => value + 1)}><RefreshCw size={16} />Refresh</button>
    </div>
    {state.status === 'loading' ? <StatePanel title="Loading insights" loading />
      : state.status === 'error' ? <StatePanel title="Couldn’t load insights" retry={() => setRetry((value) => value + 1)}>{state.message}</StatePanel> : <>
        <div className="filter-list insight-ranges" role="group" aria-label="Time range">{insightRanges.map((item) => <button key={item.value}
          className={`filter-button ${range === item.value ? 'selected' : ''}`} aria-pressed={range === item.value} onClick={() => setRange(item.value)}>{item.label}</button>)}</div>
        {!demo && state.feed.fromCache && <div className="notice">Showing cached data. Live updates will resume when the connection is restored.</div>}
        <div className="metrics">
          <Metric title="Analyses requested" value={scoped.length.toLocaleString('en')} note={`${result.outcome.running} still running`} icon={<FileText size={18} />} tone="navy" />
          <Metric title="Success rate" value={formatPercent(result.outcome.successRate)} icon={<TrendingUp size={18} />} tone="green"
            note={result.outcome.finished ? `${result.outcome.done} of ${result.outcome.finished} finished analyses` : 'No finished analyses yet'} />
          <Metric title="Fabricated references" value={formatPercent(result.references.fabricatedRate, 1)} icon={<ShieldAlert size={18} />} tone="red"
            note={result.references.total ? `${result.references.counts.hallucinated} of ${result.references.total.toLocaleString('en')} checked references` : 'No completed checks yet'} />
          <Metric title="Average processing time" value={formatDuration(result.timing.averageMs)} icon={<Clock3 size={18} />} tone="amber"
            note={result.timing.count ? `Median ${formatDuration(result.timing.medianMs)} · ${result.timing.count} completed` : 'No completed analyses yet'} />
        </div>
        <section className="detail-panel insight-panel" aria-labelledby="activity-title"><div className="insight-heading"><h2 id="activity-title">Analyses requested per {result.trend.unit}</h2>
          <span className="panel-caption">{rangeLabel}</span></div>
          <ColumnChart label={`Analyses requested per ${result.trend.unit}`} tableHeadings={[result.trend.unit === 'day' ? 'Day' : 'Week of', 'Requested', 'Completed', 'Failed', 'Other']}
            columns={result.trend.buckets.map((bucket) => {
              const label = dayFormat.format(bucket.start);
              return { key: bucket.start.toISOString(), label, value: bucket.total, tableCells: [bucket.total, bucket.done, bucket.failed, bucket.other],
                detail: `${result.trend.unit === 'week' ? 'Week of ' : ''}${label}: ${bucket.total} requested · ${bucket.done} completed · ${bucket.failed} failed · ${bucket.other} other` };
            })} />
        </section>
        <section className="detail-panel insight-panel" aria-labelledby="references-title"><div className="insight-heading"><h2 id="references-title">Reference verification</h2>
          <span className="panel-caption">{result.references.papers} completed {result.references.papers === 1 ? 'paper' : 'papers'} · {result.references.total.toLocaleString('en')} references</span></div>
          <p className="muted insight-note">Hallucinated references are the ones the checker could not match to any real publication.</p>
          <SegmentedBar label="Reference status distribution" unit="references" segments={(['hallucinated', 'error', 'warning', 'unverified', 'verified'] as const).map((status) => ({
            key: status, value: result.references.counts[status], ...referenceColors[status] }))} />
        </section>
        <section className="detail-panel insight-panel" aria-labelledby="weak-title"><div className="insight-heading"><h2 id="weak-title"><GitBranch size={18} />Common weak topics</h2>
          <span className="panel-caption">Papers where the topic was weak</span></div>
          <p className="muted insight-note">Weak: at least {rule.minRefs} references, with ≥ {Math.round(rule.threshold * 100)}% marked Error or Hallucinated.
            {result.weak.summarized < result.weak.completed && ` ${result.weak.completed - result.weak.summarized} of ${result.weak.completed} completed papers have no topic summary yet; run the backend backfill to include them.`}</p>
          <BarList label="Weak topics" empty={result.weak.summarized ? 'No topic was weak in this period.' : 'No topic summaries yet.'}
            rows={result.weak.topics.map((topic) => ({ key: topic.term, label: topic.term, text: topic.term, value: topic.papers,
              display: `${topic.papers} ${topic.papers === 1 ? 'paper' : 'papers'} · ${formatPercent(topic.flagged / topic.total)} flagged` }))} />
        </section>
        <div className="insight-grid">
          <section className="detail-panel insight-panel" aria-labelledby="failures-title"><div className="insight-heading"><h2 id="failures-title"><CircleAlert size={18} />Common failure reasons</h2>
            <span className="panel-caption">{result.outcome.failed} failed</span></div>
            <BarList label="Failure reasons" empty="No failed analyses in this period." rows={result.reasons.map((item) => ({ key: item.reason, label: item.reason, text: item.reason, value: item.count }))} />
          </section>
          <section className="detail-panel insight-panel" aria-labelledby="longest-title"><div className="insight-heading"><h2 id="longest-title"><BarChart3 size={18} />Longest runs</h2>
            <span className="panel-caption">Request to completion</span></div>
            <BarList label="Longest analyses" empty="No completed analyses in this period." rows={result.timing.longest.map((run) => ({ key: run.analysis.id, label: run.analysis.title,
              text: run.analysis.title, value: run.ms, display: formatDuration(run.ms), href: `${base}/analyses/${encodeURIComponent(run.analysis.id)}` }))} />
          </section>
        </div>
      </>}
  </>;
}

function Metric({ title, value, note, icon, tone }: { title: string; value: string; note: string; icon: ReactNode; tone: string }) {
  return <section className="metric" aria-label={`${title}: ${value}`}>
    <div className="metric-top"><span>{title}</span><span className={`metric-icon ${tone}`}>{icon}</span></div>
    <strong>{value}</strong><span className="metric-note">{note}</span>
  </section>;
}
