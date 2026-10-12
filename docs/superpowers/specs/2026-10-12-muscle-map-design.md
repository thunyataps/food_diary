# Muscle Map — Design

**Status:** Approved by user in conversation, written spec pending review.

## Goal

Add a new "Muscles" tab that shows a rotatable 3D human body. The user taps
any individual muscle (at the level of muscle heads, ~49 muscles) and sees
which exercises train it, with full text instructions for each exercise.
Selecting an exercise highlights every muscle it works (primary vs
secondary) on the 3D body.

## Non-goals

- Images, GIFs, or videos of exercises. Text only.
- Workout logging, programs, sets/reps tracking, or anything persisted.
- Supabase tables or server-side code. All content is bundled in the app.
- Face, hand, and foot muscles as tappable targets (shown as non-interactive
  context geometry only).
- iOS. The app ships as an Android `.apk` only (see
  `2026-09-02-food-nutrition-app-design.md`).
- Dark theme. The app is light-theme only today.

## Architecture

### Rendering choice

Render with **three.js inside a WebView** (`flutter_inappwebview`), loading a
bundled HTML page, three.js, and a `body.glb` model from Flutter assets.

Rationale: the hard parts of this feature are per-mesh tap picking,
highlighting, and camera focusing. three.js does all three reliably
(Raycaster, materials, OrbitControls). Alternatives considered and rejected:

- `three_js` (Dart port): avoids WebView but is immature; GLB loading and
  raycasting are not dependable yet.
- `flutter_scene` (Impeller): fastest, but experimental with no picking.
- `model_viewer_plus` (Google model-viewer): simpler, but picking is
  per-material only and highlight control is limited.

Assets are served through Android's `WebViewAssetLoader`
(`https://appassets.androidplatform.net/...`) so `GLTFLoader` can fetch
`body.glb` without `file://` CORS problems. Works fully offline.

Cost accepted: ~0.5–1 s first-load latency, async JS↔Dart bridge, APK grows
by roughly 3–6 MB.

### Navigation

A 4th `NavigationDestination` in `lib/main.dart`, placed between Capture and
Profile: label "Muscles" / "กล้ามเนื้อ", icon `Icons.accessibility_new`.

### Files

`lib/features/muscles/`:

| File | Responsibility |
|---|---|
| `muscle_map_screen.dart` | Tab screen: viewer, front/back/reset buttons, "muscle list" button, ⓘ credits button, loading/error states |
| `body_viewer.dart` | `BodyViewer` widget wrapping `InAppWebView`; `BodyViewerController` abstract interface + WebView implementation |
| `muscle_sheet.dart` | `DraggableScrollableSheet`: muscle name (TH/EN), anatomical name, description, exercise list with in-place expansion |
| `muscle_list_screen.dart` | Searchable list of all muscles grouped by body region; required for `deep` muscles that cannot be tapped in 3D |
| `muscle_catalog.dart` | Loads `muscles.json` + `exercises.json` from assets and answers queries |

`lib/models/`: `muscle.dart`, `exercise.dart`, `localized_text.dart`.

`assets/body_viewer/`: `index.html`, `viewer.js`, `viewer_core.js`, three.js
(pinned version) with `GLTFLoader`, `OrbitControls`, `MeshoptDecoder`, and
`body.glb`.

`assets/muscles/`: `muscles.json`, `exercises.json`.

`tools/body_model/`: `README.md`, `mesh_map.json`, `build_glb.py`.

### User flow

1. User rotates/zooms the body and taps a muscle.
2. JS raycasts, takes the hit mesh name (e.g. `deltoid_anterior__L`), strips
   everything from `__` onward → `muscleId` (`deltoid_anterior`). Left and
   right sides map to the same muscle.
3. Flutter opens the muscle sheet; the muscle is highlighted in 3D and the
   camera turns to face it.
4. The exercise list shows exercises where this muscle is **primary** first,
   then those where it is **secondary**.
5. Tapping an exercise expands it in place: equipment, difficulty, 3–5 steps,
   tips, common mistakes. The 3D body highlights the exercise's primary
   muscles (strong color) and secondary muscles (light color).
6. Tapping empty background closes the selection and clears highlights.

## Data

### Where text lives

- **ARB files** (`lib/l10n/app_en.arb`, `app_th.arb`): UI chrome only — tab
  label, buttons, "Primary" / "Secondary", equipment names, difficulty
  names, error/loading messages, credits text.
- **JSON assets**: all muscle and exercise content, with every text field
  carrying both languages inline as `{ "en": ..., "th": ... }`. There are
  ~100–120 exercises with multi-paragraph content, which is too much to
  maintain as ARB keys.
- `LocalizedText.resolve(Locale)` returns Thai when the locale is `th`,
  otherwise English, and falls back to English if Thai is missing.

### `assets/muscles/muscles.json`

```json
{
  "id": "deltoid_anterior",
  "group": "shoulders",
  "deep": false,
  "name": { "en": "Front deltoid", "th": "ไหล่หน้า" },
  "anatomical": "Deltoid, clavicular part",
  "description": { "en": "...", "th": "..." }
}
```

- `group`: one of `chest`, `shoulders`, `back`, `arms`, `core`, `hips`,
  `thighs`, `lower_legs`, `neck`.
- `deep: true` marks muscles with no mesh in the model; they are reachable
  from the muscle list only. When `highlight()` names a deep muscle, the
  viewer ignores it.

### `assets/muscles/exercises.json`

```json
{
  "id": "incline_dumbbell_press",
  "name": { "en": "Incline Dumbbell Press", "th": "ดัมเบลเพรสม้านั่งเอียง" },
  "equipment": "dumbbell",
  "difficulty": "intermediate",
  "primary": ["pec_major_clavicular"],
  "secondary": ["deltoid_anterior", "triceps_lateral", "triceps_long"],
  "steps":    { "en": ["..."], "th": ["..."] },
  "tips":     { "en": ["..."], "th": ["..."] },
  "mistakes": { "en": ["..."], "th": ["..."] }
}
```

- `equipment`: `bodyweight` | `dumbbell` | `barbell` | `cable` | `machine` |
  `kettlebell` | `band`.
- `difficulty`: `beginner` | `intermediate` | `advanced`.

### Muscle list (49; `*` = `deep`)

| Group | Muscles |
|---|---|
| chest | `pec_major_clavicular`, `pec_major_sternocostal`, `pec_minor`*, `serratus_anterior` |
| shoulders | `deltoid_anterior`, `deltoid_lateral`, `deltoid_posterior`, `supraspinatus`*, `infraspinatus`, `teres_minor`, `subscapularis`*, `teres_major` |
| back | `trapezius_upper`, `trapezius_middle`, `trapezius_lower`, `rhomboids`*, `latissimus_dorsi`, `erector_spinae` |
| arms | `biceps_long`, `biceps_short`, `brachialis`, `brachioradialis`, `triceps_long`, `triceps_lateral`, `triceps_medial`, `forearm_flexors`, `forearm_extensors` |
| core | `rectus_abdominis`, `external_oblique`, `internal_oblique`*, `transversus_abdominis`* |
| hips | `gluteus_maximus`, `gluteus_medius`, `gluteus_minimus`*, `hip_adductors`, `iliopsoas`, `tensor_fasciae_latae` |
| thighs | `rectus_femoris`, `vastus_lateralis`, `vastus_medialis`, `vastus_intermedius`*, `biceps_femoris`, `semitendinosus`, `semimembranosus` |
| lower_legs | `gastrocnemius_medial`, `gastrocnemius_lateral`, `soleus`, `tibialis_anterior` |
| neck | `sternocleidomastoid` |

`deep` flags are final (milestone 1, after inspecting the model; source of
truth: `tools/body_model/mesh_map.json`). `triceps_medial` and `iliopsoas`
were candidates but are tappable: Z-Anatomy shows them from outside (distal
medial upper arm; groin).

### Content rules

- Every muscle has ≥3 exercises where it is primary; `deep` muscles ≥1.
- Every exercise has 3–5 steps, ≥1 tip, ≥1 mistake, in both languages.
- Content is authored by Claude in both languages. **It must be reviewed by
  someone with exercise knowledge before release.**

## 3D model pipeline

Source: **Z-Anatomy** (CC BY-SA 4.0) `.blend` file. Too large to commit; the
download URL and exact version are recorded in `tools/body_model/README.md`.

`tools/body_model/build_glb.py`, run headless as
`blender -b <Z-Anatomy.blend> -P tools/body_model/build_glb.py`, is the only
way `body.glb` is produced. It:

1. Reads `mesh_map.json` (`muscleId → [Z-Anatomy object names]`).
2. Extracts those objects and renames them `<muscleId>__L` / `<muscleId>__R`
   (further suffixes like `__2` for multi-part muscles).
3. Splits muscle heads that Z-Anatomy does not separate, using planes or
   vertex groups defined in the script. If a split cannot be scripted, it is
   done with Blender tooling and the steps are documented in the README.
4. Adds non-tappable context geometry (head/face, hands, feet, tendons,
   unlisted muscles, visible skeleton) with names prefixed `_ctx_`.
5. Decimates and exports GLB.

Then `gltfpack` (meshopt compression) produces the committed
`assets/body_viewer/body.glb`. Target: ~150k triangles total, file ≤ 4 MB.

License: credit Z-Anatomy via the ⓘ button on the Muscles screen. The
derived `body.glb` is itself CC BY-SA 4.0. App code is not affected.

## 3D look and interaction

- Background: app surface `#FAF6F0`.
- Default muscle color: muted red-pink. `_ctx_` geometry: warm grey.
- Selected / primary: brand terracotta `#C1652F`. Secondary: light terracotta
  tint. While anything is selected, all other muscles are desaturated.
- Lighting: `HemisphereLight` + two `DirectionalLight`s;
  `MeshStandardMaterial`, matte.
- Controls (`OrbitControls`): rotate around the vertical axis, limited polar
  angle, pinch zoom with min/max distance, pan disabled.
- Tap vs drag: a pointer sequence counts as a tap only if it moved < 6 px and
  lasted < 300 ms.
- Focus: on `select(id)`, the camera tweens to face the side the muscle's
  bounding-box center lies on, with a slight zoom.
- Render on demand only (while controls change or a tween runs);
  `pixelRatio = min(devicePixelRatio, 2)`.

## JS ↔ Dart bridge

| Direction | Messages |
|---|---|
| JS → Dart | `ready`, `muscleTapped {id}`, `backgroundTapped`, `error {message}` |
| Dart → JS | `select(id)`, `highlight({primary, secondary})`, `clear()`, `setView("front" \| "back")`, `resetView()` |

`BodyViewerController` is the only Dart surface that knows about JS. Screens
depend on the abstract interface, which widget tests replace with a fake.

## Error handling

- Spinner until `ready`.
- On `error`, or if `ready` has not arrived within 10 s: show a message with
  a "Retry" button (reloads the WebView) and keep the "muscle list" button
  working, so all content stays reachable without 3D.
- Catalog JSON parse failure is a programming error caught by the integrity
  test, not handled at runtime.

## Testing

- **Unit:** `Muscle` / `Exercise` / `LocalizedText` JSON parsing and Thai →
  English fallback; `MuscleCatalog.exercisesFor(id)` ordering (primary before
  secondary); muscle search over both languages.
- **Catalog integrity** (`test/features/muscles/catalog_integrity_test.dart`):
  every referenced muscle id exists; ids unique; both languages present in
  every field; 3–5 steps; per-muscle exercise minimums from Content rules.
- **Model integrity** (`test/features/muscles/body_model_test.dart`): parse
  the GLB JSON chunk in Dart; every non-`_ctx_` mesh maps to a muscle id;
  every non-`deep` muscle has at least one mesh; file ≤ 4 MB.
- **Widget:** with a fake `BodyViewerController` — simulated `muscleTapped`
  opens the sheet with the right name and exercises; expanding an exercise
  calls `highlight` with its primary/secondary ids; `error` and timeout show
  Retry + muscle list; list screen search filters and opens the sheet.
- **JS:** pure logic in `viewer_core.js` (mesh name → id, tap-vs-drag,
  facing side) tested with `node --test`.
- **Manual, real Android device:** smooth rotation; taps land on the
  intended muscle including small ones (rear delt, teres); screen ready in
  < 2 s; record APK size delta.

## Milestones

1. **Model spike (riskiest first):** inspect Z-Anatomy's muscle-head
   granularity; write `mesh_map.json` + `build_glb.py`; produce `body.glb`;
   finalize the muscle list and `deep` flags.
2. **Standalone viewer:** `index.html` / `viewer.js` running in a desktop
   browser against `body.glb`.
3. **Flutter integration:** add `flutter_inappwebview`; `BodyViewer` +
   controller; new tab; loading/error states.
4. **Data:** models, catalog, integrity tests, `muscles.json`, then exercise
   content region by region.
5. **UI:** muscle sheet, exercise expansion + highlight, muscle list screen,
   credits, ARB strings (EN + TH).
6. **Finish:** device testing; bump version to 1.13.0.

## Prerequisites

Not installed on the dev machine yet; each is confirmed with the user before
installing or downloading:

- Blender: `brew install --cask blender`
- gltfpack: `npm i -g gltfpack`
- Z-Anatomy `.blend` (several GB), stored outside the repo.
