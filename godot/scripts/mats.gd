class_name Mats
## Materiales compartidos (PBR).

static var _c := {}

static func get_m(key: String) -> Material:
	if _c.has(key):
		return _c[key]
	var m := StandardMaterial3D.new()
	match key:
		"bronze":
			m.albedo_color = Color(0.72, 0.5, 0.26); m.metallic = 1.0; m.roughness = 0.36
		"dark_bronze":
			m.albedo_color = Color(0.36, 0.28, 0.2); m.metallic = 0.9; m.roughness = 0.35
		"patina":
			m.albedo_color = Color(0.37, 0.4, 0.27); m.metallic = 0.75; m.roughness = 0.55
		"steel":
			m.albedo_color = Color(0.86, 0.85, 0.8); m.metallic = 1.0; m.roughness = 0.2
		"cloth":
			m.albedo_color = Color(0.48, 0.1, 0.07); m.roughness = 0.9; m.cull_mode = BaseMaterial3D.CULL_DISABLED
		"leather":
			m.albedo_color = Color(0.29, 0.17, 0.1); m.roughness = 0.75
		"wood":
			m.albedo_color = Color(0.36, 0.23, 0.13); m.roughness = 0.8
		"black":
			m.albedo_color = Color(0.03, 0.02, 0.02); m.roughness = 1.0
		"glow_red":
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; m.albedo_color = Color(1, 0.2, 0.05)
			m.emission_enabled = true; m.emission = Color(1, 0.15, 0.03); m.emission_energy_multiplier = 6.0
		"eye":
			m.albedo_texture = load("res://assets/tex/eye.jpg"); m.roughness = 0.15
		"brow":
			m.albedo_color = Color(0.16, 0.1, 0.07); m.roughness = 0.9
		"beard":
			m.albedo_color = Color(0.12, 0.08, 0.05); m.roughness = 0.9
		"gold":
			m.albedo_color = Color(0.95, 0.7, 0.32); m.metallic = 1.0; m.roughness = 0.24
		"horse":
			m.albedo_color = Color(0.62, 0.07, 0.04); m.roughness = 0.9; m.cull_mode = BaseMaterial3D.CULL_DISABLED
			m.albedo_texture = load("res://assets/tex/hair_c.jpg")
			m.normal_enabled = true; m.normal_texture = load("res://assets/tex/hair_n.jpg"); m.normal_scale = 0.8
			m.rim_enabled = true; m.rim = 0.4; m.rim_tint = 0.3
		"helm_bronze":
			m.albedo_color = Color(0.7, 0.48, 0.25); m.metallic = 1.0; m.roughness = 0.34; m.cull_mode = BaseMaterial3D.CULL_DISABLED
		"helm_patina":
			m.albedo_color = Color(0.35, 0.39, 0.27); m.metallic = 0.75; m.roughness = 0.55; m.cull_mode = BaseMaterial3D.CULL_DISABLED
		"helm_gold":
			m.albedo_color = Color(0.95, 0.7, 0.32); m.metallic = 1.0; m.roughness = 0.22; m.cull_mode = BaseMaterial3D.CULL_DISABLED
		"helm_dark":
			m.albedo_color = Color(0.16, 0.14, 0.13); m.metallic = 0.9; m.roughness = 0.4; m.cull_mode = BaseMaterial3D.CULL_DISABLED
		"glow_cyan":
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; m.albedo_color = Color(0.4, 1, 0.9)
			m.emission_enabled = true; m.emission = Color(0.3, 1, 0.85); m.emission_energy_multiplier = 6.0
		"glow_fire":
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; m.albedo_color = Color(1, 0.6, 0.15)
			m.emission_enabled = true; m.emission = Color(1, 0.45, 0.08); m.emission_energy_multiplier = 8.0
		"ivory":
			m.albedo_color = Color(0.83, 0.77, 0.64); m.roughness = 0.45
		"fur":
			m.albedo_texture = load("res://assets/tex/fur_c.jpg"); m.albedo_color = Color(0.55, 0.45, 0.42)
			m.normal_enabled = true; m.normal_texture = load("res://assets/tex/fur_n.jpg"); m.roughness = 0.95
			m.uv1_triplanar = true; m.uv1_scale = Vector3.ONE * 1.6
		"fur_bull":
			m.albedo_texture = load("res://assets/tex/fur_c.jpg"); m.albedo_color = Color(0.85, 0.62, 0.48)
			m.normal_enabled = true; m.normal_texture = load("res://assets/tex/fur_n.jpg"); m.roughness = 0.9
			m.uv1_triplanar = true; m.uv1_scale = Vector3.ONE * 3.0
		"chiton":
			m.albedo_color = Color(0.4, 0.07, 0.05); m.roughness = 0.95
		"rag":
			m.albedo_color = Color(0.24, 0.18, 0.13); m.roughness = 1.0; m.cull_mode = BaseMaterial3D.CULL_DISABLED
			m.albedo_texture = load("res://assets/tex/fur_c.jpg"); m.uv1_triplanar = true; m.uv1_scale = Vector3.ONE * 4.0
		"linen":
			m.albedo_color = Color(0.66, 0.58, 0.45); m.roughness = 0.95
		"gums":
			m.albedo_color = Color(0.35, 0.06, 0.06); m.roughness = 0.35
	if key in ["bronze", "dark_bronze", "patina", "gold", "steel", "helm_bronze", "helm_patina", "helm_gold", "helm_dark"]:
		_hammered(m, key)
	_c[key] = m
	return m

## Metal con textura martillada: hoyuelos, rayas y pátina (rompe el aspecto de plástico liso).
static func _hammered(m: StandardMaterial3D, key: String) -> void:
	m.albedo_texture = load("res://assets/tex/bronze_c.jpg")
	m.normal_enabled = true
	m.normal_texture = load("res://assets/tex/bronze_n.jpg")
	m.normal_scale = 0.5 if key == "steel" else 0.9
	m.roughness_texture = load("res://assets/tex/bronze_r.jpg")
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	m.roughness = clampf(m.roughness * 2.2, 0.4, 1.0)
	m.uv1_triplanar = true
	m.uv1_scale = Vector3.ONE * (5.0 if key == "steel" else 3.5)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC

## Escudo pintado: bronce con meandro y emblema, proyectado de frente sobre el cuenco.
static func shield(tex: String, r: float) -> StandardMaterial3D:
	var key := "shield_%s_%.2f" % [tex, r]
	if _c.has(key):
		return _c[key]
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/tex/shield_%s.jpg" % tex)
	m.metallic = 0.85
	m.roughness = 0.75
	m.roughness_texture = load("res://assets/tex/bronze_r.jpg")
	m.normal_enabled = true
	m.normal_texture = load("res://assets/tex/bronze_n.jpg")
	m.normal_scale = 0.6
	_c[key] = m
	return m

static func skin(tint: Color, tex := "c") -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/tex/body_%s.jpg" % tex)
	m.albedo_color = tint
	m.normal_enabled = true
	m.normal_texture = load("res://assets/tex/body_n.jpg")
	m.roughness_texture = load("res://assets/tex/body_r.jpg")
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	m.roughness = 1.0
	# luz de contorno y luz que atraviesa la piel: separa al personaje del fondo
	m.rim_enabled = true
	m.rim = 0.35
	m.rim_tint = 0.65
	m.backlight_enabled = true
	m.backlight = Color(0.22, 0.07, 0.04)
	return m
