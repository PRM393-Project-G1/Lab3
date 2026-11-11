export const analysisStatuses = ['queued', 'processing', 'done', 'failed', 'cancelled', 'unknown'] as const;
export type AnalysisStatus = typeof analysisStatuses[number];
export type AnalysisFilter = 'all' | 'done' | 'running' | 'stalled' | 'failed' | 'cancelled' | 'unknown';
export const referenceStatuses = ['hallucinated', 'error', 'warning', 'unverified', 'verified'] as const;
export type ReferenceStatus = typeof referenceStatuses[number];
export type Counts = Record<ReferenceStatus, number>;
export type RawDocument = Record<string, unknown>;

export interface Analysis {
  id: string;
  title: string;
  authors: string[];
  status: AnalysisStatus;
  createdAt: Date | null;
  finishedAt: Date | null;
  /** Last backend write; tells a slow job from a stalled one. */
  updatedAt: Date | null;
  totalRefs: number;
  counts: Counts;
  progress: number;
  stage: string;
  error: string | null;
  /** UID of the user whose request started the latest run. */
  requestedBy: string | null;
  /** Null for legacy records written before the flag existed. */
  aiAssisted: boolean | null;
  /** Per-topic subtree counts written by the backend; null before it was computed. */
  topicSummary: TopicStat[] | null;
}
export type CheckMode = 'all' | 'ai' | 'standard';
export interface AnalysisScope { requester?: string; mode?: CheckMode }

export interface Reference {
  id: string;
  index: number;
  title: string;
  authors: string[];
  year: number | null;
  status: ReferenceStatus;
  url: string | null;
  topicIds: string[];
  issues: { type: string; message: string; cited: string | null; actual: string | null }[];
  hallucination: string | null;
}

export interface Topic {
  id: string;
  term: string;
  parentId: string | null;
  refIds: string[];
  counts: Counts;
}

export interface TopicStat { term: string; depth: number; total: number; flagged: number }
export interface WeakRule { threshold: number; minRefs: number }
export interface TopicNode extends Topic { children: TopicNode[]; total: number; isWeak: boolean }
export interface AnalysisResults {
  analysis: Analysis;
  references: Reference[];
  topics: Topic[];
  weakRule: WeakRule;
}
export interface AnalysisFeed { analyses: Analysis[]; fromCache: boolean }

function object(value: unknown): RawDocument {
  return value && typeof value === 'object' && !Array.isArray(value) ? value as RawDocument : {};
}
function string(value: unknown, fallback = ''): string { return typeof value === 'string' ? value : fallback; }
function strings(value: unknown): string[] {
  return Array.isArray(value) ? value.filter((item): item is string => typeof item === 'string') : [];
}
function number(value: unknown): number {
  return typeof value === 'number' && Number.isFinite(value) ? Math.max(0, value) : 0;
}
export function date(value: unknown): Date | null {
  if (value && typeof value === 'object' && 'toDate' in value && typeof value.toDate === 'function') {
    return date(value.toDate());
  }
  if (value instanceof Date) return Number.isNaN(value.getTime()) ? null : value;
  return null;
}
export function counts(value: unknown): Counts {
  const data = object(value);
  return Object.fromEntries(referenceStatuses.map((key) => [key, number(data[key])])) as Counts;
}
export function totalCounts(value: Counts): number { return referenceStatuses.reduce((sum, key) => sum + value[key], 0); }

export function parseAnalysis(id: string, data: RawDocument): Analysis {
  const summary = object(data.summary);
  const tally = counts(summary);
  const progress = object(data.progress);
  return {
    id, title: string(data.paperTitle).trim() || `arXiv:${id}`,
    authors: strings(data.paperAuthors),
    status: analysisStatuses.includes(data.status as AnalysisStatus) ? data.status as AnalysisStatus : 'unknown',
    createdAt: date(data.createdAt), finishedAt: date(data.finishedAt), updatedAt: date(data.updatedAt),
    totalRefs: typeof summary.totalRefs === 'number' ? number(summary.totalRefs) : totalCounts(tally),
    counts: tally, progress: Math.min(100, number(progress.percent)),
    stage: string(progress.stage, 'references'), error: typeof data.error === 'string' ? data.error : null,
    requestedBy: string(data.requestedBy) || null, aiAssisted: typeof data.aiAssisted === 'boolean' ? data.aiAssisted : null,
    topicSummary: Array.isArray(data.topicSummary) ? data.topicSummary.flatMap((raw) => {
      const row = object(raw);
      const term = string(row.term).trim();
      const total = number(row.total);
      return term && total ? [{ term, depth: number(row.depth), total, flagged: Math.min(total, number(row.flagged)) }] : [];
    }) : null,
  };
}

export function parseReference(id: string, data: RawDocument): Reference {
  const state = data.status === 'hallucination' ? 'hallucinated' : data.status;
  return {
    id, index: number(data.index), title: string(data.title, 'Untitled reference'),
    authors: strings(data.authors), year: typeof data.year === 'number' ? data.year : null,
    status: referenceStatuses.includes(state as ReferenceStatus) ? state as ReferenceStatus : 'unverified',
    url: safeExternalUrl(data.url), topicIds: strings(data.topicIds),
    hallucination: string(object(data.hallucination).explanation) || null,
    issues: (Array.isArray(data.issues) ? data.issues : []).map((raw) => {
      const issue = object(raw);
      return { type: string(issue.type, 'other'), message: string(issue.message),
        cited: issue.cited == null ? null : String(issue.cited),
        actual: issue.actual == null ? null : String(issue.actual) };
    }),
  };
}

export function parseTopic(id: string, data: RawDocument): Topic {
  return { id, term: string(data.term, id), parentId: string(data.parentId) || null,
    refIds: strings(data.refIds), counts: counts(data.counts) };
}

export function safeExternalUrl(value: unknown): string | null {
  if (typeof value !== 'string') return null;
  try { const url = new URL(value); return ['http:', 'https:'].includes(url.protocol) ? url.href : null; }
  catch { return null; }
}

export const statusLabel: Record<AnalysisStatus, string> = {
  queued: 'Queued', processing: 'Processing', done: 'Completed', failed: 'Failed', cancelled: 'Cancelled', unknown: 'Unknown',
};
export function isRunning(analysis: Analysis): boolean { return ['queued', 'processing'].includes(analysis.status); }
export function summarize(analyses: Analysis[]) {
  return { total: analyses.length, done: analyses.filter((a) => a.status === 'done').length,
    running: analyses.filter(isRunning).length, failed: analyses.filter((a) => a.status === 'failed').length };
}
export function filterAnalyses(analyses: Analysis[], query: string, filter: AnalysisFilter, scope: AnalysisScope = {}, now = new Date()): Analysis[] {
  const text = query.trim().toLowerCase();
  return analyses.filter((a) =>
    (filter === 'all' || (filter === 'running' ? isRunning(a) : filter === 'stalled' ? stalledFor(a, now) !== null : a.status === filter)) &&
    (!scope.requester || a.requestedBy === scope.requester) &&
    (!scope.mode || scope.mode === 'all' || a.aiAssisted === (scope.mode === 'ai')) &&
    (!text || a.title.toLowerCase().includes(text) || a.id.toLowerCase().includes(text)),
  ).sort((a, b) => (b.createdAt?.getTime() ?? 0) - (a.createdAt?.getTime() ?? 0) || a.id.localeCompare(b.id));
}

/** Parent totals include descendants, deduplicating references as in the mobile app. */
export function buildTopicTree(topics: Topic[], references: Reference[], rule: WeakRule): TopicNode[] {
  const nodes = new Map(topics.map((t) => [t.id, { ...t, children: [], total: 0, isWeak: false } as TopicNode]));
  const roots: TopicNode[] = [];
  for (const node of nodes.values()) {
    // Broken legacy cycles become roots instead of breaking the detail screen.
    const ancestors = new Set([node.id]);
    let parent = nodes.get(node.parentId ?? '');
    let cyclic = false;
    while (parent) {
      if (ancestors.has(parent.id)) { cyclic = true; break; }
      ancestors.add(parent.id);
      parent = nodes.get(parent.parentId ?? '');
    }
    const owner = cyclic ? undefined : nodes.get(node.parentId ?? '');
    if (owner) owner.children.push(node); else roots.push(node);
  }
  const statuses = new Map(references.map((r) => [r.id, r.status]));
  function aggregate(node: TopicNode): Set<string> {
    const ids = new Set(node.refIds);
    node.children.forEach((child) => aggregate(child).forEach((id) => ids.add(id)));
    if (references.length) {
      node.counts = counts({});
      ids.forEach((id) => { const state = statuses.get(id); if (state) node.counts[state]++; });
    }
    node.total = totalCounts(node.counts);
    node.isWeak = node.total >= rule.minRefs && node.total > 0 &&
      (node.counts.error + node.counts.hallucinated) / node.total >= rule.threshold;
    node.children.sort(byIssues);
    return ids;
  }
  function byIssues(a: TopicNode, b: TopicNode): number {
    return (b.counts.error + b.counts.hallucinated) - (a.counts.error + a.counts.hallucinated) || b.total - a.total;
  }
  roots.forEach(aggregate);
  return roots.sort(byIssues);
}

// Saffron alone may run for up to 30 minutes without a progress write.
export const stallMinutes = { processing: 40, queued: 120 } as const;
/** Minutes since the last progress write, when a running job has been silent for too long. */
export function stalledFor(analysis: Analysis, now: Date): number | null {
  if (analysis.status !== 'processing' && analysis.status !== 'queued') return null;
  const since = analysis.updatedAt ?? analysis.createdAt;
  if (!since) return null;
  const minutes = Math.floor((now.getTime() - since.getTime()) / 60000);
  return minutes >= stallMinutes[analysis.status] ? minutes : null;
}

export function formatMinutes(minutes: number): string {
  if (minutes < 120) return `${minutes} min`;
  if (minutes < 2880) return `${Math.floor(minutes / 60)} h ${String(minutes % 60).padStart(2, '0')} min`;
  return `${Math.floor(minutes / 1440)} days ${Math.floor((minutes % 1440) / 60)} h`;
}
