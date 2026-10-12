import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
import { MeshoptDecoder } from 'three/addons/libs/meshopt_decoder.module.js';
import {
  CONTEXT_PREFIX, muscleIdFromName, TapTracker, orbitPosition, lerpAngle,
  accumulateOutward, mergeOutward, facingFromOutward, pickMuscleId,
} from './viewer_core.js';

const COLORS = {
  background: 0xfaf6f0,
  muscle: 0xc98a86,
  context: 0xb9aea4,
  primary: 0xc1652f,
  secondary: 0xe8b08f,
};
const DIM_TOWARD = new THREE.Color(0xd9d2cb);
const DIM_AMOUNT = 0.6;
const FOCUS_ZOOM = 0.6;
const TWEEN_MS = 450;
// The Front/Back/Reset buttons overlay the bottom of the view (~72 dp) and the tap hint
// sits at the top, so the body is framed inside the strip between these insets (CSS px).
const BOTTOM_INSET = 96;
const TOP_INSET = 24;
// Context geometry within this distance (model units = metres, so 1.5 cm) in front of a
// muscle does not block a tap on it.
const PICK_TOLERANCE = 0.015;

// ---------- bridge ----------
const standalone = new URLSearchParams(location.search).has('standalone');
let platformReady = standalone || typeof window.flutter_inappwebview?.callHandler === 'function';
const outbox = [];

function post(msg) {
  if (standalone) {
    console.log('[viewer]', JSON.stringify(msg));
    return;
  }
  if (!platformReady) {
    outbox.push(msg);
    return;
  }
  window.flutter_inappwebview.callHandler('viewer', msg);
}

window.addEventListener('flutterInAppWebViewPlatformReady', () => {
  platformReady = true;
  outbox.splice(0).forEach(post);
});
window.addEventListener('error', (e) => post({ type: 'error', message: String(e.message) }));
window.addEventListener('unhandledrejection', (e) => post({ type: 'error', message: String(e.reason) }));

// ---------- scene ----------
const renderer = new THREE.WebGLRenderer({ antialias: true });
renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
renderer.setSize(window.innerWidth, window.innerHeight);
renderer.setClearColor(COLORS.background);
document.body.appendChild(renderer.domElement);
renderer.domElement.addEventListener('webglcontextlost', () => post({ type: 'error', message: 'WebGL context lost' }));

const scene = new THREE.Scene();
const camera = new THREE.PerspectiveCamera(35, window.innerWidth / window.innerHeight, 0.01, 100);
scene.add(new THREE.HemisphereLight(0xffffff, 0x8a7f74, 1.6));
const keyLight = new THREE.DirectionalLight(0xffffff, 1.4);
keyLight.position.set(2, 3, 4);
scene.add(keyLight);
const rimLight = new THREE.DirectionalLight(0xffffff, 0.8);
rimLight.position.set(-3, 2, -4);
scene.add(rimLight);

const controls = new OrbitControls(camera, renderer.domElement);
controls.enablePan = false;
controls.minPolarAngle = Math.PI * 0.25;
controls.maxPolarAngle = Math.PI * 0.75;

let renderQueued = false;
function requestRender() {
  if (renderQueued) return;
  renderQueued = true;
  requestAnimationFrame(() => {
    renderQueued = false;
    renderer.render(scene, camera);
  });
}
controls.addEventListener('change', requestRender);

// Shifts the rendered image up by half the inset difference (picking follows the
// projection matrix, so taps stay aligned).
function applyFrameOffset() {
  const w = window.innerWidth;
  const h = window.innerHeight;
  camera.setViewOffset(w, h, 0, (BOTTOM_INSET - TOP_INSET) / 2, w, h);
}
applyFrameOffset();

window.addEventListener('resize', () => {
  camera.aspect = window.innerWidth / window.innerHeight;
  camera.updateProjectionMatrix();
  applyFrameOffset();
  renderer.setSize(window.innerWidth, window.innerHeight);
  requestRender();
});

// ---------- model ----------
const muscleMeshes = new Map(); // muscleId -> Mesh[]
const pickables = [];
let homeDistance = 0;
let modelLoaded = false;
const skeletonMeshes = [];

// GLTFLoader names unnamed meshes `mesh_<index>`; those are not muscle ids.
const LOADER_MESH_NAME = /^mesh_\d+(_\d+)*$/; // also createUniqueName suffixes: mesh_5_1

function resolveId(obj) {
  for (let n = obj; n; n = n.parent) {
    if (LOADER_MESH_NAME.test(n.name)) continue;
    const id = muscleIdFromName(n.name);
    if (id) return id;
    if (n.name && n.name.startsWith(CONTEXT_PREFIX)) return null;
  }
  return null;
}

const loader = new GLTFLoader();
loader.setMeshoptDecoder(MeshoptDecoder);
loader.load('./body.glb', (gltf) => {
  const root = gltf.scene;
  const box = new THREE.Box3().setFromObject(root);
  const size = box.getSize(new THREE.Vector3());
  root.position.sub(box.getCenter(new THREE.Vector3()));
  scene.add(root);
  root.updateMatrixWorld(true);

  root.traverse((o) => {
    if (!o.isMesh) return;
    const id = resolveId(o);
    o.material = new THREE.MeshStandardMaterial({
      color: id ? COLORS.muscle : COLORS.context, roughness: 0.85, metalness: 0,
    });
    pickables.push(o);
    for (let n = o; n; n = n.parent) {
      if (n.name === `${CONTEXT_PREFIX}skeleton`) { skeletonMeshes.push(o); break; }
    }
    if (id) {
      o.userData.muscleId = id;
      if (!muscleMeshes.has(id)) muscleMeshes.set(id, []);
      muscleMeshes.get(id).push(o);
    }
  });

  const halfFov = THREE.MathUtils.degToRad(camera.fov / 2);
  // Fit the body height into the viewport minus the insets.
  const usable = Math.max(window.innerHeight - BOTTOM_INSET - TOP_INSET, window.innerHeight * 0.5);
  homeDistance = (size.y / 2 / Math.tan(halfFov)) * (window.innerHeight / usable);
  controls.minDistance = homeDistance * 0.25;
  controls.maxDistance = homeDistance * 1.6;
  setView('front', false);
  modelLoaded = true;
  applyColors(); // re-apply select/highlight state set before load finished
  post({ type: 'ready' });
}, undefined, (err) => post({ type: 'error', message: String(err?.message ?? err) }));

// ---------- camera ----------
let tweenId = 0;
function moveCamera(angle, target, distance, animate) {
  const id = ++tweenId;
  const toTarget = new THREE.Vector3(...target);
  if (!animate) {
    camera.position.set(...orbitPosition(angle, target, distance));
    controls.target.copy(toTarget);
    controls.update();
    requestRender();
    return;
  }
  // Tween in orbit space (azimuth along the shortest arc, distance and target
  // linearly) so front<->back swings around the body instead of through it.
  const fromTarget = controls.target.clone();
  const offset = camera.position.clone().sub(fromTarget);
  const fromAngle = Math.atan2(offset.x, offset.z);
  const fromRadius = Math.hypot(offset.x, offset.z);
  const fromHeight = offset.y;
  const start = performance.now();
  const step = (now) => {
    if (id !== tweenId) return;
    const t = Math.min((now - start) / TWEEN_MS, 1);
    const e = t < 0.5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2;
    controls.target.lerpVectors(fromTarget, toTarget, e);
    const a = lerpAngle(fromAngle, angle, e);
    const r = fromRadius + (distance - fromRadius) * e;
    const h = fromHeight * (1 - e);
    camera.position.set(
      controls.target.x + r * Math.sin(a),
      controls.target.y + h,
      controls.target.z + r * Math.cos(a),
    );
    controls.update();
    requestRender();
    if (t < 1) requestAnimationFrame(step);
  };
  requestAnimationFrame(step);
}

function setView(view, animate = true) {
  if (!homeDistance) return;
  const angle = view === 'back' ? Math.PI : 0;
  moveCamera(angle, [0, 0, 0], homeDistance, animate);
}

// World-space vertices of a mesh as a flat [x,y,z,...] array (keeps every `step`-th).
function worldPoints(mesh, step = 1) {
  mesh.updateMatrixWorld(true);
  const pos = mesh.geometry.attributes.position;
  const v = new THREE.Vector3();
  const out = [];
  for (let i = 0; i < pos.count; i += step) {
    v.fromBufferAttribute(pos, i).applyMatrix4(mesh.matrixWorld);
    out.push(v.x, v.y, v.z);
  }
  return out;
}

// Azimuth of the side a muscle is on (0 front, PI back), or null if ambiguous
// (e.g. lateral deltoid, whose L/R halves point opposite ways). Computed lazily, cached.
let skeletonPoints = null;
const facingCache = new Map();
function muscleFacing(id) {
  if (facingCache.has(id)) return facingCache.get(id);
  if (!skeletonPoints) skeletonPoints = skeletonMeshes.flatMap((m) => worldPoints(m, 4));
  const sums = muscleMeshes.get(id).map((m) => accumulateOutward(worldPoints(m), skeletonPoints));
  const angle = facingFromOutward(mergeOutward(sums));
  facingCache.set(id, angle);
  return angle;
}

function focus(id) {
  const meshes = muscleMeshes.get(id);
  if (!meshes || !homeDistance) return;
  const box = new THREE.Box3();
  meshes.forEach((m) => box.expandByObject(m));
  const c = box.getCenter(new THREE.Vector3());
  const target = [0, c.y, 0];
  // Ambiguous facing keeps the current azimuth (only height/zoom change).
  const angle = muscleFacing(id)
    ?? Math.atan2(camera.position.x - controls.target.x, camera.position.z - controls.target.z);
  moveCamera(angle, target, homeDistance * FOCUS_ZOOM, true);
}

// ---------- highlight ----------
let primary = new Set();
let secondary = new Set();

function applyColors() {
  // Only ids that exist in the model count; deep/unknown ids must not dim anything.
  const known = (set) => [...set].some((id) => muscleMeshes.has(id));
  const active = known(primary) || known(secondary);
  for (const [id, meshes] of muscleMeshes) {
    const hex = primary.has(id) ? COLORS.primary : secondary.has(id) ? COLORS.secondary : COLORS.muscle;
    for (const m of meshes) {
      m.material.color.setHex(hex);
      if (active && hex === COLORS.muscle) m.material.color.lerp(DIM_TOWARD, DIM_AMOUNT);
    }
  }
  requestRender();
}

const idList = (v) => (Array.isArray(v) ? v.filter((x) => typeof x === 'string') : []);

function select(id) {
  if (typeof id !== 'string' || (modelLoaded && !muscleMeshes.has(id))) {
    clear();
    return;
  }
  primary = new Set([id]);
  secondary = new Set();
  applyColors();
  focus(id);
}

function highlight(arg) {
  const { primary: p, secondary: s } = arg ?? {};
  primary = new Set(idList(p));
  secondary = new Set(idList(s).filter((id) => !primary.has(id)));
  applyColors();
}

function clear() {
  primary = new Set();
  secondary = new Set();
  applyColors();
}

// ---------- picking ----------
const taps = new TapTracker();
const raycaster = new THREE.Raycaster();
const ndc = new THREE.Vector2();
const canvas = renderer.domElement;

canvas.addEventListener('pointerdown', (e) => taps.down(e.pointerId, e.clientX, e.clientY, e.timeStamp));
canvas.addEventListener('pointercancel', (e) => taps.cancel(e.pointerId));
canvas.addEventListener('pointerup', (e) => {
  if (!taps.up(e.pointerId, e.clientX, e.clientY, e.timeStamp) || !homeDistance) return;
  const rect = canvas.getBoundingClientRect();
  ndc.set(((e.clientX - rect.left) / rect.width) * 2 - 1, -((e.clientY - rect.top) / rect.height) * 2 + 1);
  raycaster.setFromCamera(ndc, camera);
  const hits = raycaster.intersectObjects(pickables, false)
    .map((h) => ({ distance: h.distance, id: h.object.userData.muscleId ?? null }));
  const id = pickMuscleId(hits, PICK_TOLERANCE);
  if (id) {
    post({ type: 'muscleTapped', id });
    if (standalone) select(id);
  } else {
    post({ type: 'backgroundTapped' });
    if (standalone) clear();
  }
});

window.viewer = {
  select,
  highlight,
  clear,
  setView: (view) => setView(view, true),
  resetView: () => setView('front', true),
};

// Debug hooks for headless checks; never exposed inside the app.
if (standalone) window.__dbg = { camera, controls, muscleMeshes, pickables, raycaster, THREE, scene };
