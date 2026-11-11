import { describe, expect, it } from 'vitest';
import { filterAnalyses, parseAnalysis } from '../src/domain/analysis';
import { analysesCsv, csvCell, toCsv } from '../src/domain/csv';

describe('analysis scope filters', () => {
  const all = [
    parseAnalysis('1706.03762', { status: 'done', requestedBy: 'u1', aiAssisted: true }),
    parseAnalysis('1409.0473', { status: 'failed', requestedBy: 'u2', aiAssisted: false }),
    parseAnalysis('1512.03385', { status: 'done', requestedBy: 'u1' }),
  ];
  it('combines requester and check mode; legacy records without a flag match neither mode', () => {
    expect(filterAnalyses(all, '', 'all', { requester: 'u1' }).map((a) => a.id)).toEqual(['1512.03385', '1706.03762']);
    expect(filterAnalyses(all, '', 'all', { mode: 'ai' }).map((a) => a.id)).toEqual(['1706.03762']);
    expect(filterAnalyses(all, '', 'all', { mode: 'standard' }).map((a) => a.id)).toEqual(['1409.0473']);
    expect(filterAnalyses(all, '', 'done', { requester: 'u2' })).toEqual([]);
  });
});

describe('CSV export', () => {
  it('quotes separators and neutralizes formula-like cells', () => {
    expect(csvCell('a,b')).toBe('"a,b"');
    expect(csvCell('say "hi"\nnow')).toBe('"say ""hi""\nnow"');
    expect(csvCell('=HYPERLINK("x")')).toBe(`"'=HYPERLINK(""x"")"`);
    expect(csvCell('-1')).toBe("'-1");
    expect(csvCell(-1)).toBe('-1');
    expect(csvCell(null)).toBe('');
    expect(toCsv([['a', 1], ['b', true]])).toBe('a,1\r\nb,true');
  });

  it('writes one row per analysis with names, duration and counts only for completed runs', () => {
    const csv = analysesCsv([
      parseAnalysis('1706.03762', { paperTitle: 'Attention, again', paperAuthors: ['A', 'B'], status: 'done', requestedBy: 'u1', aiAssisted: true,
        createdAt: new Date('2026-11-10T10:00:00Z'), finishedAt: new Date('2026-11-10T10:12:30Z'), summary: { totalRefs: 3, verified: 2, hallucinated: 1 } }),
      parseAnalysis('1409.0473', { status: 'failed', error: 'Topic extraction took too long.' }),
    ], (uid) => uid === 'u1' ? 'Linh' : 'Unknown').split('\r\n');
    expect(csv).toHaveLength(3);
    expect(csv[0]).toBe('arXiv ID,Title,Authors,Status,Requested at (UTC),Finished at (UTC),Duration (min),Requested by,Requester UID,Check mode,Total references,Hallucinated,Error,Warning,Unverified,Verified,Failure reason');
    expect(csv[1]).toBe('1706.03762,"Attention, again",A; B,Completed,2026-11-10T10:00:00.000Z,2026-11-10T10:12:30.000Z,12.5,Linh,u1,AI-assisted,3,1,0,0,0,2,');
    expect(csv[2]).toBe('1409.0473,arXiv:1409.0473,,Failed,,,,,,,,,,,,,Topic extraction took too long.');
  });
});

describe('stalled jobs and action drafts', async () => {
  const { stalledFor, formatMinutes } = await import('../src/domain/analysis');
  const { normalizeAction, validateAction, availableActions } = await import('../src/domain/actions');
  const now = new Date(2026, 10, 11, 12, 0);
  const ago = (minutes: number) => new Date(now.getTime() - minutes * 60000);
  it('uses the last backend write, with a longer allowance for queued work', () => {
    expect(stalledFor(parseAnalysis('a', { status: 'processing', createdAt: ago(300), updatedAt: ago(10) }), now)).toBeNull();
    expect(stalledFor(parseAnalysis('a', { status: 'processing', createdAt: ago(300), updatedAt: ago(45) }), now)).toBe(45);
    expect(stalledFor(parseAnalysis('a', { status: 'queued', createdAt: ago(100) }), now)).toBeNull();
    expect(stalledFor(parseAnalysis('a', { status: 'queued', createdAt: ago(130) }), now)).toBe(130);
    expect(stalledFor(parseAnalysis('a', { status: 'done', createdAt: ago(900) }), now)).toBeNull();
    expect(formatMinutes(45)).toBe('45 min');
    expect(formatMinutes(185)).toBe('3 h 05 min');
    expect(formatMinutes(6960)).toBe('4 days 20 h');
  });
  it('validates drafts like the rules and offers only actions that fit the status', () => {
    expect(normalizeAction({ type: 'cancelAnalysis', target: '1706.03762', reason: '  ' })).toEqual({ type: 'cancelAnalysis', target: '1706.03762' });
    expect(validateAction({ type: 'cancelAnalysis', target: '../users' })).toMatch(/not valid/);
    expect(validateAction({ type: 'retryAnalysis', target: '1706.03762', reason: 'x'.repeat(201) })).toMatch(/200/);
    expect(availableActions(parseAnalysis('a', { status: 'queued' }))).toEqual(['cancelAnalysis']);
    expect(availableActions(parseAnalysis('a', { status: 'cancelled' }))).toEqual(['retryAnalysis', 'deleteAnalysis']);
    expect(availableActions(parseAnalysis('a', { status: 'done' }))).toEqual(['hideAnalysis', 'deleteAnalysis']);
    expect(availableActions(parseAnalysis('a', { status: 'done', hidden: true }))).toEqual(['unhideAnalysis', 'retryAnalysis', 'deleteAnalysis']);
  });
});
