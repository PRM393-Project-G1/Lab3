import { AlertCircle, CheckCircle2, Clock3, HelpCircle, LoaderCircle, XCircle, type LucideIcon } from 'lucide-react';
import type { ReactNode } from 'react';
import { statusLabel, type AnalysisStatus, type ReferenceStatus } from '../domain/analysis';

const statusIcons: Record<AnalysisStatus, LucideIcon> = {
  done: CheckCircle2, queued: Clock3, processing: LoaderCircle,
  failed: AlertCircle, cancelled: XCircle, unknown: HelpCircle,
};
export function StatusBadge({ status }: { status: AnalysisStatus }) {
  const Icon = statusIcons[status];
  return <span className={`status status-${status}`}><Icon size={13} aria-hidden="true" />{statusLabel[status]}</span>;
}
export function ReferenceBadge({ status }: { status: ReferenceStatus }) {
  return <span className={`reference-badge reference-${status}`}><span aria-hidden="true" />{status[0].toUpperCase() + status.slice(1)}</span>;
}
export function StatePanel({ title, children, retry, loading = false }: {
  title: string; children?: ReactNode; retry?: () => void; loading?: boolean;
}) {
  return <section className="state-panel" role={loading ? 'status' : undefined} aria-live="polite">
    <div className="state-icon">{loading ? <LoaderCircle className="spin" /> : <AlertCircle />}</div>
    <h2>{title}</h2>{children && <div className="state-message">{children}</div>}
    {retry && <button className="button secondary" onClick={retry}>Try again</button>}
  </section>;
}
export function formatDate(date: Date | null, full = false): string {
  return date ? new Intl.DateTimeFormat('en', { month: 'short', day: 'numeric',
    ...(full ? { year: 'numeric', hour: '2-digit', minute: '2-digit' } as const : {}) }).format(date) : 'Date unavailable';
}
