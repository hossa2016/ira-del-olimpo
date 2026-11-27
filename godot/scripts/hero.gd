class_name Hero
extends CharacterBody3D
## Damón: movimiento con inercia relativo a la cámara, combo de 3 cortes, voltereta, daño y muerte.

signal died
signal hp_changed

const COMBO := [
	{"clip": "Sword_Regular_A", "speed": 1.05, "hits": [0.24], "end": 0.41, "lunge": [0.06, 0.26, 3.4], "reach": 2.1, "arc": 1.25, "dmg": 12.0, "kb": 3.0},
	{"clip": "Sword_Regular_B", "speed": 1.05, "hits": [0.2], "end": 0.5, "lunge": [0.04, 0.22, 3.2], "reach": 2.1, "arc": 1.3, "dmg": 12.0, "kb": 4.0},
	{"clip": "Sword_Regular_C", "speed": 1.2, "hits": [0.27, 0.65], "end": 1.05, "lunge": [0.12, 0.32, 3.6], "reach": 2.5, "arc": 1.9, "dmg": 15.0, "kb": 7.0},
]

var body: Body
var game: Node
var face := PI
var vel := Vector3.ZERO
var kb := Vector3.ZERO
var hp := 100.0
var max_hp := 100.0
var rage := 0.0
var st := "loco"
var st_t := 0.0
var combo := 0
var cfg: Dictionary
var hit_i := 0
var queued := false
var last_end := -9.0
var inv := 0.0
var roll_cd := 0.0
var roll_dir := Vector3.ZERO
var lean := 0.0
var clock := 0.0

func _ready() -> void:
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.38
	cap.height = 1.8
	col.shape = cap
	col.position.y = 0.9
	add_child(col)
	collision_layer = 2
	collision_mask = 1 | 4
	body = Body.new()
	add_child(body)
	body.setup({"tint": Color(0.95, 0.82, 0.72), "armor": true, "shield": true, "weapon": "sword", "beard": true, "crest": "cloth"})
	body.rotation.y = face

func reset_at(p: Vector3) -> void:
	position = p
	vel = Vector3.ZERO
	kb = Vector3.ZERO
	hp = max_hp
	rage = 0.0
	st = "loco"
	face = PI
	body.play("Sword_Idle", 1.0, 0.0, true)
	hp_changed.emit()

func physics_tick(dt: float, inp: Dictionary, cam_yaw: float) -> void:
	clock += dt
	st_t += dt
	inv -= dt
	roll_cd -= dt
	var mv: Vector2 = inp.move
	var fwd := Vector3(sin(cam_yaw), 0, cos(cam_yaw))
	var right := Vector3(-cos(cam_yaw), 0, sin(cam_yaw))
	var wish := right * mv.x + fwd * (-mv.y)
	var m := minf(1.0, wish.length())
	if wish.length() > 0.01:
		wish = wish.normalized()
	var prev_face := face

	if st == "dead":
		vel = vel.lerp(Vector3.ZERO, 1.0 - exp(-6.0 * dt))
	elif st == "roll":
		var k := minf(1.0, st_t / 0.58)
		vel = roll_dir * (9.5 * (1.0 - k * k) + 0.4)
		if st_t >= 0.58:
			st = "loco"
	elif st == "atk":
		var t := body.pos_t()
		var nh = cfg.hits[hit_i] if hit_i < cfg.hits.size() else null
		if t < cfg.hits[0] * 0.7 and m > 0.15:
			face = lerp_angle(face, atan2(wish.x, wish.z), 1.0 - exp(-8.0 * dt))
		var f := Vector3(sin(face), 0, cos(face))
		var lg: Array = cfg.lunge
		vel = vel.lerp(f * (lg[2] if t >= lg[0] and t <= lg[1] else 0.0), 1.0 - exp(-14.0 * dt))
		if nh != null and t >= nh:
			hit_i += 1
			game.hero_hit(self, cfg, combo == 3 and hit_i == cfg.hits.size())
		if inp.atk and t > cfg.hits[0] * 0.5:
			queued = true
		if inp.roll and t > cfg.hits[0] and roll_cd <= 0.0:
			_start_roll(wish, m)
		elif t >= cfg.end or body.done():
			last_end = clock
			if queued:
				_start_atk(wish, m)
			else:
				st = "loco"
	else:
		vel = vel.lerp(Vector3.ZERO, 1.0 - exp(-9.0 * dt))
		if st == "hurt" and st_t >= 0.35:
			st = "loco"

	if st == "loco":
		if inp.roll and roll_cd <= 0.0:
			_start_roll(wish, m)
		elif inp.atk:
			_start_atk(wish, m)
		else:
			var ts := 0.0 if m < 0.15 else 1.3 + (m - 0.15) / 0.85 * 3.7
			var target := wish * ts
			var acc := 13.0 if ts > vel.length() else 22.0
			var dv := target - vel
			if dv.length() > acc * dt:
				dv = dv.normalized() * acc * dt
			vel += dv
			var sp := vel.length()
			if sp > 0.3:
				face = lerp_angle(face, atan2(vel.x, vel.z), 1.0 - exp(-(7.0 if sp < 2.0 else 10.0) * dt))
			body.loco(sp, false, true)

	kb = kb.lerp(Vector3.ZERO, 1.0 - exp(-6.0 * dt))
	velocity = vel + kb
	velocity.y = 0.0
	move_and_slide()
	position.y = 0.0
	var r := Vector2(position.x, position.z).length()
	if r > Game.AR - 0.6:
		var k2 := (Game.AR - 0.6) / r
		position.x *= k2
		position.z *= k2
	var da := wrapf(face - prev_face, -PI, PI)
	var tl := clampf(-da / maxf(dt, 0.001) * 0.03 * minf(1.0, vel.length() / 3.0), -0.2, 0.2)
	lean = lerpf(lean, tl, minf(1.0, dt * 8.0))
	body.rotation = Vector3(0, face, 0)
	body.model.rotation.z = lean

func _start_atk(wish: Vector3, m: float) -> void:
	if m > 0.15:
		face = atan2(wish.x, wish.z)
	else:
		var tg = game.nearest_enemy(global_position, 4.5)
		if tg:
			var d: Vector3 = tg.global_position - global_position
			face = atan2(d.x, d.z)
	combo = (combo % 3) + 1 if (queued or clock - last_end < 0.45) else 1
	queued = false
	cfg = COMBO[combo - 1]
	st = "atk"
	st_t = 0.0
	hit_i = 0
	body.play(cfg.clip, cfg.speed, 0.08, true)
	game.sfx("whoosh")

func _start_roll(wish: Vector3, m: float) -> void:
	roll_dir = wish if m > 0.15 else Vector3(sin(face), 0, cos(face))
	face = atan2(roll_dir.x, roll_dir.z)
	st = "roll"
	st_t = 0.0
	inv = 0.45
	roll_cd = 0.7
	queued = false
	body.play("Roll", 2.4, 0.08, true)

func take_hit(dmg: float, from: Vector3) -> void:
	if inv > 0.0 or st == "dead" or st == "roll":
		return
	hp -= dmg
	inv = 0.7
	var d := global_position - from
	d.y = 0
	if d.length() > 0.01:
		kb = d.normalized() * 6.0
		face = atan2(-d.x, -d.z)
	vel *= 0.2
	hp_changed.emit()
	game.on_hero_hurt()
	if hp <= 0.0:
		hp = 0.0
		st = "dead"
		body.play("Death01", 1.0, 0.15, true)
		died.emit()
	else:
		st = "hurt"
		st_t = 0.0
		body.play("Hit_Chest" if randf() < 0.5 else "Hit_Head", 1.05, 0.12, true)
