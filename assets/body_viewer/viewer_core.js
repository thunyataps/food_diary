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

// Interpolates between two angles along the shortest arc.
export function lerpAngle(from, to, t) {
  const delta = Math.atan2(Math.sin(to - from), Math.cos(to - from));
  return from + delta * t;
}

// Which side of the body a muscle is on, from the offset of its vertices to the
// nearest point of the underlying skeleton (outward = away from the bone).
// Muscle meshes are closed, so summed face normals cancel; offsets from the bone
// do not. `points`/`refs` are flat [x,y,z,...] arrays (world space).
export function accumulateOutward(points, refs, maxSamples = 200) {
  const out = { x: 0, z: 0, abs: 0 };
  const n = Math.floor(points.length / 3);
  const m = Math.floor(refs.length / 3);
  if (n === 0 || m === 0) return out;
  const stride = Math.max(1, Math.ceil(n / maxSamples));
  for (let i = 0; i < n; i += stride) {
    const px = points[i * 3], py = points[i * 3 + 1], pz = points[i * 3 + 2];
    let best = Infinity, bx = 0, bz = 0;
    for (let j = 0; j < m; j++) {
      const dx = px - refs[j * 3], dy = py - refs[j * 3 + 1], dz = pz - refs[j * 3 + 2];
      const d = dx * dx + dy * dy + dz * dz;
      if (d < best) { best = d; bx = dx; bz = dz; }
    }
    out.x += bx;
    out.z += bz;
    out.abs += Math.hypot(bx, bz);
  }
  return out;
}

export function mergeOutward(list) {
  return list.reduce((a, o) => ({ x: a.x + o.x, z: a.z + o.z, abs: a.abs + o.abs }),
    { x: 0, z: 0, abs: 0 });
}

// Azimuth (0 = front +Z, PI = back) of the dominant outward direction, or null
// when it is ambiguous (sideways pair cancelling, or a muscle wrapping the limb).
export function facingFromOutward({ x, z, abs }, minRatio = 0.3) {
  if (!(abs > 0) || Math.hypot(x, z) / abs < minRatio) return null;
  return Math.atan2(x, z);
}

// Muscle id for a tap given ray hits sorted near-to-far ({distance, id|null}).
// The nearest hit wins, except that context geometry (skin-level shell, bone) lying
// within `tolerance` in front of a muscle does not block it; the model's context
// shell sits ~1 cm over thin muscles such as tibialis anterior.
export function pickMuscleId(hits, tolerance) {
  if (!hits.length) return null;
  if (hits[0].id) return hits[0].id;
  const limit = hits[0].distance + tolerance;
  for (const h of hits) {
    if (h.distance > limit) break;
    if (h.id) return h.id;
  }
  return null;
}
