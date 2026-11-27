class_name Game
extends Node3D
## Flujo del juego: historia entre mundos, oleadas, jefes, combate y efectos.

const AR := 15.0
const SAVE := "user://progreso.cfg"

var hero: Hero
var cam: ShoulderCam
var ui: GameUI
var sun: DirectionalLight3D
var env: Environment
var sky_mat: ShaderMaterial
var world_root: Node3D
var world_i := 0
var W: Dictionary
var enemies: Array = []
var to_spawn: Array = []
var wave := 0
var spawn_t := 0.0
var gap := 0.0
var score := 0
var state := "menu"
var tokens: Array = []
var boss: Enemy = null
var hitstop := 0.0
var slowmo := 0.0
var fires: Array = []
var clock := 0.0
var autotest := false
var _frames := 0
var unlocked := 0
var audio: GameAudio
var vfx: Vfx
var cine_cam: Camera3D
var cine := {}
var menu_t := 0.0
var cine_light: OmniLight3D

func _ready() -> void:
	audio = GameAudio.new()
	add_child(audio)
	vfx = Vfx.new()
	add_child(vfx)
	vfx.setup(self)
	_environment()
	world_root = Node3D.new()
	add_child(world_root)
	hero = Hero.new()
	hero.game = self
	add_child(hero)
	hero.died.connect(_on_dead)
	cam = ShoulderCam.new()
	add_child(cam)
	cine_cam = Camera3D.new()
	cine_cam.fov = 40.0
	cine_cam.near = 0.03
	cine_cam.far = 600.0
	add_child(cine_cam)
	# luz de retrato que acompaña a la cámara de cine (ilumina el rostro aunque esté a contraluz)
	cine_light = OmniLight3D.new()
	cine_light.light_color = Color(1.0, 0.85, 0.7)
	cine_light.light_energy = 0.0
	cine_light.omni_range = 7.0
	cine_light.position = Vector3(0.7, 0.5, 0.2)
	cine_cam.add_child(cine_light)
	ui = GameUI.new()
	add_child(ui)
	ui.play_pressed.connect(_on_play)
	ui.continue_pressed.connect(_on_continue)
	ui.retry_pressed.connect(func(): _start_world(world_i, false))
	ui.story_done.connect(_on_story_done)
	ui.toggle_pressed.connect(_on_toggle)
	ui.process_mode = Node.PROCESS_MODE_ALWAYS
	ui.pause_pressed.connect(_on_pause)
	ui.pause_action.connect(_on_pause_action)
	_load()
	audio.set_music(audio.music_on)
	ui.set_toggles(audio.music_on, audio.voice_on)
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--world="):
			world_i = int(a.substr(8))
	_build_world(world_i)
	hero.reset_at(Vector3(0, 0, 3))
	cam.global_position = hero.global_position + Vector3(0, 1.5, 0)
	ui.show_menu(unlocked > 0, LIST_NAME(unlocked))
	audio.music("menu", 0.5)
	if "--autotest" in args:
		autotest = true
		call_deferred("_start_world", world_i, false)

func LIST_NAME(i: int) -> String:
	return Worlds.LIST[clampi(i, 0, Worlds.LIST.size() - 1)].name

func _load() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE) == OK:
		unlocked = int(cf.get_value("p", "mundo", 0))
		audio.music_on = bool(cf.get_value("p", "musica", true))
		audio.voice_on = bool(cf.get_value("p", "voz", true))

func _save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("p", "mundo", unlocked)
	cf.set_value("p", "musica", audio.music_on)
	cf.set_value("p", "voz", audio.voice_on)
	cf.save(SAVE)

# ---------------- entorno ----------------
func _environment() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	var sky := Sky.new()
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = load("res://shaders/sky.gdshader")
	sky.sky_material = sky_mat
	sky.process_mode = Sky.PROCESS_MODE_QUALITY
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.06
	env.glow_hdr_threshold = 1.2
	env.fog_enabled = true
	env.fog_sky_affect = 0.25
	env.fog_height = 1.0
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.05
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_split_1 = 0.22
	sun.directional_shadow_max_distance = 26.0
	sun.directional_shadow_fade_start = 0.85
	sun.shadow_blur = 1.6
	sun.shadow_normal_bias = 1.2
	add_child(sun)

func _apply_env(w: Dictionary) -> void:
	sky_mat.set_shader_parameter("top_color", w.sky_top)
	sky_mat.set_shader_parameter("horizon_color", w.sky_hor)
	sky_mat.set_shader_parameter("ground_color", w.gnd)
	sky_mat.set_shader_parameter("cloud_cover", w.clouds)
	sky_mat.set_shader_parameter("cloud_color", w.cloud_col)
	sky_mat.set_shader_parameter("cloud_shade", w.cloud_shade)
	sky_mat.set_shader_parameter("hdri", load("res://assets/hdri/%s.hdr" % w.hdri))
	sky_mat.set_shader_parameter("hdri_tint", w.hdri_tint)
	env.ambient_light_energy = w.amb
	env.tonemap_exposure = w.exp
	env.fog_light_color = w.fog
	env.fog_density = w.fog_d
	env.fog_height_density = w.fog_h
	sun.light_color = w.sun
	sun.light_energy = w.sun_e
	var r: Vector3 = w.sun_rot
	sun.rotation = Vector3(deg_to_rad(r.x), deg_to_rad(r.y), 0)

func _build_world(i: int) -> void:
	for c in world_root.get_children():
		c.queue_free()
	fires.clear()
	world_i = i
	W = Worlds.LIST[i]
	_apply_env(W)
	Worlds.build(self, world_root, W.id)
	audio.ambience(W.id)

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
func _on_toggle(which: String) -> void:
	sfx("click")
	if which == "music":
		audio.set_music(not audio.music_on)
	else:
		audio.voice_on = not audio.voice_on
		if not audio.voice_on:
			audio.hush()
		else:
			audio.say("Narrador activado.")
	ui.set_toggles(audio.music_on, audio.voice_on)
	_save()

func _on_pause() -> void:
	if state != "play" and state != "boss":
		return
	sfx("click")
	get_tree().paused = true
	ui.show_pause(true)

func _on_pause_action(which: String) -> void:
	sfx("click")
	get_tree().paused = false
	ui.show_pause(false)
	match which:
		"restart":
			_clear_enemies()
			_start_world(world_i, false)
		"menu":
			_clear_enemies()
			hero.reset_at(Vector3(0, 0, 3))
			state = "menu"
			audio.music("menu")
			ui.show_menu(unlocked > 0, LIST_NAME(unlocked))

func _on_play() -> void:
	sfx("click")
	unlocked = 0
	_save()
	_story_for(0)

func _on_continue() -> void:
	sfx("click")
	_story_for(unlocked)

func _story_for(i: int) -> void:
	if i != world_i:
		_build_world(i)
	_clear_enemies()
	hero.reset_at(Vector3(0, 0, 3))
	state = "story"
	ui.show_story(W.intro_t, W.intro, "Luchar", "intro")
	audio.music("menu")
	audio.say(W.intro_t.get_slice("·", 1).strip_edges() + ". " + W.intro)

func _on_story_done(tag: String) -> void:
	sfx("click")
	audio.hush()
	if tag == "intro":
		_start_world(world_i, false)
	elif tag == "outro":
		if world_i + 1 < Worlds.LIST.size():
			_story_for(world_i + 1)
		else:
			state = "menu"
			ui.show_menu(true, LIST_NAME(unlocked))
			audio.music("menu")

func _clear_enemies() -> void:
	for e in enemies:
		e.queue_free()
	enemies.clear()
	tokens.clear()
	boss = null

func _start_world(i: int, rebuild: bool) -> void:
	if rebuild or i != world_i:
		_build_world(i)
	_clear_enemies()
	score = 0 if i == 0 else score
	wave = 0
	hero.reset_at(Vector3(0, 0, 3))
	cam.yaw = PI
	cam.cam.current = true
	cine = {}
	ui.hide_screens()
	ui.set_playing(true)
	state = "play"
	gap = 0.5
	audio.music(W.id, 1.0)
	if autotest:
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--wave="):
				wave = int(a.substr(7)) - 1
	_next_wave()

func _next_wave() -> void:
	wave += 1
	var waves: Array = W.waves
	if wave > waves.size():
		state = "won"
		unlocked = maxi(unlocked, mini(world_i + 1, Worlds.LIST.size() - 1))
		_save()
		ui.set_playing(false)
		audio.music("victoria", 0.6)
		await get_tree().create_timer(1.2).timeout
		ui.show_story("Victoria", W.outro, "Seguir" if world_i + 1 < Worlds.LIST.size() else "Menú", "outro")
		audio.say(W.outro)
		return
	to_spawn = waves[wave - 1].duplicate()
	spawn_t = 1.0
	if wave == waves.size():
		ui.set_banner("¡Jefe!")
	else:
		ui.set_banner("Oleada %d" % wave)
	if wave > 1:
		hero.hp = minf(hero.max_hp, hero.hp + 15)

func _spawn(k: String) -> void:
	var e: Enemy = Cerberus.new() if k == "cerb" else Enemy.new()
	e.game = self
	add_child(e)
	e.setup(k, W.lv + (wave - 1) * 0.05)
	var a := randf() * TAU
	var p := Vector3(cos(a), 0, sin(a)) * (AR - 2.0 if not e.boss else AR - 3.0)
	if p.distance_to(hero.global_position) < 7.0:
		p = -p
	e.global_position = p
	e.face = atan2(-p.x, -p.z)
	enemies.append(e)
	if e.boss:
		boss = e
		ui.boss_l.text = e.title
		cam.shake(0.4)
		audio.music("jefe", 1.0)
		get_tree().create_timer(1.0 if e.zombie else 0.3).timeout.connect(func(): _boss_intro(e))
	elif e.zombie:
		sfx_at("rise", e.global_position)

## Retrato del héroe en el menú y la historia: primer plano lento de su rostro.
func _portrait(dt: float) -> void:
	menu_t += dt
	var face := _head_pos(hero)
	var f := Vector3(sin(hero.face), 0, cos(hero.face))
	var r := Vector3(cos(hero.face), 0, -sin(hero.face))
	var sway := sin(menu_t * 0.25) * 0.55
	var dir := (f * cos(sway) + r * sin(sway)).normalized()
	cine_cam.fov = 32.0
	cine_light.light_energy = 0.9
	cine_light.omni_range = 4.0
	cine_cam.global_position = face + dir * 1.45 + Vector3(0, -0.05, 0)
	cine_cam.look_at(face + Vector3(0, -0.06, 0) - r * 0.18 * sin(sway))
	cine_cam.current = true

func _head_pos(n: Node) -> Vector3:
	if n is Cerberus:
		return n.heads[1].node.global_position
	var b: Body = n.body
	var i := b.skel.find_bone("Head")
	if i < 0:
		return n.global_position + Vector3(0, 1.6, 0)
	return (b.skel.global_transform * b.skel.get_bone_global_pose(i)).origin + Vector3(0, 0.08, 0) * b.scale.x

## Presentación del jefe: cámara lenta hacia su rostro, franjas de cine y su nombre.
func _boss_intro(e: Enemy) -> void:
	if not is_instance_valid(e) or e.st == "dead" or state != "play":
		return
	cine = {"t": 0.0, "dur": 3.0, "e": e}
	# el arma baja durante la presentación para no tapar el rostro
	if e.body and e.body.sword:
		cine["wrot"] = e.body.sword.rotation
		e.body.sword.rotation.x += 2.4
	ui.cine_mode(true, e.title)
	audio.say(e.title)
	sfx({"mino": "roar", "cerb": "growl", "ares": "roar", "gig": "roar"}.get(e.kind, "roar"))
	cine_cam.current = true

func _cine_tick(dt: float) -> void:
	cine.t += dt
	var e: Enemy = cine.e
	if not is_instance_valid(e) or cine.t >= cine.dur:
		if is_instance_valid(e) and e.body and e.body.sword and cine.has("wrot"):
			e.body.sword.rotation = cine.wrot
		cine = {}
		ui.cine_mode(false, "")
		cam.cam.current = true
		cine_light.light_energy = 0.0
		return
	var k: float = cine.t / cine.dur
	var sm := k * k * (3.0 - 2.0 * k)
	var face := _head_pos(e)
	var sc: float = e.sc
	var f := Vector3(sin(e.face), 0, cos(e.face))
	var r := Vector3(cos(e.face), 0, -sin(e.face))
	# plano contrapicado: desde abajo, para ver el rostro aunque el jefe incline la cabeza
	# lado opuesto al arma (mano derecha) para que no tape la cara
	var side := 1.0
	var p0 := face + f * 3.0 * sc - r * 1.0 * side * sc + Vector3(0, -0.95 * sc, 0)
	var p1 := face + f * 1.5 * sc - r * 0.5 * side * side * sc + Vector3(0, -0.7 * sc, 0)
	cine_light.light_energy = 2.6 if world_i != 1 and world_i != 2 else 4.5
	cine_light.omni_range = 6.0 * sc
	cine_cam.fov = lerpf(42.0, 34.0, sm)
	cine_cam.global_position = p0.lerp(p1, sm) + Vector3(sin(cine.t * 7.0), cos(cine.t * 5.0), 0) * 0.006
	cine_cam.look_at(face + Vector3(0, -0.04 * sc, 0))
	if autotest and cine.t > 1.6 and cine.t - dt <= 1.6:
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--shot="):
				get_viewport().get_texture().get_image().save_png(a.substr(7) + "_cine.png")
	if cine.t > 0.8 and cine.t - dt <= 0.8:
		cam.shake(0.3)
		Input.vibrate_handheld(40)

func summon(k: String, n: int) -> void:
	for i in range(n):
		to_spawn.append(k)
	spawn_t = 0.3

func _on_dead() -> void:
	state = "over"
	audio.music("derrota", 0.8)
	audio.say("Damón ha caído.")
	await get_tree().create_timer(1.6).timeout
	ui.show_over("Caíste en %s con %d puntos." % [W.name, score])

func _physics_process(dt: float) -> void:
	clock += dt
	for l in fires:
		if is_instance_valid(l):
			l.light_energy = float(l.get_meta("base", 2.5)) * (0.82 + 0.12 * sin(clock * 9.3 + l.global_position.x) + 0.08 * sin(clock * 23.7 + l.global_position.z))
	if state == "menu" or state == "story":
		cam.yaw += dt * 0.12
		cam.tick(dt, hero)
		hero.body.loco(0, false, true)
		_portrait(dt)
		return
	if not cine.is_empty():
		ui.read()
		_cine_tick(dt)
		return
	if cine_cam.current:
		cam.cam.current = true
		cine_light.light_energy = 0.0
	var inp := ui.read()
	if autotest:
		_bot(inp)
	cam.rotate_by(inp.cam.x, inp.cam.y)
	var sdt := dt
	if hitstop > 0.0:
		hitstop -= dt
		sdt = 0.0
	elif slowmo > 0.0:
		slowmo -= dt
		sdt = dt * 0.35
	if sdt > 0.0:
		hero.physics_tick(sdt, inp, cam.yaw)
		for e in enemies:
			e.tick(sdt, hero)
	cam.tick(dt, hero)
	_occlusion()
	if state == "play":
		spawn_t -= dt
		var alive := enemies.filter(func(q): return q.st != "dead").size()
		if spawn_t <= 0.0 and to_spawn.size() > 0 and alive < 5:
			_spawn(to_spawn.pop_front())
			spawn_t = 1.4
		for e in enemies.duplicate():
			if e.st == "dead" and e.st_t > 3.5:
				enemies.erase(e)
				if e.body and is_instance_valid(e.body.dropped):
					e.body.dropped.queue_free()
				e.queue_free()
		if to_spawn.is_empty() and enemies.is_empty():
			gap -= dt
			if gap <= 0.0:
				gap = 1.5
				_next_wave()
	var nw: int = W.waves.size()
	var wt: String = W.name + " · " + ("Jefe" if wave >= nw else "Oleada %d/%d" % [wave, nw - 1])
	ui.update_hud(hero, score, wt, boss if boss and boss.st != "dead" else null)
	ui.threats = _threats() if state == "play" else []

func _bot(inp: Dictionary) -> void:
	_frames += 1
	if "--runtest" in OS.get_cmdline_user_args():
		inp.move = Vector2(0, -1)
		inp.atk = false
		if _frames % 20 == 0:
			print("run f=", _frames, " v=", snappedf(hero.vel.length(), 0.01), " clip=", hero.body.cur, " st=", hero.st)
		return
	var tg := nearest_enemy(hero.global_position, 50.0)
	if tg:
		var d := tg.global_position - hero.global_position
		var yaw := cam.yaw
		var fwd := Vector3(sin(yaw), 0, cos(yaw))
		var rt := Vector3(-cos(yaw), 0, sin(yaw))
		var reach := 1.8 + tg.r
		if d.length() > reach:
			var dn := d.normalized()
			inp.move = Vector2(rt.dot(dn), -fwd.dot(dn))
		elif tg.st == "atk" and _frames % 3 == 0:
			inp.blk = true
		elif _frames % 8 == 0:
			inp.atk = true
		if hero.rage >= 100.0:
			inp.ira = true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot=") and _frames in [150, 420, 700]:
			get_viewport().get_texture().get_image().save_png(a.substr(7) + "_%d.png" % _frames)
	if _frames % 300 == 0:
		print("t=", _frames, " w=", W.id, " wave=", wave, " hp=", int(hero.hp), " en=", enemies.size(), " boss=", int(boss.hp) if boss else -1, " st=", state)

# ---------------- combate ----------------
func nearest_enemy(p: Vector3, maxd: float) -> Enemy:
	var best: Enemy = null
	var bd := maxd
	for e in enemies:
		if e.st == "dead" or e.st == "rise":
			continue
		var d: float = e.global_position.distance_to(p) - e.r
		if d < bd:
			bd = d
			best = e
	return best

## Tabla de sensaciones por tipo de impacto: congelado (hitstop), temblor, empujón de cámara, vibración.
const FEEL := {
	"light": {"stop": 0.045, "shake": 0.16, "kick": 0.10, "vib": 10},
	"heavy": {"stop": 0.085, "shake": 0.3, "kick": 0.2, "vib": 18},
	"final": {"stop": 0.11, "shake": 0.42, "kick": 0.28, "vib": 26},
	"ira": {"stop": 0.14, "shake": 0.9, "kick": 0.4, "vib": 60},
}

func hero_hit(h: Hero, c: Dictionary, final: bool) -> void:
	var f := Vector3(sin(h.face), 0, cos(h.face))
	var n := 0
	var blocked := 0
	var any_armor := false
	var last_p := Vector3.ZERO
	var last_dir := f
	for e in enemies:
		if e.st == "dead" or e.st == "rise":
			continue
		if c.has("finish") and e != h.lock_t:
			continue
		var to: Vector3 = e.global_position - h.global_position
		to.y = 0
		var d := to.length()
		if d > c.reach + e.r:
			continue
		if d > e.r + 0.35 and f.angle_to(to) > c.arc:
			continue
		var dir := to.normalized() if d > 0.01 else f
		var heavy: bool = final or c.get("heavy", false)
		# punto de contacto: en la superficie del enemigo, a la altura del pecho
		var hp_: Vector3 = e.global_position - dir * e.r * 0.8 + Vector3(0, 1.25 * e.sc, 0)
		if e.hurt(c.dmg, dir * c.kb, heavy, c):
			blocked += 1
			vfx.sparks(hp_, -dir, Color(1, 0.8, 0.45), heavy)
			continue
		n += 1
		last_p = hp_
		last_dir = dir
		var arm: bool = e.armored and randf() < 0.4
		any_armor = any_armor or arm
		if arm:
			vfx.sparks(hp_, -dir, Color(1, 0.75, 0.4))
		if e is Cerberus or e.kind == "som":
			vfx.flash(hp_, 0.5, Color(0.6, 0.9, 1.0) if e.kind == "som" else Color(1, 0.5, 0.2))
		if e.kind != "som":
			vfx.blood(hp_, dir, heavy)
			if c.has("finish"):
				vfx.blood(hp_ + Vector3(0, 0.15, 0), dir.rotated(Vector3.UP, 0.4), true)
				vfx.blood(hp_ - Vector3(0, 0.2, 0), -dir, true)
		else:
			vfx.dust(e.global_position)
	if n > 0:
		var kind := "ira" if c.has("ira") else ("final" if final else ("heavy" if c.get("heavy", false) else "light"))
		var fe: Dictionary = FEEL[kind]
		hitstop = fe.stop
		cam.shake(fe.shake)
		cam.kick(last_dir, fe.kick)
		if kind == "final" or kind == "heavy":
			cam.punch(-2.5)
		vfx.flash(last_p, 0.45 if kind == "light" else 0.75)
		vfx.light(last_p, Color(1, 0.7, 0.45), 1.5, 0.08)
		# sonido en capas: carne + golpe grave + metal si había armadura
		audio.play("flesh", 0.0, 0.1)
		audio.play("hit", 0.0, 0.08, -4.0)
		if kind != "light":
			audio.play("sub", 0.0, 0.05)
		if any_armor:
			audio.play("armor", 0.0, 0.1)
		h.rage = minf(100.0, h.rage + 4.0 * n)
		Input.vibrate_handheld(fe.vib)
	elif blocked > 0:
		hitstop = 0.05
		cam.shake(0.14)
		cam.kick(-f, 0.12)
		audio.play("clang", 0.0, 0.1)
		Input.vibrate_handheld(8)

## Remate: cámara lenta, acercamiento y golpe seco
func on_finish_start(h: Hero, e: Enemy) -> void:
	slowmo = 0.55
	cam.punch(-6.0)
	sfx("rise")
	if e.st != "stun" and e.st != "down":
		e.st = "stun"
		e.st_t = 0.0
	get_tree().create_timer(0.32).timeout.connect(func():
		cam.shake(0.45)
		audio.play("boom", 0.0, 0.05, -2.0)
		audio.play("sub", 0.0, 0.05)
		ui.screen_flash(Color(0.6, 0.05, 0.02), 0.35)
		score += 150)

func on_ira(h: Hero) -> void:
	slowmo = 0.5
	cam.shake(0.25)
	cam.punch(-4.0)
	sfx("ira")
	vfx.light(h.global_position + Vector3(0, 1.5, 0), Color(1, 0.5, 0.15), 3.0, 0.5)
	get_tree().create_timer(0.45).timeout.connect(func():
		_ring(h.global_position, 4.8, Color(1.0, 0.42, 0.1))
		vfx.scorch(h.global_position, 6.5)
		for k in range(8):
			var a := k / 8.0 * TAU
			vfx.dust(h.global_position + Vector3(cos(a), 0, sin(a)) * 3.0, true)
		cam.shake(FEEL.ira.shake)
		cam.punch(9.0)
		Input.vibrate_handheld(FEEL.ira.vib))

func on_parry(h: Hero, src: Node, dn := Vector3.ZERO) -> void:
	var fw := Vector3(sin(h.face), 0, cos(h.face))
	var p := h.global_position + Vector3(0, 1.3, 0) + fw * 0.55
	hitstop = 0.14
	slowmo = 0.45
	cam.shake(0.22)
	cam.kick(-fw, 0.22)
	cam.punch(-6.0)
	vfx.sparks(p, fw, Color(1.0, 0.92, 0.7), true)
	vfx.flash(p, 1.1, Color(1.0, 0.95, 0.8))
	vfx.light(p, Color(1, 0.9, 0.7), 6.0, 0.25)
	ui.screen_flash(Color(1, 0.95, 0.85), 0.16)
	Input.vibrate_handheld(25)
	if src and src.has_method("parried"):
		src.parried()
	audio.play("parry", 0.0, 0.04)
	audio.play("sub", 0.0, 0.05, -3.0)

func on_block(h: Hero, dn := Vector3.ZERO) -> void:
	var fw := Vector3(sin(h.face), 0, cos(h.face))
	var p := h.global_position + Vector3(0, 1.25, 0) + fw * 0.5
	vfx.sparks(p, fw, Color(1, 0.72, 0.35))
	vfx.dust(h.global_position)
	cam.shake(0.14)
	cam.kick(dn, 0.14)
	hitstop = 0.05
	Input.vibrate_handheld(10)
	audio.play("clang", 0.0, 0.1)
	audio.play("step", 0.0, 0.1, 2.0, 0.7)

func on_guard_break(h: Hero) -> void:
	cam.shake(0.45)
	cam.punch(-3.0)
	sfx("guard_break")
	audio.play("sub", 0.0, 0.05)
	vfx.sparks(h.global_position + Vector3(0, 1.2, 0), Vector3(sin(h.face), 0, cos(h.face)), Color(1, 0.55, 0.3), true)
	ui.screen_flash(Color(0.6, 0.15, 0.05), 0.2)

func telegraph(_e: Node) -> void:
	sfx("warn")

func on_boss_phase(e: Enemy) -> void:
	cam.shake(0.6)
	match e.kind:
		"ares":
			ui.set_banner("Ares se enfurece")
			audio.say("Ares se enfurece y llama a su guardia.")
			summon("hop", 2)
		"mino":
			ui.set_banner("Asterión brama")
			sfx("roar")
		"cerb":
			ui.set_banner("Cerbero arde")
			sfx("growl")
		_:
			pass

func shockwave(p: Vector3, radius: float, dmg: float, unbl: bool, src: Node) -> void:
	_ring(p, radius, Color(1.0, 0.55, 0.2) if not unbl else Color(1.0, 0.25, 0.08))
	sfx("boom")
	vfx.scorch(p, radius * 0.9)
	for k in range(6):
		var a := k / 6.0 * TAU
		vfx.dust(p + Vector3(cos(a), 0, sin(a)) * radius * 0.6, true)
	var dk := hero.global_position - p
	dk.y = 0
	if dk.length() < radius * 3.0:
		cam.kick(dk.normalized() if dk.length() > 0.01 else Vector3.FORWARD, 0.3)
	cam.shake(0.6)
	var d := hero.global_position - p
	d.y = 0
	if d.length() < radius:
		hero.take_hit(dmg * (1.0 - d.length() / radius * 0.4), p, src, unbl)

func on_enemy_dead(e: Enemy) -> void:
	score += 1000 if e.boss else 100
	sfx_at("death", e.global_position)
	if not e.boss:
		hero.hp = minf(hero.max_hp, hero.hp + 4.0)
	if e == boss:
		boss = null
		slowmo = 1.2
		cam.shake(0.8)
		for o in enemies:
			if o != e and o.st != "dead":
				o.hurt(9999.0, Vector3.ZERO, true)
		to_spawn.clear()

func on_hero_hurt() -> void:
	sfx("hurt")
	ui.hurt_flash()
	cam.shake(0.5)
	Input.vibrate_handheld(30)
	vfx.blood(hero.global_position + Vector3(0, 1.3, 0), Vector3(randf() - 0.5, 0.3, randf() - 0.5))
	audio.play("flesh", 0.0, 0.1, -3.0)

func take_token(e: Enemy) -> bool:
	tokens = tokens.filter(func(q): return is_instance_valid(q) and q.st == "atk")
	if tokens.size() >= 2:
		return false
	tokens.append(e)
	return true

func release_token(e: Enemy) -> void:
	tokens.erase(e)

# ---------------- efectos ----------------
func _ring(p: Vector3, radius: float, col: Color) -> void:
	var t := TorusMesh.new()
	t.inner_radius = 0.93
	t.outer_radius = 1.0
	t.rings = 48
	t.ring_segments = 6
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(col.r * 2.0, col.g * 1.6, col.b * 1.4, 0.55)
	var mi := MeshInstance3D.new()
	mi.mesh = t
	mi.material_override = m
	mi.position = p + Vector3(0, 0.15, 0)
	mi.scale = Vector3(0.3, 0.3, 0.3)
	add_child(mi)
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = 6.0
	l.omni_range = radius * 1.6
	l.position = p + Vector3(0, 1.0, 0)
	add_child(l)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(radius, 1.5, radius), 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.45)
	tw.tween_property(l, "light_energy", 0.0, 0.5)
	tw.chain().tween_callback(func():
		mi.queue_free()
		l.queue_free())
	# anillo de fuego que se levanta del suelo
	var fire := CPUParticles3D.new()
	fire.one_shot = true
	fire.emitting = true
	fire.amount = 70
	fire.lifetime = 0.55
	fire.explosiveness = 0.85
	fire.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	fire.emission_ring_axis = Vector3.UP
	fire.emission_ring_radius = radius * 0.75
	fire.emission_ring_inner_radius = radius * 0.55
	fire.emission_ring_height = 0.05
	fire.direction = Vector3.UP
	fire.spread = 15.0
	fire.initial_velocity_min = 1.5
	fire.initial_velocity_max = 3.5
	fire.gravity = Vector3(0, 2, 0)
	fire.scale_amount_min = 1.5
	fire.scale_amount_max = 3.0
	var fg := Gradient.new()
	fg.set_color(0, Color(1, 0.85, 0.5, 0.9))
	fg.add_point(0.4, Color(col.r, col.g * 0.8, col.b * 0.5, 0.7))
	fg.set_color(fg.get_point_count() - 1, Color(0.2, 0.08, 0.05, 0))
	fire.color_ramp = fg
	var fq := QuadMesh.new()
	fq.size = Vector2(0.5, 0.7)
	var fmat := StandardMaterial3D.new()
	fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fmat.vertex_color_use_as_albedo = true
	fmat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	fmat.albedo_texture = _glow_tex()
	fq.material = fmat
	fire.mesh = fq
	fire.position = p + Vector3(0, 0.1, 0)
	add_child(fire)
	get_tree().create_timer(1.0).timeout.connect(fire.queue_free)
	var dust := CPUParticles3D.new()
	dust.one_shot = true
	dust.emitting = true
	dust.amount = 30
	dust.lifetime = 0.9
	dust.explosiveness = 1.0
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	dust.emission_ring_axis = Vector3.UP
	dust.emission_ring_radius = radius * 0.5
	dust.emission_ring_inner_radius = 0.2
	dust.emission_ring_height = 0.1
	dust.direction = Vector3.UP
	dust.spread = 60.0
	dust.initial_velocity_min = 1.0
	dust.initial_velocity_max = 3.0
	dust.gravity = Vector3(0, -3, 0)
	dust.scale_amount_min = 2.0
	dust.scale_amount_max = 4.0
	var q := QuadMesh.new()
	q.size = Vector2(0.4, 0.4)
	var dm := StandardMaterial3D.new()
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	dm.albedo_texture = _glow_tex()
	dm.albedo_color = Color(0.6, 0.52, 0.45, 0.35)
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	q.material = dm
	dust.mesh = q
	dust.position = p + Vector3(0, 0.2, 0)
	add_child(dust)
	get_tree().create_timer(1.3).timeout.connect(dust.queue_free)

func sparks(p: Vector3, col: Color, n := 16) -> void:
	var ps := CPUParticles3D.new()
	ps.one_shot = true
	ps.emitting = true
	ps.amount = n
	ps.lifetime = 0.35
	ps.explosiveness = 1.0
	ps.direction = Vector3.UP
	ps.spread = 180.0
	ps.initial_velocity_min = 3.0
	ps.initial_velocity_max = 7.0
	ps.gravity = Vector3(0, -14, 0)
	ps.scale_amount_min = 0.6
	ps.scale_amount_max = 1.2
	var bm := BoxMesh.new()
	bm.size = Vector3(0.012, 0.012, 0.09)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = 5.0
	bm.material = m
	ps.mesh = bm
	ps.particle_flag_align_y = true
	ps.position = p
	add_child(ps)
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = 3.0
	l.omni_range = 3.0
	l.position = p
	add_child(l)
	create_tween().tween_property(l, "light_energy", 0.0, 0.18)
	get_tree().create_timer(0.6).timeout.connect(func():
		ps.queue_free()
		l.queue_free())

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

func sfx(n: String) -> void:
	audio.play(n)

func sfx_at(n: String, p: Vector3) -> void:
	audio.play(n, p.distance_to(hero.global_position))

## Enemigos fuera de la vista (detrás o a los lados): dirección en pantalla y si están atacando.
func _threats() -> Array:
	var out: Array = []
	var c := cam.cam
	var vp := get_viewport().get_visible_rect().size
	var cb := c.global_transform.basis
	for e in enemies:
		if e.st == "dead" or e.st == "rise":
			continue
		var p: Vector3 = e.global_position + Vector3(0, 1.0 * e.sc, 0)
		var on_screen := false
		if not c.is_position_behind(p):
			var sp := c.unproject_position(p)
			on_screen = sp.x > vp.x * 0.04 and sp.x < vp.x * 0.96 and sp.y > vp.y * 0.06 and sp.y < vp.y * 0.94
		if on_screen:
			continue
		var rel := cb.inverse() * (p - c.global_position)
		var ang := atan2(rel.x, -rel.z)  # 0 = al frente, ±PI = detrás
		var d: float = e.global_position.distance_to(hero.global_position)
		var lvl := 0
		if e.st == "atk":
			lvl = 2 if A_unbl(e) else 1
		out.append({"a": ang, "d": d, "lvl": lvl})
	return out

func A_unbl(e: Enemy) -> bool:
	return e.A.get("unbl", false) or (e is Cerberus and e.mode in ["fire", "pounce"])

## Vuelve translúcido a quien se interpone entre la cámara y Damón.
func _occlusion() -> void:
	var cp := cam.cam.global_position
	var hp := hero.global_position + Vector3(0, 1.2, 0)
	var seg := hp - cp
	var L := seg.length()
	for e in enemies:
		if e.st == "dead" and e.st_t > 2.3:
			continue
		var c: Vector3 = e.global_position + Vector3(0, 1.0 * e.sc, 0)
		var t := clampf((c - cp).dot(seg) / maxf(L * L, 0.001), 0.0, 1.0)
		var d := (cp + seg * t).distance_to(c)
		var near := cp.distance_to(c)
		var f := 0.0
		if e.st != "dead" and t < 0.92 and d < 0.75 * maxf(e.sc, 1.0) + e.r * 0.5:
			f = 0.65
		if near < 1.6 * e.sc:
			f = maxf(f, 0.8)
		e.set_fade(f)

func _notification(what: int) -> void:
	# botón atrás de Android o salir de la app: pausar en vez de cerrar
	if what == NOTIFICATION_WM_GO_BACK_REQUEST or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if state == "play" and not get_tree().paused:
			_on_pause()
		elif what == NOTIFICATION_WM_GO_BACK_REQUEST and state == "menu":
			get_tree().quit()
