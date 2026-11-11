import { render, screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter } from 'react-router-dom';
import { describe, expect, it } from 'vitest';
import { App } from '../src/App';
import { parseAnalysis } from '../src/domain/analysis';
import { activity, durations, failureReasons, formatDuration, formatPercent, inRange, outcomes, referenceTotals, weakTopics } from '../src/domain/insights';

const now = new Date(2026, 10, 11, 15, 0);
const at = (day: number, hour = 9) => new Date(2026, 10, day, hour);

describe('insight calculations', () => {
  const analyses = [
    parseAnalysis('a', { status: 'done', createdAt: at(11), finishedAt: at(11, 10), summary: { verified: 8, hallucinated: 2 } }),
    parseAnalysis('b', { status: 'done', createdAt: at(10), finishedAt: new Date(at(10).getTime() + 5 * 60000), summary: { error: 5, verified: 5 } }),
    parseAnalysis('c', { status: 'failed', createdAt: at(10), error: 'Paper 1706.03762 failed after 3 tries' }),
    parseAnalysis('d', { status: 'failed', createdAt: at(1), error: 'Paper 1409.0473 failed after 12 tries' }),
    parseAnalysis('e', { status: 'cancelled', createdAt: at(9) }),
    parseAnalysis('f', { status: 'processing', createdAt: at(11) }),
    parseAnalysis('g', { status: 'done' }),
  ];

  it('scopes by local calendar days and keeps undated records for all time only', () => {
    expect(inRange(analyses, '7d', now).map((a) => a.id)).toEqual(['a', 'b', 'c', 'e', 'f']);
    expect(inRange(analyses, 'all', now)).toHaveLength(7);
  });

  it('buckets requests per day and splits outcomes', () => {
    const { unit, buckets } = activity(inRange(analyses, '7d', now), '7d', now);
    expect(unit).toBe('day');
    expect(buckets).toHaveLength(7);
    expect(buckets.at(-1)).toMatchObject({ total: 2, done: 1, other: 1 });
    expect(buckets.at(-2)).toMatchObject({ total: 2, done: 1, failed: 1 });
  });

  it('switches to weeks for spans longer than 90 days', () => {
    const old = [parseAnalysis('x', { status: 'done', createdAt: new Date(2026, 0, 5) })];
    const result = activity(old, 'all', now);
    expect(result.unit).toBe('week');
    expect(result.buckets[0].start.getDay()).toBe(1);
    expect(result.buckets.reduce((sum, bucket) => sum + bucket.total, 0)).toBe(1);
  });

  it('computes success over finished analyses only', () => {
    expect(outcomes(analyses)).toMatchObject({ finished: 6, done: 3, failed: 2, cancelled: 1, running: 1, successRate: 0.5 });
    expect(outcomes([]).successRate).toBeNull();
  });

  it('sums reference outcomes over completed papers', () => {
    const totals = referenceTotals(analyses);
    expect(totals).toMatchObject({ total: 20, papers: 3, fabricatedRate: 0.1 });
    expect(totals.counts).toMatchObject({ verified: 13, hallucinated: 2, error: 5 });
  });

  it('measures request-to-completion time and ranks the longest runs', () => {
    const result = durations(analyses);
    expect(result.count).toBe(2);
    expect(result.longest.map((run) => run.analysis.id)).toEqual(['a', 'b']);
    expect(formatDuration(result.averageMs)).toBe('33 min');
    expect(formatDuration(3_900_000)).toBe('1 h 05 min');
    expect(formatDuration(null)).toBe('—');
  });

  it('groups failure messages that differ only by IDs or numbers', () => {
    expect(failureReasons(analyses)).toEqual([{ reason: 'Paper # failed after # tries', count: 2 }]);
    const many = Array.from({ length: 7 }, (_, i) => parseAnalysis(`${i}`, { status: 'failed', error: `Reason ${'abcdefg'[i]}` }));
    expect(failureReasons(many, 5).at(-1)).toEqual({ reason: 'Other reasons', count: 2 });
  });

  it('ranks topics by how many papers they were weak in, applying the current rule', () => {
    const papers = [
      parseAnalysis('p1', { status: 'done', topicSummary: [{ term: 'Attention', total: 4, flagged: 3 }, { term: 'attention', total: 5, flagged: 5 }, { term: 'GANs', total: 2, flagged: 2 }] }),
      parseAnalysis('p2', { status: 'done', topicSummary: [{ term: 'Attention', total: 10, flagged: 5 }, { term: 'Optimization', total: 6, flagged: 1 }] }),
      parseAnalysis('p3', { status: 'done' }),
      parseAnalysis('p4', { status: 'failed', topicSummary: [{ term: 'Attention', total: 9, flagged: 9 }] }),
    ];
    const result = weakTopics(papers, { threshold: 0.5, minRefs: 3 });
    expect(result).toMatchObject({ summarized: 2, completed: 3 });
    expect(result.topics).toEqual([{ term: 'Attention', papers: 2, flagged: 8, total: 14 }]);
    expect(weakTopics(papers, { threshold: 0.6, minRefs: 2 }).topics.map((t) => t.term)).toEqual(['GANs', 'Attention']);
    expect(parseAnalysis('x', { topicSummary: [{ term: ' ', total: 3 }, { term: 'A', total: 2, flagged: 9 }] }).topicSummary).toEqual([{ term: 'A', depth: 0, total: 2, flagged: 2 }]);
  });

  it('never rounds a non-zero share to zero', () => {
    expect(formatPercent(0.0004, 1)).toBe('<0.1%');
    expect(formatPercent(0)).toBe('0%');
    expect(formatPercent(null)).toBe('—');
  });
});

describe('insights page', () => {
  it('shows headline numbers, the request chart and its table view in the demo workspace', async () => {
    render(<MemoryRouter initialEntries={['/demo/insights']}><App /></MemoryRouter>);
    await screen.findByRole('heading', { name: 'Insights.' });
    await userEvent.click(screen.getByRole('button', { name: 'All time' }));
    expect(screen.getByLabelText('Analyses requested: 12')).toBeInTheDocument();
    expect(screen.getByLabelText(/^Success rate: 70%/)).toBeInTheDocument();
    expect(screen.getByRole('group', { name: 'Reference status distribution' })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /^Hallucinated: 3 references/ })).toBeInTheDocument();
    const failures = screen.getByRole('list', { name: 'Failure reasons' });
    expect(within(failures).getByText('The server restarted. Try again.')).toBeInTheDocument();
    const weak = screen.getByRole('list', { name: 'Weak topics' });
    expect(within(weak).getByText('Attention mechanisms')).toBeInTheDocument();
    expect(within(weak).getByText(/^2 papers/)).toBeInTheDocument();
    expect(screen.getByRole('link', { name: /BERT/ })).toHaveAttribute('href', '/demo/analyses/1810.04805');
    await userEvent.click(screen.getByRole('link', { name: 'Insights' }));
    expect(screen.getByRole('link', { name: 'Insights' })).toHaveAttribute('aria-current', 'page');
  });
});

describe('worker liveness', () => {
  it('needs three missed beats and at least three minutes before a running worker is offline', async () => {
    const { liveness, parseWorker, timeAgo } = await import('../src/domain/workers');
    const now = new Date(2026, 10, 11, 12, 0);
    const seen = (minutes: number, extra = {}) => parseWorker('backend', { state: 'running', lastSeen: new Date(now.getTime() - minutes * 60000), ...extra });
    expect(liveness(seen(2.5), now)).toBe('online');
    expect(liveness(seen(4), now)).toBe('offline');
    expect(liveness(seen(4, { intervalSeconds: 120 }), now)).toBe('online');
    expect(liveness(seen(0, { state: 'stopped' }), now)).toBe('stopped');
    expect(liveness(undefined, now)).toBe('never');
    expect(liveness(parseWorker('backend', { state: 'running' }), now)).toBe('never');
    expect(timeAgo(new Date(now.getTime() - 3 * 3600000), now)).toBe('3 h ago');
  });
});
