class_name Cape
extends MeshInstance3D
## Capa con física de tela (verlet): cuelga de los hombros, ondea con el movimiento y el viento,
## y no atraviesa la espalda. 7x10 puntos: barato incluso en móvil.

const W := 7
const H := 10
const LEN := 1.05
const ITER := 4

var body: Body
var skel: Skeleton3D
var spine_i := -1
var pts: PackedVector3Array
var prev: PackedVector3Array
var rest_w: float
var rest_h: float
var im := ImmediateMesh.new()
var wind := Vector3(0.6, 0, 0.3)
var clock := 0.0
var ready_ok := false

func setup(b: Body, col: Color) -> void:
	body = b
	skel = b.skel
	spine_i = skel.find_bone("spine_03")
	top_level = true
	mesh = im
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.85
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.normal_enabled = true
	m.normal_texture = load("res://assets/tex/fur_n.jpg")
	m.normal_scale = 0.4
	m.uv1_scale = Vector3(2.0, 3.0, 1.0)
	m.rim_enabled = true
	m.rim = 0.2
	m.backlight_enabled = true
	m.backlight = Color(col.r * 0.5, col.g * 0.3, col.b * 0.3)
	material_override = m
	rest_w = 0.62 / (W - 1)
	rest_h = LEN / (H - 1)
	pts.resize(W * H)
	prev.resize(W * H)

func _anchor_frame() -> Array:
	var bt := body.global_transform
	var sc := bt.basis.get_scale().x
	var right := bt.basis.x.normalized()
	var fwd := bt.basis.z.normalized()
	var sp := bt.origin + Vector3(0, 1.45 * sc, 0)
	if spine_i >= 0:
		sp = (skel.global_transform * skel.get_bone_global_pose(spine_i)).origin
	return [sp, right, fwd, sc]

func _top(i: int, fr: Array) -> Vector3:
	var sp: Vector3 = fr[0]
	var right: Vector3 = fr[1]
	var fwd: Vector3 = fr[2]
	var sc: float = fr[3]
	var u := float(i) / (W - 1) - 0.5
	# de hombro a hombro, un poco curvada siguiendo la espalda
	return sp + right * u * 0.42 * sc + Vector3.UP * (0.17 - u * u * 0.12) * sc - fwd * (0.13 + (0.25 - u * u) * -0.04) * sc

func _reset(fr: Array) -> void:
	for j in range(H):
		for i in range(W):
			var p: Vector3 = _top(i, fr) + Vector3.DOWN * rest_h * j * fr[3] - fr[2] * 0.02 * j
			pts[j * W + i] = p
			prev[j * W + i] = p
	ready_ok = true

func _physics_process(dt: float) -> void:
	if body == null or not is_instance_valid(body) or dt <= 0.0:
		return
	clock += dt
	var fr := _anchor_frame()
	if not ready_ok:
		_reset(fr)
	var sc: float = fr[3]
	var g := Vector3(0, -9.8, 0) * dt * dt
	var wv := wind * (0.6 + 0.4 * sin(clock * 1.7) + 0.2 * sin(clock * 4.3)) * dt * dt
	for j in range(1, H):
		for i in range(W):
			var k := j * W + i
			var p := pts[k]
			var v := (p - prev[k]) * 0.96
			prev[k] = p
			pts[k] = p + v + g + wv * (float(j) / H)
	for j in range(W):
		pts[j] = _top(j, fr)
	var sp: Vector3 = fr[0]
	var fwd: Vector3 = fr[2]
	var hw := rest_w * sc * (1.0)
	for it in range(ITER):
		for j in range(H):
			for i in range(W):
				var k := j * W + i
				var widen := 1.0 + float(j) / H * 0.5
				if i < W - 1:
					_link(k, k + 1, hw * widen, j == 0)
				if j < H - 1:
					_link(k, k + W, rest_h * sc, j == 0)
		# no atravesar la espalda ni las piernas: los puntos se quedan detrás del plano del cuerpo
		for k in range(W, W * H):
			var p := pts[k]
			var d := (p - sp).dot(fwd)
			var lim := -0.1 * sc
			if d > lim:
				pts[k] = p - fwd * (d - lim)
			if pts[k].y < 0.03:
				pts[k].y = 0.03
	_rebuild()

func _link(a: int, b: int, rest: float, pin_a: bool) -> void:
	var pa := pts[a]
	var pb := pts[b]
	var d := pb - pa
	var L := d.length()
	if L < 0.0001:
		return
	var diff := (L - rest) / L
	if pin_a:
		pts[b] = pb - d * diff
	else:
		pts[a] = pa + d * diff * 0.5
		pts[b] = pb - d * diff * 0.5

func _rebuild() -> void:
	im.clear_surfaces()
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var nrm := PackedVector3Array()
	nrm.resize(W * H)
	for j in range(H):
		for i in range(W):
			var l := pts[j * W + maxi(i - 1, 0)]
			var r := pts[j * W + mini(i + 1, W - 1)]
			var u := pts[maxi(j - 1, 0) * W + i]
			var dn := pts[mini(j + 1, H - 1) * W + i]
			nrm[j * W + i] = (dn - u).cross(r - l).normalized()
	for j in range(H - 1):
		for i in range(W - 1):
			var a := j * W + i
			var b := a + 1
			var c := a + W + 1
			var d := a + W
			for q in [a, b, c, a, c, d]:
				im.surface_set_normal(nrm[q])
				im.surface_set_uv(Vector2(float(q % W) / (W - 1), float(q / W) / (H - 1)))
				im.surface_add_vertex(pts[q])
	im.surface_end()
