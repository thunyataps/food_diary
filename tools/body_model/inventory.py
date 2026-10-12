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
