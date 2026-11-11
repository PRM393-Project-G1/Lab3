import { act, cleanup, render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter, Route, Routes } from 'react-router-dom';
import { describe, expect, it, vi } from 'vitest';
import { AccessGate, App } from '../src/App';
import { parseAnalysis, type AnalysisFeed } from '../src/domain/analysis';
import type { AdminGateway, AdminUser } from '../src/services/gateway';
import type { AnnouncementDraft, AnnouncementRequest, NotificationRecipient } from '../src/domain/notifications';
import { normalizeDraft, parseAnnouncement } from '../src/domain/notifications';
import { parseWorker, type WorkerStatus } from '../src/domain/workers';
import { parseAction, type AdminActionRecord } from '../src/domain/actions';

class FakeGateway implements AdminGateway {
  recipients: NotificationRecipient[] = [
    { uid: 'user-a', name: 'User A', hasDevice: true },
    { uid: 'user-b', name: 'User B', hasDevice: false },
  ];
  announcements: AnnouncementRequest[] = [];
  announcementNext?: (requests: AnnouncementRequest[]) => void;
  watchRecipients = vi.fn<AdminGateway['watchRecipients']>((next) => { queueMicrotask(() => next(this.recipients)); return () => {}; });
  watchAnnouncements = vi.fn<AdminGateway['watchAnnouncements']>((next) => { this.announcementNext = next; queueMicrotask(() => next(this.announcements)); return () => {}; });
  queueAnnouncement = vi.fn<AdminGateway['queueAnnouncement']>(async (id, draft) => {
    this.announcements = [parseAnnouncement(id, { ...draft, status: 'queued', requestedBy: 'admin', createdAt: new Date() }), ...this.announcements];
    this.announcementNext?.(this.announcements);
  });
  user: AdminUser | null = { uid: 'admin', name: 'Test admin', email: 'admin@example.test' };
  role: 'admin' | 'user' = 'admin';
  pendingRole = false;
  feed: AnalysisFeed = { fromCache: false, analyses: [
    parseAnalysis('1706.03762', { paperTitle: 'Attention Is All You Need', status: 'done', summary: { totalRefs: 41 }, requestedBy: 'user-a', aiAssisted: true }),
    parseAnalysis('1409.0473', { paperTitle: 'Translation paper', status: 'failed', requestedBy: 'user-b', aiAssisted: false }),
    parseAnalysis('1512.03385', { paperTitle: 'Queued paper', status: 'queued' }),
  ] };
  authNext?: (user: AdminUser | null) => void;
  roleNext = new Map<string, (role: 'admin' | 'user') => void>();
  roleError?: (error: unknown) => void;
  feedNext?: (feed: AnalysisFeed) => void;
  feedError?: (error: unknown) => void;
  stopFeed = vi.fn();
  watchAuth: AdminGateway['watchAuth'] = (next) => { this.authNext = next; queueMicrotask(() => next(this.user)); return () => {}; };
  watchRole: AdminGateway['watchRole'] = (uid, next, error) => {
    this.roleNext.set(uid, next); this.roleError = error;
    if (!this.pendingRole) queueMicrotask(() => next(this.role));
    return () => {};
  };
  signIn = vi.fn(async () => {});
  signOut = vi.fn(async () => { this.authNext?.(null); });
  watchAnalyses = vi.fn<AdminGateway['watchAnalyses']>((next, error) => {
    this.feedNext = next; this.feedError = error; queueMicrotask(() => next(this.feed)); return this.stopFeed;
  });
  workers: WorkerStatus[] = [parseWorker('backend', { state: 'running', lastSeen: new Date() }), parseWorker('notifications', { state: 'running', lastSeen: new Date() })];
  actions: AdminActionRecord[] = [];
  actionNext?: (actions: AdminActionRecord[]) => void;
  watchActions = vi.fn<AdminGateway['watchActions']>((next) => { this.actionNext = next; queueMicrotask(() => next(this.actions)); return () => {}; });
  requestAction = vi.fn<AdminGateway['requestAction']>(async (id, draft) => {
    this.actions = [parseAction(id, { ...draft, requestedBy: 'admin', status: 'queued', createdAt: new Date() }), ...this.actions];
    this.actionNext?.(this.actions);
  });
  settle(fields: Partial<AdminActionRecord>) { this.actions = [{ ...this.actions[0], ...fields }, ...this.actions.slice(1)]; this.actionNext?.(this.actions); }
  watchWorkers = vi.fn<AdminGateway['watchWorkers']>((next) => { queueMicrotask(() => next(this.workers)); return () => {}; });
  getWeakRule = vi.fn<AdminGateway['getWeakRule']>(async () => ({ threshold: 0.5, minRefs: 3 }));
  getResults = vi.fn<AdminGateway['getResults']>(async (id) => ({
    analysis: this.feed.analyses.find((a) => a.id === id)!, references: [], topics: [], weakRule: { threshold: 0.5, minRefs: 3 },
  }));
}

function open(gateway: FakeGateway, path = '/') {
  return render(<MemoryRouter initialEntries={[path]}><Routes><Route path="/*" element={<AccessGate gateway={gateway} />} /></Routes></MemoryRouter>);
}
function cleanupAndOpen(gateway: FakeGateway, path: string) {
  cleanup();
  return open(gateway, path);
}

describe('admin access boundary', () => {
  it('shows an actionable configuration error when Google sign-in rejects the API key', async () => {
    const gateway = new FakeGateway();
    gateway.user = null;
    gateway.signIn.mockRejectedValue({ code: 'auth/invalid-api-key', message: 'API key not valid: private-test-value' });
    open(gateway);
    await userEvent.click(await screen.findByRole('button', { name: 'Continue with Google' }));
    const alert = await screen.findByRole('alert');
    expect(alert).toHaveTextContent('The Firebase Web API key is invalid.');
    expect(alert).toHaveTextContent('restart the dev server');
    expect(alert).not.toHaveTextContent('private-test-value');
    expect(screen.getByRole('button', { name: 'Continue with Google' })).toBeEnabled();
    expect(gateway.watchAnalyses).not.toHaveBeenCalled();
  });

  it('waits for role before subscribing and denies ordinary users', async () => {
    const gateway = new FakeGateway(); gateway.pendingRole = true;
    open(gateway);
    await screen.findByText('Checking workspace access');
    expect(gateway.watchAnalyses).not.toHaveBeenCalled();
    act(() => gateway.roleNext.get('admin')?.('user'));
    await screen.findByText('Admin access required.');
    expect(gateway.watchAnalyses).not.toHaveBeenCalled();
  });

  it('removes the dashboard and cancels the feed when admin role is revoked', async () => {
    const gateway = new FakeGateway(); open(gateway);
    await screen.findByRole('heading', { name: 'Analysis overview.' });
    act(() => gateway.roleNext.get('admin')?.('user'));
    await screen.findByText('Admin access required.');
    expect(gateway.stopFeed).toHaveBeenCalledTimes(1);
    expect(screen.queryByText('Attention Is All You Need')).not.toBeInTheDocument();
  });

  it('ignores stale role callbacks after switching accounts', async () => {
    const gateway = new FakeGateway(); open(gateway);
    await screen.findByText('Attention Is All You Need');
    gateway.pendingRole = true;
    act(() => gateway.authNext?.({ uid: 'other', name: 'Other', email: 'other@example.test' }));
    act(() => gateway.roleNext.get('admin')?.('admin'));
    expect(screen.queryByText('Attention Is All You Need')).not.toBeInTheDocument();
    act(() => gateway.roleNext.get('other')?.('user'));
    await screen.findByText('Admin access required.');
  });

  it('role errors block data and expose retry instead of falling back to user privileges', async () => {
    const gateway = new FakeGateway(); gateway.pendingRole = true; open(gateway);
    await screen.findByText('Checking workspace access');
    act(() => gateway.roleError?.({ code: 'unavailable' }));
    await screen.findByText('Couldn’t verify access');
    expect(gateway.watchAnalyses).not.toHaveBeenCalled();
    gateway.pendingRole = false;
    await userEvent.click(screen.getByText('Try again'));
    await screen.findByText('Attention Is All You Need');
  });
});

describe('admin announcements', () => {
  async function compose(gateway: FakeGateway) {
    open(gateway, '/notifications');
    await screen.findByText('User A');
    await userEvent.type(screen.getByRole('textbox', { name: /^Title/ }), 'Maintenance notice');
    await userEvent.type(screen.getByRole('textbox', { name: /^Message/ }), 'A short update for users.');
  }

  it('selected recipients require an explicit confirmation before creating a request', async () => {
    const gateway = new FakeGateway(); await compose(gateway);
    await userEvent.click(screen.getByRole('checkbox', { name: /User A/ }));
    await userEvent.click(screen.getByRole('button', { name: 'Review message' }));
    const dialog = screen.getByRole('dialog', { name: 'Confirm announcement' });
    expect(within(dialog).getByText('Send to 1 selected user?')).toBeInTheDocument();
    expect(gateway.queueAnnouncement).not.toHaveBeenCalled();
    await userEvent.click(within(dialog).getByRole('button', { name: 'Confirm send' }));
    expect(gateway.queueAnnouncement).toHaveBeenCalledWith(expect.any(String), {
      title: 'Maintenance notice', body: 'A short update for users.', audience: 'selected', recipientUids: ['user-a'],
    });
    await screen.findByText('Waiting for the backend worker.');
  });

  it('all users uses an empty UID list so the backend resolves the current audience', async () => {
    const gateway = new FakeGateway(); await compose(gateway);
    await userEvent.click(screen.getByRole('radio', { name: /All users/ }));
    await userEvent.click(screen.getByRole('button', { name: 'Review message' }));
    expect(screen.getByText('Send to all users (2 currently listed)?')).toBeInTheDocument();
    await userEvent.click(screen.getByRole('button', { name: 'Confirm send' }));
    expect(gateway.queueAnnouncement.mock.calls[0][1]).toMatchObject({ audience: 'all', recipientUids: [] });
  });

  it('cancel never queues a message and an empty selection is rejected', async () => {
    const gateway = new FakeGateway(); await compose(gateway);
    await userEvent.click(screen.getByRole('button', { name: 'Review message' }));
    expect(screen.getByRole('alert')).toHaveTextContent('Select at least one user.');
    await userEvent.click(screen.getByRole('checkbox', { name: /User A/ }));
    await userEvent.click(screen.getByRole('button', { name: 'Review message' }));
    await userEvent.click(screen.getByRole('button', { name: 'Cancel' }));
    expect(gateway.queueAnnouncement).not.toHaveBeenCalled();
  });

  it('retry uses the same request ID after a lost acknowledgement', async () => {
    const gateway = new FakeGateway(); await compose(gateway);
    gateway.queueAnnouncement.mockRejectedValueOnce({ code: 'unavailable' });
    await userEvent.click(screen.getByRole('radio', { name: /All users/ }));
    await userEvent.click(screen.getByRole('button', { name: 'Review message' }));
    await userEvent.click(screen.getByRole('button', { name: 'Confirm send' }));
    await screen.findByRole('alert');
    await userEvent.click(screen.getByRole('button', { name: 'Confirm send' }));
    expect(gateway.queueAnnouncement.mock.calls[0][0]).toBe(gateway.queueAnnouncement.mock.calls[1][0]);
  });

  it('ordinary users cannot load recipients or announcement history', async () => {
    const gateway = new FakeGateway(); gateway.role = 'user'; open(gateway, '/notifications');
    await screen.findByText('Admin access required.');
    expect(gateway.watchRecipients).not.toHaveBeenCalled();
    expect(gateway.watchAnnouncements).not.toHaveBeenCalled();
    expect(gateway.queueAnnouncement).not.toHaveBeenCalled();
  });
});

describe('dashboard interactions', () => {
  it('search and status filters combine, and clearing retains global metrics', async () => {
    const gateway = new FakeGateway(); open(gateway);
    await screen.findByText('Attention Is All You Need');
    await userEvent.click(screen.getByRole('button', { name: 'Failed 1' }));
    expect(screen.getByText('Translation paper')).toBeInTheDocument();
    expect(screen.queryByText('Attention Is All You Need')).not.toBeInTheDocument();
    expect(screen.getByLabelText('Total analyses: 3')).toBeInTheDocument();
    await userEvent.type(screen.getByRole('textbox', { name: 'Search title or arXiv ID' }), '1706');
    expect(screen.getByText('No matching analyses')).toBeInTheDocument();
    await userEvent.click(screen.getByRole('button', { name: 'Clear filters' }));
    expect(screen.getByText('Attention Is All You Need')).toBeInTheDocument();
  });

  it('updates global counts from live snapshots; errors clear rows and retry recovers', async () => {
    const gateway = new FakeGateway(); open(gateway);
    await screen.findByText('Attention Is All You Need');
    act(() => gateway.feedNext?.({ analyses: [parseAnalysis('1706.03762', { status: 'done' })], fromCache: true }));
    expect(screen.getByLabelText('Total analyses: 1')).toBeInTheDocument();
    expect(screen.getByText(/Showing cached data/)).toBeInTheDocument();
    act(() => gateway.feedError?.({ code: 'permission-denied' }));
    expect(screen.getByText('Couldn’t load analyses')).toBeInTheDocument();
    expect(screen.queryByRole('table')).not.toBeInTheDocument();
    gateway.feed = { analyses: [], fromCache: false };
    await userEvent.click(screen.getByText('Try again'));
    await screen.findByText('Your workspace is ready');
    expect(screen.getByLabelText('Total analyses: 0')).toBeInTheDocument();
  });

  it('filters by requester and check mode, and exports exactly the filtered rows', async () => {
    const gateway = new FakeGateway(); open(gateway);
    await screen.findByText('Attention Is All You Need');
    expect(screen.getByText('by User A')).toBeInTheDocument();
    await userEvent.selectOptions(screen.getByRole('combobox', { name: 'Requested by' }), 'User A (1)');
    expect(screen.queryByText('Translation paper')).not.toBeInTheDocument();
    await userEvent.selectOptions(screen.getByRole('combobox', { name: 'Check mode' }), 'Standard');
    expect(screen.getByText('No matching analyses')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /Export CSV/ })).toBeDisabled();
    await userEvent.selectOptions(screen.getByRole('combobox', { name: 'Check mode' }), 'AI-assisted');
    const blobs: Blob[] = [];
    URL.createObjectURL = vi.fn((blob: Blob) => { blobs.push(blob); return 'blob:test'; });
    URL.revokeObjectURL = vi.fn();
    const click = vi.spyOn(HTMLAnchorElement.prototype, 'click').mockImplementation(() => {});
    await userEvent.click(screen.getByRole('button', { name: 'Export CSV (1 analysis)' }));
    expect(click).toHaveBeenCalledTimes(1);
    const csv = await new Promise<string>((resolve) => { const reader = new FileReader(); reader.onload = () => resolve(String(reader.result)); reader.readAsText(blobs[0]); });
    expect(csv).toContain('Attention Is All You Need');
    expect(csv).toContain('User A');
    expect(csv).not.toContain('Translation paper');
    click.mockRestore();
  });

  it('opens analysis results and returns to the overview', async () => {
    const gateway = new FakeGateway(); open(gateway);
    await userEvent.click(await screen.findByText('Attention Is All You Need'));
    await screen.findByRole('heading', { name: 'Attention Is All You Need' });
    expect(gateway.getResults).toHaveBeenCalledWith('1706.03762');
    await userEvent.click(screen.getByText('Back to analyses'));
    await screen.findByText('Paper analyses');
  });

  it('signs out and clears all protected content', async () => {
    const gateway = new FakeGateway(); open(gateway);
    await screen.findByText('Attention Is All You Need');
    await userEvent.click(screen.getByRole('button', { name: 'Sign out' }));
    await screen.findByRole('button', { name: 'Continue with Google' });
    expect(screen.queryByText('Attention Is All You Need')).not.toBeInTheDocument();
  });

  it('paginates the visible subset and resets page after searching', async () => {
    const gateway = new FakeGateway();
    gateway.feed.analyses = Array.from({ length: 10 }, (_, i) => parseAnalysis(`1706.${String(i).padStart(5, '0')}`, { paperTitle: `Paper ${i}`, status: 'done' }));
    open(gateway);
    await screen.findByText('Paper 0');
    await userEvent.click(screen.getByRole('button', { name: 'Next page' }));
    expect(within(screen.getByRole('table')).getAllByRole('row')).toHaveLength(3);
    await userEvent.type(screen.getByRole('textbox'), 'Paper 0');
    expect(screen.getByText('Page 1 of 1')).toBeInTheDocument();
    expect(screen.getByText('Paper 0')).toBeInTheDocument();
  });

  it('needs no Firebase config to enter the isolated, clearly labeled demo', async () => {
    render(<MemoryRouter><App /></MemoryRouter>);
    await userEvent.click(screen.getByRole('link', { name: /Explore demo workspace/ }));
    await screen.findByText('Sample data');
    await screen.findByText('Attention Is All You Need');
    expect(screen.getByLabelText('Total analyses: 12')).toBeInTheDocument();
    await userEvent.click(screen.getByRole('link', { name: 'Exit demo' }));
    await screen.findByText('Connect your Firebase Web app');
    await waitFor(() => expect(screen.queryByText('Attention Is All You Need')).not.toBeInTheDocument());
  });
});

describe('background service status', () => {
  const minutesAgo = (minutes: number) => new Date(Date.now() - minutes * 60000);

  it('shows both services online in the header without any warning', async () => {
    const gateway = new FakeGateway(); open(gateway);
    await screen.findByText('Attention Is All You Need');
    expect(await screen.findByLabelText(/^Backend online\./)).toBeInTheDocument();
    expect(screen.getByLabelText(/^Notification worker online\./)).toBeInTheDocument();
    expect(screen.queryByText(/will not progress/)).not.toBeInTheDocument();
  });

  it('warns on the overview when the backend is silent while analyses are queued', async () => {
    const gateway = new FakeGateway();
    gateway.workers = [parseWorker('backend', { state: 'running', lastSeen: minutesAgo(12) })];
    open(gateway);
    expect(await screen.findByText(/Backend is offline \(last heartbeat 12 min ago\)\. 1 queued or processing analysis will not progress/)).toBeInTheDocument();
    expect(screen.getByLabelText(/^Notification worker not seen yet\./)).toBeInTheDocument();
  });

  it('explains on the notifications page that requests wait for a stopped worker', async () => {
    const gateway = new FakeGateway();
    gateway.workers = [parseWorker('notifications', { state: 'stopped', lastSeen: minutesAgo(1) })];
    open(gateway, '/notifications');
    expect(await screen.findByText(/Notification worker is stopped .* New messages stay queued/)).toBeInTheDocument();
  });
});

describe('admin actions on analyses', () => {
  it('queues a retry for a failed paper after confirmation and reloads when it settles', async () => {
    const gateway = new FakeGateway(); open(gateway, '/analyses/1409.0473');
    await userEvent.click(await screen.findByRole('button', { name: 'Run again' }));
    expect(gateway.requestAction).not.toHaveBeenCalled();
    await userEvent.type(screen.getByRole('textbox', { name: /Reason for the log/ }), 'Saffron is back');
    await userEvent.click(screen.getByRole('button', { name: 'Run again' }));
    expect(gateway.requestAction).toHaveBeenCalledWith(expect.any(String), { type: 'retryAnalysis', target: '1409.0473', reason: 'Saffron is back' });
    expect(await screen.findByText(/Waiting for backend/)).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Run again' })).toBeDisabled();
    const loads = gateway.getResults.mock.calls.length;
    act(() => gateway.settle({ status: 'completed', result: 'Analysis queued again with its original settings.' }));
    await waitFor(() => expect(gateway.getResults.mock.calls.length).toBe(loads + 1));
    expect(await screen.findByText(/Completed .* Analysis queued again/)).toBeInTheDocument();
  });

  it('offers stop for running papers, nothing for completed ones, and shows refusals', async () => {
    const gateway = new FakeGateway(); open(gateway, '/analyses/1512.03385');
    await userEvent.click(await screen.findByRole('button', { name: 'Stop analysis' }));
    await userEvent.click(screen.getByRole('button', { name: 'Stop analysis' }));
    expect(gateway.requestAction.mock.calls[0][1]).toEqual({ type: 'cancelAnalysis', target: '1512.03385', reason: '' });
    act(() => gateway.settle({ status: 'failed', error: 'Only queued or processing analyses can be stopped; this one is done.' }));
    expect(await screen.findByText(/Failed .* this one is done/)).toBeInTheDocument();
    cleanupAndOpen(gateway, '/analyses/1706.03762');
    await screen.findByRole('heading', { name: 'Attention Is All You Need' });
    expect(screen.queryByRole('heading', { name: 'Admin actions' })).not.toBeInTheDocument();
  });

  it('flags stalled jobs on the overview and filters to them', async () => {
    const gateway = new FakeGateway();
    gateway.feed.analyses.push(parseAnalysis('2101.00001', { paperTitle: 'Silent paper', status: 'processing',
      createdAt: new Date(Date.now() - 3 * 3600000), updatedAt: new Date(Date.now() - 125 * 60000) }));
    open(gateway);
    expect(await screen.findByText('No progress · 2 h 05 min')).toBeInTheDocument();
    await userEvent.click(screen.getByRole('button', { name: 'Show stalled' }));
    expect(screen.getByRole('button', { name: 'Stalled 1' })).toHaveAttribute('aria-pressed', 'true');
    expect(screen.getByText('Silent paper')).toBeInTheDocument();
    expect(screen.queryByText('Queued paper')).not.toBeInTheDocument();
  });
});
