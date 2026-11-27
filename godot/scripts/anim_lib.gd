class_name AnimLib
## Carga las animaciones (UAL1+UAL2, CC0) y las redirige a los huesos del Skeleton3D del personaje.

static var _lib: AnimationLibrary
const NAT := {"Walk_Loop": 1.25, "Jog_Fwd_Loop": 3.24, "Sprint_Loop": 4.21, "Zombie_Walk_Fwd_Loop": 1.22}

static func get_lib() -> AnimationLibrary:
	if _lib:
		return _lib
	var src: Node = load("res://assets/models/anims.glb").instantiate()
	var ap: AnimationPlayer = src.find_child("AnimationPlayer", true, false)
	_lib = AnimationLibrary.new()
	for n in ap.get_animation_list():
		var a: Animation = ap.get_animation(n).duplicate(true)
		for i in range(a.get_track_count() - 1, -1, -1):
			var bone := String(a.track_get_path(i)).get_file()
			var tt := a.track_get_type(i)
			if tt == Animation.TYPE_SCALE_3D:
				a.remove_track(i)
				continue
			if tt == Animation.TYPE_POSITION_3D and bone != "pelvis":
				a.remove_track(i)
				continue
			a.track_set_path(i, NodePath("Armature/Skeleton3D:" + bone))
		var out := String(n)
		var looped: bool = ap.get_animation(n).loop_mode != Animation.LOOP_NONE or out.ends_with("_Loop")
		if looped and not out.ends_with("_Loop"):
			out += "_Loop"
		a.loop_mode = Animation.LOOP_LINEAR if looped else Animation.LOOP_NONE
		_lib.add_animation(out, a)
	src.free()
	return _lib
