// @vitest-environment jsdom
import { act } from 'react';
import { createRoot, type Root } from 'react-dom/client';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { I18nProvider } from '../i18n';

Object.assign(globalThis, { IS_REACT_ACT_ENVIRONMENT: true });

const mocks = vi.hoisted(() => ({
  lastTurnStats: undefined as unknown,
}));

vi.mock('@qwen-code/web-shell/daemon-react-sdk', () => ({
  useConnection: () => ({ lastTurnStats: mocks.lastTurnStats }),
}));

const { TurnStatsRow } = await import('./TurnStatsRow');

let container: HTMLDivElement | null = null;
let root: Root | null = null;

afterEach(() => {
  if (root) act(() => root!.unmount());
  container?.remove();
  root = null;
  container = null;
  mocks.lastTurnStats = undefined;
});

function render(active: boolean): string {
  container = document.createElement('div');
  document.body.appendChild(container);
  root = createRoot(container);
  act(() => {
    root!.render(
      <I18nProvider language="en">
        <TurnStatsRow active={active} />
      </I18nProvider>,
    );
  });
  return container.textContent ?? '';
}

const FULL_STATS = {
  inputTokens: 12_000,
  outputTokens: 3_000,
  thoughtTokens: 800,
  cachedTokens: 8_000,
  modelDurationMs: 12_000,
  requestCount: 3,
};

describe('TurnStatsRow', () => {
  it('renders nothing without a finished turn', () => {
    expect(render(false)).toBe('');
  });

  it('renders nothing while a turn is still in flight', () => {
    mocks.lastTurnStats = FULL_STATS;

    expect(render(true)).toBe('');
  });

  it('summarizes tokens, duration, rate and request count', () => {
    mocks.lastTurnStats = FULL_STATS;

    const text = render(false);

    // ↑12.0k (8.0k cached, 67%) ↓3.0k · thinking 800 · took 12.0s · …
    expect(text).toContain('↑12.0k');
    expect(text).toContain('8.0k cached, 67%');
    expect(text).toContain('↓3.0k');
    expect(text).toContain('thinking 800');
    expect(text).toContain('took 12.0s');
    // 3000 output tokens over 12_000ms of model time.
    expect(text).toContain('250 tok/s');
    expect(text).toContain('3 requests');
  });

  it('omits the rate when no frame carried a model duration', () => {
    mocks.lastTurnStats = { ...FULL_STATS, modelDurationMs: 0 };

    const text = render(false);

    expect(text).not.toContain('tok/s');
    expect(text).not.toContain('took');
  });

  it('omits the cache breakdown and single-request count', () => {
    mocks.lastTurnStats = {
      inputTokens: 900,
      outputTokens: 50,
      thoughtTokens: 0,
      cachedTokens: 0,
      modelDurationMs: 1_000,
      requestCount: 1,
    };

    const text = render(false);

    expect(text).not.toContain('cached');
    expect(text).not.toContain('thinking');
    expect(text).not.toContain('request');
    expect(text).toContain('↑900 ↓50');
    expect(text).toContain('50 tok/s');
  });
});
