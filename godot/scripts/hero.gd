class_name Hero
extends CharacterBody3D
## Damón: movimiento con inercia relativo a la cámara, combo de 3 cortes, voltereta,
## escudo (bloqueo, parada perfecta, golpe de escudo), estocada tras voltereta y furia (Ira).

signal died
signal hp_changed

const COMBO := [
	{"clip": "Sword_Regular_A", "speed": 1.05, "hits": [0.24], "end": 0.41, "lunge": [0.06, 0.26, 3.4], "reach": 2.1, "arc": 1.25, "dmg": 12.0, "kb": 3.0},
	{"clip": "Sword_Regular_B", "speed": 1.05, "hits": [0.2], "end": 0.5, "lunge": [0.04, 0.22, 3.2], "reach": 2.1, "arc": 1.3, "dmg": 12.0, "kb": 4.0},
	{"clip": "Sword_Regular_C", "speed": 1.2, "hits": [0.27, 0.65], "end": 1.05, "lunge": [0.12, 0.32, 3.6], "reach": 2.5, "arc": 1.9, "dmg": 15.0, "kb": 7.0, "heavy": true},
]
const BASH := {"clip": "Shield_OneShot", "speed": 1.25, "hits": [0.1], "end": 0.42, "lunge": [0.0, 0.16, 4.0], "reach": 1.9, "arc": 1.1, "dmg": 5.0, "kb": 7.0, "heavy": true, "bash": true}
const DASH := {"clip": "Sword_Dash", "speed": 1.3, "hits": [0.33], "end": 0.78, "lunge": [0.04, 0.38, 10.0], "reach": 2.3, "arc": 0.9, "dmg": 20.0, "kb": 7.0, "heavy": true}
const IRA := {"clip": "Sword_Attack", "speed": 1.0, "hits": [0.4], "end": 0.98, "lunge": [0.18, 0.38, 2.5], "reach": 4.6, "arc": 3.2, "dmg": 48.0, "kb": 12.0, "heavy": true, "ira": true}
const PARRY_WIN := 0.22

var body: Body
var game: Node
var face := PI
var vel := Vector3.ZERO
var kb := Vector3.ZERO
var hp := 100.0
var max_hp := 100.0
var rage := 0.0
var guard := 100.0
var guard_t := 0.0
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
var blk_since := -9.0
var block_anim_t := 0.0
var trail: SwordTrail
var step_acc := 0.0
var lock_t = null

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
	body.setup({"tint": Color(0.95, 0.82, 0.72), "armor": true, "shield": true, "weapon": "sword", "beard": true, "crest": "horse", "crest_scale": 1.4})
	trail = SwordTrail.new()
	add_child(trail)
	var cape := Cape.new()
	add_child(cape)
	cape.setup(body, Color(0.68, 0.1, 0.06))
	body.rotation.y = face

func reset_at(p: Vector3) -> void:
	position = p
	vel = Vector3.ZERO
	kb = Vector3.ZERO
	hp = max_hp
	rage = 0.0
	guard = 100.0
	st = "loco"
	face = PI
	body.play("Sword_Idle", 1.0, 0.0, true)
	hp_changed.emit()

func blocking() -> bool:
	return st == "block"

func physics_tick(dt: float, inp: Dictionary, cam_yaw: float) -> void:
	clock += dt
	st_t += dt
	inv -= dt
	roll_cd -= dt
	guard_t -= dt
	if guard_t <= 0.0 and st != "block":
		guard = minf(100.0, guard + 30.0 * dt)
	var mv: Vector2 = inp.move
	var fwd := Vector3(sin(cam_yaw), 0, cos(cam_yaw))
	var right := Vector3(-cos(cam_yaw), 0, sin(cam_yaw))
	var wish := right * mv.x + fwd * (-mv.y)
	var m := minf(1.0, wish.length())
	if wish.length() > 0.01:
		wish = wish.normalized()
	var prev_face := face
	var blk: bool = inp.get("blk", false)
	if blk and blk_since < 0.0:
		blk_since = clock
	elif not blk:
		blk_since = -9.0

	if st == "dead":
		vel = vel.lerp(Vector3.ZERO, 1.0 - exp(-6.0 * dt))
	elif st == "roll":
		var k := minf(1.0, st_t / 0.58)
		# arranque explosivo, frenado al apoyar (sin deslizar al final)
		vel = roll_dir * (9.0 * (1.0 - k * k * k) * (1.0 if k < 0.8 else 0.5) + 0.3)
		if st_t > 0.42 and st_t - get_physics_process_delta_time() <= 0.42:
			game.vfx.dust(global_position + roll_dir * 0.3)
			game.sfx("step")
		if inp.atk and st_t > 0.12:
			_start_special(DASH, roll_dir, 1.0)
		elif st_t >= 0.58:
			st = "loco"
	elif st == "atk":
		var t := body.pos_t()
		var nh = cfg.hits[hit_i] if hit_i < cfg.hits.size() else null
		if t < cfg.hits[0] * 0.7 and m > 0.15:
			face = lerp_angle(face, atan2(wish.x, wish.z), 1.0 - exp(-8.0 * dt))
		var f := Vector3(sin(face), 0, cos(face))
		var lg: Array = cfg.lunge
		var lunge_v: float = lg[2] if t >= lg[0] and t <= lg[1] else 0.0
		if lock_t and is_instance_valid(lock_t) and not cfg.has("ira"):
			# avance "magnético": se detiene al llegar a distancia de golpe, sin atravesar al enemigo
			var to: Vector3 = lock_t.global_position - global_position
			to.y = 0
			var gap: float = to.length() - lock_t.r - cfg.reach * 0.55
			lunge_v = clampf(gap * 8.0, 0.0, lunge_v * 1.35) if lunge_v > 0.0 else 0.0
			if t < cfg.hits[0]:
				face = lerp_angle(face, atan2(to.x, to.z), 1.0 - exp(-12.0 * dt))
		vel = vel.lerp(Vector3(sin(face), 0, cos(face)) * lunge_v, 1.0 - exp(-16.0 * dt))
		if nh != null and t >= nh:
			hit_i += 1
			game.hero_hit(self, cfg, cfg.get("heavy", false) and hit_i == cfg.hits.size())
		if inp.atk and t > cfg.hits[0] * 0.5 and not cfg.has("ira"):
			queued = true
		var hits_done: bool = hit_i >= cfg.hits.size()
		if inp.roll and t > cfg.hits[0] and roll_cd <= 0.0 and not cfg.has("ira"):
			_start_roll(wish, m)
		elif blk and hits_done and not cfg.has("ira"):
			_start_block()
		elif t >= cfg.end or body.done():
			last_end = clock
			if queued and not cfg.has("bash"):
				_start_atk(wish, m)
			else:
				queued = false
				st = "loco"
	elif st == "block":
		block_anim_t -= dt
		if block_anim_t <= 0.0:
			body.play("Idle_Shield_Loop", 1.0, 0.15)
		var tg = game.nearest_enemy(global_position, 7.0)
		if tg:
			var d: Vector3 = tg.global_position - global_position
			face = lerp_angle(face, atan2(d.x, d.z), 1.0 - exp(-10.0 * dt))
		elif m > 0.15:
			face = lerp_angle(face, atan2(wish.x, wish.z), 1.0 - exp(-6.0 * dt))
		vel = vel.lerp(wish * m * 1.1, 1.0 - exp(-10.0 * dt))
		if inp.atk:
			_start_special(BASH, Vector3(sin(face), 0, cos(face)), 1.0)
		elif inp.roll and roll_cd <= 0.0:
			_start_roll(wish, m)
		elif not blk:
			st = "loco"
	elif st == "stun":
		vel = vel.lerp(Vector3.ZERO, 1.0 - exp(-9.0 * dt))
		if st_t >= 1.0:
			st = "loco"
	else:
		vel = vel.lerp(Vector3.ZERO, 1.0 - exp(-9.0 * dt))
		if st == "hurt" and st_t >= 0.35:
			st = "loco"

	if st == "loco":
		if inp.get("ira", false) and rage >= 100.0:
			_start_special(IRA, wish, m)
		elif inp.roll and roll_cd <= 0.0:
			_start_roll(wish, m)
		elif blk:
			_start_block()
		elif inp.atk:
			_start_atk(wish, m)
		else:
			var ts := 0.0 if m < 0.15 else 1.3 + (m - 0.15) / 0.85 * 3.7
			var fdir := Vector3(sin(face), 0, cos(face))
			var align := clampf(fdir.dot(wish) * 0.5 + 0.5, 0.0, 1.0) if m > 0.15 else 1.0
			# giro brusco a gran velocidad: frena para pivotar en lugar de girar en seco
			ts *= lerpf(0.3, 1.0, align * align) if vel.length() > 2.0 else 1.0
			var target := wish * ts
			var acc := 11.0 if ts > vel.length() else 18.0
			var dv := target - vel
			if dv.length() > acc * dt:
				dv = dv.normalized() * acc * dt
			vel += dv
			var sp := vel.length()
			if m > 0.15:
				var turn_rate := lerpf(11.0, 6.0, clampf(sp / 5.0, 0, 1))
				face = lerp_angle(face, atan2(wish.x, wish.z), 1.0 - exp(-turn_rate * dt))
			body.loco(sp, false, true)
			# pasos: uno por zancada según la distancia recorrida
			step_acc += sp * dt
			var stride := 0.75 if sp < 2.0 else 1.25
			if step_acc > stride:
				step_acc = 0.0
				game.audio.play("step", 0.0, 0.12, -4.0 if sp < 2.0 else 0.0)
				if sp > 3.8:
					game.vfx.dust(global_position)

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
	if st != "loco":
		tl = 0.0
	lean = lerpf(lean, tl, minf(1.0, dt * 8.0))
	body.rotation = Vector3(0, face, 0)
	body.model.rotation.z = lean
	if body.sword:
		var on: bool = st == "atk" and body.pos_t() < cfg.get("end", 0.5)
		trail.feed(body.sword.global_transform * Vector3(0, 0, 0.12), body.sword.global_transform * Vector3(0, 0, 0.72), on, Color(1.0, 0.55, 0.2) if cfg.has("ira") else Color(1.0, 0.92, 0.8))

func _start_block() -> void:
	st = "block"
	st_t = 0.0
	queued = false
	block_anim_t = 0.25
	body.play("Sword_Block", 1.6, 0.08, true)

func _start_atk(wish: Vector3, m: float) -> void:
	_aim(wish, m, 4.5)
	combo = (combo % 3) + 1 if (queued or clock - last_end < 0.45) else 1
	queued = false
	cfg = COMBO[combo - 1]
	st = "atk"
	st_t = 0.0
	hit_i = 0
	body.play(cfg.clip, cfg.speed, 0.08, true)
	game.sfx("whoosh")

func _start_special(c: Dictionary, wish: Vector3, m: float) -> void:
	_aim(wish, m, 6.0)
	cfg = c
	combo = 0
	queued = false
	st = "atk"
	st_t = 0.0
	hit_i = 0
	if c.has("ira"):
		rage = 0.0
		inv = 1.0
		game.on_ira(self)
	body.play(c.clip, c.speed, 0.06, true)
	game.sfx("whoosh")

func _aim(wish: Vector3, m: float, rng: float) -> void:
	lock_t = null
	var tg = game.nearest_enemy(global_position, rng)
	if m > 0.15:
		face = atan2(wish.x, wish.z)
		# solo se fija al enemigo si está más o menos hacia donde apunta el joystick
		if tg:
			var d: Vector3 = tg.global_position - global_position
			d.y = 0
			if d.normalized().dot(wish) > 0.6:
				lock_t = tg
	elif tg:
		var d: Vector3 = tg.global_position - global_position
		face = atan2(d.x, d.z)
		lock_t = tg

func _start_roll(wish: Vector3, m: float) -> void:
	roll_dir = wish if m > 0.15 else Vector3(sin(face), 0, cos(face))
	face = atan2(roll_dir.x, roll_dir.z)
	st = "roll"
	st_t = 0.0
	inv = 0.42
	game.vfx.dust(global_position)
	roll_cd = 0.7
	queued = false
	body.play("Roll", 2.4, 0.08, true)
	game.sfx("roll")

## Devuelve "hit", "block", "parry" o "miss".
func take_hit(dmg: float, from: Vector3, src: Node = null, unblockable := false) -> String:
	if inv > 0.0 or st == "dead" or st == "roll":
		return "miss"
	var d := global_position - from
	d.y = 0
	var dn := d.normalized() if d.length() > 0.01 else -Vector3(sin(face), 0, cos(face))
	var front := Vector3(sin(face), 0, cos(face)).dot(-dn) > 0.2
	if st == "block" and front and not unblockable:
		if clock - blk_since <= PARRY_WIN or st_t <= PARRY_WIN:
			body.play("Shield_OneShot", 1.4, 0.04, true)
			block_anim_t = 0.4
			rage = minf(100.0, rage + 20.0)
			kb = dn * 1.5
			game.on_parry(self, src, dn)
			return "parry"
		guard -= dmg * 3.2
		guard_t = 0.9
		kb = dn * (3.0 + dmg * 0.1)
		game.cam.kick(dn, 0.15)
		body.recoil(dn, 0.15)
		hp -= dmg * 0.1
		hp_changed.emit()
		if guard <= 0.0:
			guard = 0.0
			st = "stun"
			st_t = 0.0
			body.play("Idle_Shield_Break", 1.0, 0.08, true)
			game.on_guard_break(self)
		else:
			body.play("Sword_Block", 1.8, 0.04, true)
			block_anim_t = 0.35
			game.on_block(self, dn)
		return "block"
	hp -= dmg
	inv = 0.7
	kb = dn * (6.0 if not unblockable else 9.0)
	game.cam.kick(dn, 0.25 if dmg < 20.0 else 0.45)
	body.recoil(dn, 0.25)
	face = atan2(-dn.x, -dn.z)
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
		var heavy := dmg >= 20.0
		body.play("Hit_Knockback" if heavy else ("Hit_Chest" if randf() < 0.5 else "Hit_Head"), 1.05, 0.12, true)
		if heavy:
			st_t = -0.35
	return "hit"
