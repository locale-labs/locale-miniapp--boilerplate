/**
 * Debug Logger for Mini-App
 *
 * Centralized logging system that can be enabled/disabled.
 * Set DEBUG_ENABLED to true or use window.MINIAPP_DEBUG = true to see logs.
 */

const DEFAULT_DEBUG = true;

function isDebugEnabled(): boolean {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  if (typeof window !== 'undefined' && (window as any).MINIAPP_DEBUG === true) {
    return true;
  }
  return DEFAULT_DEBUG;
}

export function logger(...args: unknown[]): void {
  if (isDebugEnabled()) {
    console.log('[MiniApp]', ...args);
  }
}

export function logError(...args: unknown[]): void {
  console.error('[MiniApp Error]', ...args);
}

export function logWarn(...args: unknown[]): void {
  console.warn('[MiniApp Warning]', ...args);
}

export function logTrace(...args: unknown[]): void {
  if (isDebugEnabled()) {
    console.trace('[MiniApp Trace]', ...args);
  }
}
