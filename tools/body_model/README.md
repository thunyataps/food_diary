# body_model

Builds `assets/body_viewer/body.glb` from Z-Anatomy (CC BY-SA 4.0,
https://github.com/Z-Anatomy/Models-of-human-anatomy). The source `.blend` is not committed.

## Source
- Zip: https://raw.githubusercontent.com/Z-Anatomy/Models-of-human-anatomy/master/Z-Anatomy.zip
  (the brief's `The-blend` repo URL now returns an HTML page / empty file; the repo is
  `Models-of-human-anatomy`, default branch `master`, file is a plain 83 MB zip, not LFS)
- Downloaded: 2026-10-12, SHA-256: `e029688545627bd0214b269e1063143abb580aad72b2c2445d6d8a9a0d9da736`
- Blend inside zip: `Z-Anatomy/Startup.blend` (293 MB; extracted to `~/Z-Anatomy/template/Z-Anatomy/Startup.blend`;
  note capital S). Blender prints "scripts disabled ... skipping 'z-anatomy.py'" — harmless.

## Tools
- Blender 5.2.0 LTS at `/Applications/Blender.app/Contents/MacOS/Blender` (not on PATH; use the full path)
- gltfpack 1.3.0 (`npm i -g gltfpack@1.3.0`)

## Inventory
```
mkdir -p tools/body_model/out
/Applications/Blender.app/Contents/MacOS/Blender -b ~/Z-Anatomy/template/Z-Anatomy/Startup.blend -P tools/body_model/inventory.py -- tools/body_model/out/inventory.json
```
7184 objects: 4569 MESH, 1660 FONT, 951 CURVE, 3 LIGHT, 1 CAMERA. Units are meters, Z up; the body is
~1.75 m tall, centered on x = 0. Y is the depth axis (anterior = -Y: pectoralis y < 0, trapezius/lats y > 0).

Filter for muscles: MESH objects in collections `4: Muscular system` AND `Muscles` (509 meshes).
The other 280 meshes in `4: Muscular system` (789 total) are not in `Muscles` and are not muscles:
105 `.j` 2-vert point markers, 78 bursae (collection `Bursae`), 56 fascia (`Fascia`, e.g. Diaphragmatic fascia,
Transversalis fascia), 38 tendon sheaths (`Tendon sheaths`),
2 fibrous sheaths of digit of hand, and 1 `Muscular system.g` (791 verts). Requiring `Muscles` excludes all of them.
Separately, the insertion markers (`Deltoid muscle.el`, `.ol/.or/.er`; 705 meshes) live only in
`2: Muscular insertions`, not in `4: Muscular system`, and carry SOLIDIFY/SUBSURF.

## Findings
- Side suffix: `.l` / `.r`. `.l` center x sign: **+** (252/252 `.l` muscles have x > 0; 253/253 `.r` have x < 0).
  So character's left = Blender +X, as expected. 4 unsuffixed midline/unpaired muscles: Diaphragm, Linea alba,
  Iliocostalis colli muscle (x = +0.05, probably missing suffix), Transverse arytenoid muscle.
- Heads already separate (all exist as `<name>.l` / `.r` separate meshes):
  - Deltoid: Clavicular / Acromial / Scapular spinal part of deltoid muscle
  - Pectoralis major: Clavicular head, Sternocostal head, (Abdominal part of pectoralis major muscle) — note the parentheses in the name
  - Biceps brachii: Long head, Short head
  - Triceps brachii: Long, Lateral, Medial head
  - Trapezius: Descending / Transverse / Ascending part of trapezius muscle
  - Gastrocnemius: Lateral head, Medial head
  - Also single objects: Rhomboid major, Rhomboid minor, Latissimus dorsi, Rectus abdominis, Gluteus maximus/medius/minimus,
    Rectus femoris, Vastus lateralis/medialis/intermedius, Semitendinosus, Semimembranosus,
    Long head + Short head of biceps femoris, Soleus, Tibialis anterior, External/Internal abdominal oblique,
    Serratus anterior, Sternocleidomastoid, Brachioradialis, Teres major/minor, Infraspinatus, Supraspinatus.
- Heads needing plane splits: none found among the probed targets. Rectus abdominis is a single mesh per side
  (10304 verts, includes tendinous intersections) and Latissimus dorsi is a single mesh per side; split only if the app
  wants sub-regions. Note the exact name differences: no plain "Deltoid muscle" mesh exists
  (only `Deltoid muscle.el/.er` insertion markers and `Deltoid fascia`, which is a fascia mesh, not a muscle).
- Modifiers on muscles: none on the real muscle bellies. Only 23 of the 509 muscle-collection meshes have modifiers
  (SOLIDIFY 22, SUBSURF 5) and they are all thin sheets: retinacula, patellar retinacula, plantar aponeurosis,
  transverse metacarpal/metatarsal ligaments, plus Diaphragm (SUBSURF). Insertion markers (`.ol/.or/.el/.er`) also carry
  SOLIDIFY+SUBSURF. No MIRROR/ARRAY/CURVE on any of the 509 muscle meshes.
  Non-muscle objects do carry them: 44 objects have MIRROR (42 MESH, 2 CURVE; mostly `7: Nervous system & Sense organs`
  (35), `8: Visceral systems` (6), 1 cardiovascular, 1 skeletal; 7 are in `Head`, 6 of those also in `Brain`), and 28 of the 44
  also have ARRAY+CURVE (30 objects in the file have ARRAY and CURVE). Task 2 must bake modifiers if it pulls in any of
  these as context. Baking modifiers is still safe.
- Context collections:
  - Skeleton: `1: Skeletal system` (1244 meshes; sub-collections `Axial skeleton`, `Appendicular skeleton`, `Bones of ...`;
    many `.i/.j` marker objects live in `Bonus collection`). Skull/head bones also in `Head`.
  - Muscles: `4: Muscular system` > `Muscles` (children `Muscle`, `Tendon`) — every muscle mesh is in both.
    Region/compartment sub-collections (e.g. `Muscles of upper limb`, `Superficial muscles`, `Left/Right upper limb`) are
    attached to the same objects, so an object belongs to many collections; use the object name, not a single collection.
  - Skin/head: **no skin surface mesh exists in this file.** `Skin` collection has no objects (only the child `Dermis`),
    and `9: Regions of human body` holds 299 tiny 2-vert `.j` markers. Task 2 must use the skull (`Head` collection /
    `Frontal bone`, etc.) and the surface-region markers for head context, or build a context shell from other sources.
    This is the main risk for the "skin-head" context group.

## Rebuild
(filled in Task 2)
