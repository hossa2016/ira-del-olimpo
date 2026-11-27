class_name Cerberus
extends Enemy
## Cerbero: perro de tres cabezas del Inframundo con animación procedural
## (marcha a cuatro patas, mordiscos, aliento de fuego y salto).

var rig: Node3D
var legs: Array = []      # [hip, knee, phase_offset]
var heads: Array = []     # {node, jaw, base, rest, lunge, open}
var necks: Array = []
var tail: Node3D
var gait := 0.0
var fire: GPUParticles3D
var fire_light: OmniLight3D
var embers: CPUParticles3D
var mode := ""
var jump_from := Vector3.ZERO
var jump_to := Vector3.ZERO
var tick_dmg := 0.0
var flinch := 0.0
var fur_mat: StandardMaterial3D

func setup(k: String, lv: float) -> void:
	kind = k
	boss = true
	zombie = false
	sc = 1.25
	r = 1.25
	max_hp = 480.0 * lv
	hp = max_hp
	speed = 3.2
	dmg = 16.0
	title = "Cerbero, guardián del Hades"
	st = "move"
	cd = 1.5
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.9
	cap.height = 3.2
	col.shape = cap
	col.rotation.x = PI / 2
	col.position = Vector3(0, 1.3, 0.2)
	add_child(col)
	collision_layer = 4
	collision_mask = 1 | 2 | 4
	_build()

func _mi(parent: Node3D, mesh: Mesh, mat: Material, pos := Vector3.ZERO, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.position = pos
	m.rotation = rot
	m.scale = scl
	parent.add_child(m)
	return m

func _sph(rad: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = rad
	s.height = rad * 2
	s.radial_segments = 20
	s.rings = 10
	return s

func _cap(rad: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = rad
	c.height = h
	c.radial_segments = 16
	c.rings = 6
	return c

func _build() -> void:
	fur_mat = Mats.get_m("fur").duplicate()
	var fur := fur_mat
	rig = Node3D.new()
	add_child(rig)
	body = null
	# torso: pecho ancho, vientre recogido, cadera
	_mi(rig, _sph(0.72), fur, Vector3(0, 1.45, 0.85), Vector3.ZERO, Vector3(1.0, 1.0, 1.1))
	_mi(rig, _cap(0.5, 2.4), fur, Vector3(0, 1.38, 0.0), Vector3(PI / 2 + 0.06, 0, 0), Vector3(1.0, 1.0, 0.9))
	_mi(rig, _sph(0.52), fur, Vector3(0, 1.32, -0.95), Vector3.ZERO, Vector3(1.0, 0.95, 1.05))
	# lomo con púas de hueso
	for i in range(7):
		var z := 1.0 - i * 0.32
		var sp := _cyl(0.0, 0.06, 0.26 - absf(i - 3) * 0.025)
		_mi(rig, sp, Mats.get_m("ivory"), Vector3(0, 1.98 - absf(z - 0.6) * 0.12, z), Vector3(-0.35, 0, 0))
	# patas
	var lp := [[-0.42, 1.0, 0.0], [0.42, 1.0, PI], [-0.38, -0.95, PI], [0.38, -0.95, 0.0]]
	for q in lp:
		var hip := Node3D.new()
		hip.position = Vector3(q[0], 1.25, q[1])
		rig.add_child(hip)
		_mi(hip, _cap(0.17 if q[1] > 0 else 0.19, 0.85), fur, Vector3(0, -0.32, 0))
		var knee := Node3D.new()
		knee.position = Vector3(0, -0.66, 0)
		hip.add_child(knee)
		_mi(knee, _cap(0.11, 0.7), fur, Vector3(0, -0.28, 0))
		_mi(knee, _sph(0.14), Mats.get_m("black"), Vector3(0, -0.6, 0.07), Vector3.ZERO, Vector3(1.0, 0.55, 1.4))
		legs.append([hip, knee, q[2], q[1] > 0])
	# cola
	tail = Node3D.new()
	tail.position = Vector3(0, 1.45, -1.35)
	rig.add_child(tail)
	_mi(tail, _cap(0.07, 1.0), fur, Vector3(0, 0, -0.45), Vector3(PI / 2 - 0.5, 0, 0))
	# tres cabezas
	var hp_ := [Vector3(-0.62, 2.0, 1.75), Vector3(0, 2.22, 1.95), Vector3(0.62, 2.0, 1.75)]
	for i in range(3):
		var base := Vector3((i - 1) * 0.3, 1.75, 1.2)
		var neck := Node3D.new()
		rig.add_child(neck)
		_mi(neck, _cap(0.22, 1.0), fur, Vector3.ZERO, Vector3(PI / 2, 0, 0))
		necks.append([neck, base])
		var h := Node3D.new()
		h.position = hp_[i]
		rig.add_child(h)
		_mi(h, _sph(0.3), fur, Vector3(0, 0.02, -0.02), Vector3.ZERO, Vector3(0.95, 0.85, 1.05))
		_mi(h, _box(0.24, 0.17, 0.4), fur, Vector3(0, -0.03, 0.34))
		_mi(h, _sph(0.06), Mats.get_m("black"), Vector3(0, 0.0, 0.55), Vector3.ZERO, Vector3(1.3, 0.8, 0.8))
		for s in [-1, 1]:
			var ear := PrismMesh.new()
			ear.size = Vector3(0.12, 0.2, 0.05)
			_mi(h, ear, fur, Vector3(s * 0.15, 0.28, -0.08), Vector3(-0.3, 0, s * 0.3))
			_mi(h, _sph(0.035), Mats.get_m("glow_fire"), Vector3(s * 0.13, 0.1, 0.2))
			for t in range(3):
				var fang := _cyl(0.0, 0.018, 0.08)
				_mi(h, fang, Mats.get_m("ivory"), Vector3(s * (0.06 + t * 0.03), -0.13, 0.5 - t * 0.08), Vector3(PI, 0, 0))
		var jaw := Node3D.new()
		jaw.position = Vector3(0, -0.1, 0.12)
		h.add_child(jaw)
		_mi(jaw, _box(0.22, 0.08, 0.4), fur, Vector3(0, -0.03, 0.2))
		_mi(jaw, _box(0.16, 0.02, 0.34), Mats.get_m("gums"), Vector3(0, 0.015, 0.2))
		heads.append({"node": h, "jaw": jaw, "rest": hp_[i], "lunge": 0.0, "open": 0.0, "pitch": 0.0})
	# brasas sobre el lomo
	embers = CPUParticles3D.new()
	embers.amount = 24
	embers.lifetime = 1.4
	embers.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	embers.emission_box_extents = Vector3(0.4, 0.1, 1.2)
	embers.position = Vector3(0, 1.9, 0)
	embers.direction = Vector3.UP
	embers.spread = 20.0
	embers.gravity = Vector3(0, 1.2, 0)
	embers.initial_velocity_min = 0.3
	embers.initial_velocity_max = 0.8
	embers.scale_amount_min = 0.5
	embers.scale_amount_max = 1.0
	var em := _sph(0.025)
	em.material = Mats.get_m("glow_fire")
	embers.mesh = em
	rig.add_child(embers)
	# aliento de fuego (cabeza central)
	fire = GPUParticles3D.new()
	fire.emitting = false
	fire.amount = 90
	fire.lifetime = 0.7
	fire.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 0, 1)
	pm.spread = 14.0
	pm.initial_velocity_min = 8.0
	pm.initial_velocity_max = 11.0
	pm.gravity = Vector3(0, 1.5, 0)
	pm.damping_min = 3.0
	pm.damping_max = 5.0
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.3))
	curve.add_point(Vector2(0.5, 1.4))
	curve.add_point(Vector2(1, 2.2))
	var ct := CurveTexture.new()
	ct.curve = curve
	pm.scale_curve = ct
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 0.95, 0.6, 1))
	grad.add_point(0.35, Color(1, 0.5, 0.1, 0.9))
	grad.set_color(grad.get_point_count() - 1, Color(0.25, 0.08, 0.05, 0))
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	fire.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.7, 0.7)
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fm.vertex_color_use_as_albedo = true
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	fm.albedo_texture = game._glow_tex()
	fm.albedo_color = Color(2.0, 1.4, 0.9)
	quad.material = fm
	fire.draw_pass_1 = quad
	heads[1].node.add_child(fire)
	fire.position = Vector3(0, -0.05, 0.6)
	fire_light = OmniLight3D.new()
	fire_light.light_color = Color(1, 0.5, 0.15)
	fire_light.light_energy = 0.0
	fire_light.omni_range = 7.0
	heads[1].node.add_child(fire_light)
	fire_light.position = Vector3(0, 0, 1.2)
	for c in rig.find_children("*", "MeshInstance3D", true, false):
		c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

func _cyl(top: float, bot: float, h: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bot
	m.height = h
	m.radial_segments = 8
	return m

func _box(x: float, y: float, z: float) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = Vector3(x, y, z)
	return m

func tick(dt: float, hero: Hero) -> void:
	st_t += dt
	flinch = maxf(0.0, flinch - dt * 3.0)
	if st == "dead":
		rig.rotation.z = lerpf(rig.rotation.z, PI / 2 * 0.92, 1.0 - exp(-4.0 * dt))
		rig.position.y = lerpf(rig.position.y, -0.55, 1.0 - exp(-4.0 * dt))
		for hd in heads:
			hd.jaw.rotation.x = lerpf(hd.jaw.rotation.x, 0.35, dt * 3.0)
		if st_t > 2.5:
			rig.position.y -= dt * 0.6
		_pose(dt, 0.0)
		return
	var to := hero.global_position - global_position
	to.y = 0
	var d := maxf(0.01, to.length())
	var dir := to / d
	var tf := atan2(to.x, to.z)
	var alive := hero.st != "dead"
	var want := Vector3.ZERO
	if st == "move":
		face = lerp_angle(face, tf, 1.0 - exp(-3.0 * dt))
		cd -= dt
		if alive and d > 3.2:
			want = dir * speed * (1.0 if absf(wrapf(tf - face, -PI, PI)) < 1.0 else 0.4)
		if alive and cd <= 0.0:
			var r2 := randf()
			if d < 3.8:
				mode = "bite" if r2 < 0.55 else ("tri" if r2 < 0.8 else "fire")
			elif d < 7.0:
				mode = "fire" if r2 < 0.5 else "pounce"
			elif d < 11.0:
				mode = "pounce"
			else:
				mode = ""
			if mode != "":
				st = "atk"
				st_t = 0.0
				hit_i = 0
				tick_dmg = 0.0
				if mode == "fire" or mode == "pounce":
					_telegraph_c(0.6)
				game.sfx("growl")
	elif st == "atk":
		want = _do_attack(dt, hero, d, dir, tf)
	elif st == "hurt":
		if st_t >= 0.35:
			st = "move"
	elif st == "stun":
		if st_t >= 1.2:
			st = "move"
			cd = 0.5
	var acc := 9.0
	var dv := want - vel
	if dv.length() > acc * dt:
		dv = dv.normalized() * acc * dt
	vel += dv
	kb = kb.lerp(Vector3.ZERO, 1.0 - exp(-5.0 * dt))
	velocity = vel + kb
	velocity.y = 0.0
	if mode != "pounce" or st != "atk":
		move_and_slide()
	position.y = 0.0
	var rr := Vector2(position.x, position.z).length()
	if rr > Game.AR - 1.2:
		position.x *= (Game.AR - 1.2) / rr
		position.z *= (Game.AR - 1.2) / rr
	rotation.y = face
	_pose(dt, vel.length())

func _telegraph_c(t: float) -> void:
	fur_mat.emission_enabled = true
	fur_mat.emission = Color(1, 0.2, 0.05)
	fur_mat.emission_energy_multiplier = 0.6
	game.telegraph(self)
	get_tree().create_timer(t).timeout.connect(func(): fur_mat.emission_enabled = false)

func _do_attack(dt: float, hero: Hero, d: float, dir: Vector3, tf: float) -> Vector3:
	var want := Vector3.ZERO
	var t := st_t
	var fw := Vector3(sin(face), 0, cos(face))
	match mode:
		"bite", "tri":
			var n := 1 if mode == "bite" else 3
			var per := 0.62
			var k := int(t / per)
			var lt := fmod(t, per)
			if k >= n:
				_end_atk(0.9)
				return want
			var hi: int = [1, 0, 2][k] if mode == "tri" else (0 if dir.dot(Vector3(cos(face), 0, -sin(face))) < 0 else 2)
			if mode == "bite":
				hi = 1
			var hd: Dictionary = heads[hi]
			if lt < 0.3:
				face = lerp_angle(face, tf, 1.0 - exp(-6.0 * dt))
				hd.open = lerpf(hd.open, 0.7, dt * 10.0)
				hd.lunge = lerpf(hd.lunge, -0.15, dt * 8.0)
			elif lt < 0.42:
				hd.lunge = lerpf(hd.lunge, 0.75, dt * 25.0)
				want = fw * 4.0
				if hit_i <= k and lt > 0.36:
					hit_i = k + 1
					hd.open = 0.0
					if d < 3.7 and fw.dot(dir) > 0.45:
						hero.take_hit(dmg * (1.0 if mode == "bite" else 0.75), global_position, self)
					game.sfx("bite")
			else:
				hd.lunge = lerpf(hd.lunge, 0.0, dt * 6.0)
		"fire":
			var hd: Dictionary = heads[1]
			if t < 0.7:
				face = lerp_angle(face, tf, 1.0 - exp(-5.0 * dt))
				hd.pitch = lerpf(hd.pitch, -0.5, dt * 6.0)
				hd.open = lerpf(hd.open, 0.3, dt * 6.0)
			elif t < 2.3:
				if not fire.emitting:
					fire.emitting = true
					game.cam.shake(0.3)
					game.sfx("fire")
				face = rotate_toward(face, tf, 0.6 * dt)
				hd.pitch = lerpf(hd.pitch, 0.22, dt * 6.0)
				hd.open = lerpf(hd.open, 0.85, dt * 10.0)
				fire_light.light_energy = 3.0 + randf() * 1.5
				tick_dmg -= dt
				var hp_rel := hero.global_position - (global_position + fw * 1.8)
				hp_rel.y = 0
				if tick_dmg <= 0.0 and hp_rel.length() < 7.5 and fw.dot(hp_rel.normalized()) > cos(0.38):
					tick_dmg = 0.3
					hero.take_hit(7.0, global_position, self, true)
			else:
				fire.emitting = false
				fire_light.light_energy = 0.0
				hd.pitch = lerpf(hd.pitch, 0.0, dt * 5.0)
				hd.open = lerpf(hd.open, 0.0, dt * 6.0)
				if t > 2.7:
					_end_atk(1.0)
		"pounce":
			if t < 0.6:
				face = lerp_angle(face, tf, 1.0 - exp(-8.0 * dt))
				rig.position.y = lerpf(rig.position.y, -0.25, dt * 8.0)
				jump_from = global_position
				jump_to = hero.global_position - dir * 1.6
			elif t < 1.25:
				var k := (t - 0.6) / 0.65
				var p := jump_from.lerp(jump_to, k)
				global_position = Vector3(p.x, 0, p.z)
				rig.position.y = sin(k * PI) * 2.2
				rig.rotation.x = lerpf(-0.35, 0.3, k)
				for hd in heads:
					hd.open = 0.6
			else:
				if hit_i == 0:
					hit_i = 1
					rig.position.y = 0.0
					rig.rotation.x = 0.0
					game.shockwave(global_position + fw * 1.6, 3.0, dmg * 1.3, false, self)
					game.cam.shake(0.7)
				for hd in heads:
					hd.open = lerpf(hd.open, 0.0, dt * 5.0)
				if t > 1.8:
					_end_atk(1.2)
	return want

func _end_atk(c: float) -> void:
	st = "move"
	mode = ""
	cd = c + randf() * 0.8
	fire.emitting = false
	fire_light.light_energy = 0.0

func _pose(dt: float, sp: float) -> void:
	gait += dt * (1.2 + sp * 1.9)
	var amp := clampf(sp / 3.0, 0.0, 1.0) * 0.55
	for L in legs:
		var ph: float = gait + L[2]
		var hip: Node3D = L[0]
		var knee: Node3D = L[1]
		hip.rotation.x = sin(ph) * amp
		var bend := maxf(0.0, -cos(ph)) * amp * 1.4
		knee.rotation.x = -bend if L[3] else bend
	if st != "dead" and not (st == "atk" and mode == "pounce"):
		rig.position.y = lerpf(rig.position.y, absf(sin(gait)) * amp * 0.08, 1.0 - exp(-10.0 * dt))
		rig.rotation.x = lerpf(rig.rotation.x, -flinch * 0.15, 1.0 - exp(-8.0 * dt))
	tail.rotation.y = sin(gait * 0.7) * 0.4
	tail.rotation.x = -0.2 + sin(gait * 0.5) * 0.1
	for i in range(3):
		var hd: Dictionary = heads[i]
		var h: Node3D = hd.node
		var idle := sin(gait * 0.6 + i * 2.1) * 0.06
		var rest: Vector3 = hd.rest
		h.position = rest + Vector3(0, idle + hd.pitch * -0.3, hd.lunge)
		h.rotation = Vector3(hd.pitch + idle, (i - 1) * 0.28 + sin(gait * 0.4 + i) * 0.08, 0)
		hd.jaw.rotation.x = lerpf(hd.jaw.rotation.x, hd.open * 0.8, 1.0 - exp(-14.0 * dt))
		if st == "move" and randf() < dt * 0.3:
			hd.open = 0.5
		elif st == "move":
			hd.open = lerpf(hd.open, 0.0, dt * 3.0)
		var nk: Array = necks[i]
		var base: Vector3 = nk[1]
		var tgt: Vector3 = h.position - Vector3(0, 0.05, 0.25)
		var mid := (base + tgt) * 0.5
		var dirv := tgt - base
		var neck: Node3D = nk[0]
		neck.transform = Transform3D(Basis.looking_at(dirv.normalized(), Vector3.UP), mid)
		neck.scale = Vector3(1, 1, dirv.length() / 1.0)

func set_fade(f: float) -> void:
	super.set_fade(f)

func parried() -> void:
	if st == "dead":
		return
	fire.emitting = false
	st = "stun"
	st_t = 0.0
	mode = ""
	flinch = 1.0

func hurt(amount: float, push: Vector3, heavy: bool, c := {}) -> bool:
	if st == "dead":
		return false
	hp -= amount * (1.5 if st == "stun" else 1.0)
	kb = push * 0.1
	flinch = 1.0 if heavy else 0.5
	fur_mat.emission_enabled = true
	fur_mat.emission = Color(0.5, 0.3, 0.2)
	fur_mat.emission_energy_multiplier = 0.5
	get_tree().create_timer(0.1).timeout.connect(func(): fur_mat.emission_enabled = false)
	if hp <= 0.0:
		st = "dead"
		st_t = 0.0
		fire.emitting = false
		embers.emitting = false
		collision_layer = 0
		collision_mask = 0
		game.on_enemy_dead(self)
		return false
	if phase == 1 and hp < max_hp * 0.5:
		phase = 2
		speed *= 1.2
		game.on_boss_phase(self)
	poise += amount
	if poise > 80.0 and st == "move":
		poise = 0.0
		st = "hurt"
		st_t = 0.0
	return false
