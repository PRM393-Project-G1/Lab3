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
