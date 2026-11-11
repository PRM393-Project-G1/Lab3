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

describe('user directory helpers', async () => {
  const { parseUser, filterUsers, activityByUser } = await import('../src/domain/users');
  const { userActions, validateAction, normalizeAction } = await import('../src/domain/actions');
  const users = [parseUser('b', { displayName: 'Bao', role: 'user' }), parseUser('a', { displayName: 'An', role: 'admin', email: 'an@x.test' }),
    parseUser('c', { displayName: 'Chi', role: 'user', disabled: true })];
  it('lists admins first, filters by state and searches emails', () => {
    expect(filterUsers(users, '', 'all').map((u) => u.uid)).toEqual(['a', 'b', 'c']);
    expect(filterUsers(users, '', 'user').map((u) => u.uid)).toEqual(['b']);
    expect(filterUsers(users, '', 'disabled').map((u) => u.uid)).toEqual(['c']);
    expect(filterUsers(users, 'AN@X', 'all').map((u) => u.uid)).toEqual(['a']);
    expect(parseUser('x', { displayName: ' ' })).toMatchObject({ name: 'Unnamed user', role: 'user', disabled: false, email: null });
  });
  it('counts activity per requester', () => {
    const activity = activityByUser([parseAnalysis('1', { requestedBy: 'a', status: 'failed' }), parseAnalysis('2', { requestedBy: 'a', status: 'done' }), parseAnalysis('3', {})]);
    expect(activity.get('a')).toMatchObject({ total: 2, done: 1, failed: 1 });
    expect(activity.size).toBe(1);
  });
  it('offers only safe changes and refuses self changes', () => {
    expect(userActions(users[0], 'a').map((d) => [d.type, d.role ?? d.disabled])).toEqual([['setRole', 'admin'], ['setDisabled', true]]);
    expect(userActions(users[1], 'b')).toEqual([{ type: 'setRole', target: 'a', role: 'user' }]);
    expect(userActions(users[2], 'a')).toEqual([{ type: 'setDisabled', target: 'c', disabled: false }]);
    expect(userActions(users[1], 'a')).toEqual([]);
    expect(validateAction({ type: 'setRole', target: 'a', role: 'user' }, 'a')).toMatch(/your own/);
    expect(validateAction({ type: 'setDisabled', target: 'b' }, 'a')).toMatch(/disable or enable/);
    expect(normalizeAction({ type: 'setRole', target: 'b', role: 'admin', disabled: true, reason: ' ' })).toEqual({ type: 'setRole', target: 'b', role: 'admin' });
  });
});

describe('announcement drafts with a paper link', async () => {
  const { normalizeDraft, validateDraft, parseAnnouncement } = await import('../src/domain/notifications');
  it('keeps a valid link, drops an empty one and rejects anything else', () => {
    const base = { title: 'T', body: 'B', audience: 'all' as const, recipientUids: [] };
    expect(normalizeDraft({ ...base, analysisId: ' ' })).toEqual(base);
    expect(validateDraft({ ...base, analysisId: '1706.03762' })).toBeNull();
    expect(validateDraft({ ...base, analysisId: '../users' })).toMatch(/valid paper/);
    expect(parseAnnouncement('x', { ...base, analysisId: '1706.03762' }).analysisId).toBe('1706.03762');
  });
});

describe('scheduled announcement drafts', async () => {
  const { validateDraft, parseAnnouncement, isScheduled } = await import('../src/domain/notifications');
  const now = new Date(2026, 10, 12, 9, 0);
  const base = { title: 'T', body: 'B', audience: 'all' as const, recipientUids: [] };
  const at = (minutes: number) => new Date(now.getTime() + minutes * 60000);
  it('accepts 5 minutes to 30 days ahead, matching the rules with a margin', () => {
    expect(validateDraft({ ...base, sendAt: at(4) }, now)).toMatch(/at least 5 minutes/);
    expect(validateDraft({ ...base, sendAt: at(6) }, now)).toBeNull();
    expect(validateDraft({ ...base, sendAt: at(30 * 1440) }, now)).toMatch(/30 days/);
    expect(validateDraft({ ...base, sendAt: new Date('invalid') }, now)).toMatch(/delivery time/);
  });
  it('reads the schedule back and tells scheduled from due requests', () => {
    const request = parseAnnouncement('r', { ...base, status: 'queued', sendAt: at(60) });
    expect(isScheduled(request, now)).toBe(true);
    expect(isScheduled(request, at(61))).toBe(false);
    expect(parseAnnouncement('r', { ...base, status: 'cancelled' }).status).toBe('cancelled');
  });
});

describe('announcement read rates', async () => {
  const { parseAnnouncement, readRate } = await import('../src/domain/notifications');
  const base = { title: 'T', body: 'B', audience: 'all' as const, recipientUids: [], status: 'completed' };
  it('divides opened items by stored ones and waits for the first count', () => {
    expect(readRate(parseAnnouncement('r', { ...base, counts: { inboxStored: 4 }, readCount: 3 }))).toBe(0.75);
    expect(readRate(parseAnnouncement('r', { ...base, counts: { inboxStored: 4 } }))).toBeNull();
    expect(readRate(parseAnnouncement('r', { ...base, counts: { inboxStored: 0 }, readCount: 0 }))).toBeNull();
    expect(readRate(parseAnnouncement('r', { ...base, counts: { inboxStored: 2 }, readCount: 5 }))).toBe(1);
  });
});

describe('recipient segments', async () => {
  const { recipientSegments } = await import('../src/domain/segments');
  const { parseUser } = await import('../src/domain/users');
  const now = new Date(2026, 10, 12);
  const recipients = ['a', 'b', 'c', 'd'].map((uid) => ({ uid, name: uid, hasDevice: uid === 'a' }));
  const users = [parseUser('d', { lastSignInAt: new Date(2026, 8, 1) }), parseUser('c', { lastSignInAt: new Date(2026, 10, 10) })];
  const analyses = [
    parseAnalysis('1', { requestedBy: 'a', status: 'failed', createdAt: new Date(2026, 10, 1) }),
    parseAnalysis('2', { requestedBy: 'a', status: 'done', createdAt: new Date(2026, 10, 5) }),
    parseAnalysis('3', { requestedBy: 'b', status: 'failed', createdAt: new Date(2026, 10, 2) }),
    parseAnalysis('4', { requestedBy: 'c', status: 'queued', createdAt: new Date(2026, 10, 11) }),
    parseAnalysis('5', { requestedBy: 'admin', status: 'failed' }),
  ];
  it('groups regular users by their latest outcome, activity and device', () => {
    const groups = Object.fromEntries(recipientSegments(recipients, users, analyses, now).map((segment) => [segment.key, segment.uids]));
    expect(groups).toEqual({ 'last-failed': ['b'], running: ['c'], never: ['d'], inactive: ['d'], push: ['a'] });
  });
});

describe('audit log', async () => {
  const { auditLog, filterAudit } = await import('../src/domain/audit');
  const { parseAction } = await import('../src/domain/actions');
  const { parseAnnouncement } = await import('../src/domain/notifications');
  it('orders newest first and maps outcomes from both queues', () => {
    const log = auditLog([
      parseAction('a1', { type: 'hideAnalysis', target: '1706.03762', requestedBy: 'x', status: 'queued', createdAt: new Date(2026, 0, 2) }),
      parseAction('a2', { type: 'setDisabled', target: 'u', disabled: true, requestedBy: 'y', status: 'completed', createdAt: new Date(2026, 0, 1) }),
    ], [parseAnnouncement('n1', { title: 'Hello', body: 'B', audience: 'selected', recipientUids: ['u'], requestedBy: 'x', status: 'partial',
      error: 'Some push attempts need review.', sendAt: new Date(2026, 0, 5), createdAt: new Date(2026, 0, 3) })]);
    expect(log.map((entry) => [entry.id, entry.kind, entry.action, entry.outcome])).toEqual([
      ['n1', 'announcement', 'Schedule announcement', 'done'], ['a1', 'analysis', 'Hide results', 'pending'], ['a2', 'user', 'Disable account', 'done']]);
    expect(log[0].detail).toBe('1 selected users · Some push attempts need review.');
    expect(filterAudit(log, 'all', 'y').map((entry) => entry.id)).toEqual(['a2']);
    expect(filterAudit(log, 'analysis', '').map((entry) => entry.id)).toEqual(['a1']);
  });
});
