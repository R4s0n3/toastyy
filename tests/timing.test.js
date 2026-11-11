import test from 'node:test';
import assert from 'node:assert/strict';
import { canStopRound } from '../src/timing.js';

test('only the final 720 milliseconds accept a stop, excluding the pop itself', () => {
  for (const popAt of [1450, 2800, 5200]) {
    assert.equal(canStopRound(0, popAt), false);
    assert.equal(canStopRound(popAt - 721, popAt), false);
    assert.equal(canStopRound(popAt - 720, popAt), true);
    assert.equal(canStopRound(popAt - 1, popAt), true);
    assert.equal(canStopRound(popAt, popAt), false);
    assert.equal(canStopRound(popAt + 1, popAt), false);
  }
  assert.equal(canStopRound(NaN, 2000), false);
});
