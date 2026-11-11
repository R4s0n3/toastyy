// Match the native final stop window; an expired round can never score.
export const stopWindowMs = 720;
export function canStopRound(elapsed, popAt) {
  return Number.isFinite(elapsed) && Number.isFinite(popAt)
    && elapsed >= Math.max(0, popAt - stopWindowMs) && elapsed < popAt;
}
