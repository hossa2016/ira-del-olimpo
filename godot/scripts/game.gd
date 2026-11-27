class_name Game
extends Node3D
## Fase 1: Tebas. Entorno realista, arena, oleadas de Espartos, combate y HUD.

const AR := 15.0
const WAVES := [["esp", "esp"], ["esp", "esp", "esp"], ["esp", "esp", "esp", "esp"], ["gig", "esp", "esp"]]

var hero: Hero
var cam: ShoulderCam
var ui: GameUI
var sun: DirectionalLight3D
var env: Environment
var enemies: Array[Enemy] = []
var to_spawn: Array = []
var wave := 0
var spawn_t := 0.0
var gap := 0.0
var score := 0
var state := "menu"
var tokens: Array = []
var boss: Enemy = null
var hitstop := 0.0
var fires: Array = []
var clock := 0.0
var autotest := false
var _frames := 0

func _ready() -> void:
	_environment()
	_arena()
	hero = Hero.new()
	hero.game = self
	add_child(hero)
	hero.died.connect(_on_dead)
	cam = ShoulderCam.new()
	add_child(cam)
	ui = GameUI.new()
	add_child(ui)
	ui.play_pressed.connect(_start)
	ui.retry_pressed.connect(_start)
	hero.reset_at(Vector3(0, 0, 3))
	cam.global_position = hero.global_position + Vector3(0, 1.5, 0)
	ui.show_menu()
	if "--autotest" in OS.get_cmdline_user_args():
		autotest = true
		call_deferred("_start")

# ---------------- entorno ----------------
func _environment() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.3, 0.45, 0.66)
	sm.sky_horizon_color = Color(0.93, 0.72, 0.55)
	sm.sky_curve = 0.12
	sm.ground_horizon_color = Color(0.8, 0.6, 0.45)
	sm.ground_bottom_color = Color(0.22, 0.3, 0.38)
	sm.sun_angle_max = 18.0
	sm.sun_curve = 0.08
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.75
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.9
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.06
	env.glow_hdr_threshold = 1.2
	env.fog_enabled = true
	env.fog_light_color = Color(0.9, 0.72, 0.56)
	env.fog_density = 0.0045
	env.fog_sky_affect = 0.25
	env.fog_height = 1.0
	env.fog_height_density = 0.06
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.08
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.84, 0.66)
	sun.light_energy = 1.7
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 40.0
	sun.shadow_blur = 1.4
	sun.rotation = Vector3(deg_to_rad(-32), deg_to_rad(-145), 0)
	add_child(sun)

func _tex_mat(path: String, normal: String, rough: String, scale_uv: float, tint := Color.WHITE) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(path)
	m.albedo_color = tint
	if normal != "":
		m.normal_enabled = true
		m.normal_texture = load(normal)
		m.normal_scale = 1.0
	if rough != "":
		m.roughness_texture = load(rough)
		m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	m.roughness = 1.0
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * scale_uv
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m

func _static(mesh: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO, shape: Shape3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	add_child(mi)
	if shape:
		var sb := StaticBody3D.new()
		sb.collision_layer = 1
		var cs := CollisionShape3D.new()
		cs.shape = shape
		sb.add_child(cs)
		mi.add_child(sb)
	return mi

func _arena() -> void:
	var floor_m := _tex_mat("res://assets/tex/floor_c.jpg", "res://assets/tex/floor_n.jpg", "res://assets/tex/floor_r.jpg", 0.17, Color(0.78, 0.7, 0.6))
	var plat := CylinderMesh.new()
	plat.top_radius = AR + 7
	plat.bottom_radius = AR + 4
	plat.height = 10
	plat.radial_segments = 96
	_static(plat, floor_m, Vector3(0, -5, 0))
	# mar
	var sea := PlaneMesh.new()
	sea.size = Vector2(1500, 1500)
	var sea_m := StandardMaterial3D.new()
	sea_m.albedo_color = Color(0.12, 0.25, 0.32)
	sea_m.roughness = 0.08
	sea_m.metallic = 0.3
	_static(sea, sea_m, Vector3(0, -9, 0))
	# colinas e islas lejanas
	var isl_m := StandardMaterial3D.new()
	isl_m.albedo_color = Color(0.42, 0.37, 0.3)
	isl_m.roughness = 1.0
	for k in range(14):
		var a := -2.4 + k * 0.33 + sin(k * 7.0) * 0.12
		var rr := 140.0 + float(k * 37 % 5) * 22.0
		var sp := SphereMesh.new()
		sp.radius = 28.0 + float(k % 4) * 9.0
		sp.height = sp.radius * 2.0
		sp.radial_segments = 24
		sp.rings = 12
		var mi := _static(sp, isl_m, Vector3(cos(a) * rr, -9.0 - sp.radius * 0.55, sin(a) * rr))
		mi.scale = Vector3(1.0, 0.45 + float(k % 3) * 0.12, 0.7)
	# anillos de incrustación
	var inlay := StandardMaterial3D.new()
	inlay.albedo_color = Color(0.16, 0.11, 0.08)
	inlay.roughness = 0.55
	for rad in [AR, 9.7, 2.7]:
		var t := TorusMesh.new()
		t.inner_radius = rad - 0.18
		t.outer_radius = rad + 0.18
		t.rings = 96
		t.ring_segments = 4
		var mi := _static(t, inlay, Vector3(0, -0.17, 0))
		mi.scale = Vector3(1, 1, 1)
	# columnas
	var marble := _tex_mat("res://assets/tex/marble_c.jpg", "", "", 0.35, Color(1, 0.98, 0.94))
	marble.roughness = 0.5
	var broken := [2, 5, 6, 10, 13]
	for i in range(16):
		var a := i / 16.0 * TAU + 0.1
		var p := Vector3(cos(a), 0, sin(a)) * (AR + 2.6)
		var pl := BoxMesh.new()
		pl.size = Vector3(1.7, 0.32, 1.7)
		_static(pl, marble, p + Vector3(0, 0.16, 0))
		var h := 6.5 if not broken.has(i) else 1.6 + (i % 3) * 1.1
		var col := CylinderMesh.new()
		col.top_radius = 0.55
		col.bottom_radius = 0.64
		col.height = h
		col.radial_segments = 28
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.62
		cyl.height = h
		_static(col, marble, p + Vector3(0, 0.3 + h / 2, 0), Vector3((i % 2 - 0.5) * 0.1, 0, (i % 2 - 0.5) * 0.12) if broken.has(i) else Vector3.ZERO, cyl)
		if not broken.has(i):
			var cap := CylinderMesh.new()
			cap.top_radius = 0.82
			cap.bottom_radius = 0.55
			cap.height = 0.35
			_static(cap, marble, p + Vector3(0, 6.97, 0))
			var ab := BoxMesh.new()
			ab.size = Vector3(1.8, 0.26, 1.8)
			_static(ab, marble, p + Vector3(0, 7.27, 0))
	# braseros con fuego
	for k in range(4):
		var a := k / 4.0 * TAU + PI / 4
		_brazier(Vector3(cos(a), 0, sin(a)) * (AR + 1.2))

func _brazier(p: Vector3) -> void:
	var bronze: Material = Mats.get_m("bronze")
	var g := Node3D.new()
	g.position = p
	add_child(g)
	for k in range(3):
		var a := k / 3.0 * TAU
		var leg := CylinderMesh.new()
		leg.top_radius = 0.04
		leg.bottom_radius = 0.04
		leg.height = 1.3
		var mi := MeshInstance3D.new()
		mi.mesh = leg
		mi.material_override = bronze
		mi.position = Vector3(cos(a) * 0.28, 0.62, sin(a) * 0.28)
		mi.rotation = Vector3(sin(a) * 0.22, 0, -cos(a) * 0.22)
		g.add_child(mi)
	var bowl := CylinderMesh.new()
	bowl.top_radius = 0.56
	bowl.bottom_radius = 0.28
	bowl.height = 0.32
	var bm := MeshInstance3D.new()
	bm.mesh = bowl
	bm.material_override = bronze
	bm.position.y = 1.36
	g.add_child(bm)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.3)
	light.light_energy = 2.5
	light.omni_range = 9.0
	light.position.y = 2.0
	g.add_child(light)
	var fire := GPUParticles3D.new()
	fire.amount = 40
	fire.lifetime = 0.8
	fire.position.y = 1.5
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 12.0
	pm.initial_velocity_min = 0.8
	pm.initial_velocity_max = 1.6
	pm.gravity = Vector3(0, 0.6, 0)
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.22
	pm.scale_min = 0.6
	pm.scale_max = 1.1
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.5))
	curve.add_point(Vector2(0.3, 1.0))
	curve.add_point(Vector2(1, 0.0))
	var ct := CurveTexture.new()
	ct.curve = curve
	pm.scale_curve = ct
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.9, 0.5, 1))
	grad.set_color(1, Color(0.8, 0.15, 0.02, 0))
	grad.add_point(0.4, Color(1.0, 0.45, 0.1, 0.9))
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	fire.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.5, 0.7)
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fm.vertex_color_use_as_albedo = true
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	fm.albedo_texture = _glow_tex()
	fm.albedo_color = Color(2.2, 1.6, 1.0)
	quad.material = fm
	fire.draw_pass_1 = quad
	g.add_child(fire)
	fires.append(light)

var _gt: Texture2D
func _glow_tex() -> Texture2D:
	if _gt:
		return _gt
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	_gt = t
	return t

# ---------------- flujo ----------------
func _start() -> void:
	for e in enemies:
		e.queue_free()
	enemies.clear()
	tokens.clear()
	boss = null
	score = 0
	wave = 0
	hero.reset_at(Vector3(0, 0, 3))
	cam.yaw = PI
	ui.over.visible = false
	ui.menu.visible = false
	ui.set_playing(true)
	state = "play"
	gap = 0.5
	_next_wave()

func _next_wave() -> void:
	wave += 1
	if wave > WAVES.size():
		state = "won"
		ui.show_over("¡Tebas está a salvo! Puntuación: %d. Pronto: el Laberinto de Creta." % score)
		ui.over.get_child(0).get_child(0).text = "Victoria"
		return
	to_spawn = WAVES[wave - 1].duplicate()
	spawn_t = 1.0
	ui.set_banner("Esparto Gigante" if wave == WAVES.size() else "Oleada %d" % wave)
	if wave > 1:
		hero.hp = minf(hero.max_hp, hero.hp + 15)

func _spawn(k: String) -> void:
	var e := Enemy.new()
	e.game = self
	add_child(e)
	e.setup(k, 1.0 + (wave - 1) * 0.05)
	var a := randf() * TAU
	var p := Vector3(cos(a), 0, sin(a)) * (AR - 2.0)
	if p.distance_to(hero.global_position) < 7.0:
		p = -p
	e.global_position = p
	e.face = atan2(-p.x, -p.z)
	enemies.append(e)
	if e.boss:
		boss = e
		ui.boss_l.text = "Esparto Gigante"

func _on_dead() -> void:
	state = "over"
	await get_tree().create_timer(1.6).timeout
	ui.show_over("Caíste en Tebas con %d puntos." % score)

func _physics_process(dt: float) -> void:
	clock += dt
	for l in fires:
		l.light_energy = 2.5 * (0.82 + 0.12 * sin(clock * 9.3 + l.position.x) + 0.08 * sin(clock * 23.7))
	if state == "menu":
		cam.yaw += dt * 0.15
		cam.tick(dt, hero)
		hero.body.loco(0, false, true)
		return
	var inp := ui.read()
	if autotest:
		_frames += 1
		var tg := nearest_enemy(hero.global_position, 50.0)
		if tg:
			var d := tg.global_position - hero.global_position
			var yaw := cam.yaw
			var fwd := Vector3(sin(yaw), 0, cos(yaw))
			var rt := Vector3(-cos(yaw), 0, sin(yaw))
			if d.length() > 1.8:
				var dn := d.normalized()
				inp.move = Vector2(rt.dot(dn), -fwd.dot(dn))
			elif _frames % 8 == 0:
				inp.atk = true
		if _frames in [240, 700, 1500, 3400]:
			for a in OS.get_cmdline_user_args():
				if a.begins_with("--shot="):
					get_viewport().get_texture().get_image().save_png(a.substr(7) + "_%d.png" % _frames)
		if _frames % 300 == 0:
			print("t=", _frames, " wave=", wave, " hp=", hero.hp, " enemies=", enemies.size(), " score=", score, " st=", state)
	cam.rotate_by(inp.cam.x, inp.cam.y)
	var sdt := dt
	if hitstop > 0.0:
		hitstop -= dt
		sdt = 0.0
	if sdt > 0.0:
		hero.physics_tick(sdt, inp, cam.yaw)
		for e in enemies:
			e.tick(sdt, hero)
	cam.tick(dt, hero)
	if state == "play":
		spawn_t -= dt
		var alive := enemies.filter(func(q): return q.st != "dead").size()
		if spawn_t <= 0.0 and to_spawn.size() > 0 and alive < 4:
			_spawn(to_spawn.pop_front())
			spawn_t = 1.4
		for e in enemies.duplicate():
			if e.st == "dead" and e.st_t > 3.0:
				enemies.erase(e)
				e.queue_free()
		if to_spawn.is_empty() and enemies.is_empty():
			gap -= dt
			if gap <= 0.0:
				gap = 1.5
				_next_wave()
	var wt := "Tebas · " + ("Jefe" if wave >= WAVES.size() else "Oleada %d/3" % wave)
	ui.update_hud(hero, score, wt, boss if boss and boss.st != "dead" else null)

# ---------------- combate ----------------
func nearest_enemy(p: Vector3, maxd: float) -> Enemy:
	var best: Enemy = null
	var bd := maxd
	for e in enemies:
		if e.st == "dead" or e.st == "rise":
			continue
		var d := e.global_position.distance_to(p) - e.r
		if d < bd:
			bd = d
			best = e
	return best

func hero_hit(h: Hero, c: Dictionary, final: bool) -> void:
	var f := Vector3(sin(h.face), 0, cos(h.face))
	var n := 0
	for e in enemies:
		if e.st == "dead" or e.st == "rise":
			continue
		var to := e.global_position - h.global_position
		to.y = 0
		var d := to.length()
		if d > c.reach + e.r:
			continue
		if d > e.r + 0.35 and f.angle_to(to) > c.arc:
			continue
		var dir := to.normalized() if d > 0.01 else f
		e.hurt(c.dmg, dir * c.kb, final)
		_blood(e.global_position + Vector3(0, 1.2 * e.sc, 0), dir)
		n += 1
	if n > 0:
		hitstop = 0.09 if final else 0.05
		cam.shake(0.45 if final else 0.25)
		h.rage = minf(100.0, h.rage + 4.0 * n)
		Input.vibrate_handheld(12)

func on_enemy_dead(e: Enemy) -> void:
	score += 800 if e.boss else 100
	if e == boss:
		boss = null

func on_hero_hurt() -> void:
	ui.hurt_flash()
	cam.shake(0.5)
	Input.vibrate_handheld(30)
	_blood(hero.global_position + Vector3(0, 1.3, 0), Vector3.UP)

func take_token(e: Enemy) -> bool:
	tokens = tokens.filter(func(q): return is_instance_valid(q) and q.st == "atk")
	if tokens.size() >= 2:
		return false
	tokens.append(e)
	return true

func release_token(e: Enemy) -> void:
	tokens.erase(e)

func _blood(p: Vector3, dir: Vector3) -> void:
	var ps := CPUParticles3D.new()
	ps.one_shot = true
	ps.emitting = true
	ps.amount = 18
	ps.lifetime = 0.7
	ps.explosiveness = 1.0
	ps.direction = (dir + Vector3.UP * 0.6).normalized()
	ps.spread = 35.0
	ps.initial_velocity_min = 2.0
	ps.initial_velocity_max = 4.5
	ps.gravity = Vector3(0, -12, 0)
	ps.scale_amount_min = 0.5
	ps.scale_amount_max = 1.0
	var sm := SphereMesh.new()
	sm.radius = 0.025
	sm.height = 0.05
	sm.radial_segments = 6
	sm.rings = 3
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(0.32, 0.02, 0.01)
	bm.roughness = 0.2
	sm.material = bm
	ps.mesh = sm
	ps.position = p
	add_child(ps)
	get_tree().create_timer(1.2).timeout.connect(ps.queue_free)

func sfx(_n: String) -> void:
	pass
