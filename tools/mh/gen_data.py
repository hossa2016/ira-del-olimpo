import json, sys
names = sys.argv[1:]
out = ["class_name MHData", "## Datos de los cuerpos MakeHuman (generado por tools/mh/gen_data.py)", "const BODIES := {"]
for n in names:
    e = json.load(open(f"/home/claude/mh/{n}2_eyes.json" if n == "damon" else f"/home/claude/mh/{n}_eyes.json"))["eye"]
    sp = json.load(open(f"/home/claude/mh/{n}2_anim.blend.json" if n == "damon" else f"/home/claude/mh/{n}_anim.blend.json"))
    nat = {k: round(v["speed"], 3) for k, v in sp.items() if v.get("loop") and v["speed"] > 0.3}
    out.append(f'\t"{n}": {{"eye": Vector3({e[0]:.4f}, {e[1]:.4f}, {e[2]:.4f}), "nat": {json.dumps(nat)}}},')
out.append("}")
open("/home/claude/ira-del-olimpo/godot/scripts/mh_data.gd", "w").write("\n".join(out) + "\n")
print("\n".join(out))
