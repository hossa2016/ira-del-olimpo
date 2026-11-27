class_name GameAudio
extends Node
## Música con fundidos, ambiente por mundo, efectos con variación y narrador (voz del sistema Android).

const VARIANTS := {"whoosh": 3, "hit": 3, "clang": 2, "step": 4, "flesh": 3}
const VOL := {
	"whoosh": -9.0, "hit": -3.0, "clang": -5.0, "parry": -2.0, "guard_break": -3.0, "boom": -2.0,
	"roar": -2.0, "growl": -3.0, "bite": -4.0, "fire": -4.0, "warn": -8.0, "rise": -10.0,
	"roll": -9.0, "hurt": -3.0, "click": -12.0, "ira": -1.0, "death": -6.0,
	"step": -17.0, "flesh": -4.0, "sub": -5.0, "armor": -9.0, "bodyfall": -6.0,
}

var music_on := true
var voice_on := true
var _streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _mus: Array[AudioStreamPlayer] = []
var _cur := 0
var _cur_name := ""
var _amb: AudioStreamPlayer
var _music_db := -9.0
var _voice := ""
var _duck := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in range(14):
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	for i in range(2):
		var m := AudioStreamPlayer.new()
		m.volume_db = -80.0
		add_child(m)
		_mus.append(m)
	_amb = AudioStreamPlayer.new()
	_amb.volume_db = -14.0
	add_child(_amb)
	_pick_voice()

func _stream(n: String) -> AudioStream:
	if _streams.has(n):
		return _streams[n]
	var path := "res://assets/audio/%s.ogg" % n
	var s: AudioStream = load(path) if ResourceLoader.exists(path) else null
	_streams[n] = s
	return s

## Efecto: dist = distancia al héroe para atenuar (0 = cerca).
func play(n: String, dist := 0.0, pitch_var := 0.08, vol_add := 0.0, pitch := 1.0) -> void:
	var key := n
	if VARIANTS.has(n):
		key = n + str(randi() % VARIANTS[n])
	var s := _stream(key)
	if s == null:
		return
	var p: AudioStreamPlayer = null
	for q in _pool:
		if not q.playing:
			p = q
			break
	if p == null:
		p = _pool[randi() % _pool.size()]
	p.stream = s
	p.volume_db = VOL.get(n, -6.0) + vol_add - clampf(dist - 3.0, 0.0, 20.0) * 0.8
	p.pitch_scale = pitch * (1.0 + randf_range(-pitch_var, pitch_var))
	p.play()

func music(n: String, fade := 1.5) -> void:
	if n == _cur_name:
		return
	_cur_name = n
	var old := _mus[_cur]
	_cur = 1 - _cur
	var nw := _mus[_cur]
	var s := _stream("mus_" + n)
	if s is AudioStreamOggVorbis:
		s.loop = not (n == "victoria" or n == "derrota")
	nw.stream = s
	nw.volume_db = -40.0
	if s:
		nw.play()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(old, "volume_db", -60.0, fade)
	tw.tween_property(nw, "volume_db", _music_db if music_on else -80.0, fade * 0.7)
	tw.chain().tween_callback(old.stop)

func ambience(n: String) -> void:
	var s := _stream("amb_" + n)
	if s is AudioStreamOggVorbis:
		s.loop = true
	_amb.stream = s
	if s:
		_amb.play()

func set_music(on: bool) -> void:
	music_on = on
	_mus[_cur].volume_db = _music_db if on else -80.0
	_amb.volume_db = -14.0 if on else -80.0

# ---------------- narrador ----------------
func _pick_voice() -> void:
	if not DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
		return
	var voices := DisplayServer.tts_get_voices()
	var best := ""
	var score := -1
	for v in voices:
		var lang := String(v.get("language", "")).to_lower()
		if not lang.begins_with("es"):
			continue
		var sc := 1
		for pref in ["co", "419", "mx", "us"]:
			if pref in lang:
				sc = 3
		if "es_es" in lang or "es-es" in lang:
			sc = 2
		if sc > score:
			score = sc
			best = v.get("id", "")
	_voice = best

func say(text: String) -> void:
	if not voice_on or _voice == "":
		return
	DisplayServer.tts_stop()
	DisplayServer.tts_speak(text.replace("\n", " "), _voice, 85, 0.92, 0.98)

func hush() -> void:
	if DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
		DisplayServer.tts_stop()

func _process(dt: float) -> void:
	# baja la música mientras habla el narrador
	var speaking := _voice != "" and voice_on and DisplayServer.tts_is_speaking()
	var target := -7.0 if speaking else 0.0
	_duck = move_toward(_duck, target, dt * 12.0)
	if music_on and _mus[_cur].playing and not get_tree().get_processed_tweens().size():
		_mus[_cur].volume_db = _music_db + _duck
