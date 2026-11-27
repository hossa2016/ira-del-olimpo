class_name Vfx
extends Node3D
## Efectos de impacto con pools reutilizables (sin crear nodos en cada golpe, para el rendimiento móvil):
## chispas, sangre, polvo, destello, luz de impacto y manchas en el suelo (decals).

const POOL := 6
const MAX_DECALS := 28

var game: Node
var _sparks: Array = []
var _blood: Array = []
var _dust: Array = []
var _flash: Array = []
var _lights: Array = []
var _decals: Array = []
var _i := {"sparks": 0, "blood": 0, "dust": 0, "flash": 0, "light": 0, "decal": 0}
var _blood_tex: Texture2D
var _scorch_tex: Texture2D

func setup(g: Node) -> void:
	game = g
	_blood_tex = _splat_tex(Color(0.33, 0.02, 0.01), 7)
	_scorch_tex = _splat_tex(Color(0.05, 0.03, 0.02), 11, true)
	for k in range(POOL):
		_sparks.append(_make_sparks())
		_blood.append(_make_blood())
		_dust.append(_make_dust())
		_flash.append(_make_flash())
	for k in range(3):
		var l := OmniLight3D.new()
		l.light_energy = 0.0
		l.omni_range = 4.0
		l.shadow_enabled = false
		add_child(l)
		_lights.append(l)

func _next(key: String, arr: Array):
	var n: int = _i[key]
	_i[key] = (n + 1) % arr.size()
	return arr[n]

# ---------------- construcción ----------------
func _mat_add(col: Color, tex: Texture2D = null) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.vertex_color_use_as_albedo = true
	m.albedo_color = col
	if tex:
		m.albedo_texture = tex
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	return m

func _make_sparks() -> CPUParticles3D:
	var ps := CPUParticles3D.new()
	ps.one_shot = true
	ps.emitting = false
	ps.amount = 22
	ps.lifetime = 0.4
	ps.explosiveness = 1.0
	ps.spread = 70.0
	ps.initial_velocity_min = 4.0
	ps.initial_velocity_max = 9.0
	ps.gravity = Vector3(0, -16, 0)
	ps.damping_min = 2.0
	ps.damping_max = 4.0
	ps.scale_amount_min = 0.5
	ps.scale_amount_max = 1.2
	ps.particle_flag_align_y = true
	var bm := BoxMesh.new()
	bm.size = Vector3(0.01, 0.11, 0.01)
	bm.material = _mat_add(Color(4.0, 2.6, 1.2))
	ps.mesh = bm
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 0.4, 0.1, 0))
	ps.color_ramp = g
	add_child(ps)
	return ps

func _make_blood() -> CPUParticles3D:
	var ps := CPUParticles3D.new()
	ps.one_shot = true
	ps.emitting = false
	ps.amount = 26
	ps.lifetime = 0.55
	ps.explosiveness = 0.95
	ps.spread = 28.0
	ps.initial_velocity_min = 3.0
	ps.initial_velocity_max = 6.5
	ps.gravity = Vector3(0, -14, 0)
	ps.scale_amount_min = 0.4
	ps.scale_amount_max = 1.1
	ps.particle_flag_align_y = true
	var sm := SphereMesh.new()
	sm.radius = 0.012
	sm.height = 0.05
	sm.radial_segments = 6
	sm.rings = 3
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.42, 0.015, 0.01)
	m.roughness = 0.15
	m.metallic_specular = 0.8
	sm.material = m
	ps.mesh = sm
	add_child(ps)
	return ps

func _make_dust() -> CPUParticles3D:
	var ps := CPUParticles3D.new()
	ps.one_shot = true
	ps.emitting = false
	ps.amount = 14
	ps.lifetime = 0.9
	ps.explosiveness = 0.9
	ps.direction = Vector3.UP
	ps.spread = 80.0
	ps.initial_velocity_min = 0.6
	ps.initial_velocity_max = 1.8
	ps.gravity = Vector3(0, -0.6, 0)
	ps.damping_min = 1.5
	ps.damping_max = 2.5
	ps.scale_amount_min = 1.0
	ps.scale_amount_max = 2.2
	var c := Curve.new()
	c.add_point(Vector2(0, 0.4))
	c.add_point(Vector2(1, 1.6))
	ps.scale_amount_curve = c
	var q := QuadMesh.new()
	q.size = Vector2(0.3, 0.3)
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = game._glow_tex()
	q.material = m
	ps.mesh = q
	var g := Gradient.new()
	g.set_color(0, Color(0.55, 0.45, 0.35, 0.22))
	g.set_color(1, Color(0.55, 0.45, 0.35, 0.0))
	ps.color_ramp = g
	add_child(ps)
	return ps

func _make_flash() -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	var m := _mat_add(Color(3.0, 2.4, 1.6, 1.0))
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_texture = _star_tex()
	m.no_depth_test = true
	q.material = m
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.visible = false
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi

func _star_tex() -> Texture2D:
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in range(n):
		for x in range(n):
			var d := Vector2(x - n / 2.0, y - n / 2.0) / (n / 2.0)
			var r := d.length()
			var core := clampf(1.0 - r * 2.2, 0, 1)
			var rays := pow(clampf(1.0 - absf(d.x * d.y) * 40.0, 0, 1), 3.0) * clampf(1.0 - r, 0, 1)
			var a := clampf(core + rays * 0.8, 0, 1)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)

func _splat_tex(col: Color, seed_i: int, soft := false) -> Texture2D:
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rnd := RandomNumberGenerator.new()
	rnd.seed = seed_i
	var blobs: Array = [[Vector2(64, 64), 26.0]]
	for k in range(22):
		var a := rnd.randf() * TAU
		var dist := rnd.randf_range(12, 56)
		blobs.append([Vector2(64, 64) + Vector2(cos(a), sin(a)) * dist, rnd.randf_range(2.5, 10.0) * (1.0 - dist / 80.0) + 1.5])
	for y in range(n):
		for x in range(n):
			var p := Vector2(x, y)
			var a := 0.0
			for b in blobs:
				var d: float = p.distance_to(b[0]) / b[1]
				a = maxf(a, clampf((1.0 - d) * (2.0 if not soft else 0.9), 0, 1))
			if a > 0.0:
				img.set_pixel(x, y, Color(col.r, col.g, col.b, a * (0.92 if not soft else 0.75)))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

# ---------------- uso ----------------
func sparks(p: Vector3, dir: Vector3, col := Color(1, 0.75, 0.4), big := false) -> void:
	var ps: CPUParticles3D = _next("sparks", _sparks)
	ps.global_position = p
	ps.direction = (dir + Vector3.UP * 0.4).normalized()
	ps.amount = 34 if big else 18
	ps.spread = 90.0 if big else 60.0
	(ps.mesh.material as StandardMaterial3D).albedo_color = Color(col.r * 4.0, col.g * 3.4, col.b * 3.0)
	ps.restart()
	ps.emitting = true
	light(p, col, 4.0 if big else 2.2, 0.12)
	flash(p, 0.55 if big else 0.32, col)

func blood(p: Vector3, dir: Vector3, heavy := false) -> void:
	var ps: CPUParticles3D = _next("blood", _blood)
	ps.global_position = p
	ps.direction = (dir + Vector3.UP * 0.35).normalized()
	ps.amount = 34 if heavy else 20
	ps.restart()
	ps.emitting = true
	# mancha en el suelo donde cae la sangre
	var land := p + dir.normalized() * randf_range(0.6, 1.3)
	land.y = 0.0
	decal(land, randf_range(0.5, 0.9) * (1.3 if heavy else 1.0), _blood_tex, 14.0)

func dust(p: Vector3, big := false) -> void:
	var ps: CPUParticles3D = _next("dust", _dust)
	ps.global_position = Vector3(p.x, 0.15, p.z)
	ps.amount = 22 if big else 10
	ps.initial_velocity_max = 3.0 if big else 1.6
	ps.restart()
	ps.emitting = true

func flash(p: Vector3, size: float, col := Color(1, 0.85, 0.6)) -> void:
	var f: MeshInstance3D = _next("flash", _flash)
	f.global_position = p
	f.visible = true
	f.scale = Vector3.ONE * size * 0.3
	f.rotation.z = randf() * TAU
	var m: StandardMaterial3D = f.mesh.material
	m.albedo_color = Color(col.r * 3.0, col.g * 3.0, col.b * 3.0, 1.0)
	var tw := f.create_tween()
	tw.tween_property(f, "scale", Vector3.ONE * size, 0.05)
	tw.tween_property(f, "scale", Vector3.ONE * size * 0.1, 0.07)
	tw.tween_callback(func(): f.visible = false)

func light(p: Vector3, col: Color, energy: float, dur: float) -> void:
	var l: OmniLight3D = _next("light", _lights)
	l.global_position = p
	l.light_color = col
	l.light_energy = energy
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, dur)

func decal(p: Vector3, size: float, tex: Texture2D, life: float) -> void:
	var d: Decal
	if _decals.size() < MAX_DECALS:
		d = Decal.new()
		d.cull_mask = 1
		add_child(d)
		_decals.append(d)
	else:
		d = _next("decal", _decals)
	d.texture_albedo = tex
	d.size = Vector3(size, 0.6, size)
	d.global_position = p
	d.rotation.y = randf() * TAU
	d.albedo_mix = 1.0
	d.modulate = Color(1, 1, 1, 1)
	d.visible = true
	var tw := d.create_tween()
	tw.tween_interval(life)
	tw.tween_property(d, "modulate:a", 0.0, 2.5)

func scorch(p: Vector3, size: float) -> void:
	decal(Vector3(p.x, 0.0, p.z), size, _scorch_tex, 10.0)
