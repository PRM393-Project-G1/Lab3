import { Bell, Server } from 'lucide-react';
import { timeAgo, workerLabels, type Liveness, type WorkerName } from '../domain/workers';
import type { SystemStatus } from '../hooks/useWorkers';

const words: Record<Liveness, string> = { online: 'online', offline: 'offline', stopped: 'stopped', never: 'not seen yet' };
const shortLabels: Record<WorkerName, string> = { backend: 'Backend', notifications: 'Notifications' };
const icons = { backend: Server, notifications: Bell };

/** Header pills: an icon and a label carry identity, the dot carries state, and the name says it in words. */
export function SystemIndicator({ system }: { system: SystemStatus }) {
  if (!system.loaded || system.failed) return null;
  return <div className="system-status" role="group" aria-label="Background services">{(['backend', 'notifications'] as const).map((name) => {
    const { liveness, worker } = system.of(name);
    const Icon = icons[name];
    const summary = `${workerLabels[name]} ${words[liveness]}. Last heartbeat ${timeAgo(worker?.lastSeen ?? null, system.now)}.`;
    return <span key={name} className={`system-pill ${liveness}`} title={summary} aria-label={summary}>
      <Icon size={13} aria-hidden="true" /><span className="system-label" aria-hidden="true">{shortLabels[name]}</span><span className="system-dot" aria-hidden="true" />
    </span>;
  })}</div>;
}

/** A banner for pages whose work waits on a background process. Renders nothing while it is healthy. */
export function WorkerNotice({ system, name, children }: { system: SystemStatus; name: WorkerName; children: (when: string) => string }) {
  const { liveness, worker } = system.of(name);
  if (!system.loaded || system.failed || liveness === 'online') return null;
  const when = liveness === 'never' ? `${workerLabels[name]} has not reported in yet` : `${workerLabels[name]} is ${words[liveness]} (last heartbeat ${timeAgo(worker?.lastSeen ?? null, system.now)})`;
  return <div className="notice worker-notice" role="status">{children(when)}</div>;
}
