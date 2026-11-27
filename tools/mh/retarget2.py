"""Retarget de animaciones (Quaternius glTF y CMU BVH) al esqueleto game_engine de MakeHuman.
Uso: python3 retarget2.py <in.blend> <out.blend> <plan.json>
plan: [{"name","src":"quat"|"bvh","clip" (acción quat) | "bvh" (ruta),"start","end" (seg. en origen),"loop","inplace","speed"?}]
Todas las acciones resultantes se muestrean a 30 fps.
"""
import sys, json, math, bpy
from mathutils import Matrix, Quaternion, Vector

FPS = 30
SRC_FPS = {"quat": 30.0, "bvh": 120.0}
BVH_MAP = {"Hips": "pelvis", "LowerBack": "spine_01", "Spine": "spine_02", "Spine1": "spine_03", "Neck1": "neck_01",
           "Head": "head", "LeftArm": "upperarm_l", "LeftForeArm": "lowerarm_l", "LeftHand": "hand_l",
           "RightArm": "upperarm_r", "RightForeArm": "lowerarm_r", "RightHand": "hand_r",
           "LeftUpLeg": "thigh_l", "LeftLeg": "calf_l", "LeftFoot": "foot_l", "LeftToeBase": "ball_l",
           "RightUpLeg": "thigh_r", "RightLeg": "calf_r", "RightFoot": "foot_r", "RightToeBase": "ball_r"}
Q_MAP = {n: n for n in ["pelvis", "spine_01", "spine_02", "spine_03", "neck_01", "clavicle_l", "upperarm_l", "lowerarm_l",
                        "hand_l", "clavicle_r", "upperarm_r", "lowerarm_r", "hand_r", "thigh_l", "calf_l", "foot_l", "ball_l",
                        "thigh_r", "calf_r", "foot_r", "ball_r"]}
Q_MAP["Head"] = "head"
# nombres "semánticos" comunes -> nombre en cada origen, para tronco y extremidades
SEM = {"bvh": {"hips": "Hips", "spine": "Spine", "neck": "Neck", "head": "Head", "lul": "LeftUpLeg", "rul": "RightUpLeg",
               "lua": "LeftArm", "rua": "RightArm", "lla": "LeftForeArm", "rla": "RightForeArm", "lh": "LeftHand", "rh": "RightHand",
               "lll": "LeftLeg", "rll": "RightLeg", "lf": "LeftFoot", "rf": "RightFoot", "lt": "LeftToeBase", "rt": "RightToeBase",
               "lmid": "LeftFingerBase", "rmid": "RightFingerBase", "lth": "LThumb", "rth": "RThumb"},
       "quat": {"hips": "pelvis", "spine": "spine_02", "neck": "neck_01", "head": "Head", "lul": "thigh_l", "rul": "thigh_r",
                "lua": "upperarm_l", "rua": "upperarm_r", "lla": "lowerarm_l", "rla": "lowerarm_r", "lh": "hand_l", "rh": "hand_r",
                "lll": "calf_l", "rll": "calf_r", "lf": "foot_l", "rf": "foot_r", "lt": "ball_l", "rt": "ball_r",
                "lmid": "middle_01_l", "rmid": "middle_01_r", "lth": "thumb_01_l", "rth": "thumb_01_r"}}
# tronco: (sem_desde, sem_hasta, sem_lado_a, sem_lado_b, tgt_desde, tgt_hasta, tgt_a, tgt_b)
# manos y pies: por posiciones (antes torcían el antebrazo y la pantorrilla)
EXT = {"hand_l": ("lh", "lmid", "lh", "lth", "hand_l", "middle_01_l", "hand_l", "thumb_01_l"),
       "hand_r": ("rh", "rmid", "rh", "rth", "hand_r", "middle_01_r", "hand_r", "thumb_01_r"),
       "foot_l": ("lf", "lt", "lf", "lll", "foot_l", "ball_l", "foot_l", "calf_l"),
       "foot_r": ("rf", "rt", "rf", "rll", "foot_r", "ball_r", "foot_r", "calf_r")}
TORSO = {"pelvis": ("hips", "spine", "rul", "lul", "pelvis", "spine_02", "thigh_r", "thigh_l"),
         "spine_01": ("hips", "spine", "rul", "lul", "spine_01", "spine_02", "thigh_r", "thigh_l"),
         "spine_02": ("spine", "neck", "rua", "lua", "spine_02", "neck_01", "upperarm_r", "upperarm_l"),
         "spine_03": ("spine", "neck", "rua", "lua", "spine_03", "neck_01", "upperarm_r", "upperarm_l")}
LIMB = {"upperarm_l": ("lua", "lla", "lh", "upperarm_l", "lowerarm_l", "hand_l", False, (0, -1, 0)),
        "lowerarm_l": ("lua", "lla", "lh", "upperarm_l", "lowerarm_l", "hand_l", True, (0, -1, 0)),
        "upperarm_r": ("rua", "rla", "rh", "upperarm_r", "lowerarm_r", "hand_r", False, (0, -1, 0)),
        "lowerarm_r": ("rua", "rla", "rh", "upperarm_r", "lowerarm_r", "hand_r", True, (0, -1, 0)),
        "thigh_l": ("lul", "lll", "lf", "thigh_l", "calf_l", "foot_l", False, (0, 1, 0)),
        "calf_l": ("lul", "lll", "lf", "thigh_l", "calf_l", "foot_l", True, (0, 1, 0)),
        "thigh_r": ("rul", "rll", "rf", "thigh_r", "calf_r", "foot_r", False, (0, 1, 0)),
        "calf_r": ("rul", "rll", "rf", "thigh_r", "calf_r", "foot_r", True, (0, 1, 0))}
TDIR = {"neck_01": "head", "clavicle_l": "upperarm_l", "clavicle_r": "upperarm_r", "hand_l": "middle_01_l", "hand_r": "middle_01_r",
        "foot_l": "ball_l", "foot_r": "ball_r", "head": None, "ball_l": None, "ball_r": None}

def frame(p, sd):
    p = p.normalized()
    x = sd - p * sd.dot(p)
    if x.length < 1e-6:
        x = p.orthogonal()
    x.normalize()
    return Matrix((x, p.cross(x), p)).transposed().to_quaternion()

in_blend, out_blend, plan = sys.argv[1], sys.argv[2], json.loads(open(sys.argv[3]).read())
bpy.ops.wm.open_mainfile(filepath=in_blend)
sc = bpy.context.scene
sc.render.fps = FPS
tgt = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]
for pb in tgt.pose.bones:
    pb.rotation_mode = "QUATERNION"
TW = tgt.matrix_world.copy()
tb = tgt.data.bones
order = [b.name for b in tb]
t_rest = {b.name: TW @ b.matrix_local for b in tb}
th = lambda n: TW @ tb[n].head_local
t_hip_h = th("pelvis").z - min(th("ball_l").z, th("ball_r").z)

# ---------------- fuentes ----------------
def gltf_rest(path):
    """Matrices de reposo (TRS de los nodos) leídas del JSON del glb, convertidas a Z arriba de Blender."""
    import struct
    data = open(path, "rb").read()
    ln = struct.unpack_from("<I", data, 12)[0]
    js = json.loads(data[20:20 + ln])
    nodes = js["nodes"]
    parent = {}
    for i, n in enumerate(nodes):
        for c in n.get("children", []):
            parent[c] = i
    C = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
    def local(n):
        t = Vector(n.get("translation", [0, 0, 0]))
        r = n.get("rotation", [0, 0, 0, 1])
        s = n.get("scale", [1, 1, 1])
        return Matrix.Translation(t) @ Quaternion((r[3], r[0], r[1], r[2])).to_matrix().to_4x4() @ Matrix.Diagonal((s[0], s[1], s[2], 1))
    cache = {}
    def world(i):
        if i in cache:
            return cache[i]
        m = local(nodes[i])
        if i in parent:
            m = world(parent[i]) @ m
        cache[i] = m
        return m
    out = {}
    for i, n in enumerate(nodes):
        if "name" in n:
            out[n["name"]] = C @ world(i) @ C.inverted()
    return out

class QuatSrc:
    def __init__(self):
        before = set(bpy.data.actions.keys())
        bpy.ops.import_scene.gltf(filepath="/home/claude/ira-del-olimpo/godot/assets/models/anims.glb")
        for a in list(bpy.data.actions):
            if a.name not in before:
                a.name = "SRC_" + a.name
        self.objs = {o.name: o for o in bpy.data.objects if o.type == "EMPTY"}
        self.rest = gltf_rest("/home/claude/ira-del-olimpo/godot/assets/models/anims.glb")
    def set_action(self, name):
        act = bpy.data.actions.get("SRC_" + name) if name else None
        for n, o in self.objs.items():
            if act is None:
                if o.animation_data:
                    o.animation_data.action = None
                continue
            o.animation_data_create()
            o.animation_data.action = act
            slot = act.slots.get("OB" + n)
            if slot:
                o.animation_data.action_slot = slot
            else:
                o.animation_data.action = None
    def pose(self, n):
        return self.objs[n].matrix_world
    def rest_m(self, n):
        return self.rest[n]
    def cleanup(self):
        pass

class BvhSrc:
    def __init__(self, path):
        bpy.ops.import_anim.bvh(filepath=path, axis_forward="-Z", axis_up="Y", global_scale=1.0, frame_start=0,
                                update_scene_fps=False, update_scene_duration=False)
        self.arm = bpy.context.active_object
    def pose(self, n):
        return self.arm.matrix_world @ self.arm.pose.bones[n].matrix
    def rest_m(self, n):
        return self.arm.matrix_world @ self.arm.data.bones[n].matrix_local
    def cleanup(self):
        bpy.data.objects.remove(self.arm)

quat = None
results = {}
for clip in plan:
    kind = clip["src"]
    S = SEM[kind]
    if kind == "quat":
        if quat is None:
            quat = QuatSrc()
        src = quat
        src.set_action(None)
        MAP = Q_MAP
    else:
        src = BvhSrc(clip["bvh"])
        MAP = BVH_MAP
    sc.frame_set(0)
    bpy.context.view_layer.update()
    rp = lambda s: src.rest_m(S[s]).to_translation()
    s_foot = min(rp("lt").z, rp("rt").z)
    k = t_hip_h / max(rp("hips").z - s_foot, 1e-5)
    # alineación de reposo
    ALLPOS = dict(TORSO); ALLPOS.update(EXT)
    tframe_torso = {t: frame(th(c[5]) - th(c[4]), th(c[7]) - th(c[6])) for t, c in ALLPOS.items()}
    tframe_limb = {}
    for t, (a, b, c, ta, tb_, tc, low, rsec) in LIMB.items():
        prim = (th(tc) - th(tb_)) if low else (th(tb_) - th(ta))
        tframe_limb[t] = frame(prim, Vector(rsec))
    corr, s_rest_q = {}, {}
    for s, t in MAP.items():
        s_rest_q[s] = src.rest_m(s).to_quaternion()
        child = TDIR.get(t, "x")
        if child is None or t not in TDIR:
            corr[t] = Quaternion()
            continue
        dt = (th(child) - th(t)).normalized()
        # hijo equivalente en el origen
        inv = {v: k_ for k_, v in MAP.items()}
        sc_ = inv.get(child)
        if t in ("hand_l", "hand_r"):
            sc_ = None
        if sc_:
            ds = (src.rest_m(sc_).to_translation() - src.rest_m(s).to_translation()).normalized()
            corr[t] = dt.rotation_difference(ds)
        else:
            corr[t] = Quaternion()
    if kind == "quat":
        src.set_action(clip["clip"])
    t0, t1 = clip.get("start", 0.0), clip.get("end", None)
    if t1 is None:
        act = bpy.data.actions["SRC_" + clip["clip"]]
        t1 = act.frame_range[1] / SRC_FPS[kind]
    n_out = max(2, int(round((t1 - t0) * FPS)) + (0 if clip.get("loop") else 1))
    act_out = bpy.data.actions.new(clip["name"])
    tgt.animation_data_create()
    tgt.animation_data.action = act_out
    hip0 = None
    hip_last = None
    # suelo real del clip: el pie más bajo durante todo el clip (en el BVH la cadera de reposo está a 0)
    floor = 1e9
    for i in range(n_out):
        sf = (t0 + i / FPS) * SRC_FPS[kind]
        sc.frame_set(int(math.floor(sf)), subframe=sf - math.floor(sf))
        floor = min(floor, src.pose(S["lt"]).to_translation().z, src.pose(S["rt"]).to_translation().z)
    for i in range(n_out):
        ts = t0 + i / FPS
        sf = ts * SRC_FPS[kind]
        sc.frame_set(int(math.floor(sf)), subframe=sf - math.floor(sf))
        P = lambda s: src.pose(S[s]).to_translation()
        hip = P("hips")
        if hip0 is None:
            hip0 = hip.copy()
        hip_last = hip.copy()
        wq = {}
        for t, (a, b, c, d, *_r) in ALLPOS.items():
            wq[t] = frame(P(b) - P(a), P(d) - P(c)) @ tframe_torso[t].inverted() @ t_rest[t].to_quaternion()
        for t, (a, b, c, ta, tb_, tc, low, rsec) in LIMB.items():
            pa, pb_, pc = P(a), P(b), P(c)
            prim = (pc - pb_) if low else (pb_ - pa)
            u = (pb_ - pa).normalized()
            v = pc - pa
            bend = v - u * v.dot(u)
            srcb = S[b] if low else S[a]
            Dq = src.pose(srcb).to_quaternion() @ src.rest_m(srcb).to_quaternion().inverted()
            fb = Dq @ Vector(rsec)
            w = min(1.0, bend.length / (0.35 * max((pb_ - pa).length, 1e-6)))
            sec = fb * (1.0 - w) + ((bend.normalized() if bend.length > 1e-9 else fb) * w)
            wq[t] = frame(prim, sec) @ tframe_limb[t].inverted() @ t_rest[t].to_quaternion()
        for s, t in MAP.items():
            if t in wq:
                continue
            delta = src.pose(s).to_quaternion() @ s_rest_q[s].inverted()
            wq[t] = delta @ corr[t] @ t_rest[t].to_quaternion()
        pose_m = {}
        for name in order:
            b = tb[name]
            m = (pose_m[b.parent.name] @ (b.parent.matrix_local.inverted() @ b.matrix_local)) if b.parent else b.matrix_local.copy()
            if name in wq:
                aq = TW.to_quaternion().inverted() @ wq[name]
                loc = m.to_translation()
                if name == "pelvis":
                    off = (hip - hip0) * k
                    if clip.get("inplace", True):
                        off.x = 0.0
                        off.y = 0.0
                    off.z = ((hip.z - floor) - (rp("hips").z - s_foot)) * k
                    loc = b.matrix_local.to_translation() + TW.to_3x3().inverted() @ off
                m = Matrix.Translation(loc) @ aq.to_matrix().to_4x4()
            pose_m[name] = m
        for name in order:
            b = tb[name]
            pb = tgt.pose.bones[name]
            basis = ((b.parent.matrix_local.inverted() @ b.matrix_local).inverted() @ pose_m[b.parent.name].inverted() @ pose_m[name]) if b.parent else (b.matrix_local.inverted() @ pose_m[name])
            pb.matrix_basis = basis
            pb.keyframe_insert("rotation_quaternion", frame=i)
            if name == "pelvis":
                pb.keyframe_insert("location", frame=i)
    dist = ((hip_last - hip0) * k)
    dist.z = 0
    dur = (n_out - 1) / FPS
    results[clip["name"]] = {"frames": n_out, "speed": dist.length / max(dur, 1e-6), "loop": bool(clip.get("loop"))}
    act_out.use_fake_user = True
    print("clip", clip["name"], results[clip["name"]])
    for pb in tgt.pose.bones:
        pb.matrix_basis = Matrix.Identity(4)
    tgt.animation_data.action = None
    if kind == "bvh":
        src.cleanup()
if quat:
    for o in list(quat.objs.values()):
        bpy.data.objects.remove(o)
    for o in [o for o in bpy.data.objects if o.name == "Armature" and o.type == "EMPTY"]:
        bpy.data.objects.remove(o)
for a in list(bpy.data.actions):
    if a.name.startswith("SRC_"):
        bpy.data.actions.remove(a)
json.dump(results, open(out_blend + ".json", "w"), indent=1)
bpy.ops.wm.save_as_mainfile(filepath=out_blend)
print("saved", out_blend)
