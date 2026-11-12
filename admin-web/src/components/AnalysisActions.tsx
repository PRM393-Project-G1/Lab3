import { CircleStop, Eye, EyeOff, RotateCcw, ShieldAlert, Trash2 } from 'lucide-react';
import { formatMinutes, stalledFor, type Analysis } from '../domain/analysis';
import { availableActions, type ActionType } from '../domain/actions';
import type { AdminGateway } from '../services/gateway';
import { ActionPanel, type ActionOption } from './ActionPanel';

type AnalysisAction = Extract<ActionType, 'cancelAnalysis' | 'retryAnalysis' | 'hideAnalysis' | 'unhideAnalysis' | 'deleteAnalysis'>;
const prompts: Record<AnalysisAction, Omit<ActionOption, 'draft'>> = {
  cancelAnalysis: { question: 'Stop this analysis now? The requester’s app will show it as stopped by an administrator.', confirm: 'Stop analysis', icon: CircleStop },
  retryAnalysis: { question: 'Run this analysis again with its original requester and settings? They get the usual notification when it finishes.', confirm: 'Run again', icon: RotateCcw },
  hideAnalysis: { question: 'Hide these results from users? Their app will say an administrator removed them, with your reason. You can show them again or run the paper again later.', confirm: 'Hide results', icon: EyeOff },
  unhideAnalysis: { question: 'Show these results to users again?', confirm: 'Show results again', icon: Eye },
  deleteAnalysis: { question: 'Delete this analysis with all its references and topics? This cannot be undone. Users who saved the paper will see it is no longer available and can request it again.', confirm: 'Delete permanently', icon: Trash2, danger: true },
};

/** Stop, rerun, hide or delete one analysis, depending on its state. */
export function AnalysisActions({ gateway, analysis, onSettled }: { gateway: AdminGateway; analysis: Analysis; onSettled: () => void }) {
  const stalled = stalledFor(analysis, new Date());
  const options = (availableActions(analysis) as AnalysisAction[]).map((type) => ({ draft: { type, target: analysis.id }, ...prompts[type] }));
  return <ActionPanel gateway={gateway} target={analysis.id} options={options} onSettled={onSettled}
    notice={stalled !== null && <p className="stall-warning"><ShieldAlert size={16} />No progress for {formatMinutes(stalled)}. The backend may have stopped or the job may be stuck; you can stop it and run it again.</p>} />;
}
