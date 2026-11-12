import { describe, expect, it } from 'vitest';
import { buildTopicTree, filterAnalyses, parseAnalysis, parseReference, parseTopic, safeExternalUrl, summarize } from '../src/domain/analysis';

describe('analysis contracts', () => {
  it('maps Firestore timestamps, clamps progress and does not treat unknown states as completed', () => {
    const date = new Date('2026-11-10T12:00:00Z');
    const analysis = parseAnalysis('1706.03762', { status: 'legacy', createdAt: { toDate: () => date },
      progress: { percent: 120 }, summary: { verified: 3, error: 1 } });
    expect(analysis).toMatchObject({ status: 'unknown', createdAt: date, progress: 100, totalRefs: 4, title: 'arXiv:1706.03762' });
    expect(parseAnalysis('id', { createdAt: new Date('invalid') }).createdAt).toBeNull();
  });

  it('search and filters combine while summary retains all states', () => {
    const all = [
      parseAnalysis('1706.03762', { paperTitle: 'Attention', status: 'done', createdAt: new Date(2026, 1, 1) }),
      parseAnalysis('1409.0473', { paperTitle: 'Attention paper', status: 'failed' }),
      parseAnalysis('queued', { status: 'queued' }), parseAnalysis('processing', { status: 'processing' }),
      parseAnalysis('cancelled', { status: 'cancelled' }), parseAnalysis('unknown', { status: 'odd' }),
    ];
    expect(summarize(all)).toEqual({ total: 6, done: 1, running: 2, failed: 1 });
    expect(filterAnalyses(all, ' ATTENTION ', 'failed').map((a) => a.id)).toEqual(['1409.0473']);
    expect(filterAnalyses(all, '1706', 'all')[0].id).toBe('1706.03762');
    expect(filterAnalyses(all, '', 'all')[0].id).toBe('1706.03762');
    expect(filterAnalyses(all, '', 'cancelled')).toHaveLength(1);
  });

  it('blocks unsafe source URLs and maps unknown reference statuses safely', () => {
    expect(safeExternalUrl('javascript:alert(1)')).toBeNull();
    expect(safeExternalUrl('data:text/html,hello')).toBeNull();
    expect(safeExternalUrl('https://arxiv.org/abs/1706.03762')).toContain('https://arxiv.org');
    expect(parseReference('ref', { status: 'unexpected' }).status).toBe('unverified');
    expect(parseReference('ref', { status: 'hallucination' }).status).toBe('hallucinated');
  });
});

describe('topic hierarchy follows the shared weak-topic rule', () => {
  const rule = { threshold: 0.5, minRefs: 3 };
  it('deduplicates references across descendants and excludes warnings from the numerator', () => {
    const topics = [parseTopic('root', { term: 'Root' }),
      parseTopic('a', { parentId: 'root', refIds: ['1', '2', '3'] }),
      parseTopic('b', { parentId: 'root', refIds: ['1', '4'] })];
    const refs = ['error', 'hallucinated', 'warning', 'verified'].map((status, i) => parseReference(String(i + 1), { status }));
    const [root] = buildTopicTree(topics, refs, rule);
    expect(root.total).toBe(4);
    expect(root.counts).toMatchObject({ error: 1, hallucinated: 1, warning: 1, verified: 1 });
    expect(root.isWeak).toBe(true);
    expect(root.children.find((t) => t.id === 'b')?.isWeak).toBe(false);
    expect(buildTopicTree(topics, refs, { threshold: 0.6, minRefs: 3 })[0].isWeak).toBe(false);
  });

  it('uses stored counts for legacy records without references and handles cyclic parents', () => {
    const nodes = buildTopicTree([
      parseTopic('a', { parentId: 'b', counts: { error: 3 } }),
      parseTopic('b', { parentId: 'a', counts: { verified: 4 } }),
    ], [], rule);
    expect(nodes).toHaveLength(2);
    expect(nodes.find((t) => t.id === 'a')?.isWeak).toBe(true);
  });
});
