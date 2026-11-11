import { referenceStatuses, statusLabel, type Analysis } from './analysis';

/** Quotes as RFC 4180 and neutralizes spreadsheet formulas, since paper titles are untrusted. */
export function csvCell(value: string | number | boolean | null | undefined): string {
  if (value === null || value === undefined) return '';
  let text = String(value);
  if (typeof value === 'string' && /^[=+\-@\t\r]/.test(text)) text = `'${text}`;
  return /[",\r\n]/.test(text) ? `"${text.replace(/"/g, '""')}"` : text;
}

export function toCsv(rows: (string | number | boolean | null | undefined)[][]): string {
  return rows.map((row) => row.map(csvCell).join(',')).join('\r\n');
}

const iso = (date: Date | null) => date ? date.toISOString() : '';

export function analysesCsv(analyses: Analysis[], nameOf: (uid: string | null) => string): string {
  const header = ['arXiv ID', 'Title', 'Authors', 'Status', 'Requested at (UTC)', 'Finished at (UTC)', 'Duration (min)',
    'Requested by', 'Requester UID', 'Check mode', 'Total references', ...referenceStatuses.map((status) => `${status[0].toUpperCase()}${status.slice(1)}`), 'Failure reason'];
  return toCsv([header, ...analyses.map((a) => [
    a.id, a.title, a.authors.join('; '), statusLabel[a.status], iso(a.createdAt), iso(a.finishedAt),
    a.status === 'done' && a.createdAt && a.finishedAt ? Math.round((a.finishedAt.getTime() - a.createdAt.getTime()) / 6000) / 10 : '',
    a.requestedBy ? nameOf(a.requestedBy) : '', a.requestedBy, a.aiAssisted === null ? '' : a.aiAssisted ? 'AI-assisted' : 'Standard',
    a.status === 'done' ? a.totalRefs : '', ...referenceStatuses.map((status) => a.status === 'done' ? a.counts[status] : ''), a.error,
  ])]);
}

/** Starts a browser download; the BOM lets spreadsheet apps detect UTF-8 names. */
export function downloadCsv(fileName: string, csv: string): void {
  const url = URL.createObjectURL(new Blob(['﻿', csv], { type: 'text/csv;charset=utf-8' }));
  const link = Object.assign(document.createElement('a'), { href: url, download: fileName });
  document.body.append(link);
  link.click();
  link.remove();
  setTimeout(() => URL.revokeObjectURL(url), 0);
}
