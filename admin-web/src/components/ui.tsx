import { AlertCircle, CheckCircle2, Clock3, HelpCircle, LoaderCircle, XCircle, type LucideIcon } from 'lucide-react';
import type { MouseEvent, ReactNode } from 'react';
import { useNavigate } from 'react-router-dom';
import { statusLabel, type AnalysisStatus, type ReferenceStatus } from '../domain/analysis';

/**
 * A pointer click anywhere on a table row follows the row's link. Keyboard and
 * screen-reader users keep the real link inside the row; clicks on controls,
 * modified clicks and text selection are left alone.
 */
export function useRowLink() {
  const navigate = useNavigate();
  return (to: string) => (event: MouseEvent<HTMLElement>) => {
    if (event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
    if ((event.target as HTMLElement).closest('a, button, input, select, textarea, label, summary')) return;
    if (window.getSelection()?.toString()) return;
    navigate(to);
  };
}

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
