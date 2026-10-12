import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  muscleIdFromName, isTap, TapTracker, facingAngle, orbitPosition,
} from '../../assets/body_viewer/viewer_core.js';

test('muscleIdFromName strips the side suffix', () => {
  assert.equal(muscleIdFromName('deltoid_anterior__L'), 'deltoid_anterior');
  assert.equal(muscleIdFromName('rectus_abdominis__R_1'), 'rectus_abdominis');
  assert.equal(muscleIdFromName('soleus'), 'soleus');
});

test('muscleIdFromName rejects context and junk names', () => {
  assert.equal(muscleIdFromName('_ctx_skeleton'), null);
  assert.equal(muscleIdFromName(''), null);
  assert.equal(muscleIdFromName(undefined), null);
  assert.equal(muscleIdFromName('Scene'), null);
  assert.equal(muscleIdFromName('__L'), null);
});

test('isTap accepts small quick touches only', () => {
  assert.equal(isTap(0, 0, 100), true);
  assert.equal(isTap(3, 4, 299), true);   // 5 px
  assert.equal(isTap(6, 0, 100), false);  // 6 px is a drag
  assert.equal(isTap(0, 0, 300), false);  // too slow
});

test('TapTracker reports a single-pointer tap', () => {
  const t = new TapTracker();
  t.down(1, 10, 10, 0);
  assert.equal(t.up(1, 12, 11, 120), true);
});

test('TapTracker ignores a drag', () => {
  const t = new TapTracker();
  t.down(1, 10, 10, 0);
  assert.equal(t.up(1, 40, 10, 120), false);
});

test('TapTracker ignores a pinch even if one finger lifts quickly in place', () => {
  const t = new TapTracker();
  t.down(1, 10, 10, 0);
  t.down(2, 80, 80, 10);
  assert.equal(t.up(1, 10, 10, 100), false);
  assert.equal(t.up(2, 60, 60, 120), false);
});

test('TapTracker ignores an up without a matching down, and cancel clears', () => {
  const t = new TapTracker();
  assert.equal(t.up(7, 0, 0, 10), false);
  t.down(1, 0, 0, 0);
  t.cancel(1);
  assert.equal(t.up(1, 0, 0, 50), false);
});

test('facingAngle points the camera at the muscle side', () => {
  assert.equal(facingAngle(0, 1), 0);
  assert.ok(Math.abs(facingAngle(0, -1) - Math.PI) < 1e-9);
  assert.ok(Math.abs(facingAngle(1, 0) - Math.PI / 2) < 1e-9);
});

test('orbitPosition places the camera around the target', () => {
  const [x, y, z] = orbitPosition(0, [0, 1, 0], 5);
  assert.deepEqual([x, y, z].map((v) => Math.round(v * 1e6) / 1e6), [0, 1, 5]);
  const back = orbitPosition(Math.PI, [0, 0, 0], 2);
  assert.ok(Math.abs(back[2] + 2) < 1e-9);
});
