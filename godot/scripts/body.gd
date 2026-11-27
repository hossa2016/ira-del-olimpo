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
var aim: SpineAim
var upright := false
var mh := false
var model_y := 0.0
static var _q_rest := {}

const MH_NAT := {"Walk_Loop": 1.36, "Jog_Fwd_Loop": 2.35, "Sprint_Loop": 3.23}

func setup(o: Dictionary) -> void:
	mh = o.get("mh", "") != ""
	if mh:
		_setup_mh(o)
	else:
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
		_helmet(o.get("crest", "horse"), "helm_" + ("bronze" if mk == "bronze" else mk.replace("dark_bronze", "dark")), o.get("helm", "attic"))
	if o.get("armor", false):
		_armor(metal)
	elif o.get("rag", true):
		# taparrabos de tela vieja (los no-muertos ya no se ven en ropa interior)
		var pv := _att("pelvis")
		_mesh(pv, _cyl(0.2, 0.235, 0.24, 20), Mats.get_m("rag"), Vector3(0, -0.04, 0.01), Vector3.ZERO, Vector3(1.0, 1.0, 0.85))
		for k in range(10):
			var a := k / 10.0 * TAU + 0.3
			var st := _mesh(pv, _box(0.09, 0.16 + (k % 3) * 0.04, 0.01), Mats.get_m("rag"), Vector3(sin(a) * 0.215, -0.2, cos(a) * 0.185 + 0.01))
			st.rotation_order = EULER_ORDER_YXZ
			st.rotation = Vector3(-0.08, a, (k % 2 - 0.5) * 0.15)
		_mesh(pv, TorusMeshHelper.make(0.205, 0.015), Mats.get_m("leather"), Vector3(0, 0.07, 0.01), Vector3.ZERO, Vector3(1, 1, 0.85))
	if o.get("shield", false):
		_shield(metal, o.get("shield_face", "cloth"), o.get("shield_r", 0.42), o.get("emblem", "damon"))
	match o.get("weapon", ""):
		"sword":
			_sword(metal, o.get("blade", 1.0))
		"spear":
			_spear()
		"labrys":
			_labrys()
	if o.get("eyes", "") != "":
		var em: String = o.get("eyes")
		if o.get("bull", false):
			var hd := _att("Head")
			for s in [-1, 1]:
				_mesh(hd, _sph(0.017), Mats.get_m("glow_" + em), Vector3(s * 0.075, 0.085, 0.135))
		else:
			# los propios globos oculares brillan (antes eran discos pegados a la cara)
			for c in skel.get_children():
				if c is MeshInstance3D and String(c.name).begins_with("Eyes"):
					c.material_override = Mats.get_m("glow_" + em)
	if o.get("beard", false):
		call_deferred("_beard")
	if mh:
		_convert_attachments()
		_mh_eyes()
	var sc: float = o.get("scale", 1.0)
	scale = Vector3.ONE * sc
	upright = o.get("upright", false)
	# proporciones propias: escalar huesos (las animaciones no tienen pistas de escala, así que se conservan)
	var props: Dictionary = o.get("bones", {})
	for bn in props.keys():
		var bi := skel.find_bone(bn)
		if bi >= 0:
			skel.set_bone_pose_scale(bi, Vector3.ONE * float(props[bn]))
	aim = SpineAim.new()
	skel.add_child(aim)
	aim.setup(skel)

## Mira hacia un punto con el tronco y la cabeza (limitado a ±50°).
func look_toward(p: Vector3, w := 1.0) -> void:
	var to := p - global_position
	to.y = 0
	if to.length() < 0.3:
		aim.yaw = 0.0
		return
	var f := global_transform.basis.z
	f.y = 0
	var rel := wrapf(atan2(to.x, to.z) - atan2(f.x, f.z), -PI, PI)
	aim.yaw = clampf(rel, -0.9, 0.9)
	aim.weight = w

func look_clear() -> void:
	aim.yaw = 0.0

# ---------- cuerpo MakeHuman (piel real, animaciones de captura) ----------
func _setup_mh(o: Dictionary) -> void:
	model = load("res://assets/models/damon_mh.glb").instantiate()
	add_child(model)
	skel = model.find_child("Skeleton3D", true, false)
	# pies en el suelo: el origen del esqueleto está en la cadera
	model_y = -skel.get_bone_global_rest(skel.find_bone("ball_l")).origin.y + 0.035
	model.position.y = model_y
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/tex/damon_skin.jpg")
	m.albedo_color = o.get("tint", Color(1, 1, 1))
	m.roughness = 0.58
	m.rim_enabled = true
	m.rim = 0.3
	m.rim_tint = 0.6
	m.backlight_enabled = true
	m.backlight = Color(0.25, 0.08, 0.04)
	skin_mat = m
	var arm_on: bool = o.get("armor", false)
	for c in skel.find_children("*", "MeshInstance3D", true, false):
		c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		match String(c.name):
			"Cuirass", "Greaves":
				# coraza y grebas moldeadas sobre el propio cuerpo
				c.material_override = Mats.get_m(o.get("metal", "bronze"))
				c.visible = arm_on
			"Bracers":
				c.material_override = Mats.get_m("leather")
				c.visible = arm_on
			_:
				c.material_override = m
	ap = model.find_child("AnimationPlayer", true, false)
	# mismos nombres que la biblioteca antigua: los bucles llevan "_Loop"
	var lib := AnimationLibrary.new()
	for n in ap.get_animation_list():
		var a: Animation = ap.get_animation(n).duplicate(true)
		for i in range(a.get_track_count() - 1, -1, -1):
			if a.track_get_type(i) == Animation.TYPE_SCALE_3D:
				a.remove_track(i)
		var out := String(n)
		var looped := a.loop_mode != Animation.LOOP_NONE or out in ["Walk", "Jog_Fwd", "Sprint", "Idle", "Idle_Shield"]
		if looped:
			a.loop_mode = Animation.LOOP_LINEAR
			if not out.ends_with("_Loop"):
				out += "_Loop"
		lib.add_animation(out, a)
	for l in ap.get_animation_library_list():
		ap.remove_animation_library(l)
	ap.add_animation_library("", lib)

## Las piezas de armadura se diseñaron sobre los huesos del modelo anterior: se trasladan al cuerpo
## MakeHuman usando puntos anatómicos equivalentes (ojos, hombros, caderas) y conservando su orientación.
const MH_EYE := Vector3(0.0293, 0.8181, 0.1274)
static func _quat_rest() -> Dictionary:
	if not _q_rest.is_empty():
		return _q_rest
	var q: Node = load("res://assets/models/hero.glb").instantiate()
	var qs: Skeleton3D = q.find_child("Skeleton3D", true, false)
	for i in qs.get_bone_count():
		_q_rest[qs.get_bone_name(i)] = qs.get_bone_global_rest(i)
	for c in qs.find_children("*", "MeshInstance3D", true, false):
		if String(c.name).begins_with("Eyes"):
			var bb: AABB = c.get_aabb()
			_q_rest["_eyes"] = c.transform * bb.get_center()
	q.free()
	return _q_rest

func _ref(bn: String, quat: bool) -> Vector3:
	var qr := _quat_rest()
	var g := func(n: String) -> Vector3:
		if quat:
			return qr["Head" if n == "head" else n].origin
		return skel.get_bone_global_rest(skel.find_bone(n)).origin
	match bn:
		"head":
			if quat:
				var e: Vector3 = qr.get("_eyes", g.call("head"))
				return Vector3(0, e.y, e.z)
			return Vector3(0, MH_EYE.y, MH_EYE.z)
		"spine_03", "spine_02":
			# el torso de MakeHuman es más corto bajo los hombros: subir la coraza
			return (g.call("upperarm_l") + g.call("upperarm_r")) * 0.5 + (Vector3.ZERO if quat else Vector3(0, 0.085, 0.01))
		"pelvis":
			return (g.call("thigh_l") + g.call("thigh_r")) * 0.5
	return g.call(bn)

func _convert_attachments() -> void:
	var qr := _quat_rest()
	for att in skel.get_children():
		if not att is BoneAttachment3D:
			continue
		var bn: String = att.bone_name
		var qn := "Head" if bn == "head" else bn
		if not qr.has(qn):
			continue
		var qg: Transform3D = qr[qn]
		var mg: Transform3D = skel.get_bone_global_rest(skel.find_bone(bn))
		var bq: Basis = qg.basis.orthonormalized()
		var bm: Basis = mg.basis.orthonormalized()
		var conv: Basis = bm.inverse() * bq
		var dq := _ref(bn, true)
		var dm := _ref(bn, false)
		for c in att.get_children():
			if c is Node3D and not c.has_meta("mh_done"):
				var t: Transform3D = c.transform
				var pos_model: Vector3 = qg * t.origin - dq + dm
				c.transform = Transform3D(conv * t.basis, mg.affine_inverse() * pos_model)

func _mh_eyes() -> void:
	var hd := _att("head")
	var hb: Transform3D = skel.get_bone_global_rest(skel.find_bone("head"))
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.92, 0.9, 0.86)
	white.roughness = 0.08
	var iris := StandardMaterial3D.new()
	iris.albedo_color = Color(0.25, 0.16, 0.09)
	iris.roughness = 0.1
	var pupil := StandardMaterial3D.new()
	pupil.albedo_color = Color(0.01, 0.01, 0.01)
	pupil.roughness = 0.05
	# posiciones de los ojos (de MakeHuman, Blender Z arriba -> Godot Y arriba)
	for e in [MH_EYE, Vector3(-MH_EYE.x, MH_EYE.y, MH_EYE.z)]:
		var g := Node3D.new()
		hd.add_child(g)
		g.transform = Transform3D(hb.basis.orthonormalized().inverse(), hb.affine_inverse() * e)
		g.set_meta("mh_done", true)
		_mesh(g, _sph(0.0156), white)
		_mesh(g, _cyl(0.0062, 0.0062, 0.0012, 16), iris, Vector3(0, 0, 0.0150), Vector3(PI / 2, 0, 0))
		_mesh(g, _cyl(0.0027, 0.0027, 0.0014, 12), pupil, Vector3(0, 0, 0.0153), Vector3(PI / 2, 0, 0))

# ---------- utilidades ----------
func _att(bone: String) -> BoneAttachment3D:
	if mh and bone == "Head":
		bone = "head"
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
func _helmet(crest: String, hm: String, style := "attic") -> void:
	var g := Node3D.new()
	g.position = Vector3(0, 0.07 if style != "attic" else 0.098, -0.022)
	g.scale = Vector3.ONE * 0.97
	_att("Head").add_child(g)
	var helm := _mesh(g, Geo.corinthian_helmet(style), Mats.get_m(hm))
	if style == "attic":
		# visera sobre la frente
		var brow := _mesh(g, TorusMeshHelper.make(0.152, 0.012), Mats.get_m(hm), Vector3(0, 0.052, 0.012), Vector3(0.08, 0, 0), Vector3(1.0, 1.0, 1.14))
		brow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
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
	# medidas tomadas del esqueleto: spine_03 a 1,31 m, cuello a 1,52 m, cintura ~1,0 m
	# una sola pieza (pecho y vientre) con cinturón; antes eran dos esferas
	if not mh:
		_mesh(ch, _sph(1.0), metal, Vector3(0, -0.035, 0.018), Vector3(-0.04, 0, 0), Vector3(0.205, 0.255, 0.152))
		_mesh(ch, TorusMeshHelper.make(0.175, 0.014), metal, Vector3(0, -0.25, 0.01), Vector3(0.08, 0, 0), Vector3(1.0, 1.0, 0.8))
	var lin := Mats.get_m("linen")
	for s in ([] if mh else [-1, 1]):
		var sh := _att("upperarm_l" if s < 0 else "upperarm_r")
		_mesh(sh, _sph(0.095, true), lin, Vector3(0, 0.03, 0), Vector3(0, 0, 0), Vector3(1.1, 0.9, 1.15))

	# quitón de lino bajo las tiras de cuero (tapa la ropa interior del modelo base)
	_mesh(_att("pelvis"), _cyl(0.2, 0.225, 0.22, 24), Mats.get_m("chiton"), Vector3(0, -0.02, 0.01), Vector3.ZERO, Vector3(1.0, 1.0, 0.85))
	var sk := Node3D.new()
	sk.rotation = Vector3(-0.28, 0, 0)
	_att("pelvis").add_child(sk)
	_mesh(sk, TorusMeshHelper.make(0.19, 0.016), metal, Vector3(0, 0, 0.01), Vector3.ZERO, Vector3(1, 1, 0.82))
	for k in range(16):
		var a := k / 16.0 * TAU
		var st := _mesh(sk, _box(0.075, 0.3, 0.014), Mats.get_m("cloth" if k % 2 else "leather"), Vector3(sin(a) * 0.2, -0.17, cos(a) * 0.165 + 0.01))
		st.rotation_order = EULER_ORDER_YXZ
		st.rotation = Vector3(-0.16, a, 0)
	if mh:
		return
	for n in ["calf_l", "calf_r"]:
		_mesh(_att(n), _cyl(0.062, 0.05, 0.3, 16), metal, Vector3(0, 0.2, 0.015))
	for n in ["lowerarm_l", "lowerarm_r"]:
		_mesh(_att(n), _cyl(0.052, 0.045, 0.17, 16), Mats.get_m("leather"), Vector3(0, 0.15, 0))

func _shield(metal: Material, face: String, r: float, emblem := "damon") -> void:
	var g := Node3D.new()
	g.position = Vector3(-0.1, 0.12, 0)
	_att("lowerarm_l").add_child(g)
	# aspis: cuenco poco profundo con borde ancho
	var bw := _mesh(g, Geo.shield_bowl(r, r * 0.17), Mats.shield(emblem, r), Vector3(-0.01, 0, 0), Vector3(0, 0, PI / 2))
	bw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_mesh(g, Geo.shield_bowl(r, r * 0.17, true), Mats.get_m("leather"), Vector3(-0.01, 0, 0), Vector3(0, 0, PI / 2))
	_mesh(g, TorusMeshHelper.make(r, 0.026), metal, Vector3.ZERO, Vector3(0, 0, PI / 2))
	_mesh(g, _cyl(r * 0.62, r * 0.62, 0.01, 40), Mats.get_m(face), Vector3(-0.027, 0, 0), Vector3(0, 0, PI / 2))

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
		play("Zombie_Idle_Loop" if zombie and not upright else "Idle_Loop", 1.0, 0.3)
		return
	if zombie and not upright:
		play("Zombie_Walk_Fwd_Loop", clampf(s / 1.22, 0.6, 1.8), 0.3)
		return
	var clip := "Walk_Loop" if s < 1.9 else ("Jog_Fwd_Loop" if s < 3.8 else "Sprint_Loop")
	var nat: float = MH_NAT[clip] if mh else AnimLib.NAT[clip]
	play(clip, clampf(s / nat, 0.55, 2.1 if mh else 1.7), 0.28)

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
	model.position = Vector3(rec_p.x, model_y, rec_p.z)
	model.rotation.x = lean_x + rec_p.z * 1.6

func set_flash(on: bool, col := Color(0.5, 0.35, 0.22)) -> void:
	skin_mat.emission_enabled = on
	skin_mat.emission = col
	skin_mat.emission_energy_multiplier = 1.0 if col.r < 0.9 else 1.6
