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
# ---- apoyar los pies en el suelo en los ciclos de locomoción (captura CMU) ----
import mathutils as _mu
_rest_floor = min(arm.data.bones["ball_l"].head_local.z, arm.data.bones["ball_r"].head_local.z)
for act in list(bpy.data.actions):
    if not any(k in act.name for k in ("Walk", "Jog", "Sprint")):
        continue
    arm.animation_data_create(); arm.animation_data.action = act
    f0, f1 = [int(x) for x in act.frame_range]
    lows = []
    for f in range(f0, f1 + 1):
        bpy.context.scene.frame_set(f)
        lows.append(min(arm.pose.bones[b].head.z for b in ("ball_l", "ball_r")))
    dz = _rest_floor - min(lows)
    pb = arm.pose.bones["pelvis"]
    for f in range(f0, f1 + 1):
        bpy.context.scene.frame_set(f)
        m = pb.matrix.copy(); m.translation.z += dz
        pb.matrix = m
        bpy.context.view_layer.update()
        pb.keyframe_insert("location", frame=f)
    print("suelo", act.name, round(dz, 3))
arm.animation_data.action = None
# ---- moderar las estocadas exageradas (torso casi horizontal): enderezar cadera y columna,
#      y mantener los pies donde estaban con IK de piernas; luego hornear ----
TAME = {"Sword_Regular_C": 0.5, "Sword_Dash": 0.5, "Sword_Attack": 0.7, "Sword_Regular_A": 0.8, "Sword_Regular_B": 0.8}
bpy.context.view_layer.objects.active = arm
for act in list(bpy.data.actions):
    f_ = TAME.get(act.name)
    if f_ is None:
        continue
    arm.animation_data.action = act
    f0, f1 = [int(x) for x in act.frame_range]
    feet = {}
    for f in range(f0, f1 + 1):
        bpy.context.scene.frame_set(f)
        feet[f] = {s_: arm.pose.bones["foot_" + s_].matrix.copy() for s_ in ("l", "r")}
    tg = {}
    for s_ in ("l", "r"):
        e = bpy.data.objects.new("ikt_" + s_, None); bpy.context.collection.objects.link(e); e.parent = arm
        for f in range(f0, f1 + 1):
            e.matrix_parent_inverse.identity(); e.location = feet[f][s_].translation
            e.keyframe_insert("location", frame=f)
        tg[s_] = e
    for f in range(f0, f1 + 1):
        bpy.context.scene.frame_set(f)
        for bn, k in (("pelvis", f_), ("spine_01", f_), ("spine_02", f_), ("spine_03", f_), ("neck_01", 0.85), ("head", 0.85)):
            pb = arm.pose.bones[bn]
            pb.rotation_quaternion = _mu.Quaternion().slerp(pb.rotation_quaternion, k)
            pb.keyframe_insert("rotation_quaternion", frame=f)
    cons = []
    for s_ in ("l", "r"):
        c = arm.pose.bones["calf_" + s_].constraints.new("IK"); c.target = tg[s_]; c.chain_count = 2; cons.append(c)
    bpy.ops.object.mode_set(mode="POSE")
    bpy.ops.pose.select_all(action="SELECT")
    bpy.ops.nla.bake(frame_start=f0, frame_end=f1, only_selected=True, visual_keying=True, clear_constraints=True,
                     use_current_action=True, bake_types={"POSE"})
    bpy.ops.object.mode_set(mode="OBJECT")
    for e in tg.values(): bpy.data.objects.remove(e)
    print("moderado", act.name)
arm.animation_data.action = None
# ---- armadura moldeada sobre el cuerpo (coraza musculada, grebas, brazales) ----
import mathutils
def _shell(name, pick, push, thick):
    ob = body.copy(); ob.data = body.data.copy(); ob.name = name
    bpy.context.collection.objects.link(ob)
    gi = {g.index: g.name for g in ob.vertex_groups}
    b = bmesh.new(); b.from_mesh(ob.data)
    dl = b.verts.layers.deform.active
    kill = []
    for v in b.verts:
        w = {gi[k]: x for k, x in v[dl].items()}
        if not pick(v.co, w):
            kill.append(v)
    bmesh.ops.delete(b, geom=kill, context="VERTS")
    # quitar islas sueltas y suavizar el borde
    b.normal_update()
    for v in b.verts:
        v.co += v.normal * push
    bmesh.ops.smooth_vert(b, verts=[v for v in b.verts if v.is_boundary], factor=0.5, use_axis_x=True, use_axis_y=True, use_axis_z=True)
    b.to_mesh(ob.data); b.free()
    sm = ob.modifiers.new("solid", "SOLIDIFY"); sm.thickness = thick; sm.offset = 1.0; sm.use_rim = True
    bpy.context.view_layer.objects.active = ob
    for m in list(ob.modifiers):
        if m.type != "ARMATURE":
            bpy.ops.object.modifier_apply(modifier=m.name)
    print("pieza", name, len(ob.data.vertices))
    return ob
def W(w, *names):
    return sum(w.get(n, 0.0) for n in names)
def _rest(n):
    return arm.data.bones[n].head_local
z_neck = _rest("neck_01").z
z_waist = (_rest("spine_01").z + _rest("pelvis").z) * 0.5 + 0.02
def cuirass(co, w):
    torso = W(w, "spine_01", "spine_02", "spine_03", "pelvis", "neck_01", "clavicle_l", "clavicle_r")
    arms = W(w, "upperarm_l", "upperarm_r")
    return torso > 0.55 and arms < 0.35 and z_waist < co.z < z_neck + 0.005
def greave(co, w):
    for s in ("l", "r"):
        k = _rest("calf_" + s).z; f = _rest("foot_" + s).z
        if W(w, "calf_" + s) > 0.5 and f + 0.07 < co.z < k - 0.03:
            return True
    return False
def bracer(co, w):
    for s in ("l", "r"):
        a = _rest("lowerarm_" + s); h = _rest("hand_" + s)
        t = (co - a).dot(h - a) / (h - a).length_squared
        if W(w, "lowerarm_" + s, "lowerarm_twist_01_" + s) > 0.5 and 0.45 < t < 0.95:
            return True
    return False
armor = [_shell("Cuirass", cuirass, 0.016, 0.006), _shell("Greaves", greave, 0.009, 0.004), _shell("Bracers", bracer, 0.008, 0.004)]
for a_ in armor:
    a_.data.materials.clear(); m_ = bpy.data.materials.new(a_.name.lower()); a_.data.materials.append(m_)
for o in list(bpy.data.objects):
    if o not in [arm, body] + armor:
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
