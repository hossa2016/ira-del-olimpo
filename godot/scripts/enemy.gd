class_name Enemy
extends CharacterBody3D
## Enemigos humanoides y jefes: Esparto, guardia del Laberinto, Sombra, Hoplita, Esparto Gigante, Minotauro y Ares.

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
var hit_i := 0
var poise := 0.0
var sc := 1.0
var zombie := true
var guard_chance := 0.0
var side := 1.0
var A: Dictionary
var attacks: Array = []
var phase := 1
var charge_dir := Vector3.ZERO
var title := ""
var flash_col := Color(0.5, 0.35, 0.22)
var armored := false
var step_acc := 0.0
var zombie_loco := true
var ragdoll_on := false

const SPEAR := {"clip": "Punch_Cross", "wind_spd": 0.32, "wind_until": 0.13, "spd": 1.1, "hits": [0.19], "end": 0.72, "range": 2.2, "trig": 2.0, "arc": 0.8, "stop": 1.5, "lunge": 2.2}
const HOOK := {"clip": "Melee_Hook", "wind_spd": 0.3, "wind_until": 0.16, "spd": 1.0, "hits": [0.27], "end": 0.47, "range": 2.0, "trig": 1.8, "arc": 1.0, "stop": 1.3, "lunge": 2.6}
const SCRATCH := {"clip": "Zombie_Scratch", "wind_spd": 0.55, "wind_until": 0.4, "spd": 1.25, "hits": [0.57], "end": 1.05, "range": 2.0, "trig": 1.9, "arc": 1.0, "stop": 1.2, "lunge": 3.0}
const GIG := {"clip": "Punch_Cross", "wind_spd": 0.25, "wind_until": 0.13, "spd": 0.95, "hits": [0.19], "end": 0.78, "range": 3.6, "trig": 3.1, "arc": 0.9, "stop": 2.4, "lunge": 3.0}
const M_SLAM := {"clip": "Sword_Attack", "wind_spd": 0.45, "wind_until": 0.3, "spd": 1.0, "hits": [0.4], "end": 0.98, "range": 3.9, "trig": 3.4, "arc": 0.9, "stop": 2.6, "lunge": 2.0, "dmg": 1.4, "shock": 3.2}
const M_SWEEP := {"clip": "Sword_Regular_C", "wind_spd": 0.5, "wind_until": 0.15, "spd": 1.05, "hits": [0.27, 0.65], "end": 1.05, "range": 3.4, "trig": 3.0, "arc": 1.8, "stop": 2.4, "lunge": 3.0}
const M_CHARGE := {"clip": "Sprint_Loop", "special": "charge", "range": 12.0, "trig": 11.0, "min": 5.5, "stop": 2.0, "dmg": 1.6, "unbl": true}
const A_COMBO := {"clip": "Sword_Regular_A", "wind_spd": 0.55, "wind_until": 0.12, "spd": 1.25, "hits": [0.24], "end": 0.41, "range": 2.9, "trig": 2.6, "arc": 1.2, "stop": 2.0, "lunge": 4.0, "next": "A_B"}
const A_B := {"clip": "Sword_Regular_B", "wind_spd": 1.2, "wind_until": 0.0, "spd": 1.2, "hits": [0.2], "end": 0.5, "range": 2.9, "trig": 2.6, "arc": 1.2, "stop": 2.0, "lunge": 4.0, "next": "A_C"}
const A_C := {"clip": "Sword_Regular_C", "wind_spd": 1.25, "wind_until": 0.0, "spd": 1.25, "hits": [0.27, 0.65], "end": 1.05, "range": 3.1, "trig": 2.6, "arc": 1.8, "stop": 2.0, "lunge": 4.5, "dmg": 1.2}
const A_DASH := {"clip": "Sword_Dash", "wind_spd": 0.4, "wind_until": 0.12, "spd": 1.25, "hits": [0.33], "end": 0.8, "range": 8.0, "trig": 7.5, "min": 4.0, "arc": 0.7, "stop": 2.0, "lunge": 12.0, "lunge_win": [0.08, 0.38], "dmg": 1.3}
const A_SLAM := {"clip": "Sword_Attack", "wind_spd": 0.5, "wind_until": 0.3, "spd": 1.0, "hits": [0.4], "end": 0.98, "range": 3.3, "trig": 4.5, "arc": 0.9, "stop": 2.0, "lunge": 2.0, "dmg": 1.5, "shock": 5.5, "unbl": true}

func setup(k: String, lv: float) -> void:
	kind = k
	side = 1.0 if randf() < 0.5 else -1.0
	var o := {}
	match k:
		"esp":
			max_hp = 32.0; attacks = [SPEAR]
			var tints := [Color(0.92, 0.95, 0.9), Color(0.85, 0.9, 0.84), Color(0.95, 0.94, 0.88)]
			o = {"tint": tints[randi() % 3], "skin": "p", "metal": "patina", "crest": "" if randf() < 0.65 else "black", "weapon": "spear", "eyes": "red", "mh": "esparto",
				"bones": {"spine_03": randf_range(0.93, 1.0), "Head": randf_range(0.97, 1.04)}}
		"lab":
			max_hp = 38.0; speed = 2.0; dmg = 9.0; attacks = [HOOK]
			o = {"tint": Color(0.86, 0.8, 0.72), "skin": "p", "metal": "dark_bronze", "crest": "", "weapon": "sword", "eyes": "red", "armor": true, "mh": "esparto"}
		"som":
			max_hp = 30.0; speed = 2.3; dmg = 11.0; attacks = [SCRATCH]
			o = {"tint": Color(0.55, 0.66, 0.75), "skin": "p", "helmet": false, "eyes": "cyan", "mh": "esparto"}
		"hop":
			max_hp = 46.0; speed = 2.1; dmg = 11.0; attacks = [SPEAR]; zombie = false; guard_chance = 0.7
			o = {"tint": Color(0.95, 0.82, 0.72), "metal": "gold", "crest": "horse", "weapon": "spear", "shield": true, "shield_face": "cloth", "armor": true, "eyes": "", "helm": "corinthian", "emblem": "ares", "mh": "damon"}
		"gig":
			sc = 1.6; boss = true; max_hp = 260.0; speed = 1.9; dmg = 18.0; r = 0.75; attacks = [GIG]
			title = "Esparto Gigante"
			o = {"tint": Color(0.9, 0.93, 0.88), "skin": "p", "metal": "patina", "crest": "horse", "weapon": "spear", "eyes": "red", "upright": true, "mh": "esparto",
				"bones": {"spine_03": 1.1, "Head": 0.88, "hand_l": 1.2, "hand_r": 1.2, "thigh_l": 1.04, "thigh_r": 1.04}}
		"mino":
			sc = 1.75; boss = true; max_hp = 420.0; speed = 2.6; dmg = 17.0; r = 0.8; zombie = false
			attacks = [M_SLAM, M_SWEEP, M_CHARGE]
			title = "Asterión, el Minotauro"
			o = {"tint": Color(0.55, 0.42, 0.34), "skin": "d", "bull": true, "weapon": "labrys", "eyes": "red", "armor": true, "metal": "dark_bronze",
				"bones": {"spine_03": 1.18, "neck_01": 1.15, "hand_l": 1.15, "hand_r": 1.15, "thigh_l": 1.06, "thigh_r": 1.06}}
		"ares":
			sc = 1.38; boss = true; max_hp = 480.0; speed = 3.0; dmg = 13.0; r = 0.62; zombie = false; guard_chance = 0.45
			attacks = [A_COMBO, A_DASH]
			title = "Ares, dios de la guerra"
			o = {"tint": Color(1.0, 0.93, 0.88), "metal": "gold", "crest": "horse", "crest_scale": 1.4, "weapon": "sword", "blade": 1.35, "shield": true, "shield_face": "horse", "emblem": "ares", "armor": true, "eyes": "fire", "beard": true, "mh": "ares",
				"bones": {"spine_03": 1.08, "Head": 0.95}}
	max_hp *= lv
	hp = max_hp
	A = attacks[0]
	armored = o.get("armor", false) or o.get("shield", false)
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = r
	cap.height = maxf(1.8 * sc, r * 2.0 + 0.1)
	col.shape = cap
	col.position.y = 0.9 * sc
	add_child(col)
	collision_layer = 4
	collision_mask = 1 | 2 | 4
	body = Body.new()
	add_child(body)
	o["scale"] = sc
	body.setup(o)
	if body.upright:
		zombie_loco = false
	if k == "ares":
		var cape := Cape.new()
		add_child(cape)
		cape.setup(body, Color(0.45, 0.04, 0.03))
	if zombie:
		body.play("Zombie_Idle_Loop" if not body.upright else "Idle_Loop", 1.0, 0.0)
		body.position.y = -2.5 * sc
	else:
		st = "move"
		cd = 1.2
		body.play("Idle_Loop", 1.0, 0.0)

func _pick_attack(d: float) -> Dictionary:
	var opts: Array = []
	for a in attacks:
		if d < a.trig and d >= a.get("min", 0.0):
			opts.append(a)
	if phase == 2 and kind == "ares" and d < A_SLAM.trig and randf() < 0.35:
		return A_SLAM
	if opts.is_empty():
		return {}
	return opts[randi() % opts.size()]

func tick(dt: float, hero: Hero) -> void:
	st_t += dt
	if st == "dead":
		if ragdoll_on:
			# el cuerpo físico no se hunde: se desvanece
			if st_t > 2.3:
				set_fade(clampf((st_t - 2.3) / 1.0, 0.0, 1.0))
		elif st_t > 1.8:
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
	var fwd_speed := 0.0
	if st == "move":
		face = lerp_angle(face, tf, 1.0 - exp(-5.0 * dt))
		cd -= dt
		var holding: bool = game.tokens.has(self)
		var waiting: bool = not boss and not holding and (game.tokens.size() >= 2 or cd > 0.0)
		if alive and waiting and d < 5.0:
			# espera su turno rodeando a Damón a distancia
			var tan := Vector3(-dir.z, 0, dir.x) * side
			want = tan * 0.75 + dir * clampf((d - 3.6) * 1.2, -1.2, 1.2)
			if randf() < dt * 0.25:
				side = -side
		elif alive:
			var stop: float = A.get("stop", 1.5)
			if d > stop:
				want = dir * speed
		for o in game.enemies:
			if o != self and o.st != "dead":
				var dd: Vector3 = global_position - o.global_position
				dd.y = 0
				var ln := dd.length()
				if ln < 1.5 * maxf(sc, o.sc) and ln > 0.01:
					want += dd / ln * (1.5 - ln) * 2.0
		fwd_speed = maxf(0.0, vel.dot(Vector3(sin(face), 0, cos(face))))
		body.loco(fwd_speed, zombie and zombie_loco)
		if st == "move" and alive:
			body.look_toward(hero.global_position, 0.8)
		if alive and cd <= 0.0:
			var pick := _pick_attack(d)
			if not pick.is_empty() and (boss or game.take_token(self)):
				_begin(pick)
	elif st == "atk":
		if A.get("special", "") == "charge":
			want = _charge(dt, hero, d, dir)
		else:
			want = _attack(dt, hero, d, dir, tf)
	elif st == "hurt":
		if st_t >= 0.4:
			st = "move"
			cd = maxf(cd, 0.5)
	elif st == "down":
		# derribado: cae, queda en el suelo y se levanta
		if st_t >= 1.15 and body.cur != "LayToIdle":
			body.play("LayToIdle", 1.15, 0.25, true)
		if st_t >= 2.45:
			st = "move"
			cd = 0.8
			body.play("Zombie_Idle_Loop" if zombie and zombie_loco else "Idle_Loop", 1.0, 0.3)
	elif st == "stun":
		if st_t >= (1.0 if boss else 1.4):
			st = "move"
			cd = 0.6
			body.play("Zombie_Idle_Loop" if zombie and zombie_loco else "Idle_Loop", 1.0, 0.25)
	elif st == "block":
		face = lerp_angle(face, tf, 1.0 - exp(-8.0 * dt))
		if st_t >= 0.45:
			st = "move"
	var acc := 7.0 if not (st == "atk" and A.get("special", "") == "charge") else 30.0
	var dv := want - vel
	if dv.length() > acc * dt:
		dv = dv.normalized() * acc * dt
	vel += dv
	kb = kb.lerp(Vector3.ZERO, 1.0 - exp(-5.0 * dt))
	velocity = vel + kb
	velocity.y = 0.0
	move_and_slide()
	position.y = 0.0
	# pisadas pesadas de los gigantes: se oyen y se sienten
	if sc > 1.4 and st != "dead":
		step_acc += vel.length() * dt
		if step_acc > 1.3 * sc:
			step_acc = 0.0
			var dh := global_position.distance_to(hero.global_position)
			game.audio.play("step", dh, 0.05, 6.0, 0.55)
			if dh < 9.0:
				game.cam.shake(0.08)
			game.vfx.dust(global_position)
	var rr := Vector2(position.x, position.z).length()
	if rr > Game.AR - 0.5:
		position.x *= (Game.AR - 0.5) / rr
		position.z *= (Game.AR - 0.5) / rr
	body.rotation.y = face

func _begin(a: Dictionary) -> void:
	A = a
	st = "atk"
	st_t = 0.0
	fast = false
	hit_i = 0
	if a.get("special", "") == "charge":
		charge_dir = Vector3.ZERO
		body.play("Idle_Loop", 1.0, 0.2, true)
		_telegraph(0.6)
		game.sfx("roar")
		return
	if a.get("unbl", false):
		_telegraph(0.5)
	body.play(a.clip, a.wind_spd, 0.18 if a.wind_until > 0.0 else 0.08, true)

func _telegraph(t: float) -> void:
	body.set_flash(true, Color(1.0, 0.15, 0.05))
	game.telegraph(self)
	get_tree().create_timer(t).timeout.connect(func(): if is_instance_valid(body): body.set_flash(false))

func _attack(dt: float, hero: Hero, d: float, dir: Vector3, tf: float) -> Vector3:
	var want := Vector3.ZERO
	var t := body.pos_t()
	if not fast and t >= A.wind_until:
		fast = true
		body.ap.speed_scale = A.spd
	var first_hit: float = A.hits[0]
	if t < first_hit * 0.7:
		face = rotate_toward(face, tf, (3.5 if boss else 2.0) * dt)
	var lw: Array = A.get("lunge_win", [first_hit - 0.1, first_hit + 0.05])
	if t > lw[0] and t < lw[1] and d > 1.2 * sc:
		want = Vector3(sin(face), 0, cos(face)) * A.get("lunge", 2.2) * (sc if not boss else 1.0)
	if hit_i < A.hits.size() and t >= A.hits[hit_i]:
		hit_i += 1
		var fw := Vector3(sin(face), 0, cos(face))
		var dm: float = dmg * A.get("dmg", 1.0)
		if A.has("shock"):
			game.shockwave(global_position + fw * 1.4 * sc, A.shock, dm, A.get("unbl", false), self)
		elif d < A.range and fw.dot(dir) > cos(A.arc):
			hero.take_hit(dm, global_position, self, A.get("unbl", false))
		game.sfx_at("whoosh", global_position)
	if t >= A.end or body.done():
		if A.has("next") and d < 4.0 and randf() < 0.8:
			_begin(A_B if A.next == "A_B" else A_C)
			return want
		st = "move"
		cd = (0.5 if boss else 1.0) + randf() * (0.6 if boss else 0.8)
		game.release_token(self)
	return want

func _charge(dt: float, hero: Hero, d: float, dir: Vector3) -> Vector3:
	if st_t < 0.75:
		face = lerp_angle(face, atan2(dir.x, dir.z), 1.0 - exp(-8.0 * dt))
		return Vector3.ZERO
	if charge_dir == Vector3.ZERO:
		charge_dir = dir
		face = atan2(dir.x, dir.z)
		body.play("Sprint_Loop", 1.5, 0.1, true)
	var want := charge_dir * 9.0
	var rr := Vector2(position.x, position.z).length()
	if hit_i == 0 and d < 1.7 * sc * 0.8:
		hit_i = 1
		var res: String = hero.take_hit(dmg * A.dmg, global_position, self, true)
		if res == "hit":
			game.cam.shake(0.8)
	if st_t > 2.4 or rr > Game.AR - 1.0 or (hit_i == 1 and st_t > 0.15 + 0.75):
		# agotado tras la embestida: ventana para castigarlo
		st = "stun"
		st_t = 0.0
		vel *= 0.3
		body.play("Idle_Shield_Break", 0.8, 0.15, true)
		game.cam.shake(0.4)
		return Vector3.ZERO
	return want

var _fade := 0.0
var _meshes: Array = []
func set_fade(f: float) -> void:
	_fade = move_toward(_fade, f, 0.12)
	if _meshes.is_empty():
		_meshes = find_children("*", "GeometryInstance3D", true, false)
	for m in _meshes:
		if is_instance_valid(m):
			m.transparency = _fade

func parried() -> void:
	if st == "dead":
		return
	game.release_token(self)
	st = "stun"
	st_t = 0.0
	body.play("Hit_Knockback", 1.0, 0.08, true)

## Devuelve true si el golpe fue bloqueado con el escudo.
func hurt(amount: float, push: Vector3, heavy: bool, c := {}) -> bool:
	if st == "dead" or st == "rise":
		return false
	var hero_dir := -push.normalized() if push.length() > 0.01 else Vector3.ZERO
	var facing := Vector3(sin(face), 0, cos(face)).dot(hero_dir) > 0.4
	if guard_chance > 0.0 and st == "move" and facing and not heavy and randf() < guard_chance:
		st = "block"
		st_t = 0.0
		kb = push * 0.25
		body.play("Sword_Block", 1.6, 0.05, true)
		return true
	if guard_chance > 0.0 and st == "block" and c.has("bash"):
		parried()
	var mult := 1.5 if st == "stun" else (1.2 if st == "down" else 1.0)
	hp -= amount * mult
	kb = push * (0.15 if boss else (1.3 if heavy else 0.8))
	body.recoil(push.normalized() if push.length() > 0.01 else Vector3.ZERO, 0.12 if boss else (0.35 if heavy else 0.22))
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
		var ragdolled := false
		if not boss and sc <= 1.01:
			var imp := push * (0.9 if heavy else 0.6) + Vector3.UP * (2.2 if heavy else 1.2)
			ragdolled = Ragdoll.activate(body, imp)
		if not ragdolled:
			body.play("Death01", 1.2, 0.15, true)
		ragdoll_on = ragdolled
		get_tree().create_timer(0.7).timeout.connect(func():
			if is_instance_valid(self):
				game.sfx_at("bodyfall", global_position)
				game.vfx.dust(global_position + Vector3(sin(face), 0, cos(face)) * -0.9 * sc, sc > 1.3))
		get_tree().create_timer(0.45).timeout.connect(func(): if is_instance_valid(body): body.drop_weapon(game))
		game.on_enemy_dead(self)
		return false
	if boss and phase == 1 and hp < max_hp * 0.5:
		phase = 2
		speed *= 1.15
		game.on_boss_phase(self)
	poise += amount
	var committed := st == "atk" and fast
	var knock: bool = not boss and (c.has("ira") or (heavy and not c.has("bash") and float(c.get("kb", 0.0)) >= 7.0))
	if st == "stun" or st == "down":
		pass
	elif knock:
		poise = 0.0
		if st == "atk":
			game.release_token(self)
		st = "down"
		st_t = 0.0
		if push.length() > 0.01:
			face = atan2(-push.x, -push.z)
		body.play("Death01", 1.25, 0.1, true)
		get_tree().create_timer(0.55).timeout.connect(func():
			if is_instance_valid(self) and st == "down":
				game.vfx.dust(global_position + push.normalized() * 0.9, true)
				game.sfx_at("bodyfall", global_position))
	elif not boss and (heavy or (poise >= 20.0 and not committed)):
		poise = 0.0
		if st == "atk":
			game.release_token(self)
		st = "hurt"
		st_t = 0.0
		# reacción según la altura del golpe: cortes altos a la cabeza, el resto al pecho
		var high: bool = c.get("clip", "") in ["Sword_Regular_B", "Sword_Dash"]
		body.play("Hit_Head" if high else "Hit_Chest", 1.15, 0.1, true)
	elif boss and poise >= 70.0 and st != "atk":
		poise = 0.0
		st = "hurt"
		st_t = 0.0
		body.play("Hit_Chest", 0.9, 0.18, true)
	get_tree().create_timer(1.5).timeout.connect(func(): poise = maxf(0.0, poise - 10.0))
	return false
