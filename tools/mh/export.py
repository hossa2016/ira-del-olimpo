"""Exporta humano + esqueleto + acciones a .glb para Godot (formas horneadas, ayudantes eliminados)."""
import sys, bpy, addon_utils, bmesh
addon_utils.enable("bl_ext.user_default.mpfb", default_set=True)
from bl_ext.user_default.mpfb.services.targetservice import TargetService
blend, out = sys.argv[1], sys.argv[2]
bpy.ops.wm.open_mainfile(filepath=blend)
arm = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]
body = [o for o in bpy.data.objects if o.type == "MESH" and o.parent == arm][0]
arm.name = "Rig"
body.name = "Body"
# hornear formas (shape keys) en la malla
bpy.context.view_layer.objects.active = body
TargetService.bake_targets(body)
# borrar geometría de ayuda (lo que oculta el modificador MASK)
mask = [m for m in body.modifiers if m.type == "MASK"]
if mask:
    vg = body.vertex_groups.get(mask[0].vertex_group)
    keep = set()
    if vg:
        for v in body.data.vertices:
            for g in v.groups:
                if g.group == vg.index and g.weight > 0.5:
                    keep.add(v.index)
    bm = bmesh.new(); bm.from_mesh(body.data)
    inv = mask[0].invert_vertex_group
    dele = [v for v in bm.verts if ((v.index in keep) == inv)]
    bmesh.ops.delete(bm, geom=dele, context="VERTS")
    bm.to_mesh(body.data); bm.free()
    for m in mask:
        body.modifiers.remove(m)
# un único material simple (Godot lo sustituye)
for i in range(len(body.material_slots) - 1, 0, -1):
    body.active_material_index = i
    bpy.ops.object.material_slot_remove({"object": body}) if False else None
mat = bpy.data.materials.new("skin")
body.data.materials.clear()
body.data.materials.append(mat)
# quitar grupos de vértices que no son huesos
bones = set(b.name for b in arm.data.bones)
for g in list(body.vertex_groups):
    if g.name not in bones:
        body.vertex_groups.remove(g)
for o in list(bpy.data.objects):
    if o not in (arm, body):
        bpy.data.objects.remove(o)
print("verts", len(body.data.vertices))
# todas las acciones con usuario ficticio se exportan
for a in bpy.data.actions:
    a.use_fake_user = True
arm.animation_data_create()
arm.animation_data.action = None
bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_animation_mode="ACTIONS", export_apply=False,
                          export_skins=True, export_morph=False, export_yup=True, export_force_sampling=True,
                          export_frame_range=False, export_anim_single_armature=True, export_def_bones=False)
print("exported", out)
