import { date, type RawDocument } from './analysis';

export type WorkerName = 'backend' | 'notifications';
export interface WorkerStatus {
  name: string; state: 'running' | 'stopped' | 'unknown'; lastSeen: Date | null; startedAt: Date | null;
  version: string | null; runningJobs: number | null; intervalSeconds: number;
}
export type Liveness = 'online' | 'offline' | 'stopped' | 'never';

export const workerLabels: Record<WorkerName, string> = { backend: 'Backend', notifications: 'Notification worker' };

export function parseWorker(name: string, raw: RawDocument): WorkerStatus {
  const interval = typeof raw.intervalSeconds === 'number' && raw.intervalSeconds > 0 ? raw.intervalSeconds : 60;
  return { name, state: raw.state === 'running' || raw.state === 'stopped' ? raw.state : 'unknown',
    lastSeen: date(raw.lastSeen), startedAt: date(raw.startedAt), version: typeof raw.version === 'string' ? raw.version : null,
    runningJobs: typeof raw.runningJobs === 'number' ? raw.runningJobs : null, intervalSeconds: interval };
}

/** Three missed beats, at least three minutes, before a running process counts as offline. */
export function liveness(worker: WorkerStatus | undefined, now: Date): Liveness {
  if (!worker || !worker.lastSeen) return 'never';
  if (worker.state === 'stopped') return 'stopped';
  const allowed = Math.max(180, worker.intervalSeconds * 3) * 1000;
  return now.getTime() - worker.lastSeen.getTime() <= allowed ? 'online' : 'offline';
}

export function timeAgo(then: Date | null, now: Date): string {
  if (!then) return 'never';
  const minutes = Math.max(0, Math.round((now.getTime() - then.getTime()) / 60000));
  if (minutes < 1) return 'just now';
  if (minutes < 60) return `${minutes} min ago`;
  const hours = Math.round(minutes / 60);
  return hours < 48 ? `${hours} h ago` : `${Math.round(hours / 24)} days ago`;
}
