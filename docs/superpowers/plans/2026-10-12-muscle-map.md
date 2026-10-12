# Muscle Map Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a "Muscles" tab showing a rotatable 3D body (three.js in a WebView) where tapping any of ~49 muscle heads shows the exercises that train it, with full bilingual instructions and primary/secondary highlighting.

**Architecture:** A Blender script turns the Z-Anatomy model into a compressed `body.glb` whose mesh names encode muscle ids (`<id>__L`). A bundled three.js page renders it inside `flutter_inappwebview`, served via Android's `WebViewAssetLoader`, and talks to Dart through one JS handler. Flutter owns all state and content: a `MuscleCatalog` loaded from two bundled JSON files drives a bottom sheet and a searchable list; screens depend on an abstract `BodyViewerController` so widget tests use a fake.

**Tech Stack:** Flutter (Dart ^3.13), `flutter_inappwebview` ^6.1.5, three.js 0.170.0 (ES modules + importmap), `MeshoptDecoder`, Blender 4.x (Python `bpy`/`bmesh`), `gltfpack` 1.3.0, Node 26 (`node --test`), `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-10-12-muscle-map-design.md`

## Global Constraints

- Android only; light theme only. No iOS, no dark mode.
- All content bundled; no Supabase tables, no network use by this feature.
- Every content text field carries both `en` and `th`; UI chrome strings go in `lib/l10n/app_en.arb` + `lib/l10n/app_th.arb` (never hard-coded).
- Mesh naming: `<muscleId>__<suffix>` (double underscore); non-tappable geometry prefixed `_ctx_`.
- Muscle ids match `^[a-z][a-z0-9_]*$`.
- `equipment` ∈ `bodyweight|dumbbell|barbell|cable|machine|kettlebell|band`; `difficulty` ∈ `beginner|intermediate|advanced`; `group` ∈ `chest|shoulders|back|arms|core|hips|thighs|lower_legs|neck`.
- Exercise: 3–5 steps, ≥1 tip, ≥1 mistake. Muscle: ≥3 exercises where it is primary (`deep` muscles ≥1).
- `assets/body_viewer/body.glb` ≤ 4 MB, ~150k triangles.
- Colors: background `#FAF6F0`, selected/primary `#C1652F`.
- Tap = moved < 6 px and lasted < 300 ms. Viewer ready timeout = 10 s.
- three.js pinned to exactly `0.170.0`.
- Z-Anatomy is CC BY-SA 4.0: credit shown in-app; the Z-Anatomy `.blend` is never committed.
- Follow existing code style: models in `lib/models/`, feature code in `lib/features/<feature>/`, tests mirror under `test/`, widget tests wrap with `localizedApp()` from `test/test_utils.dart`.
- Commits end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. **Tap on a muscle id the catalog doesn't know** (mesh map and `muscles.json` drift) → nothing opens, no crash. Pinned in Task 12 (`ignores taps on unknown muscle ids`).
2. **Viewer never sends `ready`** (WebGL unavailable, asset 404, JS exception before load) → after 10 s an error panel with Retry and "Open muscle list"; Retry reloads and restarts the timer. Pinned in Task 12 (`times out to the error panel` / `retry reloads and waits again`).
3. **Thai locale with a missing/empty Thai string** → English shown instead of a blank. Pinned in Task 5 (`falls back to English when Thai is empty or missing`).
4. **Opening a `deep` muscle from the list** (no mesh) → sheet opens with the deep-muscle note; viewer `select` call is harmless. Pinned in Task 11 (`shows the deep note for deep muscles`), Task 12 (`choosing a muscle from the list opens it`), and Task 4 checklist item 6 (`viewer.select('pec_minor')` throws nothing).
5. **Pinch-zoom or rotate gesture ending over a muscle** → must not count as a tap. Pinned in Task 3 (`isTap` tests incl. multi-pointer cancel via `TapTracker`).

---

## File Map

| Path | Responsibility | Task |
|---|---|---|
| `tools/body_model/README.md` | How to get Z-Anatomy, install tools, rebuild `body.glb` | 1, 2 |
| `tools/body_model/inventory.py` | Dumps every Z-Anatomy object (name, type, collections, modifiers, bbox) to JSON | 1 |
| `tools/body_model/mesh_map.json` | `muscleId → Z-Anatomy objects (+ splits, deep flag)`, context groups, decimate ratios | 2 |
| `tools/body_model/build_glb.py` | Headless Blender build of the raw GLB | 2 |
| `assets/body_viewer/body.glb` | Committed, gltfpack-compressed model | 2 |
| `assets/body_viewer/vendor/**` | three.js 0.170.0 + addons | 3 |
| `assets/body_viewer/viewer_core.js` | Pure JS logic (id parsing, tap detection, orbit math) | 3 |
| `test/js/viewer_core.test.js` | `node --test` for `viewer_core.js` | 3 |
| `assets/body_viewer/index.html`, `viewer.js` | three.js scene, picking, highlight, bridge | 4 |
| `lib/models/localized_text.dart` | `LocalizedText`, `LocalizedList` | 5 |
| `lib/models/muscle.dart` | `MuscleGroup`, `Muscle` | 5 |
| `lib/models/exercise.dart` | `Equipment`, `Difficulty`, `Exercise` | 5 |
| `lib/features/muscles/muscle_catalog.dart` | Loads JSON, `muscleById`, `exercisesFor`, `search` | 6 |
| `assets/muscles/muscles.json` | 49 muscles | 6 |
| `assets/muscles/exercises.json` | ~114 exercises | 6–9 |
| `test/features/muscles/catalog_integrity_test.dart` | Content rules over the real JSON | 6–9 |
| `test/features/muscles/body_model_test.dart` | GLB mesh names ↔ `muscles.json` | 6 |
| `lib/features/muscles/body_viewer.dart` | `BodyView`, events, `BodyViewerController`, `parseViewerMessage` | 10 |
| `lib/features/muscles/web_body_viewer_controller.dart` | `InAppWebView` implementation | 10 |
| `test/features/muscles/fake_body_viewer_controller.dart` | Test double | 11 |
| `test/features/muscles/fixtures.dart` | Small in-memory catalog for widget tests | 11 |
| `lib/features/muscles/muscle_sheet.dart` | Muscle bottom sheet + exercise tiles | 11 |
| `lib/features/muscles/muscle_map_screen.dart` | Tab screen, status machine, credits | 12 |
| `lib/features/muscles/muscle_list_screen.dart` | Searchable grouped list | 13 |
| `lib/main.dart` | 4th tab | 14 |
| `pubspec.yaml` | deps, assets, version | 2, 3, 4, 6, 10, 15 |

---

### Task 1: Tooling and Z-Anatomy inventory (spike)

Goal: get the source model on disk and a machine-readable inventory of its objects, so Task 2 can map muscles to real object names. **Ask the user before each install/download step** (spec "Prerequisites").

**Files:**
- Create: `tools/body_model/inventory.py`
- Create: `tools/body_model/README.md`
- Modify: `.gitignore` (add `tools/body_model/out/`)

**Interfaces:**
- Produces: `tools/body_model/out/inventory.json` (gitignored) — list of `{name, type, collections, parent, modifiers, verts, center, size}`; used by Task 2.

- [ ] **Step 1: Install tools (after user confirms)**

```bash
brew install --cask blender
npm i -g gltfpack@1.3.0
/Applications/Blender.app/Contents/MacOS/Blender --version | head -1
gltfpack -h 2>&1 | head -1
```
Expected: `Blender 4.x.y` and gltfpack usage banner. If `blender` is not on PATH, use the full path above everywhere (record it in the README).

- [ ] **Step 2: Download Z-Anatomy (after user confirms; several hundred MB–GB)**

```bash
mkdir -p ~/Z-Anatomy && cd ~/Z-Anatomy
curl -L -o Z-Anatomy.zip https://github.com/Z-Anatomy/The-blend/raw/main/Z-Anatomy.zip
file Z-Anatomy.zip
```
If `file` reports ASCII text (a Git LFS pointer), re-download from `https://media.githubusercontent.com/media/Z-Anatomy/The-blend/main/Z-Anatomy.zip`. If the branch is not `main`, check the default branch on `https://github.com/Z-Anatomy/The-blend` and adjust.

```bash
unzip -o Z-Anatomy.zip -d template
find template -name '*.blend' -exec ls -lh {} \;
shasum -a 256 Z-Anatomy.zip
```
Expected: a `startup.blend` (application template). Record its path, the zip SHA-256, and today's date for the README.

- [ ] **Step 3: Write `tools/body_model/inventory.py`**

```python
"""Dump every object in a Z-Anatomy .blend to JSON so muscles can be mapped.

Usage:
  blender -b <startup.blend> -P tools/body_model/inventory.py -- <out.json>
"""
import json
import sys

import bpy
from mathutils import Vector


def out_path():
    argv = sys.argv
    if '--' not in argv or len(argv) <= argv.index('--') + 1:
        sys.exit('usage: blender -b file.blend -P inventory.py -- out.json')
    return argv[argv.index('--') + 1]


def world_bbox(obj):
    corners = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
    lo = Vector((min(c.x for c in corners), min(c.y for c in corners), min(c.z for c in corners)))
    hi = Vector((max(c.x for c in corners), max(c.y for c in corners), max(c.z for c in corners)))
    return lo, hi


def main():
    rows = []
    for obj in bpy.data.objects:
        row = {
            'name': obj.name,
            'type': obj.type,
            'collections': [c.name for c in obj.users_collection],
            'parent': obj.parent.name if obj.parent else None,
            'modifiers': [m.type for m in obj.modifiers],
            'verts': len(obj.data.vertices) if obj.type == 'MESH' else 0,
        }
        if obj.type == 'MESH':
            lo, hi = world_bbox(obj)
            row['center'] = [round(v, 4) for v in (lo + hi) / 2]
            row['size'] = [round(v, 4) for v in hi - lo]
        rows.append(row)
    tree = {c.name: [ch.name for ch in c.children] for c in bpy.data.collections}
    with open(out_path(), 'w', encoding='utf-8') as f:
        json.dump({'objects': rows, 'collections': tree}, f, ensure_ascii=False, indent=1)
    print(f'inventory: {len(rows)} objects')


main()
```

- [ ] **Step 4: Run it**

```bash
mkdir -p tools/body_model/out
blender -b ~/Z-Anatomy/template/<path>/startup.blend -P tools/body_model/inventory.py -- tools/body_model/out/inventory.json
python3 -c "import json;d=json.load(open('tools/body_model/out/inventory.json'));print(len(d['objects']))"
```
Expected: `inventory: N objects` with N in the thousands.

- [ ] **Step 5: Answer the spike questions and write them into the README**

```bash
python3 - <<'EOF'
import json, re
d = json.load(open('tools/body_model/out/inventory.json'))
for pat in ['deltoid', 'pectoralis major', 'biceps brachii', 'triceps', 'trapezius', 'gastrocnemius', 'rhomboid']:
    print('==', pat)
    for o in d['objects']:
        if o['type'] == 'MESH' and re.search(pat, o['name'], re.I):
            print(' ', o['name'], o['center'], o['modifiers'], o['collections'])
EOF
```
Record in `tools/body_model/README.md`:
1. Left/right suffix convention (expected `.l`/`.r`) and whether `.l` objects have center x > 0 (character's left = Blender +X). If the sign is opposite, note it — Task 2's side split depends on it.
2. Which target heads already exist as separate objects (deltoid parts, pectoralis major heads, biceps/triceps heads, trapezius parts, gastrocnemius heads) and which need a plane split.
3. Whether muscles carry modifiers (e.g. MIRROR) — Task 2 bakes modifiers either way.
4. Collection names holding the skeleton, skin/head, and muscles (for context groups).

README skeleton (fill the bracketed facts from Steps 1–5 — they are measurements, not decisions):

```markdown
# body_model

Builds `assets/body_viewer/body.glb` from Z-Anatomy (CC BY-SA 4.0,
https://github.com/Z-Anatomy/The-blend). The source `.blend` is not committed.

## Source
- Zip: https://github.com/Z-Anatomy/The-blend/raw/main/Z-Anatomy.zip
- Downloaded: [date], SHA-256: [hash]
- Blend inside zip: [relative path to startup.blend]

## Tools
- Blender [version] at [path]
- gltfpack 1.3.0 (`npm i -g gltfpack@1.3.0`)

## Findings
- Side suffix: [.l/.r], `.l` center x sign: [+/-]
- Heads already separate: [...]
- Heads needing plane splits: [...]
- Modifiers on muscles: [...]
- Context collections: [...]

## Rebuild
(filled in Task 2)
```

- [ ] **Step 6: Commit**

```bash
echo 'tools/body_model/out/' >> .gitignore
git add .gitignore tools/body_model/inventory.py tools/body_model/README.md
git commit -m "Add Z-Anatomy inventory script for the muscle map model

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Build pipeline → `body.glb`

**Files:**
- Create: `tools/body_model/mesh_map.json`
- Create: `tools/body_model/build_glb.py`
- Create: `assets/body_viewer/body.glb`
- Modify: `tools/body_model/README.md` (Rebuild section, final deep list)
- Modify: `docs/superpowers/specs/2026-10-12-muscle-map-design.md` (only if the muscle list or deep flags change)

**Interfaces:**
- Consumes: `tools/body_model/out/inventory.json` (Task 1).
- Produces: `assets/body_viewer/body.glb` with node names `<muscleId>__L|R` for every non-deep muscle and `_ctx_<group>` for context; `mesh_map.json` `muscles[id].deep` is the source of truth for `deep` flags in Task 6.

- [ ] **Step 1: Write `tools/body_model/mesh_map.json`**

Shape (every one of the 49 ids from the spec must be a key):

```json
{
  "decimate": 0.3,
  "muscles": {
    "deltoid_anterior": { "sources": ["<Z name>.l", "<Z name>.r"] },
    "biceps_long": {
      "sources": ["<Biceps brachii object>.l", "<...>.r"],
      "split": [{ "co": [0.0, 0.0, 0.0], "no": [1.0, 0.0, 0.0], "keep": "positive" }]
    },
    "pec_minor": { "deep": true },
    "rectus_abdominis": { "sources": ["<...>"], "decimate": 0.5 }
  },
  "context": {
    "skeleton": { "collections": ["<skeleton collection>"], "patterns": [], "decimate": 0.15 },
    "head_hands_feet": { "collections": [], "patterns": ["<regex>"], "decimate": 0.2 },
    "other_muscles": { "collections": ["<muscle collection>"], "patterns": [], "decimate": 0.2 }
  }
}
```

Rules:
- `sources` are exact Z-Anatomy object names from `inventory.json`. Use this search table (case-insensitive regex over names) to find them:

| id | search | note |
|---|---|---|
| pec_major_clavicular / pec_major_sternocostal | `pectoralis major` | clavicular vs sternocostal (+abdominal → sternocostal) |
| pec_minor | `pectoralis minor` | deep |
| serratus_anterior | `serratus anterior` | |
| deltoid_anterior / lateral / posterior | `deltoid` | clavicular / acromial / spinal parts |
| supraspinatus, infraspinatus, teres_minor, subscapularis, teres_major | same words | supraspinatus & subscapularis deep |
| trapezius_upper / middle / lower | `trapezius` | descending / transverse / ascending parts; split if single |
| rhomboids | `rhomboid` | major+minor → one id; deep |
| latissimus_dorsi | `latissimus` | |
| erector_spinae | `iliocostalis\|longissimus\|spinalis` | all superficial parts → one id |
| biceps_long / biceps_short | `biceps brachii` | split if single |
| brachialis, brachioradialis | same | |
| triceps_long / lateral / medial | `triceps` | medial deep |
| forearm_flexors | `flexor carpi\|flexor digitorum\|palmaris longus\|pronator teres` | merge |
| forearm_extensors | `extensor carpi\|extensor digitorum\|extensor digiti` | merge |
| rectus_abdominis | `rectus abdominis` | |
| external_oblique / internal_oblique | `oblique` | internal deep |
| transversus_abdominis | `transversus abdominis` | deep |
| gluteus_maximus / medius / minimus | `gluteus` | minimus deep |
| hip_adductors | `adductor\|gracilis\|pectineus` | merge |
| iliopsoas | `iliacus\|psoas` | deep |
| tensor_fasciae_latae | `tensor fasciae` | |
| rectus_femoris, vastus_lateralis, vastus_medialis, vastus_intermedius | same | intermedius deep |
| biceps_femoris, semitendinosus, semimembranosus | same | |
| gastrocnemius_medial / lateral | `gastrocnemius` | split if single |
| soleus, tibialis_anterior, sternocleidomastoid | same | |

- `split` planes are given in **left-side** world coordinates (Blender, meters); the script mirrors them for the right side. `keep: "positive"` keeps geometry on the side the normal points to. Pick planes by reading the source object's center/size in `inventory.json`, rebuild, and inspect in Task 4's standalone viewer; iterate.
- A muscle is `"deep": true` (no sources) when it cannot be seen from outside. Start with the spec's `*` list; drop the flag where Z-Anatomy shows it clearly (e.g. rhomboids visible at the trapezius border).
- Context groups gather non-tappable geometry so the body looks complete: skeleton (visible parts), head/face, hands, feet, tendons, and every muscle object not used above.

- [ ] **Step 2: Write `tools/body_model/build_glb.py`**

```python
"""Build the raw muscle-map GLB from a Z-Anatomy .blend using mesh_map.json.

Usage:
  blender -b <startup.blend> -P tools/body_model/build_glb.py -- <out.glb>

Every muscle side becomes one mesh object named `<muscleId>__L` / `__R`
(character's left = +X, facing -Y). Context geometry is merged per group
into `_ctx_<group>`. Fails (exit 1) if any non-deep muscle ends up empty.
"""
import json
import os
import re
import sys

import bmesh
import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
with open(os.path.join(HERE, 'mesh_map.json'), encoding='utf-8') as f:
    CONFIG = json.load(f)
EPS = 1e-4


def out_path():
    argv = sys.argv
    if '--' not in argv or len(argv) <= argv.index('--') + 1:
        sys.exit('usage: blender -b file.blend -P build_glb.py -- out.glb')
    return os.path.abspath(argv[argv.index('--') + 1])


def ensure_evaluable(objs):
    """Link objects into the scene and unhide them so the depsgraph evaluates modifiers."""
    scene_objs = set(bpy.context.view_layer.objects)
    for obj in objs:
        if obj not in scene_objs:
            bpy.context.scene.collection.objects.link(obj)
        obj.hide_viewport = False
        obj.hide_set(False)
    bpy.context.view_layer.update()


def baked_mesh(obj):
    """Copy of obj's evaluated mesh with world transform applied."""
    depsgraph = bpy.context.evaluated_depsgraph_get()
    mesh = bpy.data.meshes.new_from_object(obj.evaluated_get(depsgraph), depsgraph=depsgraph)
    mesh.transform(obj.matrix_world)
    return mesh


def bisect(mesh, co, no, keep_positive):
    bm = bmesh.new()
    bm.from_mesh(mesh)
    geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
    res = bmesh.ops.bisect_plane(
        bm, geom=geom, plane_co=co, plane_no=no,
        clear_inner=keep_positive, clear_outer=not keep_positive,
    )
    cut = [e for e in res['geom_cut'] if isinstance(e, bmesh.types.BMEdge)]
    if cut:
        bmesh.ops.holes_fill(bm, edges=cut, sides=0)
    bm.to_mesh(mesh)
    bm.free()
    return mesh


def split_sides(mesh):
    """Return [(side, mesh)], cutting at x=0 when the mesh spans the midline."""
    xs = [v.co.x for v in mesh.vertices]
    if not xs:
        return []
    if min(xs) > -EPS:
        return [('L', mesh)]
    if max(xs) < EPS:
        return [('R', mesh)]
    right = mesh.copy()
    bisect(mesh, (0, 0, 0), (1, 0, 0), True)
    bisect(right, (0, 0, 0), (1, 0, 0), False)
    return [('L', mesh), ('R', right)]


def apply_splits(mesh, side, planes):
    for p in planes:
        co, no = list(p['co']), list(p['no'])
        if side == 'R':
            co[0], no[0] = -co[0], -no[0]
        bisect(mesh, co, no, p.get('keep', 'positive') == 'positive')
    return mesh


def merge(name, meshes):
    verts, faces = [], []
    for m in meshes:
        off = len(verts)
        verts.extend(v.co.copy() for v in m.vertices)
        faces.extend([off + i for i in poly.vertices] for poly in m.polygons)
    out = bpy.data.meshes.new(name)
    out.from_pydata(verts, [], faces)
    for poly in out.polygons:
        poly.use_smooth = True
    out.update()
    return out


def decimated(obj, ratio):
    if ratio >= 1:
        return
    mod = obj.modifiers.new('decimate', 'DECIMATE')
    mod.ratio = ratio
    depsgraph = bpy.context.evaluated_depsgraph_get()
    mesh = bpy.data.meshes.new_from_object(obj.evaluated_get(depsgraph), depsgraph=depsgraph)
    obj.modifiers.clear()
    obj.data = mesh


def material(name, rgba):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.diffuse_color = rgba
    return mat


def new_object(name, mesh, mat, ratio, out_coll):
    obj = bpy.data.objects.new(name, mesh)
    out_coll.objects.link(obj)
    bpy.context.view_layer.update()
    decimated(obj, ratio)
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    return obj


def collection_objects(name):
    coll = bpy.data.collections.get(name)
    if coll is None:
        sys.exit(f'build_glb: collection not found: {name}')
    return [o for o in coll.all_objects if o.type == 'MESH']


def main():
    default_ratio = CONFIG.get('decimate', 0.3)
    out_coll = bpy.data.collections.new('muscle_map_export')
    bpy.context.scene.collection.children.link(out_coll)
    muscle_mat = material('muscle', (0.79, 0.54, 0.53, 1))
    ctx_mat = material('context', (0.73, 0.68, 0.64, 1))

    missing, used, built = [], set(), {}
    for mid, spec in CONFIG['muscles'].items():
        if spec.get('deep'):
            continue
        sources = []
        for name in spec.get('sources', []):
            obj = bpy.data.objects.get(name)
            if obj is None or obj.type != 'MESH':
                missing.append(f'{mid}: {name}')
                continue
            sources.append(obj)
            used.add(obj.name)
        ensure_evaluable(sources)
        by_side = {'L': [], 'R': []}
        for obj in sources:
            for side, mesh in split_sides(baked_mesh(obj)):
                by_side[side].append(apply_splits(mesh, side, spec.get('split', [])))
        built[mid] = []
        for side, meshes in by_side.items():
            meshes = [m for m in meshes if len(m.polygons)]
            if meshes:
                name = f'{mid}__{side}'
                built[mid].append(new_object(name, merge(name, meshes), muscle_mat,
                                             spec.get('decimate', default_ratio), out_coll))

    if missing:
        sys.exit('build_glb: missing source objects:\n  ' + '\n  '.join(missing))

    for group, spec in CONFIG.get('context', {}).items():
        objs = []
        for cname in spec.get('collections', []):
            objs.extend(collection_objects(cname))
        pats = [re.compile(p, re.I) for p in spec.get('patterns', [])]
        if pats:
            objs.extend(o for o in bpy.data.objects
                        if o.type == 'MESH' and any(p.search(o.name) for p in pats))
        objs = [o for o in dict.fromkeys(objs) if o.name not in used and o.users_collection
                and o.users_collection[0] is not out_coll]
        ensure_evaluable(objs)
        meshes = [baked_mesh(o) for o in objs]
        used.update(o.name for o in objs)
        if meshes:
            name = f'_ctx_{group}'
            new_object(name, merge(name, meshes), ctx_mat, spec.get('decimate', default_ratio), out_coll)

    empty = [mid for mid, objs in built.items() if not objs]
    if empty:
        sys.exit('build_glb: non-deep muscles produced no geometry: ' + ', '.join(empty))

    for obj in bpy.context.view_layer.objects:
        obj.select_set(False)
    tris = 0
    for obj in out_coll.objects:
        obj.select_set(True)
        obj.data.calc_loop_triangles()
        tris += len(obj.data.loop_triangles)

    bpy.ops.export_scene.gltf(
        filepath=out_path(),
        export_format='GLB',
        use_selection=True,
        export_yup=True,
        export_texcoords=False,
        export_animations=False,
    )
    print(f'build_glb: {len(out_coll.objects)} objects, {tris} triangles')
    for mid, objs in sorted(built.items()):
        print(f'  {mid}: {[o.name for o in objs]}')


main()
```

If the exporter rejects a keyword, list valid ones with
`blender -b --python-expr "import bpy;print(bpy.ops.export_scene.gltf.get_rna_type().properties.keys())"` and adjust.

- [ ] **Step 3: Build and compress**

```bash
blender -b ~/Z-Anatomy/template/<path>/startup.blend -P tools/body_model/build_glb.py -- tools/body_model/out/body_raw.glb
mkdir -p assets/body_viewer
gltfpack -i tools/body_model/out/body_raw.glb -o assets/body_viewer/body.glb -cc -kn -km
ls -lh assets/body_viewer/body.glb
```
Expected: `build_glb: N objects, T triangles` with T ≈ 150k (tune `decimate` values until within ±30k) and a file ≤ 4 MB. `-kn` keeps named nodes so mesh names survive.

- [ ] **Step 4: Verify node names**

```bash
node -e '
const b=require("fs").readFileSync("assets/body_viewer/body.glb");
const len=b.readUInt32LE(12); const j=JSON.parse(b.subarray(20,20+len).toString());
const names=j.nodes.map(n=>n.name).filter(Boolean).sort(); console.log(names.join("\n"));'
```
Expected: `<id>__L` and `<id>__R` for every non-deep id plus `_ctx_*` names. Fix the map and rebuild until true. Head-split quality is checked visually in Task 4; come back here to tune planes.

- [ ] **Step 5: Fill in README "Rebuild" + final deep list; update spec if the muscle list changed**

README "Rebuild" section:

```markdown
## Rebuild
1. `blender -b <startup.blend> -P tools/body_model/build_glb.py -- tools/body_model/out/body_raw.glb`
2. `gltfpack -i tools/body_model/out/body_raw.glb -o assets/body_viewer/body.glb -cc -kn -km`
3. `flutter test test/features/muscles/body_model_test.dart`

Deep muscles (no mesh): [final list from mesh_map.json]
```
If any id was added/removed or a `deep` flag changed vs. the spec's table, edit the spec's "Muscle list" table to match and mention it in the commit message.

- [ ] **Step 6: Commit**

```bash
git add tools/body_model/mesh_map.json tools/body_model/build_glb.py tools/body_model/README.md assets/body_viewer/body.glb docs/superpowers/specs/2026-10-12-muscle-map-design.md
git commit -m "Build muscle map body.glb from Z-Anatomy

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Vendor three.js and pure viewer logic

**Files:**
- Create: `assets/body_viewer/vendor/three.module.min.js`
- Create: `assets/body_viewer/vendor/addons/loaders/GLTFLoader.js`
- Create: `assets/body_viewer/vendor/addons/utils/BufferGeometryUtils.js`
- Create: `assets/body_viewer/vendor/addons/controls/OrbitControls.js`
- Create: `assets/body_viewer/vendor/addons/libs/meshopt_decoder.module.js`
- Create: `assets/body_viewer/vendor/LICENSE` (three.js MIT license)
- Create: `assets/body_viewer/viewer_core.js`
- Test: `test/js/viewer_core.test.js`

**Interfaces:**
- Produces (ES module exports of `viewer_core.js`, used by Task 4):
  - `CONTEXT_PREFIX: string` (`'_ctx_'`)
  - `muscleIdFromName(name: string): string | null`
  - `isTap(dx: number, dy: number, dtMs: number): boolean`
  - `class TapTracker { down(id, x, y, t); up(id, x, y, t): boolean; cancel(id) }` — returns true from `up` only for a single-pointer tap
  - `facingAngle(cx: number, cz: number): number` (radians; 0 = front/+Z, π = back)
  - `orbitPosition(angle: number, target: [x,y,z], distance: number): [x,y,z]`

- [ ] **Step 1: Vendor three.js 0.170.0**

```bash
cd "$(mktemp -d)" && npm pack three@0.170.0 && tar xzf three-0.170.0.tgz && P=$PWD/package && cd -
V=assets/body_viewer/vendor
mkdir -p $V/addons/loaders $V/addons/utils $V/addons/controls $V/addons/libs
cp $P/build/three.module.min.js $V/
cp $P/examples/jsm/loaders/GLTFLoader.js $V/addons/loaders/
cp $P/examples/jsm/utils/BufferGeometryUtils.js $V/addons/utils/
cp $P/examples/jsm/controls/OrbitControls.js $V/addons/controls/
cp $P/examples/jsm/libs/meshopt_decoder.module.js $V/addons/libs/
cp $P/LICENSE $V/LICENSE
grep -h "^import" $V/addons/*/*.js | sort -u
```
Expected imports are only `'three'` and `'../utils/BufferGeometryUtils.js'`. If any other relative import appears, copy that file too, keeping the same relative path.

- [ ] **Step 2: Write the failing tests `test/js/viewer_core.test.js`**

```js
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
```

- [ ] **Step 3: Run to verify failure**

Run: `node --test test/js/`
Expected: FAIL — `Cannot find module .../assets/body_viewer/viewer_core.js`.

- [ ] **Step 4: Implement `assets/body_viewer/viewer_core.js`**

```js
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
```

- [ ] **Step 5: Run to verify pass**

Run: `node --test test/js/`
Expected: all 9 tests pass.

- [ ] **Step 6: Commit**

```bash
git add assets/body_viewer/vendor assets/body_viewer/viewer_core.js test/js/viewer_core.test.js
git commit -m "Vendor three.js 0.170.0 and add pure viewer helpers

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Standalone three.js viewer

**Files:**
- Create: `assets/body_viewer/index.html`
- Create: `assets/body_viewer/viewer.js`

**Interfaces:**
- Consumes: `viewer_core.js` exports (Task 3), `body.glb` (Task 2).
- Produces (used by Task 10 via `evaluateJavascript`): `window.viewer.select(id)`, `.highlight({primary: string[], secondary: string[]})`, `.clear()`, `.setView('front'|'back')`, `.resetView()`. Messages posted via `window.flutter_inappwebview.callHandler('viewer', msg)`: `{type:'ready'}`, `{type:'muscleTapped', id}`, `{type:'backgroundTapped'}`, `{type:'error', message}`. With `?standalone` in the URL, messages go to `console.log('[viewer]', json)` and taps select locally.

- [ ] **Step 1: Write `assets/body_viewer/index.html`**

```html
<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
  <style>
    html, body { margin: 0; height: 100%; overflow: hidden; background: #FAF6F0;
      touch-action: none; -webkit-user-select: none; user-select: none; }
    canvas { display: block; }
  </style>
  <script type="importmap">
    { "imports": { "three": "./vendor/three.module.min.js", "three/addons/": "./vendor/addons/" } }
  </script>
</head>
<body>
  <script type="module" src="./viewer.js"></script>
</body>
</html>
```

- [ ] **Step 2: Write `assets/body_viewer/viewer.js`**

```js
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

function resolveId(obj) {
  for (let n = obj; n; n = n.parent) {
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
  const active = primary.size + secondary.size > 0;
  for (const [id, meshes] of muscleMeshes) {
    const hex = primary.has(id) ? COLORS.primary : secondary.has(id) ? COLORS.secondary : COLORS.muscle;
    for (const m of meshes) {
      m.material.color.setHex(hex);
      if (active && hex === COLORS.muscle) m.material.color.lerp(DIM_TOWARD, DIM_AMOUNT);
    }
  }
  requestRender();
}

function select(id) {
  primary = new Set([id]);
  secondary = new Set();
  applyColors();
  focus(id);
}

function highlight({ primary: p = [], secondary: s = [] } = {}) {
  primary = new Set(p);
  secondary = new Set(s.filter((id) => !primary.has(id)));
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
```

- [ ] **Step 3: Verify in a desktop browser**

```bash
cd assets/body_viewer && python3 -m http.server 8765
```
Open `http://localhost:8765/index.html?standalone` (Chrome; use DevTools device toolbar at 390×844). Checklist — all must hold:
1. Body appears centered on a cream background within ~1 s; console shows `[viewer] {"type":"ready"}`.
2. Drag rotates around the vertical axis; vertical tilt stops at the limits; pinch/wheel zooms within limits; no panning.
3. Clicking each muscle listed in `mesh_map.json` logs `muscleTapped` with the right id, both sides, colors it terracotta, dims others, and turns the camera toward it (back muscles → camera behind).
4. Clicking context geometry or empty space logs `backgroundTapped` and clears colors.
5. A drag that ends on a muscle does **not** log `muscleTapped`.
6. In the console: `viewer.highlight({primary:['pec_major_clavicular'],secondary:['deltoid_anterior']})` shows strong/light terracotta; `viewer.setView('back')` and `viewer.resetView()` animate; `viewer.select('pec_minor')` (deep) does nothing visible and throws no error.
7. Head splits look anatomically sensible (biceps heads, trapezius parts, gastrocnemius heads, etc.). If not, tune planes in `mesh_map.json`, rebuild (Task 2 Step 3), and recheck.

Stop the server with Ctrl-C.

- [ ] **Step 4: Commit**

```bash
git add assets/body_viewer/index.html assets/body_viewer/viewer.js
git commit -m "Add three.js muscle viewer page

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```
(If Step 3.7 changed `mesh_map.json`/`body.glb`, include them in this commit.)

---

### Task 5: Content models

**Files:**
- Create: `lib/models/localized_text.dart`
- Create: `lib/models/muscle.dart`
- Create: `lib/models/exercise.dart`
- Test: `test/models/muscle_models_test.dart`

**Interfaces:**
- Produces:
  - `LocalizedText({required String en, String? th})`, `.fromJson(Map<String,dynamic>)`, `String resolve(Locale)`, fields `en`, `th`
  - `LocalizedList({required List<String> en, List<String>? th})`, `.fromJson`, `List<String> resolve(Locale)`, fields `en`, `th`
  - `enum MuscleGroup { chest, shoulders, back, arms, core, hips, thighs, lowerLegs, neck }` with `String jsonName` and `static MuscleGroup fromJson(String)`
  - `Muscle({required String id, required MuscleGroup group, bool deep = false, required LocalizedText name, required String anatomical, required LocalizedText description})`, `.fromJson`
  - `enum Equipment { bodyweight, dumbbell, barbell, cable, machine, kettlebell, band }`
  - `enum Difficulty { beginner, intermediate, advanced }`
  - `Exercise({required String id, required LocalizedText name, required Equipment equipment, required Difficulty difficulty, required List<String> primary, List<String> secondary = const [], required LocalizedList steps, required LocalizedList tips, required LocalizedList mistakes})`, `.fromJson`

- [ ] **Step 1: Write the failing tests `test/models/muscle_models_test.dart`**

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_diary/models/exercise.dart';
import 'package:food_diary/models/localized_text.dart';
import 'package:food_diary/models/muscle.dart';

void main() {
  const en = Locale('en');
  const th = Locale('th');

  group('LocalizedText', () {
    test('resolves by language code', () {
      final t = LocalizedText.fromJson({'en': 'Chest', 'th': 'อก'});
      expect(t.resolve(en), 'Chest');
      expect(t.resolve(th), 'อก');
      expect(t.resolve(const Locale('th', 'TH')), 'อก');
    });

    test('falls back to English when Thai is empty or missing', () {
      expect(LocalizedText.fromJson({'en': 'Chest', 'th': ''}).resolve(th), 'Chest');
      expect(LocalizedText.fromJson({'en': 'Chest'}).resolve(th), 'Chest');
    });
  });

  group('LocalizedList', () {
    test('resolves and falls back', () {
      final l = LocalizedList.fromJson({
        'en': ['a', 'b'],
        'th': ['ก', 'ข'],
      });
      expect(l.resolve(th), ['ก', 'ข']);
      expect(l.resolve(en), ['a', 'b']);
      expect(LocalizedList.fromJson({'en': ['a'], 'th': <String>[]}).resolve(th), ['a']);
    });
  });

  test('Muscle.fromJson parses all fields', () {
    final m = Muscle.fromJson({
      'id': 'gastrocnemius_medial',
      'group': 'lower_legs',
      'deep': false,
      'name': {'en': 'Inner calf', 'th': 'น่องด้านใน'},
      'anatomical': 'Gastrocnemius, medial head',
      'description': {'en': 'Plantar-flexes the ankle.', 'th': 'เหยียดปลายเท้า'},
    });
    expect(m.id, 'gastrocnemius_medial');
    expect(m.group, MuscleGroup.lowerLegs);
    expect(m.deep, isFalse);
    expect(m.name.resolve(const Locale('th')), 'น่องด้านใน');
    expect(m.anatomical, 'Gastrocnemius, medial head');
  });

  test('Muscle.fromJson defaults deep to false and rejects unknown groups', () {
    final base = {
      'id': 'x',
      'group': 'chest',
      'name': {'en': 'X'},
      'anatomical': 'X',
      'description': {'en': 'X'},
    };
    expect(Muscle.fromJson(base).deep, isFalse);
    expect(
      () => Muscle.fromJson({...base, 'group': 'tail'}),
      throwsFormatException,
    );
  });

  test('Exercise.fromJson parses all fields', () {
    final e = Exercise.fromJson({
      'id': 'push_up',
      'name': {'en': 'Push-up', 'th': 'วิดพื้น'},
      'equipment': 'bodyweight',
      'difficulty': 'beginner',
      'primary': ['pec_major_sternocostal'],
      'secondary': ['triceps_lateral'],
      'steps': {'en': ['1', '2', '3'], 'th': ['๑', '๒', '๓']},
      'tips': {'en': ['t'], 'th': ['ท']},
      'mistakes': {'en': ['m'], 'th': ['ม']},
    });
    expect(e.equipment, Equipment.bodyweight);
    expect(e.difficulty, Difficulty.beginner);
    expect(e.primary, ['pec_major_sternocostal']);
    expect(e.secondary, ['triceps_lateral']);
    expect(e.steps.resolve(const Locale('th')), ['๑', '๒', '๓']);
  });

  test('Exercise.fromJson defaults secondary to empty', () {
    final e = Exercise.fromJson({
      'id': 'heel_walk',
      'name': {'en': 'Heel Walk'},
      'equipment': 'bodyweight',
      'difficulty': 'beginner',
      'primary': ['tibialis_anterior'],
      'steps': {'en': ['1', '2', '3']},
      'tips': {'en': ['t']},
      'mistakes': {'en': ['m']},
    });
    expect(e.secondary, isEmpty);
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/models/muscle_models_test.dart`
Expected: FAIL — compile errors, `localized_text.dart` not found.

- [ ] **Step 3: Implement `lib/models/localized_text.dart`**

```dart
import 'dart:ui';

/// Bundled content text that carries its own English and Thai versions.
/// Thai is used for a `th` locale when present and non-empty; otherwise
/// English.
class LocalizedText {
  const LocalizedText({required this.en, this.th});

  final String en;
  final String? th;

  factory LocalizedText.fromJson(Map<String, dynamic> json) =>
      LocalizedText(en: json['en'] as String, th: json['th'] as String?);

  String resolve(Locale locale) {
    final thai = th;
    return locale.languageCode == 'th' && thai != null && thai.isNotEmpty
        ? thai
        : en;
  }
}

/// List counterpart of [LocalizedText] (steps, tips, mistakes).
class LocalizedList {
  const LocalizedList({required this.en, this.th});

  final List<String> en;
  final List<String>? th;

  factory LocalizedList.fromJson(Map<String, dynamic> json) => LocalizedList(
    en: (json['en'] as List).cast<String>(),
    th: (json['th'] as List?)?.cast<String>(),
  );

  List<String> resolve(Locale locale) {
    final thai = th;
    return locale.languageCode == 'th' && thai != null && thai.isNotEmpty
        ? thai
        : en;
  }
}
```

- [ ] **Step 4: Implement `lib/models/muscle.dart`**

```dart
import 'localized_text.dart';

enum MuscleGroup {
  chest('chest'),
  shoulders('shoulders'),
  back('back'),
  arms('arms'),
  core('core'),
  hips('hips'),
  thighs('thighs'),
  lowerLegs('lower_legs'),
  neck('neck');

  const MuscleGroup(this.jsonName);
  final String jsonName;

  static MuscleGroup fromJson(String value) => values.firstWhere(
    (g) => g.jsonName == value,
    orElse: () => throw FormatException('Unknown muscle group: $value'),
  );
}

class Muscle {
  const Muscle({
    required this.id,
    required this.group,
    this.deep = false,
    required this.name,
    required this.anatomical,
    required this.description,
  });

  final String id;
  final MuscleGroup group;

  /// True when the muscle has no mesh in the 3D model (not visible from
  /// outside); it is reachable from the muscle list only.
  final bool deep;
  final LocalizedText name;
  final String anatomical;
  final LocalizedText description;

  factory Muscle.fromJson(Map<String, dynamic> json) => Muscle(
    id: json['id'] as String,
    group: MuscleGroup.fromJson(json['group'] as String),
    deep: json['deep'] as bool? ?? false,
    name: LocalizedText.fromJson(json['name'] as Map<String, dynamic>),
    anatomical: json['anatomical'] as String,
    description: LocalizedText.fromJson(
      json['description'] as Map<String, dynamic>,
    ),
  );
}
```

- [ ] **Step 5: Implement `lib/models/exercise.dart`**

```dart
import 'localized_text.dart';

enum Equipment { bodyweight, dumbbell, barbell, cable, machine, kettlebell, band }

enum Difficulty { beginner, intermediate, advanced }

class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.equipment,
    required this.difficulty,
    required this.primary,
    this.secondary = const [],
    required this.steps,
    required this.tips,
    required this.mistakes,
  });

  final String id;
  final LocalizedText name;
  final Equipment equipment;
  final Difficulty difficulty;

  /// Muscle ids this exercise mainly trains.
  final List<String> primary;

  /// Muscle ids that assist.
  final List<String> secondary;
  final LocalizedList steps;
  final LocalizedList tips;
  final LocalizedList mistakes;

  factory Exercise.fromJson(Map<String, dynamic> json) => Exercise(
    id: json['id'] as String,
    name: LocalizedText.fromJson(json['name'] as Map<String, dynamic>),
    equipment: Equipment.values.byName(json['equipment'] as String),
    difficulty: Difficulty.values.byName(json['difficulty'] as String),
    primary: (json['primary'] as List).cast<String>(),
    secondary: (json['secondary'] as List?)?.cast<String>() ?? const [],
    steps: LocalizedList.fromJson(json['steps'] as Map<String, dynamic>),
    tips: LocalizedList.fromJson(json['tips'] as Map<String, dynamic>),
    mistakes: LocalizedList.fromJson(json['mistakes'] as Map<String, dynamic>),
  );
}
```

- [ ] **Step 6: Run to verify pass**

Run: `flutter test test/models/muscle_models_test.dart`
Expected: all tests pass.

- [ ] **Step 7: Commit**

```bash
git add lib/models/localized_text.dart lib/models/muscle.dart lib/models/exercise.dart test/models/muscle_models_test.dart
git commit -m "Add muscle and exercise content models

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Muscle catalog, `muscles.json`, integrity and model tests

**Files:**
- Create: `lib/features/muscles/muscle_catalog.dart`
- Create: `assets/muscles/muscles.json`
- Create: `assets/muscles/exercises.json` (as `[]`)
- Modify: `pubspec.yaml` (assets)
- Test: `test/features/muscles/muscle_catalog_test.dart`
- Test: `test/features/muscles/catalog_integrity_test.dart`
- Test: `test/features/muscles/body_model_test.dart`

**Interfaces:**
- Consumes: Task 5 models; `tools/body_model/mesh_map.json` deep flags (Task 2).
- Produces:
  - `MuscleCatalog({required List<Muscle> muscles, required List<Exercise> exercises})`
  - `factory MuscleCatalog.fromJsonStrings(String musclesJson, String exercisesJson)`
  - `static Future<MuscleCatalog> load(AssetBundle bundle)`
  - `List<Muscle> muscles`, `List<Exercise> exercises`
  - `Muscle? muscleById(String id)`
  - `List<Exercise> exercisesFor(String muscleId)` — primary-role exercises first, then secondary, each in file order
  - `List<Muscle> search(String query)` — case-insensitive substring over `name.en`, `name.th`, `anatomical`, `id`; empty/blank query returns all; result in file order
  - `test/features/muscles/catalog_integrity_test.dart` contains `const authoredGroups = <String>{...}` extended by Tasks 7–9 and removed in Task 9

- [ ] **Step 1: Write the failing unit tests `test/features/muscles/muscle_catalog_test.dart`**

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:food_diary/features/muscles/muscle_catalog.dart';

Map<String, dynamic> _muscle(String id, String en, String th, String anat) => {
  'id': id,
  'group': 'chest',
  'name': {'en': en, 'th': th},
  'anatomical': anat,
  'description': {'en': 'd', 'th': 'ด'},
};

Map<String, dynamic> _exercise(String id, List<String> p, List<String> s) => {
  'id': id,
  'name': {'en': id, 'th': id},
  'equipment': 'bodyweight',
  'difficulty': 'beginner',
  'primary': p,
  'secondary': s,
  'steps': {'en': ['1', '2', '3'], 'th': ['1', '2', '3']},
  'tips': {'en': ['t'], 'th': ['t']},
  'mistakes': {'en': ['m'], 'th': ['m']},
};

void main() {
  final catalog = MuscleCatalog.fromJsonStrings(
    jsonEncode([
      _muscle('pec_major_clavicular', 'Upper chest', 'อกบน', 'Pectoralis major, clavicular head'),
      _muscle('deltoid_anterior', 'Front delt', 'ไหล่หน้า', 'Deltoid, clavicular part'),
    ]),
    jsonEncode([
      _exercise('a_secondary', ['deltoid_anterior'], ['pec_major_clavicular']),
      _exercise('b_primary', ['pec_major_clavicular'], []),
      _exercise('c_unrelated', ['deltoid_anterior'], []),
      _exercise('d_primary', ['pec_major_clavicular', 'deltoid_anterior'], []),
    ]),
  );

  test('muscleById finds known ids and returns null otherwise', () {
    expect(catalog.muscleById('deltoid_anterior')!.name.en, 'Front delt');
    expect(catalog.muscleById('nope'), isNull);
  });

  test('exercisesFor lists primary first, then secondary, in file order', () {
    expect(
      catalog.exercisesFor('pec_major_clavicular').map((e) => e.id),
      ['b_primary', 'd_primary', 'a_secondary'],
    );
    expect(catalog.exercisesFor('unknown'), isEmpty);
  });

  test('search matches English, Thai, anatomical name and id, case-insensitively', () {
    expect(catalog.search('upper').map((m) => m.id), ['pec_major_clavicular']);
    expect(catalog.search('ไหล่').map((m) => m.id), ['deltoid_anterior']);
    expect(catalog.search('PECTORALIS').map((m) => m.id), ['pec_major_clavicular']);
    expect(catalog.search('deltoid_').map((m) => m.id), ['deltoid_anterior']);
  });

  test('blank search returns every muscle', () {
    expect(catalog.search('  ').length, 2);
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/muscles/muscle_catalog_test.dart`
Expected: FAIL — `muscle_catalog.dart` not found.

- [ ] **Step 3: Implement `lib/features/muscles/muscle_catalog.dart`**

```dart
import 'dart:convert';

import 'package:flutter/services.dart';

import '../../models/exercise.dart';
import '../../models/muscle.dart';

/// All bundled muscle-map content, loaded once from JSON assets.
class MuscleCatalog {
  MuscleCatalog({
    required List<Muscle> muscles,
    required List<Exercise> exercises,
  }) : muscles = List.unmodifiable(muscles),
       exercises = List.unmodifiable(exercises),
       _byId = {for (final m in muscles) m.id: m};

  static const musclesAsset = 'assets/muscles/muscles.json';
  static const exercisesAsset = 'assets/muscles/exercises.json';

  final List<Muscle> muscles;
  final List<Exercise> exercises;
  final Map<String, Muscle> _byId;

  factory MuscleCatalog.fromJsonStrings(
    String musclesJson,
    String exercisesJson,
  ) => MuscleCatalog(
    muscles: (jsonDecode(musclesJson) as List)
        .map((j) => Muscle.fromJson(j as Map<String, dynamic>))
        .toList(),
    exercises: (jsonDecode(exercisesJson) as List)
        .map((j) => Exercise.fromJson(j as Map<String, dynamic>))
        .toList(),
  );

  static Future<MuscleCatalog> load(AssetBundle bundle) async =>
      MuscleCatalog.fromJsonStrings(
        await bundle.loadString(musclesAsset),
        await bundle.loadString(exercisesAsset),
      );

  Muscle? muscleById(String id) => _byId[id];

  List<Exercise> exercisesFor(String muscleId) => [
    ...exercises.where((e) => e.primary.contains(muscleId)),
    ...exercises.where(
      (e) => !e.primary.contains(muscleId) && e.secondary.contains(muscleId),
    ),
  ];

  List<Muscle> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return muscles;
    return muscles.where((m) {
      return [
        m.name.en,
        m.name.th ?? '',
        m.anatomical,
        m.id,
      ].any((s) => s.toLowerCase().contains(q));
    }).toList();
  }
}
```

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/features/muscles/muscle_catalog_test.dart`
Expected: all 4 tests pass.

- [ ] **Step 5: Write `assets/muscles/muscles.json`**

A JSON array with exactly one entry per id below, in this order. `deep` must equal `mesh_map.json` `muscles[id].deep` (true or absent → false). `description`: 1–2 sentences per language — where it is and what it does (action), written for a gym-goer. Thai uses natural gym Thai, not literal translation.

| id | group | en name | th name | anatomical |
|---|---|---|---|---|
| pec_major_clavicular | chest | Upper chest | อกบน | Pectoralis major, clavicular head |
| pec_major_sternocostal | chest | Mid & lower chest | อกกลางและล่าง | Pectoralis major, sternocostal head |
| pec_minor | chest | Pec minor | กล้ามอกเล็ก | Pectoralis minor |
| serratus_anterior | chest | Serratus anterior | กล้ามซี่โครงข้าง (เซอร์ราตัส) | Serratus anterior |
| deltoid_anterior | shoulders | Front delt | ไหล่หน้า | Deltoid, clavicular part |
| deltoid_lateral | shoulders | Side delt | ไหล่ข้าง | Deltoid, acromial part |
| deltoid_posterior | shoulders | Rear delt | ไหล่หลัง | Deltoid, spinal part |
| supraspinatus | shoulders | Supraspinatus | ซูปราสไปนาตัส (เอ็นหมุนไหล่) | Supraspinatus |
| infraspinatus | shoulders | Infraspinatus | อินฟราสไปนาตัส (เอ็นหมุนไหล่) | Infraspinatus |
| teres_minor | shoulders | Teres minor | เทเรสไมเนอร์ (เอ็นหมุนไหล่) | Teres minor |
| subscapularis | shoulders | Subscapularis | ซับสแคปพูลาริส (เอ็นหมุนไหล่) | Subscapularis |
| teres_major | shoulders | Teres major | เทเรสเมเจอร์ | Teres major |
| trapezius_upper | back | Upper traps | บ่า (ทราปส์บน) | Trapezius, descending part |
| trapezius_middle | back | Middle traps | ทราปส์กลาง | Trapezius, transverse part |
| trapezius_lower | back | Lower traps | ทราปส์ล่าง | Trapezius, ascending part |
| rhomboids | back | Rhomboids | รอมบอยด์ | Rhomboid major and minor |
| latissimus_dorsi | back | Lats | ปีก (แลต) | Latissimus dorsi |
| erector_spinae | back | Spinal erectors | กล้ามหลังล่าง (อีเรคเตอร์) | Erector spinae |
| biceps_long | arms | Biceps long head | ไบเซ็ปส์หัวยาว | Biceps brachii, long head |
| biceps_short | arms | Biceps short head | ไบเซ็ปส์หัวสั้น | Biceps brachii, short head |
| brachialis | arms | Brachialis | เบรเคียลิส | Brachialis |
| brachioradialis | arms | Brachioradialis | เบรคิโอเรเดียลิส | Brachioradialis |
| triceps_long | arms | Triceps long head | ไตรเซ็ปส์หัวยาว | Triceps brachii, long head |
| triceps_lateral | arms | Triceps lateral head | ไตรเซ็ปส์หัวด้านนอก | Triceps brachii, lateral head |
| triceps_medial | arms | Triceps medial head | ไตรเซ็ปส์หัวด้านใน | Triceps brachii, medial head |
| forearm_flexors | arms | Forearm flexors | กล้ามงอข้อมือ | Wrist and finger flexors |
| forearm_extensors | arms | Forearm extensors | กล้ามเหยียดข้อมือ | Wrist and finger extensors |
| rectus_abdominis | core | Abs | กล้ามหน้าท้อง (ซิกซ์แพ็ก) | Rectus abdominis |
| external_oblique | core | External obliques | กล้ามเอวด้านนอก | External abdominal oblique |
| internal_oblique | core | Internal obliques | กล้ามเอวด้านใน | Internal abdominal oblique |
| transversus_abdominis | core | Transverse abdominis | กล้ามท้องชั้นลึก | Transversus abdominis |
| gluteus_maximus | hips | Glutes | ก้น (กลูตแม็กซ์) | Gluteus maximus |
| gluteus_medius | hips | Glute medius | ก้นด้านข้าง (กลูตมีเดียส) | Gluteus medius |
| gluteus_minimus | hips | Glute minimus | กลูตมินิมัส | Gluteus minimus |
| hip_adductors | hips | Inner thigh | ต้นขาด้านใน (แอดดักเตอร์) | Adductor group |
| iliopsoas | hips | Hip flexors | กล้ามงอสะโพก (อิลิโอโซแอส) | Iliopsoas |
| tensor_fasciae_latae | hips | TFL | เทนเซอร์ฟาสเซียลาตา | Tensor fasciae latae |
| rectus_femoris | thighs | Rectus femoris | ต้นขาหน้าแนวกลาง | Rectus femoris |
| vastus_lateralis | thighs | Outer quad | ต้นขาหน้าด้านนอก | Vastus lateralis |
| vastus_medialis | thighs | Inner quad (teardrop) | ต้นขาหน้าด้านใน (หยดน้ำ) | Vastus medialis |
| vastus_intermedius | thighs | Vastus intermedius | ต้นขาหน้าชั้นลึก | Vastus intermedius |
| biceps_femoris | thighs | Outer hamstring | แฮมสตริงด้านนอก | Biceps femoris |
| semitendinosus | thighs | Semitendinosus | แฮมสตริงด้านใน (เซมิเทนดิโนซัส) | Semitendinosus |
| semimembranosus | thighs | Semimembranosus | แฮมสตริงด้านใน (เซมิเมมบราโนซัส) | Semimembranosus |
| gastrocnemius_medial | lower_legs | Inner calf | น่องด้านใน | Gastrocnemius, medial head |
| gastrocnemius_lateral | lower_legs | Outer calf | น่องด้านนอก | Gastrocnemius, lateral head |
| soleus | lower_legs | Soleus | น่องชั้นล่าง (โซเลียส) | Soleus |
| tibialis_anterior | lower_legs | Shin | หน้าแข้ง | Tibialis anterior |
| sternocleidomastoid | neck | Side neck (SCM) | กล้ามคอด้านข้าง | Sternocleidomastoid |

If Task 2 changed the muscle list, follow the updated spec table instead.

Create `assets/muscles/exercises.json` containing `[]`.

- [ ] **Step 6: Register assets in `pubspec.yaml`**

Under `flutter: assets:` (keep the existing `google_logo.svg` line). Flutter asset directories are not recursive, so each vendor folder is listed:

```yaml
  assets:
    - assets/icons/google_logo.svg
    - assets/muscles/
    - assets/body_viewer/
    - assets/body_viewer/vendor/
    - assets/body_viewer/vendor/addons/loaders/
    - assets/body_viewer/vendor/addons/utils/
    - assets/body_viewer/vendor/addons/controls/
    - assets/body_viewer/vendor/addons/libs/
```

- [ ] **Step 7: Write `test/features/muscles/catalog_integrity_test.dart`**

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:food_diary/features/muscles/muscle_catalog.dart';
import 'package:food_diary/models/localized_text.dart';
import 'package:food_diary/models/muscle.dart';

/// Groups whose exercise content is complete. Extended as content tasks land;
/// removed (checking every group) once all content exists.
const authoredGroups = <String>{};

void main() {
  final catalog = MuscleCatalog.fromJsonStrings(
    File(MuscleCatalog.musclesAsset).readAsStringSync(),
    File(MuscleCatalog.exercisesAsset).readAsStringSync(),
  );
  final idPattern = RegExp(r'^[a-z][a-z0-9_]*$');

  void expectText(LocalizedText t, String where) {
    expect(t.en.trim(), isNotEmpty, reason: '$where: en empty');
    expect(t.th?.trim() ?? '', isNotEmpty, reason: '$where: th missing');
  }

  void expectList(LocalizedList l, String where, int min, int max) {
    final th = l.th ?? const [];
    expect(l.en.length, inInclusiveRange(min, max), reason: '$where: en count');
    expect(th.length, l.en.length, reason: '$where: th count differs from en');
    for (final s in [...l.en, ...th]) {
      expect(s.trim(), isNotEmpty, reason: '$where: empty item');
    }
  }

  test('muscle ids are unique and well-formed', () {
    final ids = catalog.muscles.map((m) => m.id).toList();
    expect(ids.toSet().length, ids.length);
    for (final id in ids) {
      expect(idPattern.hasMatch(id), isTrue, reason: id);
    }
  });

  test('every muscle has both languages', () {
    for (final m in catalog.muscles) {
      expectText(m.name, '${m.id}.name');
      expectText(m.description, '${m.id}.description');
      expect(m.anatomical.trim(), isNotEmpty, reason: '${m.id}.anatomical');
    }
  });

  test('exercise ids are unique and reference known muscles', () {
    final ids = catalog.exercises.map((e) => e.id).toList();
    expect(ids.toSet().length, ids.length);
    for (final e in catalog.exercises) {
      expect(idPattern.hasMatch(e.id), isTrue, reason: e.id);
      expect(e.primary, isNotEmpty, reason: '${e.id}: no primary');
      for (final id in [...e.primary, ...e.secondary]) {
        expect(catalog.muscleById(id), isNotNull, reason: '${e.id} -> $id');
      }
      expect(
        e.primary.toSet().intersection(e.secondary.toSet()),
        isEmpty,
        reason: '${e.id}: muscle both primary and secondary',
      );
    }
  });

  test('every exercise has complete bilingual content', () {
    for (final e in catalog.exercises) {
      expectText(e.name, '${e.id}.name');
      expectList(e.steps, '${e.id}.steps', 3, 5);
      expectList(e.tips, '${e.id}.tips', 1, 99);
      expectList(e.mistakes, '${e.id}.mistakes', 1, 99);
    }
  });

  test('authored muscles have enough primary exercises', () {
    for (final m in catalog.muscles) {
      if (!authoredGroups.contains(m.group.jsonName)) continue;
      final count = catalog.exercises.where((e) => e.primary.contains(m.id)).length;
      expect(
        count,
        greaterThanOrEqualTo(m.deep ? 1 : 3),
        reason: '${m.id} has $count primary exercises',
      );
    }
  });

  test('muscle groups cover every MuscleGroup', () {
    expect(catalog.muscles.map((m) => m.group).toSet(), MuscleGroup.values.toSet());
  });
}
```

- [ ] **Step 8: Write `test/features/muscles/body_model_test.dart`**

```dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:food_diary/features/muscles/muscle_catalog.dart';

const _glbPath = 'assets/body_viewer/body.glb';

/// Node names from a GLB's JSON chunk.
List<String> glbNodeNames(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  expect(data.getUint32(0, Endian.little), 0x46546C67, reason: 'not a GLB');
  final jsonLength = data.getUint32(12, Endian.little);
  expect(data.getUint32(16, Endian.little), 0x4E4F534A, reason: 'first chunk is not JSON');
  final json = jsonDecode(utf8.decode(bytes.sublist(20, 20 + jsonLength)))
      as Map<String, dynamic>;
  return [
    for (final n in (json['nodes'] as List? ?? const []))
      if ((n as Map<String, dynamic>)['name'] case final String name) name,
  ];
}

void main() {
  final bytes = File(_glbPath).readAsBytesSync();
  final catalog = MuscleCatalog.fromJsonStrings(
    File(MuscleCatalog.musclesAsset).readAsStringSync(),
    File(MuscleCatalog.exercisesAsset).readAsStringSync(),
  );
  final meshIds = glbNodeNames(bytes)
      .where((n) => !n.startsWith('_ctx_') && n.contains('__'))
      .map((n) => n.split('__').first)
      .toSet();

  test('body.glb is at most 4 MB', () {
    expect(bytes.length, lessThanOrEqualTo(4 * 1024 * 1024));
  });

  test('every muscle mesh maps to a known muscle', () {
    for (final id in meshIds) {
      expect(catalog.muscleById(id), isNotNull, reason: 'mesh id $id');
    }
  });

  test('every non-deep muscle has a mesh and deep muscles have none', () {
    for (final m in catalog.muscles) {
      expect(meshIds.contains(m.id), !m.deep, reason: m.id);
    }
  });
}
```

- [ ] **Step 9: Run all three test files**

Run: `flutter test test/features/muscles/`
Expected: all pass (exercise checks pass vacuously on `[]`; `authoredGroups` is empty). If `body_model_test` fails, fix `muscles.json` `deep` flags to match `mesh_map.json`.

- [ ] **Step 10: Commit**

```bash
git add lib/features/muscles/muscle_catalog.dart assets/muscles pubspec.yaml test/features/muscles
git commit -m "Add muscle catalog, muscle data, and integrity tests

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Content Tasks 7–9: shared rules

Each content task appends entries to `assets/muscles/exercises.json` (keep the array in table order) and extends `authoredGroups`. For **every** row in the task's table write:

- `id`, `equipment`, `difficulty`, `primary`, `secondary` **exactly** as in the table.
- `name.en` = table name; `name.th` = the name Thai gym-goers actually use (transliteration in Thai script is fine, e.g. "เบนช์เพรส").
- `steps`: 3–5 short imperative steps (setup → movement → return), same count in both languages.
- `tips`: 1–3 cues that improve targeting of the primary muscle(s).
- `mistakes`: 1–3 common errors, phrased as what to avoid and why.
- Thai is written natively, not word-for-word; keep English exercise terms where Thai gyms do (เซ็ต, เรพ, ดัมเบล).
- If a table row looks anatomically wrong to you, do not silently change it — write the concern in the task report so the reviewer can decide.

Each content task ends with: `flutter test test/features/muscles/catalog_integrity_test.dart` passing, then a commit.

---

### Task 7: Exercises — upper body (chest, shoulders, back, neck)

**Files:**
- Modify: `assets/muscles/exercises.json`
- Modify: `test/features/muscles/catalog_integrity_test.dart` (`authoredGroups`)

**Interfaces:**
- Consumes: muscle ids from Task 6.
- Produces: 49 exercises; `authoredGroups = {'chest', 'shoulders', 'back', 'neck'}`.

- [ ] **Step 1: Extend `authoredGroups` first (test goes red)**

```dart
const authoredGroups = <String>{'chest', 'shoulders', 'back', 'neck'};
```
Run: `flutter test test/features/muscles/catalog_integrity_test.dart`
Expected: FAIL — `authored muscles have enough primary exercises` (`pec_major_clavicular has 0 primary exercises`).

- [ ] **Step 2: Author these exercises**

| # | id | EN name | equip | diff | primary | secondary |
|---|---|---|---|---|---|---|
| 1 | barbell_bench_press | Barbell Bench Press | barbell | intermediate | pec_major_sternocostal | pec_major_clavicular, deltoid_anterior, triceps_lateral, triceps_long, triceps_medial |
| 2 | incline_barbell_press | Incline Barbell Press | barbell | intermediate | pec_major_clavicular | deltoid_anterior, triceps_lateral, triceps_long |
| 3 | incline_dumbbell_press | Incline Dumbbell Press | dumbbell | intermediate | pec_major_clavicular | deltoid_anterior, triceps_lateral, triceps_long |
| 4 | dumbbell_bench_press | Dumbbell Bench Press | dumbbell | beginner | pec_major_sternocostal | pec_major_clavicular, deltoid_anterior, triceps_lateral |
| 5 | decline_bench_press | Decline Bench Press | barbell | intermediate | pec_major_sternocostal | triceps_lateral, triceps_medial |
| 6 | push_up | Push-up | bodyweight | beginner | pec_major_sternocostal | pec_major_clavicular, deltoid_anterior, triceps_lateral, serratus_anterior, rectus_abdominis |
| 7 | chest_dip | Chest Dip | bodyweight | intermediate | pec_major_sternocostal, pec_minor | triceps_lateral, triceps_long, deltoid_anterior |
| 8 | cable_fly_low_to_high | Low-to-High Cable Fly | cable | beginner | pec_major_clavicular | deltoid_anterior |
| 9 | cable_fly_high_to_low | High-to-Low Cable Fly | cable | beginner | pec_major_sternocostal | pec_minor |
| 10 | pec_deck | Pec Deck | machine | beginner | pec_major_sternocostal | pec_major_clavicular |
| 11 | dumbbell_fly | Dumbbell Fly | dumbbell | beginner | pec_major_sternocostal | pec_major_clavicular, deltoid_anterior |
| 12 | landmine_press | Landmine Press | barbell | beginner | pec_major_clavicular, deltoid_anterior | triceps_lateral, serratus_anterior |
| 13 | band_serratus_punch | Band Serratus Punch | band | beginner | serratus_anterior | |
| 14 | scapular_push_up | Scapular Push-up | bodyweight | beginner | serratus_anterior | pec_minor |
| 15 | wall_slide | Wall Slide | bodyweight | beginner | serratus_anterior, trapezius_lower | trapezius_middle |
| 16 | overhead_press | Overhead Press | barbell | intermediate | deltoid_anterior | deltoid_lateral, triceps_lateral, triceps_long, trapezius_upper, serratus_anterior |
| 17 | seated_dumbbell_press | Seated Dumbbell Shoulder Press | dumbbell | beginner | deltoid_anterior | deltoid_lateral, triceps_lateral |
| 18 | arnold_press | Arnold Press | dumbbell | intermediate | deltoid_anterior | deltoid_lateral, triceps_lateral |
| 19 | front_raise | Dumbbell Front Raise | dumbbell | beginner | deltoid_anterior | pec_major_clavicular |
| 20 | lateral_raise | Dumbbell Lateral Raise | dumbbell | beginner | deltoid_lateral | supraspinatus, trapezius_upper |
| 21 | cable_lateral_raise | Cable Lateral Raise | cable | beginner | deltoid_lateral | supraspinatus |
| 22 | upright_row | Upright Row | barbell | intermediate | deltoid_lateral, trapezius_upper | biceps_long, brachialis |
| 23 | machine_lateral_raise | Machine Lateral Raise | machine | beginner | deltoid_lateral | |
| 24 | reverse_pec_deck | Reverse Pec Deck | machine | beginner | deltoid_posterior | trapezius_middle, rhomboids, infraspinatus |
| 25 | face_pull | Face Pull | cable | beginner | deltoid_posterior, infraspinatus, teres_minor | trapezius_middle, rhomboids |
| 26 | bent_over_reverse_fly | Bent-over Reverse Fly | dumbbell | beginner | deltoid_posterior | trapezius_middle, rhomboids, infraspinatus |
| 27 | cable_external_rotation | Cable External Rotation | cable | beginner | infraspinatus, teres_minor | deltoid_posterior |
| 28 | side_lying_external_rotation | Side-lying External Rotation | dumbbell | beginner | infraspinatus, teres_minor | deltoid_posterior |
| 29 | cable_internal_rotation | Cable Internal Rotation | cable | beginner | subscapularis | pec_major_sternocostal, teres_major |
| 30 | full_can_raise | Full Can Raise | dumbbell | beginner | supraspinatus | deltoid_lateral, deltoid_anterior |
| 31 | straight_arm_pulldown | Straight-arm Pulldown | cable | beginner | latissimus_dorsi, teres_major | triceps_long |
| 32 | pull_up | Pull-up | bodyweight | intermediate | latissimus_dorsi, teres_major | biceps_long, biceps_short, brachialis, trapezius_lower, rhomboids |
| 33 | chin_up | Chin-up | bodyweight | intermediate | latissimus_dorsi | biceps_short, biceps_long, brachialis, teres_major |
| 34 | lat_pulldown | Lat Pulldown | cable | beginner | latissimus_dorsi, teres_major | biceps_long, brachialis, trapezius_lower |
| 35 | barbell_row | Barbell Row | barbell | intermediate | latissimus_dorsi, trapezius_middle | rhomboids, deltoid_posterior, biceps_long, erector_spinae |
| 36 | one_arm_dumbbell_row | One-arm Dumbbell Row | dumbbell | beginner | latissimus_dorsi | teres_major, trapezius_middle, rhomboids, deltoid_posterior, biceps_long |
| 37 | seated_cable_row | Seated Cable Row | cable | beginner | trapezius_middle, rhomboids | latissimus_dorsi, deltoid_posterior, biceps_long |
| 38 | chest_supported_row | Chest-supported Dumbbell Row | dumbbell | beginner | trapezius_middle, rhomboids | deltoid_posterior, latissimus_dorsi |
| 39 | barbell_shrug | Barbell Shrug | barbell | beginner | trapezius_upper | forearm_flexors |
| 40 | dumbbell_shrug | Dumbbell Shrug | dumbbell | beginner | trapezius_upper | forearm_flexors |
| 41 | prone_y_raise | Prone Y Raise | dumbbell | beginner | trapezius_lower | deltoid_posterior, trapezius_middle |
| 42 | scapular_pull_up | Scapular Pull-up | bodyweight | beginner | trapezius_lower | latissimus_dorsi |
| 43 | deadlift | Deadlift | barbell | advanced | erector_spinae, gluteus_maximus | biceps_femoris, semitendinosus, semimembranosus, trapezius_upper, forearm_flexors, hip_adductors |
| 44 | back_extension | Back Extension | bodyweight | beginner | erector_spinae | gluteus_maximus, biceps_femoris |
| 45 | good_morning | Good Morning | barbell | intermediate | erector_spinae, biceps_femoris | gluteus_maximus, semitendinosus |
| 46 | bird_dog | Bird Dog | bodyweight | beginner | erector_spinae | gluteus_maximus, rectus_abdominis |
| 47 | lying_neck_flexion | Lying Neck Flexion | bodyweight | beginner | sternocleidomastoid | |
| 48 | band_neck_flexion | Band Neck Flexion | band | beginner | sternocleidomastoid | |
| 49 | isometric_neck_rotation | Isometric Neck Rotation | bodyweight | beginner | sternocleidomastoid | |

- [ ] **Step 3: Run to verify pass**

Run: `flutter test test/features/muscles/catalog_integrity_test.dart`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add assets/muscles/exercises.json test/features/muscles/catalog_integrity_test.dart
git commit -m "Add upper-body exercise content

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: Exercises — arms

**Files:**
- Modify: `assets/muscles/exercises.json`
- Modify: `test/features/muscles/catalog_integrity_test.dart`

**Interfaces:**
- Produces: 20 more exercises; `authoredGroups = {'chest', 'shoulders', 'back', 'neck', 'arms'}`.

- [ ] **Step 1: Add `'arms'` to `authoredGroups`; run; expect FAIL** (`biceps_long has 0 primary exercises`).

```dart
const authoredGroups = <String>{'chest', 'shoulders', 'back', 'neck', 'arms'};
```
Run: `flutter test test/features/muscles/catalog_integrity_test.dart`

- [ ] **Step 2: Author these exercises** (shared rules above)

| # | id | EN name | equip | diff | primary | secondary |
|---|---|---|---|---|---|---|
| 50 | barbell_curl | Barbell Curl | barbell | beginner | biceps_long, biceps_short | brachialis, brachioradialis |
| 51 | incline_dumbbell_curl | Incline Dumbbell Curl | dumbbell | beginner | biceps_long | biceps_short, brachialis |
| 52 | preacher_curl | Preacher Curl | barbell | beginner | biceps_short | brachialis |
| 53 | concentration_curl | Concentration Curl | dumbbell | beginner | biceps_short | biceps_long, brachialis |
| 54 | bayesian_cable_curl | Bayesian Cable Curl | cable | intermediate | biceps_long | biceps_short |
| 55 | hammer_curl | Hammer Curl | dumbbell | beginner | brachialis, brachioradialis | biceps_long |
| 56 | reverse_curl | Reverse Curl | barbell | beginner | brachioradialis, brachialis, forearm_extensors | biceps_short |
| 57 | cross_body_hammer_curl | Cross-body Hammer Curl | dumbbell | beginner | brachialis | brachioradialis, biceps_long |
| 58 | close_grip_bench_press | Close-grip Bench Press | barbell | intermediate | triceps_lateral, triceps_medial | pec_major_sternocostal, deltoid_anterior, triceps_long |
| 59 | overhead_triceps_extension | Overhead Dumbbell Triceps Extension | dumbbell | beginner | triceps_long | triceps_lateral, triceps_medial |
| 60 | triceps_pushdown | Cable Triceps Pushdown | cable | beginner | triceps_lateral | triceps_medial, triceps_long |
| 61 | skull_crusher | Skull Crusher | barbell | intermediate | triceps_long, triceps_lateral | triceps_medial |
| 62 | bench_dip | Bench Dip | bodyweight | beginner | triceps_lateral, triceps_medial | deltoid_anterior, pec_major_sternocostal |
| 63 | cable_overhead_extension | Cable Overhead Triceps Extension | cable | beginner | triceps_long | triceps_lateral |
| 64 | wrist_curl | Dumbbell Wrist Curl | dumbbell | beginner | forearm_flexors | |
| 65 | reverse_wrist_curl | Reverse Wrist Curl | dumbbell | beginner | forearm_extensors | |
| 66 | farmers_walk | Farmer's Walk | dumbbell | beginner | forearm_flexors | trapezius_upper, forearm_extensors, external_oblique |
| 67 | dead_hang | Dead Hang | bodyweight | beginner | forearm_flexors | latissimus_dorsi, teres_major |
| 68 | band_finger_extension | Band Finger Extension | band | beginner | forearm_extensors | |
| 69 | zottman_curl | Zottman Curl | dumbbell | intermediate | brachioradialis, biceps_short | brachialis, biceps_long |

- [ ] **Step 3: Run to verify pass**

Run: `flutter test test/features/muscles/catalog_integrity_test.dart`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add assets/muscles/exercises.json test/features/muscles/catalog_integrity_test.dart
git commit -m "Add arm exercise content

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 9: Exercises — core and lower body

**Files:**
- Modify: `assets/muscles/exercises.json`
- Modify: `test/features/muscles/catalog_integrity_test.dart` (remove `authoredGroups`)

**Interfaces:**
- Produces: 45 more exercises (114 total); minimum check applies to every muscle.

- [ ] **Step 1: Remove the `authoredGroups` filter (test goes red)**

Delete the `authoredGroups` constant and its doc comment, and change the test to:

```dart
  test('every muscle has enough primary exercises', () {
    for (final m in catalog.muscles) {
      final count = catalog.exercises.where((e) => e.primary.contains(m.id)).length;
      expect(
        count,
        greaterThanOrEqualTo(m.deep ? 1 : 3),
        reason: '${m.id} has $count primary exercises',
      );
    }
  });
```
Run: `flutter test test/features/muscles/catalog_integrity_test.dart`
Expected: FAIL (`rectus_abdominis has 0 primary exercises`).

- [ ] **Step 2: Author these exercises** (shared rules above)

| # | id | EN name | equip | diff | primary | secondary |
|---|---|---|---|---|---|---|
| 70 | crunch | Crunch | bodyweight | beginner | rectus_abdominis | external_oblique |
| 71 | hanging_leg_raise | Hanging Leg Raise | bodyweight | advanced | rectus_abdominis, iliopsoas | external_oblique, rectus_femoris |
| 72 | cable_crunch | Cable Crunch | cable | intermediate | rectus_abdominis | external_oblique, internal_oblique |
| 73 | ab_wheel_rollout | Ab Wheel Rollout | bodyweight | intermediate | rectus_abdominis, transversus_abdominis | latissimus_dorsi, external_oblique |
| 74 | plank | Plank | bodyweight | beginner | transversus_abdominis, rectus_abdominis | external_oblique, internal_oblique, gluteus_maximus |
| 75 | side_plank | Side Plank | bodyweight | beginner | external_oblique, internal_oblique | gluteus_medius, transversus_abdominis |
| 76 | russian_twist | Russian Twist | bodyweight | beginner | external_oblique, internal_oblique | rectus_abdominis |
| 77 | pallof_press | Pallof Press | cable | beginner | internal_oblique, external_oblique, transversus_abdominis | rectus_abdominis |
| 78 | cable_woodchop | Cable Woodchop | cable | intermediate | external_oblique | internal_oblique, rectus_abdominis, deltoid_anterior |
| 79 | dead_bug | Dead Bug | bodyweight | beginner | transversus_abdominis, rectus_abdominis | iliopsoas |
| 80 | hip_thrust | Barbell Hip Thrust | barbell | intermediate | gluteus_maximus | biceps_femoris, semitendinosus, hip_adductors |
| 81 | glute_bridge | Glute Bridge | bodyweight | beginner | gluteus_maximus | biceps_femoris, erector_spinae |
| 82 | cable_kickback | Cable Glute Kickback | cable | beginner | gluteus_maximus | biceps_femoris |
| 83 | side_lying_hip_abduction | Side-lying Hip Abduction | bodyweight | beginner | gluteus_medius, gluteus_minimus, tensor_fasciae_latae | |
| 84 | banded_lateral_walk | Banded Lateral Walk | band | beginner | gluteus_medius | gluteus_minimus, tensor_fasciae_latae |
| 85 | clamshell | Clamshell | band | beginner | gluteus_medius | gluteus_minimus |
| 86 | hip_abduction_machine | Hip Abduction Machine | machine | beginner | gluteus_medius, tensor_fasciae_latae | gluteus_minimus |
| 87 | cable_hip_abduction | Standing Cable Hip Abduction | cable | beginner | tensor_fasciae_latae, gluteus_medius | gluteus_minimus |
| 88 | copenhagen_plank | Copenhagen Plank | bodyweight | advanced | hip_adductors | internal_oblique, external_oblique |
| 89 | hip_adduction_machine | Hip Adduction Machine | machine | beginner | hip_adductors | |
| 90 | sumo_squat | Kettlebell Sumo Squat | kettlebell | beginner | hip_adductors, gluteus_maximus | vastus_lateralis, vastus_medialis, rectus_femoris |
| 91 | lying_leg_raise | Lying Leg Raise | bodyweight | beginner | iliopsoas, rectus_abdominis | rectus_femoris |
| 92 | cable_knee_drive | Standing Cable Knee Drive | cable | beginner | iliopsoas, rectus_femoris | tensor_fasciae_latae |
| 93 | back_squat | Barbell Back Squat | barbell | intermediate | vastus_lateralis, vastus_medialis, vastus_intermedius, gluteus_maximus | rectus_femoris, hip_adductors, erector_spinae |
| 94 | front_squat | Front Squat | barbell | advanced | vastus_lateralis, vastus_medialis, vastus_intermedius | rectus_femoris, gluteus_maximus, erector_spinae |
| 95 | leg_press | Leg Press | machine | beginner | vastus_lateralis, vastus_medialis, vastus_intermedius | gluteus_maximus, hip_adductors |
| 96 | leg_extension | Leg Extension | machine | beginner | rectus_femoris, vastus_lateralis, vastus_medialis, vastus_intermedius | |
| 97 | bulgarian_split_squat | Bulgarian Split Squat | dumbbell | intermediate | vastus_medialis, gluteus_maximus | vastus_lateralis, rectus_femoris, gluteus_medius, hip_adductors |
| 98 | walking_lunge | Walking Lunge | dumbbell | beginner | vastus_lateralis, gluteus_maximus | vastus_medialis, rectus_femoris, gluteus_medius |
| 99 | sissy_squat | Sissy Squat | bodyweight | advanced | rectus_femoris, vastus_medialis | vastus_lateralis |
| 100 | reverse_nordic | Reverse Nordic | bodyweight | intermediate | rectus_femoris | vastus_lateralis, vastus_medialis |
| 101 | romanian_deadlift | Romanian Deadlift | barbell | intermediate | biceps_femoris, semitendinosus, semimembranosus | gluteus_maximus, erector_spinae, hip_adductors |
| 102 | lying_leg_curl | Lying Leg Curl | machine | beginner | biceps_femoris, semitendinosus, semimembranosus | gastrocnemius_medial, gastrocnemius_lateral |
| 103 | seated_leg_curl | Seated Leg Curl | machine | beginner | semitendinosus, semimembranosus, biceps_femoris | gastrocnemius_medial |
| 104 | nordic_hamstring_curl | Nordic Hamstring Curl | bodyweight | advanced | biceps_femoris, semitendinosus, semimembranosus | gastrocnemius_medial, gastrocnemius_lateral |
| 105 | standing_calf_raise | Standing Calf Raise | machine | beginner | gastrocnemius_medial, gastrocnemius_lateral | soleus |
| 106 | seated_calf_raise | Seated Calf Raise | machine | beginner | soleus | gastrocnemius_medial, gastrocnemius_lateral |
| 107 | single_leg_calf_raise | Single-leg Calf Raise | bodyweight | beginner | gastrocnemius_medial, gastrocnemius_lateral | soleus |
| 108 | leg_press_calf_raise | Leg Press Calf Raise | machine | beginner | gastrocnemius_medial, gastrocnemius_lateral | soleus |
| 109 | bent_knee_calf_raise | Bent-knee Single-leg Calf Raise | bodyweight | beginner | soleus | gastrocnemius_medial |
| 110 | tibialis_raise | Tibialis Raise | bodyweight | beginner | tibialis_anterior | |
| 111 | band_dorsiflexion | Band Dorsiflexion | band | beginner | tibialis_anterior | |
| 112 | heel_walk | Heel Walk | bodyweight | beginner | tibialis_anterior | |
| 113 | dumbbell_seated_calf_raise | Dumbbell Seated Calf Raise | dumbbell | beginner | soleus | gastrocnemius_medial |
| 114 | kettlebell_swing | Kettlebell Swing | kettlebell | intermediate | gluteus_maximus, biceps_femoris | erector_spinae, semitendinosus |

- [ ] **Step 3: Run the whole muscle test folder**

Run: `flutter test test/features/muscles/`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add assets/muscles/exercises.json test/features/muscles/catalog_integrity_test.dart
git commit -m "Add core and lower-body exercise content

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 10: Body viewer controller (Dart ↔ WebView)

**Files:**
- Modify: `pubspec.yaml` (add `flutter_inappwebview: ^6.1.5`)
- Create: `lib/features/muscles/body_viewer.dart`
- Create: `lib/features/muscles/web_body_viewer_controller.dart`
- Test: `test/features/muscles/body_viewer_test.dart`

**Interfaces:**
- Consumes: JS API and message shapes from Task 4.
- Produces:
  - `enum BodyView { front, back }`
  - `sealed class BodyViewerEvent`; `ViewerReady()`, `MuscleTapped(String muscleId)`, `BackgroundTapped()`, `ViewerFailed(String message)`
  - `BodyViewerEvent? parseViewerMessage(Object? raw)`
  - `abstract class BodyViewerController { Stream<BodyViewerEvent> get events; Widget buildView(); Future<void> select(String muscleId); Future<void> highlight({required List<String> primary, required List<String> secondary}); Future<void> clear(); Future<void> setView(BodyView view); Future<void> resetView(); Future<void> reload(); void dispose(); }`
  - `class WebBodyViewerController implements BodyViewerController` (no-arg constructor)

- [ ] **Step 1: Add the dependency**

Run: `flutter pub add flutter_inappwebview:^6.1.5`
Expected: resolves. If resolution fails against the current Flutter SDK, try `flutter pub add flutter_inappwebview:^6.2.0-beta.3` and note it in the commit message.

- [ ] **Step 2: Write the failing test `test/features/muscles/body_viewer_test.dart`**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:food_diary/features/muscles/body_viewer.dart';

void main() {
  test('parses every message type', () {
    expect(parseViewerMessage({'type': 'ready'}), isA<ViewerReady>());
    expect(
      parseViewerMessage({'type': 'muscleTapped', 'id': 'soleus'}),
      isA<MuscleTapped>().having((e) => e.muscleId, 'muscleId', 'soleus'),
    );
    expect(parseViewerMessage({'type': 'backgroundTapped'}), isA<BackgroundTapped>());
    expect(
      parseViewerMessage({'type': 'error', 'message': 'boom'}),
      isA<ViewerFailed>().having((e) => e.message, 'message', 'boom'),
    );
  });

  test('ignores malformed messages', () {
    expect(parseViewerMessage(null), isNull);
    expect(parseViewerMessage('ready'), isNull);
    expect(parseViewerMessage({'type': 'muscleTapped'}), isNull);
    expect(parseViewerMessage({'type': 'muscleTapped', 'id': 3}), isNull);
    expect(parseViewerMessage({'type': 'unknown'}), isNull);
  });

  test('error without message still fails the viewer', () {
    expect(
      parseViewerMessage({'type': 'error'}),
      isA<ViewerFailed>().having((e) => e.message, 'message', 'unknown error'),
    );
  });
}
```

- [ ] **Step 3: Run to verify failure**

Run: `flutter test test/features/muscles/body_viewer_test.dart`
Expected: FAIL — `body_viewer.dart` not found.

- [ ] **Step 4: Implement `lib/features/muscles/body_viewer.dart`**

```dart
import 'package:flutter/widgets.dart';

enum BodyView { front, back }

sealed class BodyViewerEvent {
  const BodyViewerEvent();
}

class ViewerReady extends BodyViewerEvent {
  const ViewerReady();
}

class MuscleTapped extends BodyViewerEvent {
  const MuscleTapped(this.muscleId);
  final String muscleId;
}

class BackgroundTapped extends BodyViewerEvent {
  const BackgroundTapped();
}

class ViewerFailed extends BodyViewerEvent {
  const ViewerFailed(this.message);
  final String message;
}

/// Turns a message posted by `assets/body_viewer/viewer.js` into an event.
/// Returns null for anything malformed.
BodyViewerEvent? parseViewerMessage(Object? raw) {
  if (raw is! Map) return null;
  return switch (raw['type']) {
    'ready' => const ViewerReady(),
    'muscleTapped' => switch (raw['id']) {
      final String id => MuscleTapped(id),
      _ => null,
    },
    'backgroundTapped' => const BackgroundTapped(),
    'error' => ViewerFailed(raw['message']?.toString() ?? 'unknown error'),
    _ => null,
  };
}

/// The 3D body as seen by screens. The WebView implementation lives in
/// `web_body_viewer_controller.dart`; tests use a fake.
abstract class BodyViewerController {
  Stream<BodyViewerEvent> get events;

  /// The widget that renders the body. Built once by the owning screen.
  Widget buildView();

  /// Highlights one muscle and turns the camera toward it.
  Future<void> select(String muscleId);

  /// Colors an exercise's muscles without moving the camera.
  Future<void> highlight({
    required List<String> primary,
    required List<String> secondary,
  });

  Future<void> clear();
  Future<void> setView(BodyView view);
  Future<void> resetView();

  /// Reloads the page (used by Retry).
  Future<void> reload();

  void dispose();
}
```

- [ ] **Step 5: Run to verify pass**

Run: `flutter test test/features/muscles/body_viewer_test.dart`
Expected: PASS.

- [ ] **Step 6: Implement `lib/features/muscles/web_body_viewer_controller.dart`**

```dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'body_viewer.dart';

/// Renders `assets/body_viewer/index.html` in a WebView. Assets are served
/// through Android's WebViewAssetLoader so the page can fetch `body.glb`.
class WebBodyViewerController implements BodyViewerController {
  static const _domain = 'appassets.androidplatform.net';
  static const _url =
      'https://$_domain/assets/flutter_assets/assets/body_viewer/index.html';

  final _events = StreamController<BodyViewerEvent>.broadcast();
  InAppWebViewController? _web;

  @override
  Stream<BodyViewerEvent> get events => _events.stream;

  void _emit(BodyViewerEvent event) {
    if (!_events.isClosed) _events.add(event);
  }

  @override
  Widget buildView() => InAppWebView(
    initialUrlRequest: URLRequest(url: WebUri(_url)),
    initialSettings: InAppWebViewSettings(
      transparentBackground: true,
      isInspectable: kDebugMode,
      supportZoom: false,
      disableContextMenu: true,
      webViewAssetLoader: WebViewAssetLoader(
        domain: _domain,
        pathHandlers: [AssetsPathHandler(path: '/assets/')],
      ),
    ),
    gestureRecognizers: {
      Factory<OneSequenceGestureRecognizer>(EagerGestureRecognizer.new),
    },
    onWebViewCreated: (controller) {
      _web = controller;
      controller.addJavaScriptHandler(
        handlerName: 'viewer',
        callback: (args) {
          final event = parseViewerMessage(args.isEmpty ? null : args.first);
          if (event != null) _emit(event);
          return null;
        },
      );
    },
    onReceivedError: (controller, request, error) {
      if (request.isForMainFrame ?? true) {
        _emit(ViewerFailed(error.description));
      }
    },
  );

  Future<void> _call(String function, [Object? arg]) async {
    final args = arg == null ? '' : jsonEncode(arg);
    await _web?.evaluateJavascript(
      source: 'window.viewer && window.viewer.$function($args);',
    );
  }

  @override
  Future<void> select(String muscleId) => _call('select', muscleId);

  @override
  Future<void> highlight({
    required List<String> primary,
    required List<String> secondary,
  }) => _call('highlight', {'primary': primary, 'secondary': secondary});

  @override
  Future<void> clear() => _call('clear');

  @override
  Future<void> setView(BodyView view) => _call('setView', view.name);

  @override
  Future<void> resetView() => _call('resetView');

  @override
  Future<void> reload() async => _web?.reload();

  @override
  void dispose() => _events.close();
}
```

- [ ] **Step 7: Analyze**

Run: `flutter analyze lib/features/muscles test/features/muscles`
Expected: `No issues found!` (If a `flutter_inappwebview` API name differs in the resolved version, fix it against that version's API docs; the names above match 6.1.x.)

- [ ] **Step 8: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/features/muscles/body_viewer.dart lib/features/muscles/web_body_viewer_controller.dart test/features/muscles/body_viewer_test.dart
git commit -m "Add body viewer controller backed by an InAppWebView

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 11: Muscle sheet

**Files:**
- Create: `test/features/muscles/fake_body_viewer_controller.dart`
- Create: `test/features/muscles/fixtures.dart`
- Create: `lib/features/muscles/muscle_sheet.dart`
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_th.arb`
- Test: `test/features/muscles/muscle_sheet_test.dart`

**Interfaces:**
- Consumes: `MuscleCatalog` (Task 6), models (Task 5), `BodyViewerController` (Task 10).
- Produces:
  - `MuscleSheet({Key? key, required Muscle muscle, required List<Exercise> exercises, required String Function(String muscleId) muscleNameOf, required ValueChanged<Exercise?> onExerciseExpanded, required VoidCallback onClose})` — calls `onExerciseExpanded(exercise)` on expand and `onExerciseExpanded(null)` on collapse. Keys: `Key('muscle_sheet')`, `Key('muscle_sheet_close')`, `Key('exercise_<id>')`.
  - Test helpers: `FakeBodyViewerController` (records `calls` as strings like `select:soleus`, `highlight:a,b|c`, `clear`, `setView:back`, `resetView`, `reload`; `emit(BodyViewerEvent)`), `testCatalog()`.

- [ ] **Step 1: Add ARB strings**

Append to `lib/l10n/app_en.arb` (before the closing `}`):

```json
  "musclesRolePrimary": "Primary",
  "musclesRoleSecondary": "Secondary",
  "musclesStepsTitle": "How to do it",
  "musclesTipsTitle": "Tips",
  "musclesMistakesTitle": "Common mistakes",
  "musclesWorksTitle": "Muscles worked",
  "musclesNoExercises": "No exercises yet",
  "musclesDeepNote": "Deep muscle — not visible on the 3D body.",
  "musclesClose": "Close",
  "equipmentBodyweight": "Bodyweight",
  "equipmentDumbbell": "Dumbbell",
  "equipmentBarbell": "Barbell",
  "equipmentCable": "Cable",
  "equipmentMachine": "Machine",
  "equipmentKettlebell": "Kettlebell",
  "equipmentBand": "Band",
  "difficultyBeginner": "Beginner",
  "difficultyIntermediate": "Intermediate",
  "difficultyAdvanced": "Advanced"
```

Append to `lib/l10n/app_th.arb`:

```json
  "musclesRolePrimary": "มัดหลัก",
  "musclesRoleSecondary": "มัดรอง",
  "musclesStepsTitle": "วิธีทำ",
  "musclesTipsTitle": "เคล็ดลับ",
  "musclesMistakesTitle": "ข้อผิดพลาดที่พบบ่อย",
  "musclesWorksTitle": "กล้ามเนื้อที่ใช้",
  "musclesNoExercises": "ยังไม่มีท่า",
  "musclesDeepNote": "กล้ามเนื้อชั้นลึก มองไม่เห็นบนร่างกาย 3D",
  "musclesClose": "ปิด",
  "equipmentBodyweight": "น้ำหนักตัว",
  "equipmentDumbbell": "ดัมเบล",
  "equipmentBarbell": "บาร์เบล",
  "equipmentCable": "เคเบิล",
  "equipmentMachine": "เครื่อง",
  "equipmentKettlebell": "เคตเทิลเบล",
  "equipmentBand": "ยางยืด",
  "difficultyBeginner": "มือใหม่",
  "difficultyIntermediate": "ระดับกลาง",
  "difficultyAdvanced": "ขั้นสูง"
```

(Add a comma after the previous last entry in each file.) Run: `flutter gen-l10n` — expected: no errors.

- [ ] **Step 2: Write test helpers**

`test/features/muscles/fake_body_viewer_controller.dart`:

```dart
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:food_diary/features/muscles/body_viewer.dart';

class FakeBodyViewerController implements BodyViewerController {
  final _events = StreamController<BodyViewerEvent>.broadcast();
  final calls = <String>[];

  void emit(BodyViewerEvent event) => _events.add(event);

  @override
  Stream<BodyViewerEvent> get events => _events.stream;

  @override
  Widget buildView() => const SizedBox.expand(key: Key('fake_body_view'));

  @override
  Future<void> select(String muscleId) async => calls.add('select:$muscleId');

  @override
  Future<void> highlight({
    required List<String> primary,
    required List<String> secondary,
  }) async => calls.add('highlight:${primary.join(',')}|${secondary.join(',')}');

  @override
  Future<void> clear() async => calls.add('clear');

  @override
  Future<void> setView(BodyView view) async => calls.add('setView:${view.name}');

  @override
  Future<void> resetView() async => calls.add('resetView');

  @override
  Future<void> reload() async => calls.add('reload');

  @override
  void dispose() => _events.close();
}
```

`test/features/muscles/fixtures.dart`:

```dart
import 'package:food_diary/features/muscles/muscle_catalog.dart';
import 'package:food_diary/models/exercise.dart';
import 'package:food_diary/models/localized_text.dart';
import 'package:food_diary/models/muscle.dart';

Muscle _muscle(String id, MuscleGroup group, String en, String th, {bool deep = false}) => Muscle(
  id: id,
  group: group,
  deep: deep,
  name: LocalizedText(en: en, th: th),
  anatomical: '$en (anatomical)',
  description: LocalizedText(en: '$en description', th: '$th คำอธิบาย'),
);

Exercise _exercise(String id, String en, List<String> primary, List<String> secondary) => Exercise(
  id: id,
  name: LocalizedText(en: en, th: '$en TH'),
  equipment: Equipment.dumbbell,
  difficulty: Difficulty.beginner,
  primary: primary,
  secondary: secondary,
  steps: const LocalizedList(en: ['Step one', 'Step two', 'Step three'], th: ['ขั้นหนึ่ง', 'ขั้นสอง', 'ขั้นสาม']),
  tips: const LocalizedList(en: ['A tip'], th: ['เคล็ดลับ']),
  mistakes: const LocalizedList(en: ['A mistake'], th: ['ข้อผิด']),
);

MuscleCatalog testCatalog() => MuscleCatalog(
  muscles: [
    _muscle('pec_major_clavicular', MuscleGroup.chest, 'Upper chest', 'อกบน'),
    _muscle('deltoid_anterior', MuscleGroup.shoulders, 'Front delt', 'ไหล่หน้า'),
    _muscle('subscapularis', MuscleGroup.shoulders, 'Subscapularis', 'ซับสแคป', deep: true),
  ],
  exercises: [
    _exercise('incline_dumbbell_press', 'Incline Dumbbell Press', ['pec_major_clavicular'], ['deltoid_anterior']),
    _exercise('front_raise', 'Front Raise', ['deltoid_anterior'], ['pec_major_clavicular']),
    _exercise('cable_internal_rotation', 'Cable Internal Rotation', ['subscapularis'], []),
  ],
);
```

- [ ] **Step 3: Write the failing test `test/features/muscles/muscle_sheet_test.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_diary/features/muscles/muscle_sheet.dart';
import 'package:food_diary/models/exercise.dart';

import '../../test_utils.dart';
import 'fixtures.dart';

void main() {
  final catalog = testCatalog();

  Future<List<Exercise?>> pumpSheet(
    WidgetTester tester,
    String muscleId, {
    Locale locale = const Locale('en'),
    VoidCallback? onClose,
  }) async {
    final expanded = <Exercise?>[];
    await tester.pumpWidget(
      localizedApp(
        Scaffold(
          body: Stack(
            children: [
              MuscleSheet(
                muscle: catalog.muscleById(muscleId)!,
                exercises: catalog.exercisesFor(muscleId),
                muscleNameOf: (id) => catalog.muscleById(id)!.name.en,
                onExerciseExpanded: expanded.add,
                onClose: onClose ?? () {},
              ),
            ],
          ),
        ),
        locale: locale,
      ),
    );
    await tester.pumpAndSettle();
    return expanded;
  }

  testWidgets('shows the muscle and its exercises with roles', (tester) async {
    await pumpSheet(tester, 'pec_major_clavicular');

    expect(find.text('Upper chest'), findsOneWidget);
    expect(find.text('Upper chest description'), findsOneWidget);
    expect(find.text('Incline Dumbbell Press'), findsOneWidget);
    expect(find.text('Front Raise'), findsOneWidget);
    expect(find.text('Primary'), findsOneWidget);
    expect(find.text('Secondary'), findsOneWidget);
    expect(find.text('Dumbbell · Beginner'), findsNWidgets(2));
  });

  testWidgets('expanding an exercise shows details and reports it', (tester) async {
    final expanded = await pumpSheet(tester, 'pec_major_clavicular');

    await tester.tap(find.byKey(const Key('exercise_incline_dumbbell_press')));
    await tester.pumpAndSettle();

    expect(find.text('How to do it'), findsOneWidget);
    expect(find.text('1. Step one'), findsOneWidget);
    expect(find.text('• A tip'), findsOneWidget);
    expect(find.text('• A mistake'), findsOneWidget);
    expect(find.textContaining('Front delt'), findsOneWidget);
    expect(expanded.single?.id, 'incline_dumbbell_press');

    await tester.tap(find.byKey(const Key('exercise_incline_dumbbell_press')));
    await tester.pumpAndSettle();
    expect(find.text('How to do it'), findsNothing);
    expect(expanded.last, isNull);
  });

  testWidgets('shows the deep note for deep muscles', (tester) async {
    await pumpSheet(tester, 'subscapularis');
    expect(find.text('Deep muscle — not visible on the 3D body.'), findsOneWidget);
  });

  testWidgets('renders Thai content', (tester) async {
    await pumpSheet(tester, 'pec_major_clavicular', locale: const Locale('th'));
    expect(find.text('อกบน'), findsOneWidget);
    expect(find.text('มัดหลัก'), findsOneWidget);
  });

  testWidgets('close button calls onClose', (tester) async {
    var closed = false;
    await pumpSheet(tester, 'deltoid_anterior', onClose: () => closed = true);
    await tester.tap(find.byKey(const Key('muscle_sheet_close')));
    expect(closed, isTrue);
  });
}
```

- [ ] **Step 4: Run to verify failure**

Run: `flutter test test/features/muscles/muscle_sheet_test.dart`
Expected: FAIL — `muscle_sheet.dart` not found.

- [ ] **Step 5: Implement `lib/features/muscles/muscle_sheet.dart`**

```dart
import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../models/exercise.dart';
import '../../models/muscle.dart';

String equipmentLabel(AppLocalizations l10n, Equipment e) => switch (e) {
  Equipment.bodyweight => l10n.equipmentBodyweight,
  Equipment.dumbbell => l10n.equipmentDumbbell,
  Equipment.barbell => l10n.equipmentBarbell,
  Equipment.cable => l10n.equipmentCable,
  Equipment.machine => l10n.equipmentMachine,
  Equipment.kettlebell => l10n.equipmentKettlebell,
  Equipment.band => l10n.equipmentBand,
};

String difficultyLabel(AppLocalizations l10n, Difficulty d) => switch (d) {
  Difficulty.beginner => l10n.difficultyBeginner,
  Difficulty.intermediate => l10n.difficultyIntermediate,
  Difficulty.advanced => l10n.difficultyAdvanced,
};

/// Draggable sheet over the 3D body listing one muscle's exercises.
class MuscleSheet extends StatefulWidget {
  const MuscleSheet({
    super.key,
    required this.muscle,
    required this.exercises,
    required this.muscleNameOf,
    required this.onExerciseExpanded,
    required this.onClose,
  });

  final Muscle muscle;

  /// Already ordered: primary-role exercises first.
  final List<Exercise> exercises;
  final String Function(String muscleId) muscleNameOf;
  final ValueChanged<Exercise?> onExerciseExpanded;
  final VoidCallback onClose;

  @override
  State<MuscleSheet> createState() => _MuscleSheetState();
}

class _MuscleSheetState extends State<MuscleSheet> {
  String? _expandedId;

  void _toggle(Exercise exercise) {
    final expand = _expandedId != exercise.id;
    setState(() => _expandedId = expand ? exercise.id : null);
    widget.onExerciseExpanded(expand ? exercise : null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final theme = Theme.of(context);
    final muscle = widget.muscle;

    return DraggableScrollableSheet(
      key: const Key('muscle_sheet'),
      initialChildSize: 0.4,
      minChildSize: 0.2,
      maxChildSize: 0.9,
      builder: (context, scrollController) => Material(
        color: Colors.white,
        elevation: 8,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    muscle.name.resolve(locale),
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  key: const Key('muscle_sheet_close'),
                  icon: const Icon(Icons.close),
                  tooltip: l10n.musclesClose,
                  onPressed: widget.onClose,
                ),
              ],
            ),
            Text(
              muscle.anatomical,
              style: theme.textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
              ),
            ),
            if (muscle.deep) ...[
              const SizedBox(height: 8),
              Text(
                l10n.musclesDeepNote,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(muscle.description.resolve(locale)),
            const SizedBox(height: 12),
            if (widget.exercises.isEmpty)
              Text(l10n.musclesNoExercises)
            else
              for (final exercise in widget.exercises)
                _ExerciseTile(
                  exercise: exercise,
                  isPrimary: exercise.primary.contains(muscle.id),
                  expanded: _expandedId == exercise.id,
                  muscleNameOf: widget.muscleNameOf,
                  onTap: () => _toggle(exercise),
                ),
          ],
        ),
      ),
    );
  }
}

class _ExerciseTile extends StatelessWidget {
  const _ExerciseTile({
    required this.exercise,
    required this.isPrimary,
    required this.expanded,
    required this.muscleNameOf,
    required this.onTap,
  });

  final Exercise exercise;
  final bool isPrimary;
  final bool expanded;
  final String Function(String muscleId) muscleNameOf;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    Widget section(String title, List<String> lines) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleSmall),
          for (final line in lines) Text(line),
        ],
      ),
    );

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            key: Key('exercise_${exercise.id}'),
            title: Text(exercise.name.resolve(locale)),
            subtitle: Text(
              '${equipmentLabel(l10n, exercise.equipment)} · '
              '${difficultyLabel(l10n, exercise.difficulty)}',
            ),
            trailing: Chip(
              label: Text(
                isPrimary ? l10n.musclesRolePrimary : l10n.musclesRoleSecondary,
              ),
              backgroundColor: primaryColor.withValues(
                alpha: isPrimary ? 0.2 : 0.08,
              ),
              side: BorderSide.none,
            ),
            onTap: onTap,
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  section(l10n.musclesStepsTitle, [
                    for (final (i, step)
                        in exercise.steps.resolve(locale).indexed)
                      '${i + 1}. $step',
                  ]),
                  section(l10n.musclesTipsTitle, [
                    for (final tip in exercise.tips.resolve(locale)) '• $tip',
                  ]),
                  section(l10n.musclesMistakesTitle, [
                    for (final m in exercise.mistakes.resolve(locale)) '• $m',
                  ]),
                  section(l10n.musclesWorksTitle, [
                    '${l10n.musclesRolePrimary}: '
                        '${exercise.primary.map(muscleNameOf).join(', ')}',
                    if (exercise.secondary.isNotEmpty)
                      '${l10n.musclesRoleSecondary}: '
                          '${exercise.secondary.map(muscleNameOf).join(', ')}',
                  ]),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 6: Run to verify pass**

Run: `flutter test test/features/muscles/muscle_sheet_test.dart`
Expected: all 5 tests pass. (`find.textContaining('Front delt')` matches the "Secondary: Front delt" line only, since the sheet is for Upper chest.)

- [ ] **Step 7: Commit**

```bash
git add lib/features/muscles/muscle_sheet.dart lib/l10n/app_en.arb lib/l10n/app_th.arb test/features/muscles/muscle_sheet_test.dart test/features/muscles/fake_body_viewer_controller.dart test/features/muscles/fixtures.dart
git commit -m "Add muscle sheet listing exercises per muscle

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 12: Muscle map screen

**Files:**
- Create: `lib/features/muscles/muscle_map_screen.dart`
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_th.arb`
- Test: `test/features/muscles/muscle_map_screen_test.dart`

**Interfaces:**
- Consumes: `MuscleSheet` (Task 11), `BodyViewerController` + events (Task 10), `MuscleCatalog` (Task 6), test helpers (Task 11).
- Produces: `MuscleMapScreen({Key? key, required MuscleCatalog catalog, BodyViewerController Function() controllerFactory = WebBodyViewerController.new, Duration readyTimeout = const Duration(seconds: 10), Future<Muscle?> Function(BuildContext context)? openMuscleList})`. Keys: `muscles_loading`, `muscles_error`, `muscles_retry`, `muscles_error_open_list`, `muscles_list_button`, `muscles_credits_button`, `muscles_view_front`, `muscles_view_back`, `muscles_view_reset`. `openMuscleList` defaults to pushing `MuscleListScreen` in Task 13; until then it is required to be passed or the list button does nothing.

- [ ] **Step 1: Add ARB strings**

`app_en.arb`:
```json
  "musclesAppBarTitle": "Muscles",
  "musclesTapHint": "Tap a muscle to see exercises",
  "musclesViewFront": "Front",
  "musclesViewBack": "Back",
  "musclesResetView": "Reset",
  "musclesListTooltip": "Muscle list",
  "musclesCreditsTooltip": "Credits",
  "musclesCreditsBody": "3D anatomy model adapted from Z-Anatomy (z-anatomy.com), licensed under CC BY-SA 4.0. The adapted model is shared under the same license.",
  "musclesLoadError": "Couldn't load the 3D body.",
  "musclesRetry": "Retry",
  "musclesOpenList": "Open muscle list"
```
`app_th.arb`:
```json
  "musclesAppBarTitle": "กล้ามเนื้อ",
  "musclesTapHint": "แตะที่กล้ามเนื้อเพื่อดูท่าออกกำลังกาย",
  "musclesViewFront": "ด้านหน้า",
  "musclesViewBack": "ด้านหลัง",
  "musclesResetView": "รีเซ็ต",
  "musclesListTooltip": "รายการกล้ามเนื้อ",
  "musclesCreditsTooltip": "เครดิต",
  "musclesCreditsBody": "โมเดลกายวิภาค 3D ดัดแปลงจาก Z-Anatomy (z-anatomy.com) สัญญาอนุญาต CC BY-SA 4.0 โมเดลที่ดัดแปลงเผยแพร่ภายใต้สัญญาอนุญาตเดียวกัน",
  "musclesLoadError": "โหลดร่างกาย 3D ไม่สำเร็จ",
  "musclesRetry": "ลองใหม่",
  "musclesOpenList": "เปิดรายการกล้ามเนื้อ"
```
Run: `flutter gen-l10n`.

- [ ] **Step 2: Write the failing test `test/features/muscles/muscle_map_screen_test.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_diary/features/muscles/body_viewer.dart';
import 'package:food_diary/features/muscles/muscle_map_screen.dart';
import 'package:food_diary/models/muscle.dart';

import '../../test_utils.dart';
import 'fake_body_viewer_controller.dart';
import 'fixtures.dart';

void main() {
  late FakeBodyViewerController viewer;

  Future<void> pumpScreen(
    WidgetTester tester, {
    Future<Muscle?> Function(BuildContext)? openMuscleList,
  }) async {
    viewer = FakeBodyViewerController();
    await tester.pumpWidget(
      localizedApp(
        MuscleMapScreen(
          catalog: testCatalog(),
          controllerFactory: () => viewer,
          openMuscleList: openMuscleList,
        ),
      ),
    );
  }

  Future<void> ready(WidgetTester tester) async {
    viewer.emit(const ViewerReady());
    await tester.pump();
  }

  testWidgets('shows a spinner until the viewer is ready', (tester) async {
    await pumpScreen(tester);
    expect(find.byKey(const Key('muscles_loading')), findsOneWidget);

    await ready(tester);
    expect(find.byKey(const Key('muscles_loading')), findsNothing);
    expect(find.text('Tap a muscle to see exercises'), findsOneWidget);
  });

  testWidgets('tapping a muscle opens its sheet and selects it', (tester) async {
    await pumpScreen(tester);
    await ready(tester);

    viewer.emit(const MuscleTapped('pec_major_clavicular'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('muscle_sheet')), findsOneWidget);
    expect(find.text('Upper chest'), findsOneWidget);
    expect(viewer.calls, contains('select:pec_major_clavicular'));
  });

  testWidgets('ignores taps on unknown muscle ids', (tester) async {
    await pumpScreen(tester);
    await ready(tester);

    viewer.emit(const MuscleTapped('tail_wagger'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('muscle_sheet')), findsNothing);
    expect(viewer.calls, isEmpty);
  });

  testWidgets('expanding an exercise highlights its muscles; collapsing reselects', (tester) async {
    await pumpScreen(tester);
    await ready(tester);
    viewer.emit(const MuscleTapped('pec_major_clavicular'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('exercise_incline_dumbbell_press')));
    await tester.pumpAndSettle();
    expect(viewer.calls.last, 'highlight:pec_major_clavicular|deltoid_anterior');

    await tester.tap(find.byKey(const Key('exercise_incline_dumbbell_press')));
    await tester.pumpAndSettle();
    expect(viewer.calls.last, 'select:pec_major_clavicular');
  });

  testWidgets('background tap and close button clear the selection', (tester) async {
    await pumpScreen(tester);
    await ready(tester);
    viewer.emit(const MuscleTapped('deltoid_anterior'));
    await tester.pumpAndSettle();

    viewer.emit(const BackgroundTapped());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('muscle_sheet')), findsNothing);
    expect(viewer.calls.last, 'clear');

    viewer.emit(const MuscleTapped('deltoid_anterior'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('muscle_sheet_close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('muscle_sheet')), findsNothing);
    expect(viewer.calls.last, 'clear');
  });

  testWidgets('view buttons drive the viewer', (tester) async {
    await pumpScreen(tester);
    await ready(tester);

    await tester.tap(find.byKey(const Key('muscles_view_back')));
    await tester.tap(find.byKey(const Key('muscles_view_front')));
    await tester.tap(find.byKey(const Key('muscles_view_reset')));
    expect(viewer.calls, ['setView:back', 'setView:front', 'resetView']);
  });

  testWidgets('a viewer error shows retry and list', (tester) async {
    await pumpScreen(tester);
    viewer.emit(const ViewerFailed('boom'));
    await tester.pump();

    expect(find.byKey(const Key('muscles_error')), findsOneWidget);
    expect(find.text("Couldn't load the 3D body."), findsOneWidget);
    expect(find.byKey(const Key('muscles_error_open_list')), findsOneWidget);
  });

  testWidgets('times out to the error panel', (tester) async {
    await pumpScreen(tester);
    await tester.pump(const Duration(seconds: 9));
    expect(find.byKey(const Key('muscles_error')), findsNothing);

    await tester.pump(const Duration(seconds: 2));
    expect(find.byKey(const Key('muscles_error')), findsOneWidget);
  });

  testWidgets('retry reloads and waits again', (tester) async {
    await pumpScreen(tester);
    viewer.emit(const ViewerFailed('boom'));
    await tester.pump();

    await tester.tap(find.byKey(const Key('muscles_retry')));
    await tester.pump();
    expect(viewer.calls, ['reload']);
    expect(find.byKey(const Key('muscles_loading')), findsOneWidget);

    await tester.pump(const Duration(seconds: 11));
    expect(find.byKey(const Key('muscles_error')), findsOneWidget);
  });

  testWidgets('choosing a muscle from the list opens it', (tester) async {
    final catalog = testCatalog();
    await pumpScreen(
      tester,
      openMuscleList: (_) async => catalog.muscleById('subscapularis'),
    );
    await ready(tester);

    await tester.tap(find.byKey(const Key('muscles_list_button')));
    await tester.pumpAndSettle();

    expect(find.text('Subscapularis'), findsOneWidget);
    expect(viewer.calls, contains('select:subscapularis'));
  });

  testWidgets('credits button shows the Z-Anatomy credit', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.byKey(const Key('muscles_credits_button')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Z-Anatomy'), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run to verify failure**

Run: `flutter test test/features/muscles/muscle_map_screen_test.dart`
Expected: FAIL — `muscle_map_screen.dart` not found.

- [ ] **Step 4: Implement `lib/features/muscles/muscle_map_screen.dart`**

```dart
import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../models/exercise.dart';
import '../../models/muscle.dart';
import 'body_viewer.dart';
import 'muscle_catalog.dart';
import 'muscle_sheet.dart';
import 'web_body_viewer_controller.dart';

enum _ViewerStatus { loading, ready, failed }

/// The Muscles tab: a 3D body; tapping a muscle opens its exercises.
class MuscleMapScreen extends StatefulWidget {
  const MuscleMapScreen({
    super.key,
    required this.catalog,
    this.controllerFactory = WebBodyViewerController.new,
    this.readyTimeout = const Duration(seconds: 10),
    this.openMuscleList,
  });

  final MuscleCatalog catalog;
  final BodyViewerController Function() controllerFactory;
  final Duration readyTimeout;

  /// Shows the muscle list and returns the chosen muscle (or null).
  final Future<Muscle?> Function(BuildContext context)? openMuscleList;

  @override
  State<MuscleMapScreen> createState() => _MuscleMapScreenState();
}

class _MuscleMapScreenState extends State<MuscleMapScreen> {
  late final BodyViewerController _viewer;
  late final Widget _view;
  late final StreamSubscription<BodyViewerEvent> _sub;
  Timer? _timeout;
  _ViewerStatus _status = _ViewerStatus.loading;
  Muscle? _selected;

  @override
  void initState() {
    super.initState();
    _viewer = widget.controllerFactory();
    _view = _viewer.buildView();
    _sub = _viewer.events.listen(_onEvent);
    _startTimeout();
  }

  @override
  void dispose() {
    _timeout?.cancel();
    _sub.cancel();
    _viewer.dispose();
    super.dispose();
  }

  void _startTimeout() {
    _timeout?.cancel();
    _timeout = Timer(widget.readyTimeout, () {
      if (mounted && _status == _ViewerStatus.loading) {
        setState(() => _status = _ViewerStatus.failed);
      }
    });
  }

  void _onEvent(BodyViewerEvent event) {
    switch (event) {
      case ViewerReady():
        _timeout?.cancel();
        setState(() => _status = _ViewerStatus.ready);
      case MuscleTapped(:final muscleId):
        _openMuscle(muscleId);
      case BackgroundTapped():
        if (_selected != null) _closeMuscle();
      case ViewerFailed():
        _timeout?.cancel();
        setState(() => _status = _ViewerStatus.failed);
    }
  }

  void _openMuscle(String id) {
    final muscle = widget.catalog.muscleById(id);
    if (muscle == null) return;
    setState(() => _selected = muscle);
    _viewer.select(id);
  }

  void _closeMuscle() {
    setState(() => _selected = null);
    _viewer.clear();
  }

  void _onExerciseExpanded(Exercise? exercise) {
    final selected = _selected;
    if (selected == null) return;
    if (exercise == null) {
      _viewer.select(selected.id);
    } else {
      _viewer.highlight(
        primary: exercise.primary,
        secondary: exercise.secondary,
      );
    }
  }

  void _retry() {
    setState(() => _status = _ViewerStatus.loading);
    _startTimeout();
    _viewer.reload();
  }

  Future<void> _openList() async {
    final open = widget.openMuscleList;
    if (open == null) return;
    final muscle = await open(context);
    if (muscle != null && mounted) _openMuscle(muscle.id);
  }

  void _showCredits() {
    final l10n = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.musclesCreditsTooltip),
        content: Text(l10n.musclesCreditsBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.musclesClose),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final selected = _selected;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.musclesAppBarTitle),
        actions: [
          IconButton(
            key: const Key('muscles_list_button'),
            icon: const Icon(Icons.list),
            tooltip: l10n.musclesListTooltip,
            onPressed: _openList,
          ),
          IconButton(
            key: const Key('muscles_credits_button'),
            icon: const Icon(Icons.info_outline),
            tooltip: l10n.musclesCreditsTooltip,
            onPressed: _showCredits,
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(child: _view),
          if (_status == _ViewerStatus.loading)
            const Center(
              child: CircularProgressIndicator(key: Key('muscles_loading')),
            ),
          if (_status == _ViewerStatus.failed)
            Center(
              child: Card(
                key: const Key('muscles_error'),
                margin: const EdgeInsets.all(24),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(l10n.musclesLoadError),
                      const SizedBox(height: 12),
                      FilledButton(
                        key: const Key('muscles_retry'),
                        onPressed: _retry,
                        child: Text(l10n.musclesRetry),
                      ),
                      TextButton(
                        key: const Key('muscles_error_open_list'),
                        onPressed: _openList,
                        child: Text(l10n.musclesOpenList),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (_status == _ViewerStatus.ready && selected == null) ...[
            Positioned(
              top: 12,
              left: 16,
              right: 16,
              child: Text(
                l10n.musclesTapHint,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                children: [
                  OutlinedButton(
                    key: const Key('muscles_view_front'),
                    onPressed: () => _viewer.setView(BodyView.front),
                    child: Text(l10n.musclesViewFront),
                  ),
                  OutlinedButton(
                    key: const Key('muscles_view_back'),
                    onPressed: () => _viewer.setView(BodyView.back),
                    child: Text(l10n.musclesViewBack),
                  ),
                  OutlinedButton(
                    key: const Key('muscles_view_reset'),
                    onPressed: _viewer.resetView,
                    child: Text(l10n.musclesResetView),
                  ),
                ],
              ),
            ),
          ],
          if (selected != null)
            MuscleSheet(
              key: ValueKey(selected.id),
              muscle: selected,
              exercises: widget.catalog.exercisesFor(selected.id),
              muscleNameOf: (id) =>
                  widget.catalog.muscleById(id)?.name.resolve(locale) ?? id,
              onExerciseExpanded: _onExerciseExpanded,
              onClose: _closeMuscle,
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Run to verify pass**

Run: `flutter test test/features/muscles/muscle_map_screen_test.dart`
Expected: all 11 tests pass. If `retry reloads and waits again` sees extra calls, note that `calls` must equal exactly `['reload']` — the error path must not call `clear`/`select`.

- [ ] **Step 6: Commit**

```bash
git add lib/features/muscles/muscle_map_screen.dart lib/l10n/app_en.arb lib/l10n/app_th.arb test/features/muscles/muscle_map_screen_test.dart
git commit -m "Add muscle map screen with loading, error, and selection states

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 13: Muscle list screen

**Files:**
- Create: `lib/features/muscles/muscle_list_screen.dart`
- Modify: `lib/features/muscles/muscle_map_screen.dart` (default `openMuscleList`)
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_th.arb`
- Test: `test/features/muscles/muscle_list_screen_test.dart`

**Interfaces:**
- Consumes: `MuscleCatalog.search` (Task 6).
- Produces: `MuscleListScreen({Key? key, required MuscleCatalog catalog})` — pops with the tapped `Muscle`. Keys: `muscle_search_field`, `muscle_tile_<id>`. `Future<Muscle?> pushMuscleList(BuildContext context, MuscleCatalog catalog)`.

- [ ] **Step 1: Add ARB strings**

`app_en.arb`:
```json
  "musclesSearchHint": "Search muscles",
  "musclesNoResults": "No muscles found",
  "muscleGroupChest": "Chest",
  "muscleGroupShoulders": "Shoulders",
  "muscleGroupBack": "Back",
  "muscleGroupArms": "Arms",
  "muscleGroupCore": "Core",
  "muscleGroupHips": "Hips & glutes",
  "muscleGroupThighs": "Thighs",
  "muscleGroupLowerLegs": "Lower legs",
  "muscleGroupNeck": "Neck"
```
`app_th.arb`:
```json
  "musclesSearchHint": "ค้นหากล้ามเนื้อ",
  "musclesNoResults": "ไม่พบกล้ามเนื้อ",
  "muscleGroupChest": "อก",
  "muscleGroupShoulders": "ไหล่",
  "muscleGroupBack": "หลัง",
  "muscleGroupArms": "แขน",
  "muscleGroupCore": "แกนกลางลำตัว",
  "muscleGroupHips": "สะโพกและก้น",
  "muscleGroupThighs": "ต้นขา",
  "muscleGroupLowerLegs": "น่องและหน้าแข้ง",
  "muscleGroupNeck": "คอ"
```
Run: `flutter gen-l10n`.

- [ ] **Step 2: Write the failing test `test/features/muscles/muscle_list_screen_test.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_diary/features/muscles/muscle_list_screen.dart';
import 'package:food_diary/models/muscle.dart';

import '../../test_utils.dart';
import 'fixtures.dart';

void main() {
  testWidgets('lists muscles grouped and filters by search', (tester) async {
    await tester.pumpWidget(localizedApp(MuscleListScreen(catalog: testCatalog())));

    expect(find.text('Chest'), findsOneWidget);
    expect(find.text('Shoulders'), findsOneWidget);
    expect(find.byKey(const Key('muscle_tile_pec_major_clavicular')), findsOneWidget);
    expect(find.byKey(const Key('muscle_tile_subscapularis')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('muscle_search_field')), 'delt');
    await tester.pump();
    expect(find.byKey(const Key('muscle_tile_deltoid_anterior')), findsOneWidget);
    expect(find.byKey(const Key('muscle_tile_pec_major_clavicular')), findsNothing);
    expect(find.text('Chest'), findsNothing);

    await tester.enterText(find.byKey(const Key('muscle_search_field')), 'zzz');
    await tester.pump();
    expect(find.text('No muscles found'), findsOneWidget);
  });

  testWidgets('searches Thai names', (tester) async {
    await tester.pumpWidget(
      localizedApp(MuscleListScreen(catalog: testCatalog()), locale: const Locale('th')),
    );
    await tester.enterText(find.byKey(const Key('muscle_search_field')), 'อกบน');
    await tester.pump();
    expect(find.byKey(const Key('muscle_tile_pec_major_clavicular')), findsOneWidget);
    expect(find.byKey(const Key('muscle_tile_deltoid_anterior')), findsNothing);
  });

  testWidgets('tapping a muscle pops it', (tester) async {
    Muscle? chosen;
    await tester.pumpWidget(
      localizedApp(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async => chosen = await pushMuscleList(context, testCatalog()),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('muscle_tile_subscapularis')));
    await tester.pumpAndSettle();
    expect(chosen?.id, 'subscapularis');
  });
}
```

- [ ] **Step 3: Run to verify failure**

Run: `flutter test test/features/muscles/muscle_list_screen_test.dart`
Expected: FAIL — file not found.

- [ ] **Step 4: Implement `lib/features/muscles/muscle_list_screen.dart`**

```dart
import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../models/muscle.dart';
import 'muscle_catalog.dart';

String muscleGroupLabel(AppLocalizations l10n, MuscleGroup g) => switch (g) {
  MuscleGroup.chest => l10n.muscleGroupChest,
  MuscleGroup.shoulders => l10n.muscleGroupShoulders,
  MuscleGroup.back => l10n.muscleGroupBack,
  MuscleGroup.arms => l10n.muscleGroupArms,
  MuscleGroup.core => l10n.muscleGroupCore,
  MuscleGroup.hips => l10n.muscleGroupHips,
  MuscleGroup.thighs => l10n.muscleGroupThighs,
  MuscleGroup.lowerLegs => l10n.muscleGroupLowerLegs,
  MuscleGroup.neck => l10n.muscleGroupNeck,
};

Future<Muscle?> pushMuscleList(BuildContext context, MuscleCatalog catalog) =>
    Navigator.push<Muscle>(
      context,
      MaterialPageRoute(builder: (_) => MuscleListScreen(catalog: catalog)),
    );

/// Searchable list of every muscle, grouped by body region. The only way to
/// reach deep muscles, which have no mesh on the 3D body.
class MuscleListScreen extends StatefulWidget {
  const MuscleListScreen({super.key, required this.catalog});

  final MuscleCatalog catalog;

  @override
  State<MuscleListScreen> createState() => _MuscleListScreenState();
}

class _MuscleListScreenState extends State<MuscleListScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final results = widget.catalog.search(_query);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.musclesListTooltip)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              key: const Key('muscle_search_field'),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: l10n.musclesSearchHint,
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Expanded(
            child: results.isEmpty
                ? Center(child: Text(l10n.musclesNoResults))
                : ListView(
                    children: [
                      for (final group in MuscleGroup.values)
                        if (results.any((m) => m.group == group)) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                            child: Text(
                              muscleGroupLabel(l10n, group),
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                          for (final m in results.where((m) => m.group == group))
                            ListTile(
                              key: Key('muscle_tile_${m.id}'),
                              title: Text(m.name.resolve(locale)),
                              subtitle: Text(m.anatomical),
                              trailing: m.deep
                                  ? const Icon(Icons.layers_outlined)
                                  : null,
                              onTap: () => Navigator.pop(context, m),
                            ),
                        ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Default the screen's list opener**

In `lib/features/muscles/muscle_map_screen.dart`, add `import 'muscle_list_screen.dart';` and change `_openList`:

```dart
  Future<void> _openList() async {
    final open =
        widget.openMuscleList ??
        (BuildContext context) => pushMuscleList(context, widget.catalog);
    final muscle = await open(context);
    if (muscle != null && mounted) _openMuscle(muscle.id);
  }
```
Update the `openMuscleList` doc comment: `/// Shows the muscle list and returns the chosen muscle. Defaults to [pushMuscleList]; overridden in tests.`

- [ ] **Step 6: Run to verify pass**

Run: `flutter test test/features/muscles/`
Expected: all pass.

- [ ] **Step 7: Commit**

```bash
git add lib/features/muscles/muscle_list_screen.dart lib/features/muscles/muscle_map_screen.dart lib/l10n/app_en.arb lib/l10n/app_th.arb test/features/muscles/muscle_list_screen_test.dart
git commit -m "Add searchable muscle list

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 14: Wire the Muscles tab

**Files:**
- Modify: `lib/main.dart` (imports; `_HomeShellState.initState`; `screens` list; `destinations` at `lib/main.dart:292-305`)

**Interfaces:**
- Consumes: `MuscleCatalog.load` (Task 6), `MuscleMapScreen` (Task 12).

Note: tabs are rebuilt via `screens[_tab]`, so the WebView reloads each time the tab is opened (~0.5–1 s). Accepted for now; do not switch to `IndexedStack` (changes behavior of the other tabs).

- [ ] **Step 1: Edit `lib/main.dart`**

Add imports (alphabetical with the others):
```dart
import 'package:flutter/services.dart';
import 'features/muscles/muscle_catalog.dart';
import 'features/muscles/muscle_map_screen.dart';
```

In `_HomeShellState`, add a field and initialize it in `initState`:
```dart
  late Future<MuscleCatalog> _muscleCatalogFuture;
```
```dart
    _muscleCatalogFuture = MuscleCatalog.load(rootBundle);
```

In `screens`, insert between `CaptureScreen(...)` and the Profile `FutureBuilder`:
```dart
      FutureBuilder<MuscleCatalog>(
        future: _muscleCatalogFuture,
        builder: (context, snapshot) {
          final catalog = snapshot.data;
          if (catalog == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return MuscleMapScreen(catalog: catalog);
        },
      ),
```

In `destinations`, insert between the Capture and Profile entries:
```dart
          NavigationDestination(
            icon: const Icon(Icons.accessibility_new),
            label: AppLocalizations.of(context).musclesAppBarTitle,
          ),
```

Check `CaptureScreen.onSave` still does `setState(() => _tab = 0)` (Diary) — unaffected. Search for any other hard-coded tab index: `grep -n "_tab = " lib/main.dart`; Profile moved from index 2 to 3, so update any `_tab = 2` that meant Profile.

- [ ] **Step 2: Analyze and run the full suite**

Run: `flutter analyze && flutter test && node --test test/js/`
Expected: `No issues found!`, all Dart tests pass, all JS tests pass.

- [ ] **Step 3: Commit**

```bash
git add lib/main.dart
git commit -m "Add Muscles tab to the bottom navigation

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 15: Device verification and version bump

**Files:**
- Modify: `pubspec.yaml` (`version: 1.13.0+17`)

- [ ] **Step 1: Run on a real Android device**

Run: `flutter run --release` with a phone connected (`flutter devices` to confirm).
Checklist — record results in the task report:
1. Muscles tab opens; body visible in < 2 s.
2. Rotation smooth (no visible stutter); pinch zoom within limits.
3. Taps land correctly on: upper chest, side delt, rear delt, teres major, infraspinatus, biceps long vs short head, triceps lateral head, vastus medialis, gastrocnemius medial vs lateral, tibialis anterior.
4. A rotate gesture never opens a sheet.
5. Expanding an exercise colors primary strong / secondary light; collapsing returns to the single muscle.
6. Thai locale (Profile → Language → ไทย): all Muscles UI and content in Thai.
7. Airplane mode: tab still works (fully offline).
8. Debug WebView via `chrome://inspect` if anything fails; fix and re-run tests.

- [ ] **Step 2: Measure APK size delta**

```bash
git worktree add ../food_diary_base 1a3512b
(cd ../food_diary_base && flutter build apk --release && ls -l build/app/outputs/flutter-apk/app-release.apk)
git worktree remove --force ../food_diary_base
flutter build apk --release && ls -l build/app/outputs/flutter-apk/app-release.apk
```
(`1a3512b` is the 1.12.0 commit before this feature.)
Record both sizes in the task report (expected growth ~3–6 MB plus the WebView plugin).

- [ ] **Step 3: Bump version**

In `pubspec.yaml`: `version: 1.12.0+16` → `version: 1.13.0+17`.

- [ ] **Step 4: Final checks and commit**

Run: `flutter analyze && flutter test && node --test test/js/`
Expected: all clean.

```bash
git add pubspec.yaml
git commit -m "Bump version to 1.13.0

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

- [ ] **Step 5: Remind the user**

Exercise content (Tasks 7–9) was authored by Claude and must be reviewed by someone with exercise knowledge before release (spec "Content rules").
