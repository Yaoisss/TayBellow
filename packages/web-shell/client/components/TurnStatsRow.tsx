/**
 * @license
 * Copyright 2025 Qwen Team
 * SPDX-License-Identifier: Apache-2.0
 */

import { useConnection } from '@qwen-code/web-shell/daemon-react-sdk';
import { useI18n } from '../i18n';
import { formatContextTokens } from '../utils/formatTokenCount';
import styles from './TurnStatsRow.module.css';

interface TurnStatsRowProps {
  /**
   * True while a turn is in flight. The composer then shows the live status
   * line instead and this row stays hidden, so the totals below the composer
   * always describe a finished turn.
   */
  active: boolean;
}

/**
 * One-turn token and timing totals, shown under the composer once a turn
 * finishes. The totals are summed by the session mappers from the main
 * conversation's usage frames, so a turn's tool rounds are included.
 */
export function TurnStatsRow({ active }: TurnStatsRowProps) {
  const connection = useConnection();
  const { t } = useI18n();
  const stats = active ? undefined : connection.lastTurnStats;
  if (!stats) return null;

  const cached =
    stats.cachedTokens > 0 && stats.inputTokens > 0
      ? ` (${formatContextTokens(stats.cachedTokens)} ${t('turn.cached')}, ${Math.round(
          (stats.cachedTokens / stats.inputTokens) * 100,
        )}%)`
      : '';
  // The summed model duration covers the generation windows only — a turn with
  // no live frames (replayed history) reports none, and the rate is omitted
  // rather than computed against wall-clock time it never measured.
  const rate =
    stats.modelDurationMs > 0 && stats.outputTokens > 0
      ? stats.outputTokens / (stats.modelDurationMs / 1000)
      : undefined;

  const parts = [
    `↑${formatContextTokens(stats.inputTokens)}${cached} ↓${formatContextTokens(stats.outputTokens)}`,
  ];
  if (stats.thoughtTokens > 0) {
    parts.push(t('turnStats.thinking', { count: stats.thoughtTokens }));
  }
  if (stats.modelDurationMs > 0) {
    parts.push(
      t('turnStats.duration', {
        duration: formatTurnDuration(stats.modelDurationMs),
      }),
    );
  }
  if (rate !== undefined) {
    parts.push(t('turnStats.rate', { rate: String(Math.round(rate)) }));
  }
  if (stats.requestCount > 1) {
    parts.push(t('turnStats.requests', { count: stats.requestCount }));
  }

  return (
    <div className={styles.row} data-testid="turn-stats-row">
      <span className={styles.label}>{t('turnStats.label')}</span>
      <span className={styles.meta}>{parts.join(' · ')}</span>
    </div>
  );
}

function formatTurnDuration(milliseconds: number): string {
  const totalSeconds = milliseconds / 1000;
  if (totalSeconds < 60) return `${totalSeconds.toFixed(1)}s`;
  const minutes = Math.floor(totalSeconds / 60);
  const seconds = Math.round(totalSeconds % 60);
  return `${minutes}m ${seconds}s`;
}
