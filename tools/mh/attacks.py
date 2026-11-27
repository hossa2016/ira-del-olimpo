# Ataques animados a mano para el cuerpo MakeHuman (rig game_engine).
# Se definen poses clave de la espada (posición de la mano + dirección de hoja y filo),
# giro/inclinación del torso, cadera y pies; los brazos y piernas se resuelven con IK y se hornea.
# uso: blender -b --python attacks.py -- entrada.blend salida.blend
import bpy, sys, math
from mathutils import Vector, Matrix, Quaternion

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
src, dst = args[0], args[1]
bpy.ops.wm.open_mainfile(filepath=src)
arm = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]
sc = bpy.context.scene
sc.render.fps = 30

R = Vector((-1, 0, 0)); F = Vector((0, -1, 0)); U = Vector((0, 0, 1))
def c(r, f, u):
    return R * r + F * f + U * u

# espada en el espacio local de la mano (medido en Godot, convertido a Blender: (x, -z, y))
hand_rest = arm.data.bones["hand_r"].matrix_local
sw_rest = Matrix.Identity(4)
sw_rest.col[0][:3] = (0, 0, 1)     # filo (eje X de la espada)
sw_rest.col[1][:3] = (-1, 0, 0)    # cara plana (eje Y)
sw_rest.col[2][:3] = (0, -1, 0)    # hoja (eje Z)
sw_rest.translation = Vector((-0.6489, -0.2058, 0.2276))
S_local = hand_rest.inverted() @ sw_rest

def sword_rot(d, e):
    d = d.normalized()
    e = (e - d * e.dot(d)).normalized()
    y = d.cross(e)
    m = Matrix((e, y, d)).transposed()
    return m.to_quaternion()

def smooth(t):
    return t * t * (3 - 2 * t)

def lerp_keys(keys, f, field, kind="vec"):
    # keys: lista de (frame, dict); interpolación suave entre claves vecinas
    ks = [k for k in keys if field in k[1]]
    if f <= ks[0][0]:
        return ks[0][1][field]
    for (f0, a), (f1, b) in zip(ks, ks[1:]):
        if f0 <= f <= f1:
            ease = b.get("ease", "smooth")
            t = (f - f0) / (f1 - f0)
            t = smooth(t) if ease == "smooth" else (t ** 0.6 if ease == "fast" else t)
            va, vb = a[field], b[field]
            if kind == "quat":
                return va.slerp(vb, t)
            if kind == "num":
                return va + (vb - va) * t
            return va.lerp(vb, t)
    return ks[-1][1][field]

# ---- pose base: guardia tomada de Sword_Idle ----
base = bpy.data.actions["Sword_Idle"]
arm.animation_data.action = base
sc.frame_set(int(base.frame_range[0]))
bpy.context.view_layer.update()
base_basis = {pb.name: pb.matrix_basis.copy() for pb in arm.pose.bones}
foot0 = {s: arm.pose.bones["foot_" + s].matrix.copy() for s in ("l", "r")}
hand_l0 = arm.pose.bones["hand_l"].matrix.copy()

GUARD = {"hand": c(0.2, 0.3, 0.28), "sw": sword_rot(c(-0.12, 0.6, 0.78), F), "yaw": 0.0, "pitch": 0.0,
         "pel": Vector((0, 0, 0.0)), "fl": Vector(), "fr": Vector(), "hl": Vector(), "sh": 32.0, "el": 18.0}

def K(**kw):
    d = dict(GUARD); d.update(kw); return d

ATTACKS = {
    # tajo diagonal de derecha-arriba a izquierda-abajo
    "Atk_A": (24, [
        (0, K()),
        (7, K(hand=c(0.3, -0.02, 0.62), sw=sword_rot(c(0.25, -0.55, 0.8), c(-0.6, 0.6, -0.5)), yaw=28.0, pel=Vector((0, 0, -0.01)))),
        (11, K(hand=c(0.02, 0.56, 0.32), sw=sword_rot(c(-0.55, 0.75, -0.05), c(-0.7, 0.2, -0.6)), yaw=-8.0, pel=Vector((0, 0, -0.07)) + c(0, 0.06, 0), ease="fast", hl=c(-0.1, -0.12, -0.02))),
        (14, K(hand=c(-0.3, 0.36, 0.02), sw=sword_rot(c(-0.75, 0.3, -0.55), c(-0.3, -0.3, -0.6)), yaw=-30.0, pel=Vector((0, 0, -0.08)) + c(0, 0.06, 0), hl=c(-0.08, -0.12, 0))),
        (24, K()),
    ], [0.37]),
    # revés horizontal de izquierda a derecha
    "Atk_B": (24, [
        (0, K()),
        (6, K(hand=c(-0.3, 0.12, 0.3), sw=sword_rot(c(-0.7, -0.55, 0.15), c(0.3, 0.7, 0)), yaw=-34.0, pel=Vector((0, 0, -0.05)))),
        (10, K(hand=c(0.05, 0.58, 0.3), sw=sword_rot(c(0.6, 0.8, 0.05), c(0.8, -0.3, 0)), yaw=6.0, pel=Vector((0, 0, -0.07)) + c(0, 0.05, 0), ease="fast", hl=c(-0.06, -0.1, 0))),
        (13, K(hand=c(0.42, 0.2, 0.28), sw=sword_rot(c(0.8, -0.5, 0.0), c(0.1, -0.8, 0)), yaw=34.0, pel=Vector((0, 0, -0.07)) + c(0, 0.05, 0), hl=c(-0.06, -0.1, 0))),
        (24, K()),
    ], [0.33]),
    # golpe vertical pesado por encima de la cabeza, con paso al frente
    "Atk_C": (34, [
        (0, K()),
        (10, K(hand=c(0.1, -0.04, 0.8), sw=sword_rot(c(0.05, -0.8, 0.45), c(0, 0.3, 0.9)), yaw=12.0, pitch=-8.0, pel=Vector((0, 0, -0.01)), hl=c(0.0, 0.08, 0.12))),
        (14, K(hand=c(0.02, 0.64, 0.1), sw=sword_rot(c(0, 0.6, -0.8), c(0, -0.2, -1)), yaw=-4.0, pitch=24.0, pel=Vector((0, 0, -0.2)) + c(0, 0.16, 0), fl=c(0, 0.3, 0), ease="fast", hl=c(-0.05, -0.1, -0.1))),
        (21, K(hand=c(0.02, 0.6, -0.04), sw=sword_rot(c(0, 0.45, -0.9), c(0, -0.2, -1)), yaw=-4.0, pitch=26.0, pel=Vector((0, 0, -0.21)) + c(0, 0.16, 0), fl=c(0, 0.3, 0), hl=c(-0.05, -0.1, -0.1))),
        (34, K()),
    ], [0.47]),
    # empujón con el escudo
    "Atk_Bash": (16, [
        (0, K()),
        (3, K(yaw=-16.0, sh=14.0, el=4.0, pel=Vector((0, 0, -0.03)))),
        (6, K(yaw=22.0, sh=72.0, el=48.0, pel=Vector((0, 0, -0.05)) + c(0, 0.12, 0), fl=c(0, 0.14, 0), ease="fast")),
        (9, K(yaw=20.0, sh=68.0, el=44.0, pel=Vector((0, 0, -0.05)) + c(0, 0.12, 0), fl=c(0, 0.14, 0))),
        (16, K()),
    ], [0.12]),
}

def mk_empty(name):
    e = bpy.data.objects.new(name, None); bpy.context.collection.objects.link(e); return e

def build(name, n, keys):
    act = bpy.data.actions.new(name)
    arm.animation_data.action = act
    tg = {k: mk_empty("t_" + k) for k in ("hr", "fl", "fr", "hl")}
    pole = mk_empty("pole_r")
    for f in range(n + 1):
        for nm, m in base_basis.items():
            arm.pose.bones[nm].matrix_basis = m
        bpy.context.view_layer.update()
        yaw = math.radians(-lerp_keys(keys, f, "yaw", "num"))
        pitch = math.radians(lerp_keys(keys, f, "pitch", "num"))
        pel = lerp_keys(keys, f, "pel")
        # cadera: desplazamiento + parte del giro
        pb = arm.pose.bones["pelvis"]
        m = pb.matrix.copy()
        m = Matrix.Translation(pel) @ m
        piv = m.translation.copy()
        m = Matrix.Translation(piv) @ Matrix.Rotation(yaw * 0.3, 4, "Z") @ Matrix.Translation(-piv) @ m
        pb.matrix = m
        bpy.context.view_layer.update()
        # columna: resto del giro e inclinación (eje lateral del personaje)
        for bn, w in (("spine_01", 0.25), ("spine_02", 0.25), ("spine_03", 0.2)):
            pb = arm.pose.bones[bn]
            m = pb.matrix.copy(); piv = m.translation.copy()
            side = Matrix.Rotation(yaw * 0.7, 4, "Z") @ R.to_4d()
            rot = Matrix.Rotation(yaw * w / 0.7, 4, "Z") @ Matrix.Rotation(-pitch * w / 0.7, 4, Vector(side[:3]))
            pb.matrix = Matrix.Translation(piv) @ rot @ Matrix.Translation(-piv) @ m
            bpy.context.view_layer.update()
        # cabeza: compensar para seguir mirando al frente
        for bn in ("neck_01", "head"):
            pb = arm.pose.bones[bn]
            m = pb.matrix.copy(); piv = m.translation.copy()
            pb.matrix = Matrix.Translation(piv) @ Matrix.Rotation(-yaw * 0.22, 4, "Z") @ Matrix.Translation(-piv) @ m
            bpy.context.view_layer.update()
        shv = math.radians(lerp_keys(keys, f, "sh", "num")); elv = math.radians(lerp_keys(keys, f, "el", "num"))
        side_ax = (Matrix.Rotation(yaw, 4, "Z") @ R.to_4d()).to_3d()
        for bn, ang in (("upperarm_l", shv), ("lowerarm_l", elv)):
            if abs(ang) > 1e-4:
                pb = arm.pose.bones[bn]
                m = pb.matrix.copy(); piv = m.translation.copy()
                pb.matrix = Matrix.Translation(piv) @ Matrix.Rotation(ang, 4, side_ax) @ Matrix.Translation(-piv) @ m
                bpy.context.view_layer.update()
        for pb in arm.pose.bones:
            if pb.name in ("pelvis", "spine_01", "spine_02", "spine_03", "neck_01", "head"):
                pb.keyframe_insert("rotation_quaternion", frame=f)
        arm.pose.bones["pelvis"].keyframe_insert("location", frame=f)
        for pb in arm.pose.bones:
            if pb.name not in ("pelvis", "spine_01", "spine_02", "spine_03", "neck_01", "head"):
                pb.keyframe_insert("rotation_quaternion", frame=f)
        # objetivos IK
        hp = lerp_keys(keys, f, "hand"); q = lerp_keys(keys, f, "sw", "quat")
        Msw = q.to_matrix().to_4x4(); Msw.translation = hp
        Mh = Msw @ S_local.inverted()
        tg["hr"].matrix_world = Mh
        tg["hr"].keyframe_insert("location", frame=f); tg["hr"].rotation_mode = "QUATERNION"; tg["hr"].keyframe_insert("rotation_quaternion", frame=f)
        pole.location = hp + c(0.55, -0.1, -0.45); pole.keyframe_insert("location", frame=f)
        for s, key in (("l", "fl"), ("r", "fr")):
            mm = foot0[s].copy(); mm.translation = mm.translation + lerp_keys(keys, f, key)
            tg[key].matrix_world = mm
            tg[key].keyframe_insert("location", frame=f); tg[key].rotation_mode = "QUATERNION"; tg[key].keyframe_insert("rotation_quaternion", frame=f)
        mm = hand_l0.copy(); mm.translation = mm.translation + lerp_keys(keys, f, "hl")
        tg["hl"].matrix_world = mm
        tg["hl"].keyframe_insert("location", frame=f); tg["hl"].rotation_mode = "QUATERNION"; tg["hl"].keyframe_insert("rotation_quaternion", frame=f)
    cons = []
    def ik(bone, target, chain, rot, pole_t=None):
        cn = arm.pose.bones[bone].constraints.new("IK")
        cn.target = target; cn.chain_count = chain; cn.use_tail = False; cn.use_rotation = rot
        if pole_t:
            cn.pole_target = pole_t; cn.pole_angle = math.radians(-90)
        cons.append(cn)
    ik("hand_r", tg["hr"], 3, False, pole)
    ik("foot_l", tg["fl"], 3, False)
    ik("foot_r", tg["fr"], 3, False)
    want = {}
    for f in range(n + 1):
        sc.frame_set(f)
        want[f] = {k: tg[k].matrix_world.copy() for k in ("hr", "fl", "fr")}
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="POSE")
    bpy.ops.pose.select_all(action="SELECT")
    bpy.ops.nla.bake(frame_start=0, frame_end=n, only_selected=True, visual_keying=True, clear_constraints=True,
                     use_current_action=True, bake_types={"POSE"})
    bpy.ops.object.mode_set(mode="OBJECT")
    # orientación exacta de la mano (hoja de la espada) y de los pies, conservando la posición
    for f in range(n + 1):
        sc.frame_set(f)
        for bn, k in (("hand_r", "hr"), ("foot_l", "fl"), ("foot_r", "fr")):
            pb = arm.pose.bones[bn]
            m = want[f][k].copy(); m.translation = pb.matrix.translation.copy()
            pb.matrix = m
            bpy.context.view_layer.update()
            pb.keyframe_insert("rotation_quaternion", frame=f)
    for e in list(tg.values()) + [pole]:
        bpy.data.objects.remove(e)
    act.use_fake_user = True
    print("ataque", name, n, "frames")

for nm, (n, keys, hits) in ATTACKS.items():
    if nm in bpy.data.actions:
        bpy.data.actions.remove(bpy.data.actions[nm])
    build(nm, n, keys)
arm.animation_data.action = None
bpy.ops.wm.save_as_mainfile(filepath=dst)
print("guardado", dst)
