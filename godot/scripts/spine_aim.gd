class_name SpineAim
extends SkeletonModifier3D
## Giro procedural del tronco y la cabeza hacia un objetivo, encima de la animación.
## Reparte el giro entre columna y cabeza (como un luchador que no pierde de vista al rival).

var yaw := 0.0          # giro deseado (rad) relativo al frente del cuerpo, ya limitado
var pitch := 0.0
var weight := 1.0
var _cur := 0.0
var _cur_p := 0.0
var _bones: Array = []  # [idx, reparto]

func setup(sk: Skeleton3D) -> void:
	for pair in [["spine_02", 0.25], ["spine_03", 0.35], ["neck_01", 0.15], ["Head", 0.25]]:
		var i := sk.find_bone(pair[0])
		if i < 0 and pair[0] == "Head":
			i = sk.find_bone("head")
		if i >= 0:
			_bones.append([i, pair[1]])

func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	var dt := get_process_delta_time() if is_inside_tree() else 0.016
	_cur = lerpf(_cur, yaw * weight, 1.0 - exp(-8.0 * maxf(dt, 0.001)))
	_cur_p = lerpf(_cur_p, pitch * weight, 1.0 - exp(-8.0 * maxf(dt, 0.001)))
	if absf(_cur) < 0.002 and absf(_cur_p) < 0.002:
		return
	for b in _bones:
		var i: int = b[0]
		var share: float = b[1]
		var q := sk.get_bone_pose_rotation(i)
		q = q * Quaternion(Vector3.UP, _cur * share) * Quaternion(Vector3.RIGHT, _cur_p * share)
		sk.set_bone_pose_rotation(i, q)
