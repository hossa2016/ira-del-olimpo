class_name Body
extends Node3D
## Personaje visual: cuerpo con piel texturizada, armadura en los huesos y reproductor de animaciones.

var model: Node3D
var skel: Skeleton3D
var ap: AnimationPlayer
var skin_mat: StandardMaterial3D
var sword: Node3D
var cur := ""

func setup(o: Dictionary) -> void:
	model = load("res://assets/models/hero.glb").instantiate()
	add_child(model)
	skel = model.find_child("Skeleton3D", true, false)
	skin_mat = Mats.skin(o.get("tint", Color(1, 1, 1)), o.get("dark", false))
	for c in skel.get_children():
		if c is MeshInstance3D:
			var n := String(c.name)
			c.material_override = Mats.get_m("eye") if n.begins_with("Eyes") else (Mats.get_m("brow") if n.begins_with("Eyebrows") else skin_mat)
			c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	ap = AnimationPlayer.new()
	model.add_child(ap)
	ap.root_node = NodePath("..")
	ap.add_animation_library("", AnimLib.get_lib())
	var metal: Material = Mats.get_m(o.get("metal", "bronze"))
	if o.get("helmet", true):
		_helmet(o.get("crest", "cloth"), metal)
	if o.get("armor", false):
		_armor(metal)
	if o.get("shield", false):
		_shield(metal)
	if o.get("weapon", "") == "sword":
		_sword(metal)
	elif o.get("weapon", "") == "spear":
		_spear()
	if o.get("eyes", false):
		var hd := _att("Head")
		for s in [-1, 1]:
			_mesh(hd, _sph(0.017), Mats.get_m("glow_red"), Vector3(s * 0.033, 0.085, 0.1))
	if o.get("beard", false):
		call_deferred("_beard")
	var sc: float = o.get("scale", 1.0)
	scale = Vector3.ONE * sc

# ---------- utilidades ----------
func _att(bone: String) -> BoneAttachment3D:
	var n := "att_" + bone
	if skel.has_node(n):
		return skel.get_node(n)
	var b := BoneAttachment3D.new()
	b.name = n
	b.bone_name = bone
	skel.add_child(b)
	return b

func _mesh(parent: Node3D, mesh: Mesh, mat: Material, pos := Vector3.ZERO, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	parent.add_child(mi)
	return mi

func _sph(r: float, hemi := false) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r if hemi else r * 2.0
	m.is_hemisphere = hemi
	m.radial_segments = 24
	m.rings = 12
	return m

func _cyl(top: float, bot: float, h: float, seg := 20) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bot
	m.height = h
	m.radial_segments = seg
	return m

func _box(x: float, y: float, z: float) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = Vector3(x, y, z)
	return m

# ---------- piezas ----------
func _helmet(crest: String, metal: Material) -> void:
	var g := Node3D.new()
	g.position = Vector3(0, 0.1, 0.012)
	g.scale = Vector3.ONE * 1.12
	_att("Head").add_child(g)
	_mesh(g, _sph(0.135, true), metal, Vector3(0, 0.02, 0), Vector3.ZERO, Vector3(1, 1.25, 1.15))
	_mesh(g, _cyl(0.137, 0.15, 0.13, 24), metal, Vector3(0, -0.045, -0.01))
	for s in [-1, 1]:
		_mesh(g, _box(0.028, 0.15, 0.11), metal, Vector3(s * 0.098, -0.06, 0.085), Vector3(0, s * 0.42, 0))
	_mesh(g, _box(0.026, 0.09, 0.022), metal, Vector3(0, -0.03, 0.155))
	if crest != "":
		var cm: Material = Mats.get_m(crest)
		for i in range(9):
			var a := PI * (0.12 + 0.76 * i / 8.0)
			_mesh(g, _box(0.035, 0.12, 0.06), cm, Vector3(0, 0.12 + sin(a) * 0.1, cos(a) * 0.2 - 0.02), Vector3(-(a - PI / 2), 0, 0))

func _armor(metal: Material) -> void:
	_mesh(_att("spine_03"), _cyl(0.16, 0.18, 0.42, 28), metal, Vector3(0, -0.03, 0), Vector3(0.22, 0, 0), Vector3(1.08, 1, 0.88))
	var sk := Node3D.new()
	sk.rotation = Vector3(-0.28, 0, 0)
	_att("pelvis").add_child(sk)
	_mesh(sk, TorusMeshHelper.make(0.2, 0.028), metal, Vector3(0, 0, 0.01), Vector3.ZERO, Vector3(1, 1, 0.82))
	for k in range(16):
		var a := k / 16.0 * TAU
		var st := _mesh(sk, _box(0.075, 0.3, 0.014), Mats.get_m("cloth" if k % 2 else "leather"), Vector3(sin(a) * 0.2, -0.17, cos(a) * 0.165 + 0.01))
		st.rotation_order = EULER_ORDER_YXZ
		st.rotation = Vector3(-0.16, a, 0)
	for n in ["calf_l", "calf_r"]:
		_mesh(_att(n), _cyl(0.062, 0.05, 0.3, 16), metal, Vector3(0, 0.2, 0.015))
	for n in ["lowerarm_l", "lowerarm_r"]:
		_mesh(_att(n), _cyl(0.052, 0.045, 0.17, 16), Mats.get_m("leather"), Vector3(0, 0.15, 0))

func _shield(metal: Material) -> void:
	var g := Node3D.new()
	g.position = Vector3(-0.1, 0.12, 0)
	_att("lowerarm_l").add_child(g)
	_mesh(g, _cyl(0.42, 0.42, 0.045, 40), metal, Vector3.ZERO, Vector3(0, 0, PI / 2))
	_mesh(g, TorusMeshHelper.make(0.42, 0.024), metal, Vector3.ZERO, Vector3(0, 0, PI / 2))
	_mesh(g, _cyl(0.3, 0.3, 0.047, 40), Mats.get_m("cloth"), Vector3(-0.004, 0, 0), Vector3(0, 0, PI / 2))
	_mesh(g, _sph(0.07), metal, Vector3(-0.03, 0, 0))

func _sword(metal: Material) -> void:
	sword = Node3D.new()
	sword.position = Vector3(-0.02, 0.085, 0)
	_att("hand_r").add_child(sword)
	_mesh(sword, _cyl(0.018, 0.018, 0.13, 10), Mats.get_m("leather"), Vector3.ZERO, Vector3(PI / 2, 0, 0))
	_mesh(sword, _box(0.12, 0.028, 0.03), metal, Vector3(0, 0, 0.075))
	_mesh(sword, _sph(0.028), metal, Vector3(0, 0, -0.075))
	_mesh(sword, _box(0.06, 0.012, 0.52), Mats.get_m("steel"), Vector3(0, 0, 0.35))
	var tip := PrismMesh.new()
	tip.size = Vector3(0.06, 0.12, 0.012)
	_mesh(sword, tip, Mats.get_m("steel"), Vector3(0, 0, 0.67), Vector3(PI / 2, 0, 0))

func _spear() -> void:
	sword = Node3D.new()
	sword.position = Vector3(-0.02, 0.085, 0)
	_att("hand_r").add_child(sword)
	_mesh(sword, _cyl(0.017, 0.017, 2.1, 8), Mats.get_m("wood"), Vector3(0, 0, 0.35), Vector3(PI / 2, 0, 0))
	var cone := _cyl(0.0, 0.045, 0.3, 8)
	_mesh(sword, cone, Mats.get_m("bronze"), Vector3(0, 0, 1.52), Vector3(PI / 2, 0, 0))

func _beard() -> void:
	var b: Node3D = load("res://assets/models/beard.glb").instantiate()
	var idx := skel.find_bone("Head")
	if idx < 0:
		b.free()
		return
	var head_rest := skel.get_bone_global_rest(idx)
	var att := _att("Head")
	att.add_child(b)
	b.transform = head_rest.affine_inverse()
	for mi in b.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = Mats.get_m("beard")

# ---------- animación ----------
func play(n: String, speed := 1.0, blend := 0.2, restart := false) -> void:
	if not ap.has_animation(n):
		return
	if n == cur and not restart:
		ap.speed_scale = speed
		return
	cur = n
	ap.speed_scale = speed
	ap.play(n, blend)
	if restart:
		ap.seek(0.0, true)

func pos_t() -> float:
	return ap.current_animation_position if ap.is_playing() or ap.current_animation != "" else 999.0

func done() -> bool:
	return not ap.is_playing()

func loco(speed: float, zombie := false, hero := false) -> void:
	var s := speed / scale.x
	if s < 0.15:
		play("Zombie_Idle_Loop" if zombie else ("Sword_Idle" if hero else "Idle_Loop"), 1.0, 0.3)
		return
	if zombie:
		play("Zombie_Walk_Fwd_Loop", clampf(s / 1.22, 0.6, 1.8), 0.3)
		return
	var clip := "Walk_Loop" if s < 1.9 else ("Jog_Fwd_Loop" if s < 3.8 else "Sprint_Loop")
	play(clip, clampf(s / AnimLib.NAT[clip], 0.55, 1.7), 0.28)

func set_flash(on: bool) -> void:
	skin_mat.emission_enabled = on
	skin_mat.emission = Color(0.5, 0.35, 0.22)
