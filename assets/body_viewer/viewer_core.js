// Pure helpers for viewer.js. No three.js or DOM access so they run under node --test.

export const CONTEXT_PREFIX = '_ctx_';
const ID_PATTERN = /^[a-z][a-z0-9_]*$/;
const TAP_MAX_MOVE_PX = 6;
const TAP_MAX_MS = 300;

// `deltoid_anterior__L` -> `deltoid_anterior`; context/unknown names -> null.
export function muscleIdFromName(name) {
  if (!name || name.startsWith(CONTEXT_PREFIX)) return null;
  const id = name.split('__')[0];
  return ID_PATTERN.test(id) ? id : null;
}

export function isTap(dx, dy, dtMs) {
  return Math.hypot(dx, dy) < TAP_MAX_MOVE_PX && dtMs < TAP_MAX_MS;
}

// Tracks pointers so only an uninterrupted single-finger touch counts as a tap.
export class TapTracker {
  constructor() {
    this.pointers = new Map();
    this.multi = false;
  }

  down(id, x, y, t) {
    if (this.pointers.size > 0) this.multi = true;
    this.pointers.set(id, { x, y, t });
  }

  up(id, x, y, t) {
    const start = this.pointers.get(id);
    this.pointers.delete(id);
    const wasMulti = this.multi;
    if (this.pointers.size === 0) this.multi = false;
    if (!start || wasMulti) return false;
    return isTap(x - start.x, y - start.y, t - start.t);
  }

  cancel(id) {
    this.pointers.delete(id);
    if (this.pointers.size === 0) this.multi = false;
  }
}

// Horizontal angle from the body axis to a point; 0 = front (+Z), PI = back.
export function facingAngle(cx, cz) {
  return Math.atan2(cx, cz);
}

export function orbitPosition(angle, target, distance) {
  return [
    target[0] + distance * Math.sin(angle),
    target[1],
    target[2] + distance * Math.cos(angle),
  ];
}
