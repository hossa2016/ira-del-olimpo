import bpy, bmesh as _bmesh, mathutils, sys
bpy.ops.wm.open_mainfile(filepath=sys.argv[1] + ".blend")
pref = sys.argv[1]
bm = bpy.data.objects["Human"]
def _eyes(o):
    hg = o.vertex_groups["HelperGeometry"].index; jc = o.vertex_groups["JointCubes"].index
    sel = set(v.index for v in o.data.vertices if any(g.group == hg and g.weight > 0.5 for g in v.groups)
              and not any(g.group == jc and g.weight > 0.5 for g in v.groups))
    b = _bmesh.new(); b.from_mesh(o.data); b.verts.ensure_lookup_table()
    seen = set(); comps = []
    for s0 in sel:
        if s0 in seen: continue
        st = [s0]; comp = []; seen.add(s0)
        while st:
            k = st.pop(); comp.append(k)
            for e in b.verts[k].link_edges:
                j = e.other_vert(b.verts[k]).index
                if j in sel and j not in seen: seen.add(j); st.append(j)
        ps = [o.matrix_world @ b.verts[k].co for k in comp]
        c = sum(ps, mathutils.Vector()) / len(ps)
        ext = max((p - c).length for p in ps)
        if len(comp) > 20 and 0.008 < ext < 0.025 and abs(c.x) > 0.015:
            comps.append(c)
    L = max([c for c in comps if c.x > 0], key=lambda c: c.y)  # el globo ocular queda detrás de párpados/pestañas
    R = max([c for c in comps if c.x < 0], key=lambda c: c.y)
    return L, R
eL, eR = _eyes(bm)
print("ojos", eL, eR)
info = {"eye.L": list(eL), "eye.R": list(eR)}
import json as _j; _j.dump({"eye": [abs(eL.x), eL.z, -eL.y]}, open(pref + "_eyes.json", "w"))
# ---- máscaras de barba y cejas pintadas por vértice y horneadas a UV ----
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
