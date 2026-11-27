class_name Geo
## Mallas procedurales: columna estriada, casco corintio, penacho, cuernos, hacha doble, rocas.

static var _cache := {}

## Columna dórica con estrías y éntasis (ligero ensanche a un tercio de la altura).
static func fluted_column(h: float, r_bot: float, r_top: float, flutes := 20, seg_y := 10) -> ArrayMesh:
	var key := "col_%.2f_%.2f_%.2f" % [h, r_bot, r_top]
	if _cache.has(key):
		return _cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var around := flutes * 4
	var rows: Array = []
	for j in range(seg_y + 1):
		var v := float(j) / seg_y
		var y := -h / 2 + v * h
		var r := lerpf(r_bot, r_top, v) * (1.0 + 0.025 * sin(clampf(v * 1.5, 0, 1) * PI))
		var row: Array = []
		for i in range(around + 1):
			var a := float(i) / around * TAU
			var fl := 0.5 - 0.5 * cos(a * flutes)  # 0 en la arista, 1 en el fondo de la estría
			var rr := r * (1.0 - 0.045 * pow(fl, 0.7))
			row.append(Vector3(cos(a) * rr, y, sin(a) * rr))
		rows.append(row)
	for j in range(seg_y):
		for i in range(around):
			var a: Vector3 = rows[j][i]
			var b: Vector3 = rows[j][i + 1]
			var c: Vector3 = rows[j + 1][i + 1]
			var d: Vector3 = rows[j + 1][i]
			for p in [a, d, c, a, c, b]:
				st.set_uv(Vector2(float(i) / around * 3.0, (p.y + h / 2) / h * 2.0))
				st.add_vertex(p)
	st.generate_normals()
	var m := st.commit()
	_cache[key] = m
	return m

## Casco corintio: casquete cerrado con nasal, aberturas de ojos en T y carrilleras, cubrenuca acampanado.
static var _style := "corinthian"

## style: "corinthian" (cara cubierta) o "attic" (ático: cara descubierta, carrilleras cortas).
static func corinthian_helmet(style := "corinthian") -> ArrayMesh:
	var key := "helm_" + style
	if _cache.has(key):
		return _cache[key]
	_style = style
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var NU := 80
	var NV := 40
	var grid: Array = []
	for j in range(NV + 1):
		var v := float(j) / NV
		var row: Array = []
		for i in range(NU + 1):
			var th := (float(i) / NU - 0.5) * TAU  # 0 = frente (+Z)
			row.append(_helm_pt(th, v))
		grid.append(row)
	for j in range(NV):
		for i in range(NU):
			var th := ((i + 0.5) / NU - 0.5) * TAU
			var v := (j + 0.5) / NV
			if _helm_open(th, v):
				continue
			var a: Vector3 = grid[j][i]
			var b: Vector3 = grid[j][i + 1]
			var c: Vector3 = grid[j + 1][i + 1]
			var d: Vector3 = grid[j + 1][i]
			for p in [a, b, c, a, c, d]:
				st.add_vertex(p)
	st.generate_normals()
	var m := st.commit()
	_cache[key] = m
	return m

static func _helm_y(v: float) -> float:
	# v 0 = coronilla, 0.42 = sien, 1 = borde inferior (cúpula elíptica, no cónica)
	if v < 0.42:
		return 0.165 - (1.0 - cos(v / 0.42 * PI / 2)) * 0.105
	return 0.06 - (v - 0.42) / 0.58 * 0.22

static func _helm_pt(th: float, v: float) -> Vector3:
	var y := _helm_y(v)
	var r: float
	if v < 0.42:
		var k := v / 0.42
		r = sin(k * PI / 2) * 0.15
	else:
		var k := (v - 0.42) / 0.58
		var back := clampf(-cos(th), 0.0, 1.0)  # 1 detrás
		var jaw := clampf(cos(th), 0.0, 1.0)    # 1 delante
		r = 0.15 + back * k * k * 0.05 - jaw * sin(k * PI * 0.8) * 0.03 - (1.0 - back) * k * 0.012
	var ax := 1.0
	var az := 1.14
	var fz := 0.012 if cos(th) > 0 else 0.0
	return Vector3(sin(th) * r * ax, y, cos(th) * r * az + fz)

static func _helm_open(th: float, v: float) -> bool:
	var a := absf(th)
	var y := _helm_y(v)
	var eye := y > -0.012 and y < 0.048 and a > 0.09 and a < 0.9 - (0.048 - y) * 3.5
	var slit := y < -0.035 and a < 0.17 + (-0.035 - y) * 0.9
	var join := y <= 0.0 and y >= -0.04 and a > 0.09 and a < 0.24
	# la nuca termina más arriba para no parecer un tubo desde atrás
	var nape := a > 2.0 and y < -0.085 + (PI - a) * 0.02
	if _style == "attic":
		# rostro descubierto: óvalo abierto bajo la visera, carrilleras que solo cubren el pómulo
		var face := a < 0.8 and y < 0.035
		var chin := a < 1.25 and y < -0.075
		return face or chin or nape
	return eye or slit or join or nape

## Penacho de crin sobre soporte: abanico en el plano sagital.
static func crest(transverse := false) -> ArrayMesh:
	var key := "crest_%s" % transverse
	if _cache.has(key):
		return _cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var N := 24
	var w := 0.028
	var inner: Array = []
	var outer: Array = []
	for i in range(N + 1):
		var t := float(i) / N
		var a := lerpf(0.62, PI - 0.25, t)  # de la frente a la nuca
		var base_r := 0.15
		var hgt := 0.035 + 0.075 * sin(t * PI) + 0.03 * t
		var bi := Vector3(0, sin(a) * base_r * 0.7 + 0.06, cos(a) * base_r * 1.1)
		var bo := Vector3(0, sin(a) * (base_r * 0.7 + hgt) + 0.07, cos(a) * (base_r + hgt) * 1.15)
		inner.append(bi)
		outer.append(bo)
	for i in range(N):
		var u0 := float(i) / N * 3.0
		var u1 := float(i + 1) / N * 3.0
		for s in [-1.0, 1.0]:
			var o := Vector3(s * w, 0, 0)
			var p: Array = [inner[i] + o * 0.5, inner[i + 1] + o * 0.5, outer[i + 1] + o, outer[i] + o]
			var uv: Array = [Vector2(u0, 1), Vector2(u1, 1), Vector2(u1, 0), Vector2(u0, 0)]
			if s > 0:
				p.reverse()
				uv.reverse()
			for k in [0, 1, 2, 0, 2, 3]:
				st.set_uv(uv[k])
				st.add_vertex(p[k])
		var q4: Array = [outer[i] + Vector3(-w, 0, 0), outer[i + 1] + Vector3(-w, 0, 0), outer[i + 1] + Vector3(w, 0, 0), outer[i] + Vector3(w, 0, 0)]
		var uq: Array = [Vector2(u0, 0), Vector2(u1, 0), Vector2(u1, 0.05), Vector2(u0, 0.05)]
		for k in [0, 1, 2, 0, 2, 3]:
			st.set_uv(uq[k])
			st.add_vertex(q4[k])
	st.generate_normals()
	var m := st.commit()
	_cache[key] = m
	return m

## Cuenco del escudo (aspis) con UV planas para pintar el emblema de frente. inner = cara interior.
static func shield_bowl(r: float, depth: float, inner := false) -> ArrayMesh:
	var key := "bowl_%.2f_%.3f_%s" % [r, depth, inner]
	if _cache.has(key):
		return _cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var NR := 10
	var NA := 40
	var pt := func(j: int, i: int) -> Vector3:
		var rho := r * float(j) / NR
		var a := float(i) / NA * TAU
		var h := depth * (1.0 - pow(rho / r, 2.0)) - (0.004 if inner else 0.0)
		return Vector3(cos(a) * rho, h, sin(a) * rho)
	for j in range(NR):
		for i in range(NA):
			var q := [pt.call(j, i), pt.call(j, i + 1), pt.call(j + 1, i + 1), pt.call(j + 1, i)]
			var order := [0, 2, 1, 0, 3, 2] if not inner else [0, 1, 2, 0, 2, 3]
			for k in order:
				var v: Vector3 = q[k]
				st.set_uv(Vector2(v.z / (2.0 * r) + 0.5, 0.5 - v.x / (2.0 * r)))
				st.add_vertex(v)
	st.generate_normals()
	var m := st.commit()
	_cache[key] = m
	return m

## Ánfora griega por revolución de un perfil (cuello, hombros, panza y pie).
static func amphora() -> ArrayMesh:
	if _cache.has("amph"):
		return _cache["amph"]
	var prof := [Vector2(0.09, 0.0), Vector2(0.12, 0.03), Vector2(0.1, 0.08), Vector2(0.18, 0.25), Vector2(0.24, 0.45), Vector2(0.23, 0.62), Vector2(0.17, 0.75), Vector2(0.08, 0.84), Vector2(0.07, 0.98), Vector2(0.1, 1.02), Vector2(0.06, 1.03)]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var NA := 20
	for j in range(prof.size() - 1):
		for i in range(NA):
			var a0 := float(i) / NA * TAU
			var a1 := float(i + 1) / NA * TAU
			var p: Array = [prof[j], prof[j + 1]]
			var q := [Vector3(cos(a0) * p[0].x, p[0].y, sin(a0) * p[0].x), Vector3(cos(a1) * p[0].x, p[0].y, sin(a1) * p[0].x), Vector3(cos(a1) * p[1].x, p[1].y, sin(a1) * p[1].x), Vector3(cos(a0) * p[1].x, p[1].y, sin(a0) * p[1].x)]
			var uv := [Vector2(float(i) / NA, 1.0 - p[0].y), Vector2(float(i + 1) / NA, 1.0 - p[0].y), Vector2(float(i + 1) / NA, 1.0 - p[1].y), Vector2(float(i) / NA, 1.0 - p[1].y)]
			for k in [0, 2, 1, 0, 3, 2]:
				st.set_uv(uv[k])
				st.add_vertex(q[k])
	st.generate_normals()
	var m := st.commit()
	_cache["amph"] = m
	return m

## Cuerno curvo (tubo que se afina siguiendo un arco).
static func horn(length := 0.5, r0 := 0.05, bend := 1.4) -> ArrayMesh:
	var key := "horn_%.2f_%.2f_%.2f" % [length, r0, bend]
	if _cache.has(key):
		return _cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var NS := 14
	var NR := 10
	var rings: Array = []
	for j in range(NS + 1):
		var t := float(j) / NS
		var ang := t * bend
		var rad := length / bend
		var c := Vector3(rad * sin(ang), rad * (1.0 - cos(ang)), 0)  # avanza en +X y sube
		var tan := Vector3(cos(ang), sin(ang), 0)
		var nrm := Vector3(-sin(ang), cos(ang), 0)
		var bin := Vector3(0, 0, 1)
		var r := r0 * (1.0 - t * 0.92)
		var ring: Array = []
		for i in range(NR + 1):
			var a := float(i) / NR * TAU
			ring.append(c + (nrm * cos(a) + bin * sin(a)) * r)
		rings.append(ring)
		tan = tan
	for j in range(NS):
		for i in range(NR):
			var a: Vector3 = rings[j][i]
			var b: Vector3 = rings[j][i + 1]
			var c2: Vector3 = rings[j + 1][i + 1]
			var d: Vector3 = rings[j + 1][i]
			for p in [a, c2, b, a, d, c2]:
				st.add_vertex(p)
	st.generate_normals()
	var m := st.commit()
	_cache[key] = m
	return m

## Roca irregular: esfera deformada por ruido.
static func rock(seed_i: int, r := 1.0) -> ArrayMesh:
	var key := "rock_%d_%.2f" % [seed_i, r]
	if _cache.has(key):
		return _cache[key]
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2
	sm.radial_segments = 16
	sm.rings = 10
	var arr := sm.get_mesh_arrays()
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var nz := FastNoiseLite.new()
	nz.seed = seed_i
	nz.frequency = 1.3 / r
	for i in verts.size():
		var v := verts[i]
		var k := 1.0 + nz.get_noise_3dv(v) * 0.35
		verts[i] = v * k
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	for i in idx:
		st.set_uv(Vector2(verts[i].x, verts[i].y) * 0.5)
		st.add_vertex(verts[i])
	st.generate_normals()
	var m := st.commit()
	_cache[key] = m
	return m

## Hoja de hacha doble (labrys) en el plano XZ, centrada en el mango.
static func labrys_blade() -> ArrayMesh:
	if _cache.has("lab"):
		return _cache["lab"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var th := 0.025
	for s in [-1.0, 1.0]:
		var pts: Array = []
		var N := 12
		for i in range(N + 1):
			var a := lerpf(-1.0, 1.0, float(i) / N)
			pts.append(Vector2(s * (0.08 + 0.3 * cos(a * 0.9)), a * 0.26))
		for i in range(N):
			var p0 := Vector3(s * 0.04, 0, pts[i].y * 0.35)
			var p1 := Vector3(pts[i].x, 0, pts[i].y)
			var p2 := Vector3(pts[i + 1].x, 0, pts[i + 1].y)
			var p3 := Vector3(s * 0.04, 0, pts[i + 1].y * 0.35)
			for yy in [th, -th]:
				var o := Vector3(0, yy * (1.0 if true else 0.0), 0)
				var e := Vector3(0, -yy * 0.9, 0)
				var q := [p0 + o, p1 + o * 0.15, p2 + o * 0.15, p3 + o]
				if (yy > 0) == (s > 0):
					q.reverse()
				for v in [q[0], q[1], q[2], q[0], q[2], q[3]]:
					st.add_vertex(v)
				e = e
	st.generate_normals()
	var m := st.commit()
	_cache["lab"] = m
	return m
