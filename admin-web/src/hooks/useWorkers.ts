import { useEffect, useState } from 'react';
import { liveness, type Liveness, type WorkerName, type WorkerStatus } from '../domain/workers';
import type { AdminGateway } from '../services/gateway';

export interface SystemStatus {
  loaded: boolean; failed: boolean; now: Date;
  workers: Map<string, WorkerStatus>;
  of(name: WorkerName): { liveness: Liveness; worker: WorkerStatus | undefined };
}

/** Live heartbeat records, re-evaluated on a timer because silence is the signal. */
export function useWorkers(gateway: AdminGateway, tickMs = 20000): SystemStatus {
  const [workers, setWorkers] = useState<Map<string, WorkerStatus>>(new Map());
  const [loaded, setLoaded] = useState(false);
  const [failed, setFailed] = useState(false);
  const [now, setNow] = useState(() => new Date());
  useEffect(() => {
    let active = true;
    const stop = gateway.watchWorkers((list) => {
      if (!active) return;
      setWorkers(new Map(list.map((worker) => [worker.name, worker]))); setLoaded(true); setFailed(false); setNow(new Date());
    }, () => { if (active) { setLoaded(true); setFailed(true); } });
    const timer = setInterval(() => setNow(new Date()), tickMs);
    return () => { active = false; stop(); clearInterval(timer); };
  }, [gateway, tickMs]);
  return { loaded, failed, now, workers, of: (name) => ({ liveness: liveness(workers.get(name), now), worker: workers.get(name) }) };
}
