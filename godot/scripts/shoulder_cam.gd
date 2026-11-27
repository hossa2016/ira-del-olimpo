class_name ShoulderCam
extends Node3D
## Cámara al hombro estilo God of War: giro por arrastre, seguimiento suave, choque con columnas y temblor.

var yaw := PI
var pitch := 0.24
var arm: SpringArm3D
var cam: Camera3D
var target: Node3D
var drag_t := -9.0
var clock := 0.0
var trauma := 0.0
var noise := FastNoiseLite.new()
var fov_add := 0.0
var _fov_t := 0.0
var kick_v := Vector3.ZERO
var kick_p := Vector3.ZERO

func _ready() -> void:
	arm = SpringArm3D.new()
	arm.collision_mask = 1
	arm.margin = 0.25
	var sh := SphereShape3D.new()
	sh.radius = 0.25
	arm.shape = sh
	add_child(arm)
	cam = Camera3D.new()
	cam.current = true
	cam.near = 0.05
	cam.far = 600.0
	arm.add_child(cam)
	noise.frequency = 0.9

func rotate_by(dx: float, dy: float) -> void:
	yaw -= dx * 0.0075
	pitch = clampf(pitch + dy * 0.004, -0.02, 0.5)
	drag_t = clock

func shake(a: float) -> void:
	trauma = minf(1.0, trauma + a)

## Cambio breve de FOV: negativo = acercamiento (parada), positivo = apertura (Ira, explosiones).
func punch(deg: float) -> void:
	fov_add = deg

## Empujón direccional de la cámara en la dirección del impacto (más físico que el temblor aleatorio).
func kick(dir_world: Vector3, amount: float) -> void:
	var local := cam.global_transform.basis.inverse() * dir_world
	kick_v += Vector3(local.x, local.y, 0.0).normalized() * amount * 6.0 if local.length() > 0.01 else Vector3.ZERO

func tick(dt: float, hero: Hero) -> void:
	clock += dt
	var vp := get_viewport().get_visible_rect().size
	var portrait := vp.y > vp.x
	if clock - drag_t > 1.4 and hero.vel.length() > 1.5:
		var want := atan2(hero.vel.x, hero.vel.z)
		var diff := wrapf(want - yaw, -PI, PI)
		if absf(diff) < 1.75:
			yaw = lerp_angle(yaw, want, 1.0 - exp(-0.9 * dt * minf(1.0, hero.vel.length() / 4.0)))
	var piv := hero.global_position + Vector3(0, 1.45 if portrait else 1.5, 0)
	# en peleas con jefes grandes la cámara se aleja un poco
	var big := 0.0
	var g = hero.game
	if g and g.boss and is_instance_valid(g.boss) and g.boss.st != "dead":
		big = clampf((g.boss.sc - 1.0) * 1.4, 0.0, 1.2)
	global_position = global_position.lerp(piv, 1.0 - exp(-10.0 * dt))
	var p := pitch + (0.08 if portrait else 0.0)
	rotation = Vector3(-p, yaw + PI, 0)
	arm.spring_length = lerpf(arm.spring_length, (4.4 if portrait else 3.6) + big, 1.0 - exp(-3.0 * dt))
	fov_add = move_toward(fov_add, 0.0, dt * 18.0)
	cam.fov = (66.0 if portrait else 58.0) + fov_add
	# resorte para el empujón
	kick_v += (-kick_p * 260.0 - kick_v * 22.0) * dt
	kick_p += kick_v * dt
	cam.h_offset = (0.12 if portrait else 0.65) + kick_p.x
	cam.v_offset = kick_p.y
	trauma = maxf(0.0, trauma - dt * 1.6)
	var s := trauma * trauma
	cam.rotation = Vector3(noise.get_noise_2d(clock * 25.0, 0.0) * 0.03 * s, noise.get_noise_2d(0.0, clock * 25.0) * 0.03 * s, noise.get_noise_2d(clock * 25.0, 50.0) * 0.02 * s)
