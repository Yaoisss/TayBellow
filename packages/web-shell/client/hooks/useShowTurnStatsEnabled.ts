/**
 * @license
 * Copyright 2025 Qwen Team
 * SPDX-License-Identifier: Apache-2.0
 */

import { useSettings } from '@qwen-code/web-shell/daemon-react-sdk';

/** Setting the composer's token/timing readouts follow. */
const RESPONSE_SPEED_SETTING = 'ui.showResponseTokensPerSecond';

/**
 * Whether the composer shows per-turn token, timing and rate readouts.
 *
 * The setting defaults to off for the terminal UI, so only an explicit
 * user/workspace value is authoritative here; with none set the Web Shell
 * shows the readouts. `values.effective` is deliberately not consulted —
 * it carries the daemon default and would pin this to off.
 */
export function useShowTurnStatsEnabled(): boolean {
  const { settings } = useSettings({ autoLoad: true });
  const descriptor = settings.find(
    (setting) => setting.key === RESPONSE_SPEED_SETTING,
  );
  const explicit = descriptor?.values.user ?? descriptor?.values.workspace;
  return explicit === undefined ? true : explicit === true;
}
