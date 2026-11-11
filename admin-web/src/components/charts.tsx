import { useState, type CSSProperties, type ReactNode } from 'react';
import { Link } from 'react-router-dom';

/** Rounds an axis maximum up to 1, 2 or 5 × 10ⁿ so ticks stay clean. */
export function niceMax(value: number): number {
  if (value <= 1) return 1;
  const power = 10 ** Math.floor(Math.log10(value));
  return ([1, 2, 5, 10].find((step) => step * power >= value) ?? 10) * power;
}

/** Near either edge the tooltip aligns to its column's outer side so it never leaves the plot. */
function tooltipPosition(index: number, count: number): CSSProperties {
  const center = (index + 0.5) / count;
  if (center < 0.3) return { left: `${(index / count) * 100}%` };
  if (center > 0.7) return { right: `${(1 - (index + 1) / count) * 100}%` };
  return { left: `${center * 100}%`, transform: 'translateX(-50%)' };
}

export interface Column { key: string; label: string; value: number; detail: string; tableCells: (string | number)[] }

/** One series of columns. Each column's full-height slot is its hover and focus target. */
export function ColumnChart({ columns, label, tableHeadings }: { columns: Column[]; label: string; tableHeadings: string[] }) {
  const [active, setActive] = useState<number | null>(null);
  const max = niceMax(Math.max(0, ...columns.map((column) => column.value)));
  const step = Math.max(1, Math.ceil(columns.length / 7));
  const current = active === null ? null : columns[active];
  return <figure className="chart">
    <div className="column-chart" onPointerLeave={() => setActive(null)}>
      <div className="column-axis" aria-hidden="true">{[max, max / 2, 0].map((tick) => <span key={tick}>{Number.isInteger(tick) ? tick.toLocaleString('en') : ''}</span>)}</div>
      <div className="column-plot">
        <div className="column-grid" aria-hidden="true"><span /><span /><span /></div>
        <div className="column-slots" role="group" aria-label={label}>{columns.map((column, index) => <button type="button" key={column.key}
          className={`column-slot ${active === index ? 'active' : ''}`} aria-label={column.detail}
          onPointerEnter={() => setActive(index)} onFocus={() => setActive(index)} onBlur={() => setActive(null)}>
          <span className="column-bar" style={{ height: `${(column.value / max) * 100}%` }} />
        </button>)}</div>
        {current && active !== null && <div className="chart-tooltip" role="status" style={tooltipPosition(active, columns.length)}>
          <strong>{current.value.toLocaleString('en')}</strong><span>{current.detail}</span></div>}
      </div>
      <div className="column-labels" aria-hidden="true">{columns.map((column, index) => <span key={column.key}>{(columns.length - 1 - index) % step === 0 ? column.label : ''}</span>)}</div>
    </div>
    <TableView headings={tableHeadings} rows={columns.map((column) => [column.label, ...column.tableCells])} />
  </figure>;
}

export interface Segment { key: string; label: string; value: number; color: string; darkText?: boolean }

/** One whole split into parts: shares inside blocks that fit, every value in the legend's table view. */
export function SegmentedBar({ segments, label, unit }: { segments: Segment[]; label: string; unit: string }) {
  const [active, setActive] = useState<string | null>(null);
  const total = segments.reduce((sum, segment) => sum + segment.value, 0);
  const share = (value: number) => total ? `${Math.round((value / total) * 100)}%` : '0%';
  const shown = segments.filter((segment) => segment.value > 0);
  const current = shown.find((segment) => segment.key === active);
  return <figure className="chart">
    <div className="segmented-bar" role="group" aria-label={label} onPointerLeave={() => setActive(null)}>
      {total === 0 ? <span className="segment-empty">No data yet</span> : shown.map((segment) => <button type="button" key={segment.key}
        className={`segment ${segment.darkText ? 'dark-text' : ''} ${segment.value / total >= 0.1 ? 'labeled' : ''}`} style={{ flex: `${segment.value} 1 0px`, background: segment.color }}
        aria-label={`${segment.label}: ${segment.value.toLocaleString('en')} ${unit} (${share(segment.value)})`}
        onPointerEnter={() => setActive(segment.key)} onFocus={() => setActive(segment.key)} onBlur={() => setActive(null)}>
        {segment.value / total >= 0.1 ? share(segment.value) : ''}
      </button>)}
    </div>
    <div className="segment-readout" aria-hidden="true">{current ? <><strong>{current.value.toLocaleString('en')}</strong> {current.label.toLowerCase()} {unit} · {share(current.value)}</> : <>&nbsp;</>}</div>
    <ul className="chart-legend">{segments.map((segment) => <li key={segment.key}><span className="legend-swatch" style={{ background: segment.color }} />{segment.label}</li>)}</ul>
    <TableView headings={['Status', 'Count', 'Share']} rows={segments.map((segment) => [segment.label, segment.value.toLocaleString('en'), share(segment.value)])} />
  </figure>;
}

export interface BarRow { key: string; label: ReactNode; text: string; value: number; display?: string; href?: string }

/** Ranked horizontal bars, one series; the value is printed at each bar's tip. */
export function BarList({ rows, label, empty }: { rows: BarRow[]; label: string; empty: string }) {
  const max = Math.max(0, ...rows.map((row) => row.value));
  if (!rows.length) return <p className="chart-empty">{empty}</p>;
  return <ul className="bar-list" aria-label={label}>{rows.map((row) => <li key={row.key}>
    <span className="bar-label">{row.href ? <Link to={row.href}>{row.label}</Link> : row.label}</span>
    <span className="bar-track"><span className="bar-fill" style={{ width: `${max ? (row.value / max) * 100 : 0}%` }} /><span className="bar-value">{row.display ?? row.value.toLocaleString('en')}</span></span>
  </li>)}</ul>;
}

export function TableView({ headings, rows }: { headings: string[]; rows: (string | number)[][] }) {
  return <details className="table-view"><summary>View as table</summary>
    <div className="table-view-scroll"><table><thead><tr>{headings.map((heading) => <th scope="col" key={heading}>{heading}</th>)}</tr></thead>
      <tbody>{rows.map((row, index) => <tr key={index}>{row.map((cell, column) => <td key={column}>{cell}</td>)}</tr>)}</tbody></table></div>
  </details>;
}
