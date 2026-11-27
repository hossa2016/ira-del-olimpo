class_name Enemy
extends CharacterBody3D
## Esparto (no-muerto con lanza) y su variante gigante.

var body: Body
var game: Node
var kind := "esp"
var hp := 32.0
var max_hp := 32.0
var speed := 1.75
var dmg := 10.0
var r := 0.42
var boss := false
var face := 0.0
var vel := Vector3.ZERO
var kb := Vector3.ZERO
var st := "rise"
var st_t := 0.0
var cd := 1.0
var fast := false
var hit_done := false
var poise := 0.0
var sc := 1.0
# ataque: preparación lenta y estocada
var A := {"clip": "Punch_Cross", "wind_spd": 0.32, "wind_until": 0.13, "spd": 1.1, "hit": 0.19, "end": 0.72, "range": 2.2, "trig": 2.0, "arc": 0.8, "stop": 1.5}

func setup(k: String, lv: float) -> void:
	kind = k
	if k == "gig":
		sc = 1.6
		boss = true
		max_hp = 260.0 * lv
		speed = 1.9
		dmg = 18.0
		r = 0.75
		A = {"clip": "Punch_Cross", "wind_spd": 0.25, "wind_until": 0.13, "spd": 0.95, "hit": 0.19, "end": 0.78, "range": 3.6, "trig": 3.1, "arc": 0.9, "stop": 2.4}
	else:
		max_hp = 32.0 * lv
	hp = max_hp
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = r
	cap.height = 1.8 * sc
	col.shape = cap
	col.position.y = 0.9 * sc
	add_child(col)
	collision_layer = 4
	collision_mask = 1 | 2 | 4
	body = Body.new()
	add_child(body)
	var tints := [Color(0.65, 0.65, 0.6), Color(0.6, 0.62, 0.56), Color(0.69, 0.66, 0.6)]
	body.setup({"tint": tints[randi() % 3], "metal": "patina", "crest": "cloth" if boss else ("" if randf() < 0.65 else "black"), "weapon": "spear", "eyes": true, "scale": sc})
	body.play("Zombie_Idle_Loop", 1.0, 0.0)
	body.position.y = -2.5 * sc

func tick(dt: float, hero: Hero) -> void:
	st_t += dt
	if st == "dead":
		if st_t > 1.8:
			body.position.y -= dt * 0.7
		return
	if st == "rise":
		body.position.y = -2.5 * sc * maxf(0.0, 1.0 - st_t / 0.9)
		if st_t >= 0.9:
			body.position.y = 0.0
			st = "move"
		return
	var to := hero.global_position - global_position
	to.y = 0
	var d := maxf(0.01, to.length())
	var dir := to / d
	var tf := atan2(to.x, to.z)
	var alive := hero.st != "dead"
	var want := Vector3.ZERO
	if st == "move":
		face = lerp_angle(face, tf, 1.0 - exp(-5.0 * dt))
		if d > A.stop and alive:
			want = dir * speed
		body.loco(vel.length(), true)
		cd -= dt
		if alive and d < A.trig and cd <= 0.0 and game.take_token(self):
			st = "atk"
			st_t = 0.0
			fast = false
			hit_done = false
			body.play(A.clip, A.wind_spd, 0.18, true)
	elif st == "atk":
		var t := body.pos_t()
		if not fast and t >= A.wind_until:
			fast = true
			body.ap.speed_scale = A.spd
		if t < A.hit * 0.7:
			face = rotate_toward(face, tf, 2.0 * dt)
		if t > A.hit - 0.1 and t < A.hit + 0.05:
			want = Vector3(sin(face), 0, cos(face)) * 2.2 * sc
		if not hit_done and t >= A.hit:
			hit_done = true
			var fwd := Vector3(sin(face), 0, cos(face))
			if d < A.range and fwd.dot(dir) > cos(A.arc):
				hero.take_hit(dmg, global_position)
			game.sfx("whoosh")
		if t >= A.end or body.done():
			st = "move"
			cd = (0.7 if boss else 1.0) + randf() * 0.8
			game.release_token(self)
	elif st == "hurt":
		if st_t >= 0.4:
			st = "move"
			cd = maxf(cd, 0.5)
	var acc := 7.0
	var dv := want - vel
	if dv.length() > acc * dt:
		dv = dv.normalized() * acc * dt
	vel += dv
	kb = kb.lerp(Vector3.ZERO, 1.0 - exp(-5.0 * dt))
	velocity = vel + kb
	velocity.y = 0.0
	move_and_slide()
	position.y = 0.0
	var rr := Vector2(position.x, position.z).length()
	if rr > Game.AR - 0.5:
		position.x *= (Game.AR - 0.5) / rr
		position.z *= (Game.AR - 0.5) / rr
	body.rotation.y = face

func hurt(amount: float, push: Vector3, heavy: bool) -> void:
	if st == "dead" or st == "rise":
		return
	hp -= amount
	kb = push * (0.15 if boss else 1.0)
	body.set_flash(true)
	get_tree().create_timer(0.1).timeout.connect(func(): if is_instance_valid(body): body.set_flash(false))
	if hp <= 0.0:
		st = "dead"
		st_t = 0.0
		game.release_token(self)
		collision_layer = 0
		collision_mask = 0
		if push.length() > 0.01:
			face = atan2(-push.x, -push.z)
			body.rotation.y = face
		body.play("Death01", 1.2, 0.15, true)
		game.on_enemy_dead(self)
		return
	poise += amount
	var committed := st == "atk" and fast
	if not boss and (heavy or (poise >= 20.0 and not committed)):
		poise = 0.0
		if st == "atk":
			game.release_token(self)
		st = "hurt"
		st_t = 0.0
		body.play("Hit_Chest" if randf() < 0.5 else "Hit_Head", 1.1, 0.18, true)
	get_tree().create_timer(1.5).timeout.connect(func(): poise = maxf(0.0, poise - 10.0))
