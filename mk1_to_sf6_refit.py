"""
MK1 -> SF6 model refit (Blender 4.x). Educational demo.

Before running, in one .blend:
  1. Import the SF6 fighter you're replacing with REME (RE Mesh Editor): its armature + body mesh.
  2. Import the MK1 character mesh (.psk from FModel) with the PSK/PSA addon.
  3. Set the three names below (Outliner names).

What it does:
  - Scales/moves the MK1 mesh to match the SF6 body's height and feet position
  - Strips MK1 bone weights, transfers SF6 weights from the reference body (no bone-name mapping needed)
  - Parents to the SF6 armature, cleans tiny weights, limits influences per vertex
Then: fix materials (see README), export with REME.

Run: Scripting tab -> Open this file -> Run Script
"""
import bpy
from mathutils import Vector

# ---- SET THESE ----
SRC_MESH   = "Scorpion"        # MK1 mesh object
REF_MESH   = "Ryu_Body"        # SF6 body mesh object (weight source)
TARGET_ARM = "Ryu_Armature"    # SF6 armature object
MAX_INFLUENCES = 4             # raise to 8 if REME export accepts it and deformation looks stiff
CLEAN_THRESHOLD = 0.01
# -------------------

def world_bbox(obj):
    pts = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
    mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return mn, mx

def get(name):
    obj = bpy.data.objects.get(name)
    if not obj:
        raise RuntimeError(f"Object '{name}' not found. Check the names at the top of the script.")
    return obj

def main():
    src, ref, arm = get(SRC_MESH), get(REF_MESH), get(TARGET_ARM)
    if arm.type != 'ARMATURE':
        raise RuntimeError(f"'{TARGET_ARM}' is not an armature")

    bpy.ops.object.mode_set(mode='OBJECT') if bpy.context.object else None
    bpy.ops.object.select_all(action='DESELECT')

    # 1. Unparent from MK1 armature, keep transform
    src.select_set(True)
    bpy.context.view_layer.objects.active = src
    if src.parent:
        bpy.ops.object.parent_clear(type='CLEAR_KEEP_TRANSFORM')

    # 2. Match height + ground position to the SF6 body
    s_mn, s_mx = world_bbox(src)
    r_mn, r_mx = world_bbox(ref)
    s_h, r_h = (s_mx.z - s_mn.z), (r_mx.z - r_mn.z)
    if s_h > 0:
        f = r_h / s_h
        src.scale = src.scale * f
        bpy.context.view_layer.update()
        s_mn, s_mx = world_bbox(src)
    s_c = (s_mn + s_mx) / 2
    r_c = (r_mn + r_mx) / 2
    src.location += Vector((r_c.x - s_c.x, r_c.y - s_c.y, r_mn.z - s_mn.z))
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    print(f"[refit] scaled x{r_h / s_h if s_h else 1:.3f}, aligned to {REF_MESH}")

    # 3. Remove MK1 weights and armature modifiers
    for m in [m for m in src.modifiers if m.type == 'ARMATURE']:
        src.modifiers.remove(m)
    src.vertex_groups.clear()

    # 4. Create SF6 vertex groups (same names as reference body)
    for vg in ref.vertex_groups:
        src.vertex_groups.new(name=vg.name)

    # 5. Transfer weights from SF6 body
    dt = src.modifiers.new("WeightTransfer", 'DATA_TRANSFER')
    dt.object = ref
    dt.use_vert_data = True
    dt.data_types_verts = {'VGROUP_WEIGHTS'}
    dt.vert_mapping = 'POLYINTERP_NEAREST'
    dt.layers_vgroup_select_src = 'ALL'
    dt.layers_vgroup_select_dst = 'NAME'
    bpy.ops.object.datalayout_transfer(modifier=dt.name)
    bpy.ops.object.modifier_apply(modifier=dt.name)
    print(f"[refit] transferred {len(ref.vertex_groups)} vertex groups")

    # 6. Clean + limit + normalize
    bpy.ops.object.mode_set(mode='WEIGHT_PAINT')
    bpy.ops.object.vertex_group_clean(group_select_mode='ALL', limit=CLEAN_THRESHOLD)
    bpy.ops.object.vertex_group_limit_total(group_select_mode='ALL', limit=MAX_INFLUENCES)
    bpy.ops.object.vertex_group_normalize_all(group_select_mode='ALL', lock_active=False)
    bpy.ops.object.mode_set(mode='OBJECT')

    # 7. Remove empty groups
    used = set()
    for v in src.data.vertices:
        for g in v.groups:
            if g.weight > 0:
                used.add(g.group)
    for vg in [vg for vg in src.vertex_groups if vg.index not in used]:
        src.vertex_groups.remove(vg)

    # 8. Parent to SF6 armature
    bpy.ops.object.select_all(action='DESELECT')
    src.select_set(True)
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.parent_set(type='ARMATURE')  # keeps our transferred weights
    print(f"[refit] done: '{SRC_MESH}' rigged to '{TARGET_ARM}'. Pose the armature to check deformation.")

main()
