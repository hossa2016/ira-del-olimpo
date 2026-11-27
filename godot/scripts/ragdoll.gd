class_name Ragdoll
## Muerte con física: convierte 11 huesos del esqueleto en cuerpos físicos unidos por articulaciones
## y los empuja en la dirección del golpe. Barato: solo al morir y con pocas cápsulas.

const PARTS := [
	# hueso, hueso hijo (para la longitud), radio, articulación
	["pelvis", "spine_02", 0.13, PhysicalBone3D.JOINT_TYPE_NONE],
	["spine_02", "neck_01", 0.15, PhysicalBone3D.JOINT_TYPE_CONE],
	["Head", "", 0.11, PhysicalBone3D.JOINT_TYPE_CONE],
	["upperarm_l", "lowerarm_l", 0.055, PhysicalBone3D.JOINT_TYPE_CONE],
	["lowerarm_l", "hand_l", 0.045, PhysicalBone3D.JOINT_TYPE_HINGE],
	["upperarm_r", "lowerarm_r", 0.055, PhysicalBone3D.JOINT_TYPE_CONE],
	["lowerarm_r", "hand_r", 0.045, PhysicalBone3D.JOINT_TYPE_HINGE],
	["thigh_l", "calf_l", 0.08, PhysicalBone3D.JOINT_TYPE_CONE],
	["calf_l", "foot_l", 0.06, PhysicalBone3D.JOINT_TYPE_HINGE],
	["thigh_r", "calf_r", 0.08, PhysicalBone3D.JOINT_TYPE_CONE],
	["calf_r", "foot_r", 0.06, PhysicalBone3D.JOINT_TYPE_HINGE],
]

static func activate(b: Body, impulse: Vector3) -> bool:
	var sk := b.skel
	if sk == null or absf(b.scale.x - 1.0) > 0.01:
		return false
	# las cápsulas físicas no admiten huesos escalados: se devuelven a escala 1
	for i in sk.get_bone_count():
		sk.set_bone_pose_scale(i, Vector3.ONE)
	b.ap.pause()
	b.aim.active = false
	var sim := PhysicalBoneSimulator3D.new()
	sk.add_child(sim)
	var pelvis_pb: PhysicalBone3D = null
	var all: Array = []
	for part in PARTS:
		var bi := sk.find_bone(part[0])
		if bi < 0:
			continue
		var len := 0.2
		if part[1] != "":
			var ci := sk.find_bone(part[1])
			if ci >= 0:
				len = sk.get_bone_global_pose(bi).origin.distance_to(sk.get_bone_global_pose(ci).origin)
		var pb := PhysicalBone3D.new()
		pb.bone_name = part[0]
		pb.mass = 3.0 if part[0] in ["pelvis", "spine_02"] else 1.2
		pb.friction = 0.9
		pb.linear_damp = 0.4
		pb.angular_damp = 1.5
		pb.collision_layer = 32
		pb.collision_mask = 1 | 16
		var cs := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		var r: float = part[2]
		cap.radius = r
		cap.height = maxf(len, r * 2.0 + 0.01)
		cs.shape = cap
		cs.position = Vector3(0, len * 0.5, 0)
		pb.add_child(cs)
		sim.add_child(pb)
		pb.joint_type = part[3]
		if part[3] == PhysicalBone3D.JOINT_TYPE_CONE:
			pb.set("joint_constraints/swing_span", 50.0)
			pb.set("joint_constraints/twist_span", 30.0)
		elif part[3] == PhysicalBone3D.JOINT_TYPE_HINGE:
			pb.set("joint_constraints/angular_limit_enabled", true)
			pb.set("joint_constraints/angular_limit_upper", 5.0)
			pb.set("joint_constraints/angular_limit_lower", -120.0)
		all.append(pb)
		if part[0] == "pelvis":
			pelvis_pb = pb
	# se arranca un fotograma después, cuando los huesos físicos ya están en el árbol
	_start.call_deferred(sim, all, pelvis_pb, impulse)
	return true

static func _start(sim: PhysicalBoneSimulator3D, all: Array, pelvis_pb: PhysicalBone3D, impulse: Vector3) -> void:
	if not is_instance_valid(sim):
		return
	sim.physical_bones_start_simulation()
	for pb in all:
		var k := 1.0 if pb == pelvis_pb else 0.35
		pb.apply_central_impulse(impulse * pb.mass * k)
