import { counts, isRunning, referenceStatuses, totalCounts, type Analysis, type Counts, type WeakRule } from './analysis';

export type InsightRange = '7d' | '30d' | '90d' | 'all';
export const insightRanges: { value: InsightRange; label: string; days: number | null }[] = [
  { value: '7d', label: 'Last 7 days', days: 7 }, { value: '30d', label: 'Last 30 days', days: 30 },
  { value: '90d', label: 'Last 90 days', days: 90 }, { value: 'all', label: 'All time', days: null },
];

function startOfDay(date: Date): Date { const day = new Date(date); day.setHours(0, 0, 0, 0); return day; }
function addDays(date: Date, days: number): Date { const next = new Date(date); next.setDate(next.getDate() + days); return next; }
function startOfWeek(date: Date): Date { const day = startOfDay(date); return addDays(day, -((day.getDay() + 6) % 7)); }

/** The first day the range covers, or null for all time. Days are local calendar days. */
export function rangeStart(range: InsightRange, now = new Date()): Date | null {
  const days = insightRanges.find((item) => item.value === range)?.days ?? null;
  return days === null ? null : addDays(startOfDay(now), 1 - days);
}

/** Records without a request time only count toward all time. */
export function inRange(analyses: Analysis[], range: InsightRange, now = new Date()): Analysis[] {
  const start = rangeStart(range, now);
  return start ? analyses.filter((a) => a.createdAt && a.createdAt >= start) : analyses;
}

export interface ActivityBucket { start: Date; total: number; done: number; failed: number; other: number }
export interface Activity { unit: 'day' | 'week'; buckets: ActivityBucket[] }

/** Requests per day, or per week once the span passes 90 days so columns stay readable. */
export function activity(analyses: Analysis[], range: InsightRange, now = new Date()): Activity {
  const dated = analyses.filter((a): a is Analysis & { createdAt: Date } => a.createdAt !== null);
  const earliest = dated.reduce<Date | null>((min, a) => !min || a.createdAt < min ? a.createdAt : min, null);
  const first = rangeStart(range, now) ?? (earliest ? startOfDay(earliest) : startOfDay(now));
  const today = startOfDay(now);
  const spanDays = Math.round((today.getTime() - first.getTime()) / 86_400_000) + 1;
  const unit = spanDays > 90 ? 'week' : 'day';
  const bucketStart = unit === 'week' ? startOfWeek : startOfDay;
  const buckets: ActivityBucket[] = [];
  const index = new Map<number, ActivityBucket>();
  for (let day = bucketStart(first); day <= today; day = addDays(day, unit === 'week' ? 7 : 1)) {
    const bucket = { start: day, total: 0, done: 0, failed: 0, other: 0 };
    buckets.push(bucket); index.set(day.getTime(), bucket);
  }
  for (const analysis of dated) {
    const bucket = index.get(bucketStart(analysis.createdAt).getTime());
    if (!bucket) continue;
    bucket.total++;
    if (analysis.status === 'done') bucket.done++;
    else if (analysis.status === 'failed') bucket.failed++;
    else bucket.other++;
  }
  return { unit, buckets };
}

export interface Outcomes { finished: number; done: number; failed: number; cancelled: number; running: number; successRate: number | null }
/** Success rate counts only analyses that reached an end state. */
export function outcomes(analyses: Analysis[]): Outcomes {
  const done = analyses.filter((a) => a.status === 'done').length;
  const failed = analyses.filter((a) => a.status === 'failed').length;
  const cancelled = analyses.filter((a) => a.status === 'cancelled').length;
  const finished = done + failed + cancelled;
  return { finished, done, failed, cancelled, running: analyses.filter(isRunning).length,
    successRate: finished ? done / finished : null };
}

export interface ReferenceTotals { counts: Counts; total: number; papers: number; fabricatedRate: number | null }
/** Reference outcomes summed over completed analyses. */
export function referenceTotals(analyses: Analysis[]): ReferenceTotals {
  const sum = counts({});
  const completed = analyses.filter((a) => a.status === 'done');
  for (const analysis of completed) referenceStatuses.forEach((status) => { sum[status] += analysis.counts[status]; });
  const total = totalCounts(sum);
  return { counts: sum, total, papers: completed.length, fabricatedRate: total ? sum.hallucinated / total : null };
}

export interface Run { analysis: Analysis; ms: number }
export interface Durations { count: number; averageMs: number | null; medianMs: number | null; longest: Run[] }
/** Wall time from request to completion. Retries restart the clock at their new request time. */
export function durations(analyses: Analysis[], top = 5): Durations {
  const runs = analyses.flatMap((analysis) => analysis.status === 'done' && analysis.createdAt && analysis.finishedAt &&
    analysis.finishedAt >= analysis.createdAt ? [{ analysis, ms: analysis.finishedAt.getTime() - analysis.createdAt.getTime() }] : [])
    .sort((a, b) => b.ms - a.ms);
  if (!runs.length) return { count: 0, averageMs: null, medianMs: null, longest: [] };
  const sorted = runs.map((run) => run.ms).sort((a, b) => a - b);
  const middle = Math.floor(sorted.length / 2);
  return { count: runs.length, averageMs: sorted.reduce((sum, ms) => sum + ms, 0) / runs.length,
    medianMs: sorted.length % 2 ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2, longest: runs.slice(0, top) };
}

export interface Reason { reason: string; count: number }
/** Groups identical failure messages; IDs and numbers are masked so variants share one row. */
export function failureReasons(analyses: Analysis[], top = 5): Reason[] {
  const groups = new Map<string, number>();
  for (const analysis of analyses) {
    if (analysis.status !== 'failed') continue;
    const reason = (analysis.error ?? '').replace(/\s+/g, ' ').replace(/\d+(\.\d+)*/g, '#').trim() || 'No error message recorded';
    groups.set(reason, (groups.get(reason) ?? 0) + 1);
  }
  const ranked = [...groups].map(([reason, count]) => ({ reason, count })).sort((a, b) => b.count - a.count || a.reason.localeCompare(b.reason));
  if (ranked.length <= top) return ranked;
  const other = ranked.slice(top).reduce((sum, item) => sum + item.count, 0);
  return [...ranked.slice(0, top), { reason: 'Other reasons', count: other }];
}

export function formatDuration(ms: number | null): string {
  if (ms === null) return '—';
  const seconds = Math.round(ms / 1000);
  if (seconds < 60) return `${seconds} s`;
  const minutes = Math.round(seconds / 60);
  if (minutes < 60) return `${minutes} min`;
  const hours = Math.floor(minutes / 60);
  return `${hours} h ${String(minutes % 60).padStart(2, '0')} min`;
}

export function formatPercent(value: number | null, digits = 0): string {
  if (value === null) return '—';
  const percent = value * 100;
  // A non-zero share never rounds down to a misleading 0%.
  return percent > 0 && percent < 10 ** -digits ? `<${10 ** -digits}%` : `${percent.toFixed(digits)}%`;
}

export interface WeakTopic { term: string; papers: number; flagged: number; total: number }
export interface WeakTopics { topics: WeakTopic[]; summarized: number; completed: number }
/** Topics that met the weak rule in the most completed papers; each paper counts once per term. */
export function weakTopics(analyses: Analysis[], rule: WeakRule, top = 8): WeakTopics {
  const completed = analyses.filter((a) => a.status === 'done');
  const groups = new Map<string, WeakTopic>();
  let summarized = 0;
  for (const analysis of completed) {
    if (!analysis.topicSummary) continue;
    summarized++;
    const seen = new Set<string>();
    for (const topic of analysis.topicSummary) {
      const key = topic.term.toLowerCase();
      if (seen.has(key) || topic.total < rule.minRefs || topic.flagged / topic.total < rule.threshold) continue;
      seen.add(key);
      const group = groups.get(key) ?? { term: topic.term, papers: 0, flagged: 0, total: 0 };
      group.papers++; group.flagged += topic.flagged; group.total += topic.total;
      groups.set(key, group);
    }
  }
  const topics = [...groups.values()].sort((a, b) => b.papers - a.papers || b.flagged / b.total - a.flagged / a.total || a.term.localeCompare(b.term));
  return { topics: topics.slice(0, top), summarized, completed: completed.length };
}
