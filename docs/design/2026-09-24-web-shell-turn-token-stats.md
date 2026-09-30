# Web Shell: Per-Turn Token, Timing and Rate Readouts

[English](2026-09-24-web-shell-turn-token-stats.md) | [简体中文](2026-09-24-web-shell-turn-token-stats.zh-CN.md)

Status: implemented (2026-09-24)

## Problem

The Web Shell shows context-window occupancy in the composer toolbar and a
per-turn summary row inside the transcript (`TurnCollapseRow`), but the
composer itself reports nothing about what the last answer cost or how fast it
streamed. The `ui.showResponseTokensPerSecond` setting has no Web Shell
consumer at all: it appears in the settings panel and does nothing there, while
only the terminal UI honors it.

## Goals

- After each turn finishes, show the turn's token spend and duration under the
  composer.
- While a turn streams, show the live output rate.
- Break out cached and thinking tokens, and the number of model requests.
- Honor one switch (the existing response-speed setting) that defaults to on in
  the Web Shell and can be turned off from the settings panel.

## Non-goals

- No time-to-first-token (TTFT) readout: live SSE frames do not carry it (it is
  recorded only in `ui_telemetry` and surfaces through paged replay timing
  frames). Adding it means new measurement and fields on the daemon's live
  frames — a separate change.
- No per-tool duration breakdown in the live path: tool timing frames likewise
  exist only in paged replay, so a live turn cannot attribute time to tools
  without new daemon fields. The transcript's existing collapse row remains the
  place to read tool counts.
- No changes to the terminal UI's own rate display or its default.

## Proposed solution

1. **Session mappers**
   (`packages/web-shell/client/daemon/session/mappers.ts`) — sum a per-turn
   `DaemonTurnStats` from the main conversation's usage frames:
   `inputTokens`, `outputTokens`, `thoughtTokens`, `cachedTokens`,
   `modelDurationMs` (summed from the live frame's `_meta.durationMs`),
   `requestCount`. Sub-agent frames (carrying `parentToolCallId`) stay excluded,
   matching the context-usage counting. `turn_complete` / `turn_error` freeze
   the running totals into `lastTurnStats` and clear `turnStats`, so a failed
   turn still reports what it spent.
2. **Connection state**
   (`daemon/session/types.ts`) — `turnStats` (in flight) and `lastTurnStats`
   (last finished turn) beside `tokenUsage`. Both reset with the session
   identity in `DaemonSessionProvider`, since they describe live frames only.
3. **Composer row** — a new `TurnStatsRow` component renders under the composer
   once a turn ends: `↑12.0k (8.0k cached, 67%) ↓3.0k · thinking 800 ·
took 12.0s · 250 tok/s · 3 requests`. It reuses the existing
   `formatContextTokens` and the `turn.cached` wording so it reads like the
   transcript's row.
4. **Live rate** — `StreamingStatus` gains `showTokensPerSecond`, appending
   `N tok/s` to its existing `(12s · ↓ 1.2k tokens · esc to cancel)` line,
   computed over the turn's elapsed time and the existing streamed-token
   estimate.
5. **Switch** — `useShowTurnStatsEnabled` reads
   `ui.showResponseTokensPerSecond` and returns true unless a user or workspace
   value explicitly turns it off. `values.effective` is deliberately not read:
   it carries the daemon default (off, for the terminal UI) and would pin the
   Web Shell to off.
6. **Mounts** — `ChatPane` and the main `App` composer status area both render
   the row and pass the rate flag to `StreamingStatus`.

## Design decisions and rationale

- **Sum in the mappers, not from rendered messages.** The composer row must be
  correct the moment a turn ends, including turns whose messages are still
  being projected, and it needs the summed model duration, which no message
  carries. The transcript's collapse row keeps its own computation.
- **Do not change the setting's default.** The setting is shared with the
  terminal UI, where off is the established default; flipping it would change
  CLI behavior for a Web Shell concern. Treating only an explicit value as
  authoritative gives the Web Shell its own default without a second setting.
- **Rate = output tokens / summed model duration.** This is the terminal UI's
  throughput definition minus the TTFT subtraction it can afford. When live
  frames carry no duration (replayed history, older daemons), the rate is
  omitted rather than computed against wall-clock time that includes tool
  rounds.
- **Cached and thinking tokens are additive display, not new accounting.**
  Cached reads are a subset of input, reported as a share so a high cache hit
  is visible at a glance.

## Constraints

- Older daemons that do not stamp `_meta.durationMs` show tokens without a
  duration or rate; nothing errors.
- `lastTurnStats` is not restored on reconnect (it describes the live turn);
  the row disappears until the next turn ends rather than showing a stale
  figure.

## Validation plan

- Mapper tests: summing across frames, frames without a duration, freezing on
  `turn_complete` and `turn_error`, no-op when no turn is open, sub-agent frames
  excluded.
- Component tests: `TurnStatsRow` renders tokens, cache share, duration, rate
  and request count; renders nothing while a turn is in flight or before any
  turn; omits rate/duration without a model duration; omits cache and
  single-request noise. `StreamingStatus` appends the rate only when enabled.
- Manual: stream a turn in the Web Shell, watch the live rate, confirm the
  composer summary after the turn ends, then disable the setting and confirm
  both disappear.

## Acceptance criteria

1. A finished turn shows its token spend (input/output/cached/thinking) and
   duration under the composer.
2. A streaming turn shows a live tokens-per-second figure.
3. Turning off `ui.showResponseTokensPerSecond` hides the composer row and the
   live rate; the terminal UI's behavior is unchanged.
4. Switched or reloaded sessions do not carry a previous session's totals.

## Open questions

- Whether to add live TTFT (and with it a terminal-UI-equivalent rate) by
  measuring first-token time in the daemon and stamping it on the live usage
  frame.
