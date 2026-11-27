"""Damón v2: humano MakeHuman + posición de ojos + piel horneada (color y normal) en texturas.
Uso: python3 build_v2.py <prefijo_salida> <macro.json> <targets.json> <tono r,g,b>
Genera <prefijo>.blend, <prefijo>_skin_c.png, <prefijo>_skin_n.png, <prefijo>_info.json
"""
import sys, os, json, bpy, addon_utils
addon_utils.enable("bl_ext.user_default.mpfb", default_set=True)
from bl_ext.user_default.mpfb.services.humanservice import HumanService
from bl_ext.user_default.mpfb.services.targetservice import TargetService

pref, macro_j, targets_j, tone = sys.argv[1], sys.argv[2], sys.argv[3], [float(x) for x in sys.argv[4].split(",")]
bpy.ops.wm.read_factory_settings(use_empty=True)
addon_utils.enable("bl_ext.user_default.mpfb", default_set=True)
macro = TargetService.get_default_macro_info_dict()
macro.update(json.loads(open(macro_j).read()))
bm = HumanService.create_human(mask_helpers=True, detailed_helpers=False, extra_vertex_groups=True,
                               feet_on_ground=False, scale=0.1, macro_detail_dict=macro)
T = "/root/.config/blender/5.3/extensions/user_default/mpfb/data/targets"
for rel, wt in json.loads(open(targets_j).read()).items():
    fp = os.path.join(T, rel + ".target.gz")
    if os.path.exists(fp):
        TargetService.load_target(bm, fp, weight=float(wt))
    else:
        print("FALTA", rel)

# fijar la forma en la malla ANTES de ajustar el esqueleto (si no, el esqueleto toma la forma base)
TargetService.bake_targets(bm)
# posición de los ojos: rig "default" temporal (tiene huesos de ojo)
info = {}
tmp = HumanService.add_builtin_rig(bm, "default", import_weights=False)
for b in tmp.data.bones:
    if "eye" in b.name.lower():
        info[b.name] = list(tmp.matrix_world @ b.head_local)
        info[b.name + "_tail"] = list(tmp.matrix_world @ b.tail_local)
bm.parent = None
for m in list(bm.modifiers):
    if m.type == "ARMATURE":
        bm.modifiers.remove(m)
bpy.data.objects.remove(tmp)
rig = HumanService.add_builtin_rig(bm, "game_engine", import_weights=True)
for pb in rig.pose.bones:
    pb.rotation_mode = "QUATERNION"
info["height"] = max((bm.matrix_world @ v.co).z for v in bm.data.vertices) - min((bm.matrix_world @ v.co).z for v in bm.data.vertices)
info["feet_z"] = min((bm.matrix_world @ v.co).z for v in bm.data.vertices)
print("altura", info["height"], "pies", info["feet_z"])

# piel procedimental de MPFB y horneado a texturas
HumanService.set_character_skin(None, bm, skin_type="LAYERED")
sc = bpy.context.scene
sc.render.engine = "CYCLES"
sc.cycles.device = "CPU"
sc.cycles.samples = 4
for kind, fname in [("DIFFUSE", "_skin_c.png"), ("NORMAL", "_skin_n.png")]:
    img = bpy.data.images.new("bake_" + kind, 2048, 2048, alpha=False)
    if kind == "NORMAL":
        img.colorspace_settings.name = "Non-Color"
    for mat in bm.data.materials:
        if mat is None or not mat.use_nodes:
            continue
        n = mat.node_tree.nodes.new("ShaderNodeTexImage")
        n.image = img
        mat.node_tree.nodes.active = n
    bpy.ops.object.select_all(action="DESELECT")
    bm.select_set(True)
    bpy.context.view_layer.objects.active = bm
    if kind == "DIFFUSE":
        sc.render.bake.use_pass_direct = False
        sc.render.bake.use_pass_indirect = False
        sc.render.bake.use_pass_color = True
    sc.render.bake.margin = 8
    bpy.ops.object.bake(type=kind)
    img.filepath_raw = pref + fname
    img.file_format = "PNG"
    img.save()
    print("horneado", kind)
json.dump(info, open(pref + "_info.json", "w"), indent=1)
bpy.ops.wm.save_as_mainfile(filepath=pref + ".blend")
print("ok", pref)

# ---- máscaras de barba y cejas pintadas por vértice y horneadas a UV ----
import mathutils
eyeL = mathutils.Vector(info["eye.L"]); eyeR = mathutils.Vector(info["eye.R"])
ec = (eyeL + eyeR) / 2
iod = (eyeL - eyeR).length
attr = bm.data.color_attributes.new("mask", "FLOAT_COLOR", "POINT")
for i, v in enumerate(bm.data.vertices):
    p = bm.matrix_world @ v.co
    d = p - ec
    front = -d.y  # hacia delante es -Y
    beard = brow = 0.0
    if front > -0.02:
        # barba: mandíbula, mentón y bigote (entre la boca y el cuello)
        if -0.16 < d.z < -0.045 and abs(d.x) < 0.075:
            jaw = 1.0 - min(1.0, max(0.0, (abs(d.x) - 0.055) / 0.02))
            low = min(1.0, max(0.0, (-0.045 - d.z) / 0.02))
            beard = jaw * low
            # despejar los labios
            if -0.08 < d.z < -0.05 and abs(d.x) < 0.028 and front > 0.04:
                beard *= 0.2
        # cejas
        if 0.014 < d.z < 0.034 and 0.01 < abs(d.x) < 0.06 and front > -0.005:
            brow = (1.0 - abs((d.z - 0.024) / 0.01)) * min(1.0, (0.06 - abs(d.x)) / 0.012)
    attr.data[i].color = (max(0, beard), max(0, brow), 0.0, 1.0)
mat = bpy.data.materials.new("maskmat"); mat.use_nodes = True
nt = mat.node_tree
for n in list(nt.nodes): nt.nodes.remove(n)
out = nt.nodes.new("ShaderNodeOutputMaterial"); em = nt.nodes.new("ShaderNodeEmission")
ca = nt.nodes.new("ShaderNodeVertexColor"); ca.layer_name = "mask"
nt.links.new(ca.outputs["Color"], em.inputs["Color"]); nt.links.new(em.outputs[0], out.inputs[0])
img = bpy.data.images.new("bake_mask", 2048, 2048, alpha=False)
tn = nt.nodes.new("ShaderNodeTexImage"); tn.image = img; nt.nodes.active = tn
old = [s.material for s in bm.material_slots]
for s in bm.material_slots: s.material = mat
bpy.ops.object.bake(type="EMIT")
img.filepath_raw = pref + "_mask.png"; img.file_format = "PNG"; img.save()
for s, m in zip(bm.material_slots, old): s.material = m
print("máscara ok")
