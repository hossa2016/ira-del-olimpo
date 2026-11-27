class_name SwordTrail
extends MeshInstance3D
## Estela luminosa que deja la hoja durante los ataques.

const MAX := 14
const LIFE := 0.08

var pts: Array = []   # [base, tip, edad]
var im := ImmediateMesh.new()
var mat := StandardMaterial3D.new()
var col := Color.WHITE

func _ready() -> void:
	top_level = true
	mesh = im
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.vertex_color_use_as_albedo = true
	material_override = mat
	global_transform = Transform3D.IDENTITY

func feed(base: Vector3, tip: Vector3, active: bool, c: Color) -> void:
	col = c
	var dt := get_physics_process_delta_time()
	for p in pts:
		p[2] += dt
	pts = pts.filter(func(p): return p[2] < LIFE)
	if active:
		pts.push_front([base, tip, 0.0])
		if pts.size() > MAX:
			pts.pop_back()
	_rebuild()

func _rebuild() -> void:
	im.clear_surfaces()
	if pts.size() < 2:
		return
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in range(pts.size()):
		var p: Array = pts[i]
		var a: float = (1.0 - p[2] / LIFE) * (1.0 - float(i) / pts.size()) * 0.26
		im.surface_set_color(Color(col.r, col.g, col.b, a * 0.0))
		im.surface_add_vertex(p[0])
		im.surface_set_color(Color(col.r * 1.6, col.g * 1.6, col.b * 1.6, a))
		im.surface_add_vertex(p[1])
	im.surface_end()
