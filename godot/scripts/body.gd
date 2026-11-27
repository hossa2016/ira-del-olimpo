class_name Body
extends Node3D
## Personaje visual: cuerpo con piel texturizada, armadura en los huesos y reproductor de animaciones.

var model: Node3D
var skel: Skeleton3D
var ap: AnimationPlayer
var skin_mat: StandardMaterial3D
var sword: Node3D
var cur := ""
var dropped: Node3D = null
var crest_scale := 1.0
var rec_p := Vector3.ZERO
var rec_v := Vector3.ZERO
var lean_x := 0.0

func setup(o: Dictionary) -> void:
	model = load("res://assets/models/hero.glb").instantiate()
	add_child(model)
	skel = model.find_child("Skeleton3D", true, false)
	skin_mat = Mats.skin(o.get("tint", Color(1, 1, 1)), o.get("skin", "c"))
	for c in skel.get_children():
		if c is MeshInstance3D:
			var n := String(c.name)
			c.material_override = Mats.get_m("eye") if n.begins_with("Eyes") else (Mats.get_m("brow") if n.begins_with("Eyebrows") else skin_mat)
			c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	ap = AnimationPlayer.new()
	model.add_child(ap)
	ap.root_node = NodePath("..")
	ap.add_animation_library("", AnimLib.get_lib())
	crest_scale = o.get("crest_scale", 1.0)
	var mk: String = o.get("metal", "bronze")
	var metal: Material = Mats.get_m(mk)
	if o.get("bull", false):
		_bull_head()
	elif o.get("helmet", true):
		_helmet(o.get("crest", "horse"), "helm_" + ("bronze" if mk == "bronze" else mk.replace("dark_bronze", "dark")))
	if o.get("armor", false):
		_armor(metal)
	if o.get("shield", false):
		_shield(metal, o.get("shield_face", "cloth"), o.get("shield_r", 0.42))
	match o.get("weapon", ""):
		"sword":
			_sword(metal, o.get("blade", 1.0))
		"spear":
			_spear()
		"labrys":
			_labrys()
	if o.get("eyes", "") != "":
		var hd := _att("Head")
		var em: String = o.get("eyes")
		var ez := 0.135 if o.get("bull", false) else 0.1
		var ex := 0.075 if o.get("bull", false) else 0.033
		for s in [-1, 1]:
			_mesh(hd, _sph(0.017), Mats.get_m("glow_" + em), Vector3(s * ex, 0.085, ez))
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
func _helmet(crest: String, hm: String) -> void:
	var g := Node3D.new()
	g.position = Vector3(0, 0.07, -0.022)
	g.scale = Vector3.ONE * 0.97
	_att("Head").add_child(g)
	var helm := _mesh(g, Geo.corinthian_helmet(), Mats.get_m(hm))
	helm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if crest != "":
		var cr := _mesh(g, Geo.crest(), Mats.get_m(crest))
		cr.scale = Vector3(1.15, crest_scale, crest_scale)
		cr.position.y = (crest_scale - 1.0) * -0.05
		_mesh(g, _box(0.02, 0.05, 0.32), Mats.get_m(hm), Vector3(0, 0.19, -0.01))

func _bull_head() -> void:
	var hd := _att("Head")
	var fur := Mats.get_m("fur_bull")
	_mesh(hd, _sph(0.17), fur, Vector3(0, 0.1, 0.03), Vector3.ZERO, Vector3(1.0, 1.08, 1.18))
	_mesh(hd, _sph(0.11), fur, Vector3(0, 0.03, 0.2), Vector3(-0.35, 0, 0), Vector3(0.95, 0.85, 1.35))
	_mesh(hd, _sph(0.075), Mats.get_m("black"), Vector3(0, 0.0, 0.32), Vector3.ZERO, Vector3(1.1, 0.75, 0.5))
	_mesh(hd, _sph(0.16), fur, Vector3(0, -0.04, -0.02), Vector3.ZERO, Vector3(1.15, 0.9, 1.0))
	for s in [-1, 1]:
		var h := _mesh(hd, Geo.horn(0.42, 0.05, 1.6), Mats.get_m("ivory"), Vector3(s * 0.13, 0.2, 0.02))
		h.scale = Vector3(s, 1, 1)
		h.rotation = Vector3(0, s * -0.25, s * 0.15)
		_mesh(hd, _box(0.12, 0.05, 0.03), fur, Vector3(s * 0.2, 0.12, -0.02), Vector3(0, 0, s * -0.4))
	var ring := _mesh(hd, TorusMeshHelper.make(0.035, 0.007), Mats.get_m("gold"), Vector3(0, -0.04, 0.31), Vector3(PI / 2, 0, 0))
	ring = ring

func _armor(metal: Material) -> void:
	# coraza musculada: dos valvas redondeadas (pecho y espalda) que siguen el torso, con hombreras de lino
	var ch := _att("spine_03")
	_mesh(ch, _sph(1.0), metal, Vector3(0, 0.15, 0.02), Vector3(0.12, 0, 0), Vector3(0.25, 0.24, 0.16))
	_mesh(ch, _sph(1.0), metal, Vector3(0, -0.02, 0.015), Vector3(0.08, 0, 0), Vector3(0.215, 0.22, 0.15))
	var lin := Mats.get_m("linen")
	for s in [-1, 1]:
		var sh := _att("upperarm_l" if s < 0 else "upperarm_r")
		_mesh(sh, _sph(0.095, true), lin, Vector3(0, 0.03, 0), Vector3(0, 0, 0), Vector3(1.1, 0.9, 1.15))

	var sk := Node3D.new()
	sk.rotation = Vector3(-0.28, 0, 0)
	_att("pelvis").add_child(sk)
	_mesh(sk, TorusMeshHelper.make(0.19, 0.016), metal, Vector3(0, 0, 0.01), Vector3.ZERO, Vector3(1, 1, 0.82))
	for k in range(16):
		var a := k / 16.0 * TAU
		var st := _mesh(sk, _box(0.075, 0.3, 0.014), Mats.get_m("cloth" if k % 2 else "leather"), Vector3(sin(a) * 0.2, -0.17, cos(a) * 0.165 + 0.01))
		st.rotation_order = EULER_ORDER_YXZ
		st.rotation = Vector3(-0.16, a, 0)
	for n in ["calf_l", "calf_r"]:
		_mesh(_att(n), _cyl(0.062, 0.05, 0.3, 16), metal, Vector3(0, 0.2, 0.015))
	for n in ["lowerarm_l", "lowerarm_r"]:
		_mesh(_att(n), _cyl(0.052, 0.045, 0.17, 16), Mats.get_m("leather"), Vector3(0, 0.15, 0))

func _shield(metal: Material, face: String, r: float) -> void:
	var g := Node3D.new()
	g.position = Vector3(-0.1, 0.12, 0)
	_att("lowerarm_l").add_child(g)
	# aspis: cuenco poco profundo con borde ancho
	var bowl := _sph(r, true)
	_mesh(g, bowl, metal, Vector3(-0.01, 0, 0), Vector3(0, 0, PI / 2), Vector3(1, 0.16, 1))
	_mesh(g, TorusMeshHelper.make(r, 0.026), metal, Vector3.ZERO, Vector3(0, 0, PI / 2))
	_mesh(g, _cyl(r * 0.62, r * 0.62, 0.01, 40), Mats.get_m(face), Vector3(-0.027, 0, 0), Vector3(0, 0, PI / 2))
	_mesh(g, _sph(r * 0.15), metal, Vector3(-0.035, 0, 0), Vector3.ZERO, Vector3(0.6, 1, 1))

func _sword(metal: Material, blade := 1.0) -> void:
	sword = Node3D.new()
	sword.position = Vector3(-0.02, 0.085, 0)
	_att("hand_r").add_child(sword)
	_mesh(sword, _cyl(0.018, 0.018, 0.13, 10), Mats.get_m("leather"), Vector3.ZERO, Vector3(PI / 2, 0, 0))
	_mesh(sword, _box(0.12, 0.028, 0.03), metal, Vector3(0, 0, 0.075))
	_mesh(sword, _sph(0.028), metal, Vector3(0, 0, -0.075))
	# xiphos: hoja en forma de hoja de laurel
	var L := 0.52 * blade
	for k in range(6):
		var t := (k + 0.5) / 6.0
		var w := 0.05 + 0.022 * sin(t * PI * 0.9 + 0.3)
		_mesh(sword, _box(w, 0.012, L / 6.0 + 0.004), Mats.get_m("steel"), Vector3(0, 0, 0.09 + t * L))
	var tip := PrismMesh.new()
	tip.size = Vector3(0.055, 0.12, 0.012)
	_mesh(sword, tip, Mats.get_m("steel"), Vector3(0, 0, 0.09 + L + 0.06), Vector3(PI / 2, 0, 0))

func _spear() -> void:
	sword = Node3D.new()
	sword.position = Vector3(-0.02, 0.085, 0)
	_att("hand_r").add_child(sword)
	_mesh(sword, _cyl(0.017, 0.017, 2.1, 8), Mats.get_m("wood"), Vector3(0, 0, 0.35), Vector3(PI / 2, 0, 0))
	var cone := _cyl(0.0, 0.045, 0.3, 8)
	_mesh(sword, cone, Mats.get_m("bronze"), Vector3(0, 0, 1.52), Vector3(PI / 2, 0, 0))

func _labrys() -> void:
	sword = Node3D.new()
	sword.position = Vector3(-0.02, 0.085, -0.25)
	_att("hand_r").add_child(sword)
	_mesh(sword, _cyl(0.025, 0.025, 1.25, 8), Mats.get_m("wood"), Vector3(0, 0, 0.5), Vector3(PI / 2, 0, 0))
	_mesh(sword, Geo.labrys_blade(), Mats.get_m("dark_bronze"), Vector3(0, 0, 1.0))
	_mesh(sword, _cyl(0.04, 0.04, 0.12, 10), Mats.get_m("bronze"), Vector3(0, 0, 1.0), Vector3(PI / 2, 0, 0))

## Al morir, el arma cae al suelo en lugar de quedar clavada en la mano.
func drop_weapon(world: Node3D) -> void:
	if sword == null or not is_instance_valid(sword):
		return
	var gt := sword.global_transform
	sword.get_parent().remove_child(sword)
	world.add_child(sword)
	sword.global_transform = gt
	dropped = sword
	var fwd := gt.basis.z
	fwd.y = 0
	if fwd.length() < 0.01:
		fwd = Vector3.FORWARD
	var target_basis := Basis.looking_at(-fwd.normalized(), Vector3.UP).scaled(gt.basis.get_scale())
	var target_pos := Vector3(gt.origin.x, 0.04, gt.origin.z)
	var tw := sword.create_tween().set_parallel(true)
	tw.tween_property(sword, "global_transform", Transform3D(target_basis, target_pos), 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	sword = null

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

## Retroceso procedural: el cuerpo se sacude en la dirección del golpe sin interrumpir la animación
## (útil en jefes, que no deben entrar en animación de dolor con cada corte).
func recoil(dir_world: Vector3, amount: float) -> void:
	var local := global_transform.basis.inverse() * dir_world
	local.y = 0.0
	if local.length() > 0.01:
		rec_v += local.normalized() * amount * 3.2 / maxf(scale.x, 0.01)

func _physics_process(dt: float) -> void:
	if model == null:
		return
	rec_v += (-rec_p * 320.0 - rec_v * 20.0) * dt
	rec_p += rec_v * dt
	model.position = Vector3(rec_p.x, 0.0, rec_p.z)
	model.rotation.x = lean_x + rec_p.z * 1.6

func set_flash(on: bool, col := Color(0.5, 0.35, 0.22)) -> void:
	skin_mat.emission_enabled = on
	skin_mat.emission = col
	skin_mat.emission_energy_multiplier = 1.0 if col.r < 0.9 else 1.6
