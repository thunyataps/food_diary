"""Build the raw muscle-map GLB from a Z-Anatomy .blend using mesh_map.json.

Usage:
  blender -b <startup.blend> -P tools/body_model/build_glb.py -- <out.glb>

Every muscle side becomes one mesh object named `<muscleId>__L` / `__R`
(character's left = +X, facing -Y). Context geometry is merged per group
into `_ctx_<group>`. Fails (exit 1) if any non-deep muscle ends up empty.

Decimation per output object: an explicit `decimate` ratio wins; otherwise a
`tris` target (triangles per muscle side, or per context group) is turned into
a ratio; otherwise the top-level `muscle_tris` (muscles) or `decimate` applies.
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
SIDE_SUFFIX = {'.l': 'L', '.r': 'R'}


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


def split_sides(obj, mesh):
    """Return [(side, mesh)]. `.l`/`.r` objects keep their side; others are cut at x=0
    when they span the midline."""
    side = SIDE_SUFFIX.get(obj.name[-2:])
    if side:
        return [(side, mesh)]
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
    out.validate()
    out.shade_smooth()
    out.update()
    return out


def tri_count(mesh):
    mesh.calc_loop_triangles()
    return len(mesh.loop_triangles)


def ratio_for(spec, mesh, default_tris=None, default_ratio=1.0):
    if 'decimate' in spec:
        return spec['decimate']
    target = spec.get('tris', default_tris)
    if target is None:
        return default_ratio
    return min(1.0, target / max(1, tri_count(mesh)))


def decimated(obj, ratio):
    if ratio >= 1:
        return
    mod = obj.modifiers.new('decimate', 'DECIMATE')
    mod.ratio = ratio
    depsgraph = bpy.context.evaluated_depsgraph_get()
    mesh = bpy.data.meshes.new_from_object(obj.evaluated_get(depsgraph), depsgraph=depsgraph)
    obj.modifiers.clear()
    old = obj.data
    obj.data = mesh
    bpy.data.meshes.remove(old)


def material(name, rgba):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.diffuse_color = rgba
    if mat.node_tree:
        bsdf = mat.node_tree.nodes.get('Principled BSDF')
        if bsdf:
            bsdf.inputs['Base Color'].default_value = rgba
            bsdf.inputs['Roughness'].default_value = 0.9
    return mat


def new_object(name, mesh, mat, ratio, out_coll):
    obj = bpy.data.objects.new(name, mesh)
    out_coll.objects.link(obj)
    bpy.context.view_layer.update()
    decimated(obj, ratio)
    obj.data.validate()  # drop degenerate faces left by decimation
    obj.data.name = name
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
    muscle_tris = CONFIG.get('muscle_tris')
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
            for side, mesh in split_sides(obj, baked_mesh(obj)):
                by_side[side].append(apply_splits(mesh, side, spec.get('split', [])))
        built[mid] = []
        for side, meshes in by_side.items():
            meshes = [m for m in meshes if len(m.polygons)]
            if meshes:
                name = f'{mid}__{side}'
                mesh = merge(name, meshes)
                ratio = ratio_for(spec, mesh, muscle_tris, default_ratio)
                built[mid].append(new_object(name, mesh, muscle_mat, ratio, out_coll))

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
        excl = [re.compile(p, re.I) for p in spec.get('exclude', [])]
        objs = [o for o in dict.fromkeys(objs) if o.name not in used and o.users_collection
                and o.users_collection[0] is not out_coll
                and not any(p.search(o.name) for p in excl)]
        ensure_evaluable(objs)
        meshes = [baked_mesh(o) for o in objs]
        used.update(o.name for o in objs)
        meshes = [m for m in meshes if len(m.polygons)]
        if meshes:
            name = f'_ctx_{group}'
            mesh = merge(name, meshes)
            new_object(name, mesh, ctx_mat, ratio_for(spec, mesh, None, default_ratio), out_coll)
            print(f'build_glb: context {group}: {len(objs)} source objects')

    empty = [mid for mid, objs in built.items() if not objs]
    if empty:
        sys.exit('build_glb: non-deep muscles produced no geometry: ' + ', '.join(empty))

    for obj in bpy.context.view_layer.objects:
        obj.select_set(False)
    tris, muscle_total = 0, 0
    per_obj = {}
    for obj in out_coll.objects:
        obj.select_set(True)
        n = tri_count(obj.data)
        per_obj[obj.name] = n
        tris += n
        if not obj.name.startswith('_ctx_'):
            muscle_total += n

    bpy.ops.export_scene.gltf(
        filepath=out_path(),
        export_format='GLB',
        use_selection=True,
        export_yup=True,
        export_texcoords=False,
        export_animations=False,
    )
    print(f'build_glb: {len(out_coll.objects)} objects, {tris} triangles '
          f'({muscle_total} tappable, {tris - muscle_total} context)')
    for name in sorted(n for n in per_obj if n.startswith('_ctx_')):
        print(f'  {name}: {per_obj[name]} tris')
    for mid, objs in sorted(built.items()):
        print(f'  {mid}: ' + ', '.join(f'{o.name} ({per_obj[o.name]})' for o in objs))
    deep = sorted(mid for mid, spec in CONFIG['muscles'].items() if spec.get('deep'))
    print(f'build_glb: deep ({len(deep)}): ' + ', '.join(deep))


main()
