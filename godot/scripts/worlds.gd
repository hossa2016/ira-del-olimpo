class_name Worlds
## Los cuatro mundos: datos de historia, oleadas, luz y construcción de cada arena.

const AR := 15.0

const LIST := [
	{
		"id": "tebas", "name": "Tebas", "boss": "gig", "lv": 1.0,
		"waves": [["esp", "esp"], ["esp", "esp", "esp"], ["esp", "esp", "esp", "esp"], ["gig", "esp", "esp"]],
		"intro_t": "I · Tebas",
		"intro": "Tebas, al amanecer. Los Espartos, guerreros nacidos de dientes de dragón, brotan de la tierra del templo. Damón, hoplita sin dios, empuña su xiphos.\n\nGolpe encadena 3 cortes. Mantén Escudo para bloquear y púlsalo justo antes del impacto para una parada perfecta. Esquivar y luego Golpe: estocada. Con la Ira llena, desata su poder.",
		"outro": "El gigante cae y la tierra calla. Entre sus restos brilla un hilo rojo: el hilo de Ariadna. Señala al sur, hacia Creta.",
		"sky_top": Color(0.3, 0.45, 0.66), "sky_hor": Color(0.93, 0.72, 0.55), "gnd": Color(0.22, 0.3, 0.38),
		"sun": Color(1.0, 0.84, 0.66), "sun_e": 1.7, "sun_rot": Vector3(-32, -145, 0), "amb": 0.7, "exp": 0.9,
		"fog": Color(0.9, 0.72, 0.56), "fog_d": 0.0045, "fog_h": 0.06,
	},
	{
		"id": "laberinto", "name": "Laberinto de Creta", "boss": "mino", "lv": 1.1,
		"waves": [["lab", "lab", "esp"], ["lab", "lab", "lab", "esp"], ["lab", "lab", "lab", "lab"], ["mino", "lab"]],
		"intro_t": "II · El Laberinto",
		"intro": "Creta. Pasillos que se cierran a tu espalda y antorchas que nunca se apagan. Los guardias de Minos, muertos hace siglos, todavía vigilan.\n\nEn el corazón espera Asterión, el Minotauro. Cuando su cuerpo brille en rojo, su embestida no se puede bloquear: esquiva.",
		"outro": "Asterión se desploma. La sangre del toro abre una grieta en el suelo que desciende hacia el reino de Hades.",
		"sky_top": Color(0.05, 0.05, 0.09), "sky_hor": Color(0.34, 0.17, 0.1), "gnd": Color(0.05, 0.04, 0.04),
		"sun": Color(0.8, 0.66, 0.85), "sun_e": 0.85, "sun_rot": Vector3(-55, 30, 0), "amb": 0.55, "exp": 1.1,
		"fog": Color(0.3, 0.16, 0.1), "fog_d": 0.012, "fog_h": 0.12,
	},
	{
		"id": "inframundo", "name": "Inframundo", "boss": "cerb", "lv": 1.2,
		"waves": [["som", "som", "som"], ["som", "som", "som", "esp"], ["som", "som", "som", "som", "som"], ["cerb"]],
		"intro_t": "III · El Inframundo",
		"intro": "Bajo la tierra fluye el Estigia, verde como el veneno. Las Sombras de los caídos son rápidas y no sienten dolor.\n\nCerbero guarda la salida. Su aliento de fuego atraviesa cualquier escudo: rueda fuera del cono.",
		"outro": "Las tres cabezas aúllan por última vez. Hades, en silencio, te deja pasar. Arriba, el Olimpo ya conoce tu nombre: fue Ares quien quemó tu ciudad.",
		"sky_top": Color(0.04, 0.06, 0.09), "sky_hor": Color(0.12, 0.32, 0.3), "gnd": Color(0.02, 0.05, 0.05),
		"sun": Color(0.6, 0.9, 0.85), "sun_e": 1.25, "sun_rot": Vector3(-60, 80, 0), "amb": 0.75, "exp": 1.25,
		"fog": Color(0.1, 0.3, 0.27), "fog_d": 0.016, "fog_h": 0.12,
	},
	{
		"id": "olimpo", "name": "Olimpo", "boss": "ares", "lv": 1.3,
		"waves": [["hop", "hop"], ["hop", "hop", "hop"], ["hop", "hop", "hop", "hop"], ["ares"]],
		"intro_t": "IV · El Olimpo",
		"intro": "Sobre las nubes, el mármol de los dioses. Los hoplitas dorados de Ares se cubren con sus escudos: rómpelos con un golpe de escudo (Golpe mientras bloqueas).\n\nAl final del pórtico, el dios de la guerra te espera.",
		"outro": "Ares cae de rodillas sobre el mármol. Los dioses observan en silencio. Tu ira se apaga… por ahora.\n\nFin del primer capítulo.",
		"sky_top": Color(0.28, 0.5, 0.85), "sky_hor": Color(1.0, 0.86, 0.66), "gnd": Color(0.9, 0.85, 0.8),
		"sun": Color(1.0, 0.92, 0.78), "sun_e": 2.0, "sun_rot": Vector3(-42, -120, 0), "amb": 0.85, "exp": 0.74,
		"fog": Color(0.98, 0.9, 0.8), "fog_d": 0.004, "fog_h": 0.03,
	},
]

static func floor_mat(scale_uv: float, tint: Color, rough := 0.88) -> StandardMaterial3D:
	# piedra seca y mate: sin textura de rugosidad y con poco brillo especular
	var m := tex_mat("res://assets/tex/floor_c.jpg", "res://assets/tex/floor_n.jpg", "", scale_uv, tint)
	m.roughness = rough
	m.metallic_specular = 0.3
	m.normal_scale = 0.75
	return m

static func motes(root: Node3D, g: Game, col: Color, amount: int, rise := 0.05, size := 0.03) -> void:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = 8.0
	p.preprocess = 8.0
	p.visibility_aabb = AABB(Vector3(-25, -2, -25), Vector3(50, 14, 50))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(16, 3, 16)
	pm.direction = Vector3(0.3, 1, 0.1)
	pm.spread = 60.0
	pm.initial_velocity_min = 0.05
	pm.initial_velocity_max = 0.25
	pm.gravity = Vector3(0, rise, 0)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.4
	pm.turbulence_noise_scale = 3.0
	pm.scale_min = 0.5
	pm.scale_max = 1.3
	var grad := Gradient.new()
	grad.set_color(0, Color(col.r, col.g, col.b, 0))
	grad.add_point(0.2, col)
	grad.add_point(0.8, col)
	grad.set_color(grad.get_point_count() - 1, Color(col.r, col.g, col.b, 0))
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_texture = g._glow_tex()
	q.material = m
	p.draw_pass_1 = q
	p.position = Vector3(0, 2.5, 0)
	root.add_child(p)

static func tex_mat(path: String, normal: String, rough: String, scale_uv: float, tint := Color.WHITE) -> StandardMaterial3D:
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

static func put(root: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO, shape: Shape3D = null, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	root.add_child(mi)
	if shape:
		var sb := StaticBody3D.new()
		sb.collision_layer = 1
		var cs := CollisionShape3D.new()
		cs.shape = shape
		sb.add_child(cs)
		mi.add_child(sb)
	return mi

static func box(x: float, y: float, z: float) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = Vector3(x, y, z)
	return m

static func platform(root: Node3D, mat: Material) -> void:
	var plat := CylinderMesh.new()
	plat.top_radius = AR + 7
	plat.bottom_radius = AR + 4
	plat.height = 10
	plat.radial_segments = 96
	put(root, plat, mat, Vector3(0, -5, 0))

static func inlays(root: Node3D, col: Color) -> void:
	var inlay := StandardMaterial3D.new()
	inlay.albedo_color = col
	inlay.roughness = 0.55
	for rad in [AR, 9.7, 2.7]:
		var t := TorusMesh.new()
		t.inner_radius = rad - 0.14
		t.outer_radius = rad + 0.14
		t.rings = 96
		t.ring_segments = 4
		put(root, t, inlay, Vector3(0, -0.2, 0), Vector3.ZERO, null, Vector3(1, 0.6, 1))

static func column(root: Node3D, p: Vector3, h: float, marble: Material, cap_mat: Material, tilt := Vector3.ZERO, full := true) -> void:
	var pl := box(1.7, 0.32, 1.7)
	put(root, pl, marble, p + Vector3(0, 0.16, 0))
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.62
	cyl.height = h
	var c := put(root, Geo.fluted_column(h, 0.64, 0.52), marble, p + Vector3(0, 0.32 + h / 2, 0), tilt, cyl)
	c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if full:
		var cap := CylinderMesh.new()
		cap.top_radius = 0.8
		cap.bottom_radius = 0.52
		cap.height = 0.3
		put(root, cap, cap_mat, p + Vector3(0, 0.32 + h + 0.15, 0))
		put(root, box(1.75, 0.24, 1.75), cap_mat, p + Vector3(0, 0.32 + h + 0.42, 0))
	else:
		# fractura irregular en la parte superior
		for k in range(3):
			var ch := box(0.35 + k * 0.1, 0.25, 0.3)
			put(root, ch, marble, p + Vector3(sin(k * 2.3) * 0.3, 0.32 + h + 0.05, cos(k * 2.3) * 0.3), Vector3(0.4 * k, k, 0.3))

static func brazier(g: Game, root: Node3D, p: Vector3, flame := "fire", scale_k := 1.0) -> void:
	var bronze: Material = Mats.get_m("bronze")
	var n := Node3D.new()
	n.position = p
	n.scale = Vector3.ONE * scale_k
	root.add_child(n)
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
		n.add_child(mi)
	var bowl := CylinderMesh.new()
	bowl.top_radius = 0.56
	bowl.bottom_radius = 0.28
	bowl.height = 0.32
	var bm := MeshInstance3D.new()
	bm.mesh = bowl
	bm.material_override = bronze
	bm.position.y = 1.36
	n.add_child(bm)
	fire_at(g, n, Vector3(0, 1.5, 0), flame, 1.0)

static func fire_at(g: Game, parent: Node3D, pos: Vector3, flame: String, k: float) -> void:
	var cyan := flame == "cyan"
	var light := OmniLight3D.new()
	light.light_color = Color(0.3, 1.0, 0.85) if cyan else Color(1.0, 0.6, 0.3)
	light.light_energy = 2.5 * k
	light.omni_range = 9.0 * k
	light.position = pos + Vector3(0, 0.5, 0)
	light.set_meta("base", 2.5 * k)
	parent.add_child(light)
	var fire := GPUParticles3D.new()
	fire.amount = int(40 * k)
	fire.lifetime = 0.8
	fire.position = pos
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 12.0
	pm.initial_velocity_min = 0.8
	pm.initial_velocity_max = 1.6
	pm.gravity = Vector3(0, 0.6, 0)
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.22 * k
	pm.scale_min = 0.6 * k
	pm.scale_max = 1.1 * k
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.5))
	curve.add_point(Vector2(0.3, 1.0))
	curve.add_point(Vector2(1, 0.0))
	var ct := CurveTexture.new()
	ct.curve = curve
	pm.scale_curve = ct
	var grad := Gradient.new()
	if cyan:
		grad.set_color(0, Color(0.8, 1.0, 0.95, 1))
		grad.set_color(1, Color(0.05, 0.4, 0.35, 0))
		grad.add_point(0.4, Color(0.2, 0.95, 0.8, 0.9))
	else:
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
	fm.albedo_texture = g._glow_tex()
	fm.albedo_color = Color(2.2, 1.6, 1.0)
	quad.material = fm
	fire.draw_pass_1 = quad
	parent.add_child(fire)
	g.fires.append(light)

# ---------------- constructores de cada mundo ----------------
static func build(g: Game, root: Node3D, id: String) -> void:
	match id:
		"tebas":
			_tebas(g, root)
		"laberinto":
			_laberinto(g, root)
		"inframundo":
			_inframundo(g, root)
		"olimpo":
			_olimpo(g, root)

static func _sea(root: Node3D, col: Color, rough: float, metal: float, y := -9.0, emit := Color.BLACK) -> void:
	var sea := PlaneMesh.new()
	sea.size = Vector2(1500, 1500)
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = metal
	if emit != Color.BLACK:
		m.emission_enabled = true
		m.emission = emit
	put(root, sea, m, Vector3(0, y, 0))

static func _tebas(g: Game, root: Node3D) -> void:
	platform(root, floor_mat(0.17, Color(0.82, 0.74, 0.64)))
	motes(root, g, Color(1.0, 0.85, 0.6, 0.5), 60)
	_sea(root, Color(0.12, 0.25, 0.32), 0.08, 0.3)
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
		put(root, sp, isl_m, Vector3(cos(a) * rr, -9.0 - sp.radius * 0.55, sin(a) * rr), Vector3.ZERO, null, Vector3(1.0, 0.45 + float(k % 3) * 0.12, 0.7))
	inlays(root, Color(0.16, 0.11, 0.08))
	var marble := tex_mat("res://assets/tex/marble_c.jpg", "", "", 0.35, Color(0.8, 0.77, 0.72))
	marble.roughness = 0.62
	var broken := [2, 5, 6, 10, 13]
	for i in range(16):
		var a := i / 16.0 * TAU + 0.1
		var p := Vector3(cos(a), 0, sin(a)) * (AR + 2.6)
		var isb := broken.has(i)
		var h := 6.5 if not isb else 1.6 + (i % 3) * 1.1
		column(root, p, h, marble, marble, Vector3((i % 2 - 0.5) * 0.1, 0, (i % 2 - 0.5) * 0.12) if isb else Vector3.ZERO, not isb)
	for k in range(4):
		var a := k / 4.0 * TAU + PI / 4
		brazier(g, root, Vector3(cos(a), 0, sin(a)) * (AR + 1.2))

static func _laberinto(g: Game, root: Node3D) -> void:
	platform(root, floor_mat(0.21, Color(0.55, 0.46, 0.4), 0.92))
	motes(root, g, Color(1.0, 0.6, 0.3, 0.6), 70, 0.08)
	inlays(root, Color(0.25, 0.06, 0.04))
	var stone := tex_mat("res://assets/tex/stone_c.jpg", "res://assets/tex/stone_n.jpg", "", 0.2, Color(0.62, 0.55, 0.48))
	stone.roughness = 0.92
	# muro de 16 lados con cuatro accesos que se pierden en pasillos oscuros
	var n := 16
	var R := AR + 1.6
	var seg := 2.0 * R * tan(PI / n) + 0.05
	for i in range(n):
		var a := (i + 0.5) / n * TAU
		var p := Vector3(cos(a), 0, sin(a)) * R
		if i % 4 == 1:
			# pasillo: muros laterales hacia fuera y dintel
			for s in [-1.0, 1.0]:
				var off: Vector3 = Vector3(-sin(a), 0, cos(a)) * s * (seg / 2 - 0.4)
				for depth in range(3):
					var q: Vector3 = p + off + Vector3(cos(a), 0, sin(a)) * (1.5 + depth * 3.0)
					put(root, box(0.8, 7.0, 3.0), stone, q + Vector3(0, 3.5, 0), Vector3(0, -a + PI / 2, 0))
			put(root, box(seg, 1.4, 1.2), stone, p + Vector3(0, 6.3, 0), Vector3(0, -a + PI / 2, 0))
			var dark := StandardMaterial3D.new()
			dark.albedo_color = Color(0, 0, 0)
			dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			put(root, box(seg, 7.0, 0.2), dark, p + Vector3(cos(a), 0, sin(a)) * 9.0 + Vector3(0, 3.5, 0), Vector3(0, -a + PI / 2, 0))
			continue
		var shp := BoxShape3D.new()
		shp.size = Vector3(seg, 7.0, 1.2)
		put(root, box(seg, 7.0, 1.2), stone, p + Vector3(0, 3.5, 0), Vector3(0, -a + PI / 2, 0), shp)
		# remate y pilastra
		put(root, box(seg + 0.1, 0.35, 1.5), stone, p + Vector3(0, 7.1, 0), Vector3(0, -a + PI / 2, 0))
		if i % 2 == 0:
			var torch := Node3D.new()
			torch.position = p - Vector3(cos(a), 0, sin(a)) * 0.75 + Vector3(0, 2.6, 0)
			root.add_child(torch)
			var stick := CylinderMesh.new()
			stick.top_radius = 0.07
			stick.bottom_radius = 0.04
			stick.height = 0.6
			put(torch, stick, Mats.get_m("wood"), Vector3.ZERO, Vector3(0, 0, 0))
			fire_at(g, torch, Vector3(0, 0.35, 0), "fire", 0.6)
	# escombros
	var rock_m := tex_mat("res://assets/tex/stone_c.jpg", "res://assets/tex/stone_n.jpg", "", 0.5, Color(0.5, 0.44, 0.38))
	for k in range(9):
		var a := k * 2.39 + 0.4
		var p := Vector3(cos(a), 0, sin(a)) * (AR - 0.3 + (k % 3) * 0.3)
		put(root, Geo.rock(k, 0.5 + (k % 3) * 0.2), rock_m, p + Vector3(0, 0.1, 0), Vector3(k, k * 0.7, 0))
	# cráneos de toro sobre el muro norte
	for k in range(3):
		var a := -PI / 2 + (k - 1) * 0.35
		var p := Vector3(cos(a), 0, sin(a)) * (R - 0.65) + Vector3(0, 4.8, 0)
		var sk := Node3D.new()
		sk.position = p
		sk.rotation.y = -a - PI / 2
		root.add_child(sk)
		put(sk, Geo.rock(40 + k, 0.22), Mats.get_m("ivory"), Vector3.ZERO, Vector3.ZERO, null, Vector3(1, 1.1, 1.3))
		for s in [-1.0, 1.0]:
			var h := put(sk, Geo.horn(0.5, 0.06, 1.5), Mats.get_m("ivory"), Vector3(s * 0.18, 0.12, 0))
			h.scale = Vector3(s, 1, 1)
	for k in range(4):
		var a := k / 4.0 * TAU
		brazier(g, root, Vector3(cos(a), 0, sin(a)) * 6.0, "fire", 0.85)

static func _inframundo(g: Game, root: Node3D) -> void:
	platform(root, tex_mat("res://assets/tex/rock_c.jpg", "res://assets/tex/rock_n.jpg", "", 0.12, Color(0.5, 0.52, 0.55)))
	_sea(root, Color(0.02, 0.12, 0.1), 0.05, 0.4, -3.0, Color(0.02, 0.35, 0.28))
	inlays(root, Color(0.04, 0.2, 0.17))
	motes(root, g, Color(0.4, 1.0, 0.85, 0.8), 110, 0.15, 0.05)
	var rock_m := tex_mat("res://assets/tex/rock_c.jpg", "res://assets/tex/rock_n.jpg", "", 0.25, Color(0.42, 0.42, 0.45))
	# estalagmitas alrededor de la arena
	for k in range(26):
		var a := k / 26.0 * TAU + sin(k * 3.1) * 0.08
		var rr := AR + 2.4 + (k % 3) * 1.4
		var h := 3.0 + float((k * 7) % 5) * 1.6
		var p := Vector3(cos(a), 0, sin(a)) * rr
		var cone := CylinderMesh.new()
		cone.top_radius = 0.05
		cone.bottom_radius = 0.7 + (k % 3) * 0.3
		cone.height = h
		cone.radial_segments = 9
		var shp: Shape3D = null
		if k % 2 == 0:
			var cs := CylinderShape3D.new()
			cs.radius = 0.6
			cs.height = h
			shp = cs
		put(root, cone, rock_m, p + Vector3(0, h / 2 - 0.2, 0), Vector3(sin(k) * 0.08, k, cos(k) * 0.08), shp)
		put(root, Geo.rock(k + 7, 0.8), rock_m, p + Vector3(0, 0.1, 0), Vector3(k, 0, k * 0.5))
	# islas de roca lejanas sobre el Estigia
	for k in range(10):
		var a := k * 0.63
		var p := Vector3(cos(a), 0, sin(a)) * (60.0 + (k % 4) * 18.0)
		put(root, Geo.rock(100 + k, 8.0 + (k % 3) * 4.0), rock_m, p + Vector3(0, -4.0, 0), Vector3(0, k, 0), null, Vector3(1.4, 0.8 + (k % 2) * 0.9, 1.2))
	# huesos dispersos
	for k in range(14):
		var a := k * 2.17
		var p := Vector3(cos(a), 0.05, sin(a)) * (4.0 + (k * 5 % 9))
		var bone := CylinderMesh.new()
		bone.top_radius = 0.03
		bone.bottom_radius = 0.035
		bone.height = 0.45
		put(root, bone, Mats.get_m("ivory"), p, Vector3(PI / 2, k, 0))
	for k in range(5):
		var a := k / 5.0 * TAU + 0.3
		brazier(g, root, Vector3(cos(a), 0, sin(a)) * (AR + 1.1), "cyan")

static func _olimpo(g: Game, root: Node3D) -> void:
	var marble := tex_mat("res://assets/tex/marble_c.jpg", "", "", 0.3, Color(0.92, 0.89, 0.84))
	marble.roughness = 0.28
	var floor_m := floor_mat(0.14, Color(1.0, 0.97, 0.92), 0.55)
	floor_m.metallic_specular = 0.45
	motes(root, g, Color(1.0, 0.85, 0.45, 0.7), 80, 0.03, 0.035)
	platform(root, floor_m)
	inlays(root, Color(0.75, 0.55, 0.25))
	# mar de nubes
	var cloud := StandardMaterial3D.new()
	cloud.albedo_color = Color(1.0, 0.96, 0.92)
	cloud.roughness = 1.0
	for k in range(40):
		var a := k * 0.157 * 2.0 + sin(k * 1.7)
		var rr := 32.0 + (k * 13 % 7) * 14.0
		var sp := SphereMesh.new()
		sp.radius = 9.0 + (k % 4) * 3.0
		sp.height = sp.radius * 2
		sp.radial_segments = 16
		sp.rings = 8
		put(root, sp, cloud, Vector3(cos(a) * rr, -10.0 - (k % 3) * 2.0, sin(a) * rr), Vector3.ZERO, null, Vector3(1.6, 0.42, 1.2))
	_sea(root, Color(0.95, 0.92, 0.9), 1.0, 0.0, -12.0)
	var gold := Mats.get_m("gold")
	for i in range(20):
		var a := i / 20.0 * TAU
		column(root, Vector3(cos(a), 0, sin(a)) * (AR + 2.6), 7.5, marble, gold)
	# arquitrabe circular
	var ring := TorusMesh.new()
	ring.inner_radius = AR + 1.75
	ring.outer_radius = AR + 3.45
	ring.rings = 80
	ring.ring_segments = 4
	put(root, ring, marble, Vector3(0, 8.95, 0), Vector3.ZERO, null, Vector3(1, 0.35, 1))
	var fr := TorusMesh.new()
	fr.inner_radius = AR + 3.3
	fr.outer_radius = AR + 3.55
	fr.rings = 80
	fr.ring_segments = 6
	put(root, fr, gold, Vector3(0, 8.7, 0))
	# estatuas doradas sobre pedestales (siluetas de hoplitas)
	for k in range(4):
		var a := k / 4.0 * TAU + PI / 4
		var p := Vector3(cos(a), 0, sin(a)) * (AR + 1.0)
		put(root, box(1.4, 1.2, 1.4), marble, p + Vector3(0, 0.6, 0), Vector3(0, -a, 0))
		var st := Body.new()
		root.add_child(st)
		st.setup({"tint": Color(0.95, 0.7, 0.35), "metal": "gold", "crest": "horse", "weapon": "spear", "shield": true, "armor": true, "scale": 1.25})
		st.position = p + Vector3(0, 1.2, 0)
		st.rotation.y = -a - PI / 2
		st.skin_mat.metallic = 1.0
		st.skin_mat.roughness = 0.3
		st.skin_mat.albedo_texture = null
		st.skin_mat.albedo_color = Color(0.9, 0.68, 0.32)
		st.play("Idle_Shield_Loop", 0.0, 0.0)
		brazier(g, root, Vector3(cos(a + 0.2), 0, sin(a + 0.2)) * (AR + 1.3), "fire", 0.9)
