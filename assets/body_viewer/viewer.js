import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
import { MeshoptDecoder } from 'three/addons/libs/meshopt_decoder.module.js';
import {
  CONTEXT_PREFIX, muscleIdFromName, TapTracker, facingAngle, orbitPosition,
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

window.addEventListener('resize', () => {
  camera.aspect = window.innerWidth / window.innerHeight;
  camera.updateProjectionMatrix();
  renderer.setSize(window.innerWidth, window.innerHeight);
  requestRender();
});

// ---------- model ----------
const muscleMeshes = new Map(); // muscleId -> Mesh[]
const pickables = [];
let homeDistance = 0;
let modelLoaded = false;

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
    if (id) {
      o.userData.muscleId = id;
      if (!muscleMeshes.has(id)) muscleMeshes.set(id, []);
      muscleMeshes.get(id).push(o);
    }
  });

  const halfFov = THREE.MathUtils.degToRad(camera.fov / 2);
  homeDistance = (size.y / 2 / Math.tan(halfFov)) * 1.15;
  controls.minDistance = homeDistance * 0.25;
  controls.maxDistance = homeDistance * 1.6;
  setView('front', false);
  modelLoaded = true;
  applyColors(); // re-apply select/highlight state set before load finished
  post({ type: 'ready' });
}, undefined, (err) => post({ type: 'error', message: String(err?.message ?? err) }));

// ---------- camera ----------
let tweenId = 0;
function moveCamera(position, target, animate) {
  const id = ++tweenId;
  const toPos = new THREE.Vector3(...position);
  const toTarget = new THREE.Vector3(...target);
  if (!animate) {
    camera.position.copy(toPos);
    controls.target.copy(toTarget);
    controls.update();
    requestRender();
    return;
  }
  const fromPos = camera.position.clone();
  const fromTarget = controls.target.clone();
  const start = performance.now();
  const step = (now) => {
    if (id !== tweenId) return;
    const t = Math.min((now - start) / TWEEN_MS, 1);
    const e = t < 0.5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2;
    camera.position.lerpVectors(fromPos, toPos, e);
    controls.target.lerpVectors(fromTarget, toTarget, e);
    controls.update();
    requestRender();
    if (t < 1) requestAnimationFrame(step);
  };
  requestAnimationFrame(step);
}

function setView(view, animate = true) {
  if (!homeDistance) return;
  const angle = view === 'back' ? Math.PI : 0;
  moveCamera(orbitPosition(angle, [0, 0, 0], homeDistance), [0, 0, 0], animate);
}

function focus(id) {
  const meshes = muscleMeshes.get(id);
  if (!meshes || !homeDistance) return;
  const box = new THREE.Box3();
  meshes.forEach((m) => box.expandByObject(m));
  const c = box.getCenter(new THREE.Vector3());
  const target = [0, c.y, 0];
  moveCamera(orbitPosition(facingAngle(c.x, c.z), target, homeDistance * FOCUS_ZOOM), target, true);
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
  const hit = raycaster.intersectObjects(pickables, false)[0];
  const id = hit?.object.userData.muscleId;
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
