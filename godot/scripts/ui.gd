class_name GameUI
extends CanvasLayer
## Controles táctiles (joystick, botones, arrastre de cámara) y HUD.

signal play_pressed
signal retry_pressed
signal continue_pressed
signal story_done(tag: String)
signal toggle_pressed(which: String)

var move := Vector2.ZERO
var atk_edge := false
var roll_edge := false
var ira_edge := false
var blk_key := false
var story: Control
var story_tag := ""
var guard_v := 1.0
var rage_full := false
var cam_delta := Vector2.ZERO

var _joy_id := -1
var _joy_origin := Vector2.ZERO
var _cam_id := -1
var _cam_last := Vector2.ZERO
var _btn_ids := {}
var font: FontFile
var font_b: FontFile

var root: Control
var hp_bar: ColorRect
var ira_bar: ColorRect
var score_l: Label
var wave_l: Label
var banner: Label
var boss_box: Control
var boss_bar: ColorRect
var boss_l: Label
var menu: Control
var over: Control
var flash: ColorRect
var pad: Control
var joy_base := Vector2.ZERO
var joy_knob := Vector2.ZERO
var joy_on := false
var buttons := {}
var banner_t := 0.0
var flash_v := 0.0
var playing := false

func _ready() -> void:
	font_b = load("res://assets/fonts/cinzel.woff2")
	font = load("res://assets/fonts/alegreya.woff2")
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var vig := TextureRect.new()
	var vg := Gradient.new()
	vg.set_color(0, Color(0, 0, 0, 0))
	vg.add_point(0.55, Color(0, 0, 0, 0))
	vg.set_color(vg.get_point_count() - 1, Color(0.03, 0.01, 0.0, 0.55))
	var vt := GradientTexture2D.new()
	vt.gradient = vg
	vt.fill = GradientTexture2D.FILL_RADIAL
	vt.fill_from = Vector2(0.5, 0.5)
	vt.fill_to = Vector2(1.05, 0.5)
	vt.width = 256
	vt.height = 256
	vig.texture = vt
	vig.stretch_mode = TextureRect.STRETCH_SCALE
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(vig)
	flash = ColorRect.new()
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(0.6, 0.1, 0.05, 0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(flash)
	pad = Control.new()
	pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.draw.connect(_draw_pad)
	root.add_child(pad)
	_build_hud()
	_build_menu()
	_build_over()
	set_playing(false)

func _lbl(txt: String, size: int, bold := true) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_override("font", font_b if bold else font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(0.94, 0.79, 0.58))
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _bar(parent: Control, pos: Vector2, w: float, col: Color) -> ColorRect:
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.06, 0.04, 0.8)
	bg.position = pos
	bg.size = Vector2(w, 14)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bg)
	var fg := ColorRect.new()
	fg.color = col
	fg.position = Vector2(2, 2)
	fg.size = Vector2(w - 4, 10)
	fg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(fg)
	return fg

func _build_hud() -> void:
	var panel := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.05, 0.03, 0.45)
	sb.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", sb)
	panel.position = Vector2(12, 10)
	panel.size = Vector2(250, 84)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.name = "hudpanel"
	root.add_child(panel)
	var l1 := _lbl("Vida", 15)
	l1.position = Vector2(12, 4)
	panel.add_child(l1)
	hp_bar = _bar(panel, Vector2(12, 26), 226, Color(0.62, 0.17, 0.1))
	var l2 := _lbl("Ira", 15)
	l2.position = Vector2(12, 42)
	panel.add_child(l2)
	ira_bar = _bar(panel, Vector2(12, 64), 226, Color(0.94, 0.79, 0.58))
	score_l = _lbl("0", 26)
	score_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_l.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	score_l.position = Vector2(-220, 8)
	score_l.size = Vector2(200, 30)
	root.add_child(score_l)
	wave_l = _lbl("Tebas · Oleada 1", 15)
	wave_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	wave_l.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	wave_l.position = Vector2(-320, 42)
	wave_l.size = Vector2(300, 24)
	root.add_child(wave_l)
	banner = _lbl("", 48)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	banner.position = Vector2(-400, 140)
	banner.size = Vector2(800, 60)
	banner.modulate.a = 0
	root.add_child(banner)
	boss_box = Control.new()
	boss_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	boss_box.position = Vector2(-170, 70)
	boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(boss_box)
	boss_l = _lbl("Jefe", 16)
	boss_l.size = Vector2(340, 20)
	boss_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_box.add_child(boss_l)
	boss_bar = _bar(boss_box, Vector2(0, 24), 340, Color(0.62, 0.17, 0.1))
	boss_box.visible = false

func _btn(txt: String, primary := true) -> Button:
	var b := Button.new()
	b.text = txt
	b.add_theme_font_override("font", font_b)
	b.add_theme_font_size_override("font_size", 26)
	b.custom_minimum_size = Vector2(300, 64)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.77, 0.4, 0.18) if primary else Color(0.12, 0.07, 0.04, 0.9)
	sb.set_corner_radius_all(32)
	sb.border_color = Color(0.94, 0.79, 0.58)
	sb.set_border_width_all(2)
	for k in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(k, sb)
	b.add_theme_color_override("font_color", Color(0.1, 0.06, 0.04) if primary else Color(0.94, 0.79, 0.58))
	b.add_theme_color_override("font_hover_color", Color(0.1, 0.06, 0.04) if primary else Color(0.94, 0.79, 0.58))
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return b

func _screen(title: String, text: String, btns: Array) -> Control:
	var c := ColorRect.new()
	c.color = Color(0.07, 0.04, 0.03, 0.84)
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(c)
	var sc := ScrollContainer.new()
	sc.set_anchors_preset(Control.PRESET_FULL_RECT)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	c.add_child(sc)
	var cc := CenterContainer.new()
	cc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.add_child(cc)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 16)
	cc.add_child(v)
	var t := _lbl(title, 52)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(t)
	var p := _lbl(text, 22, false)
	p.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p.add_theme_color_override("font_color", Color(0.95, 0.87, 0.76))
	v.add_child(p)
	var bl: Array = []
	for i in range(btns.size()):
		var b := _btn(btns[i][0], i == 0)
		b.pressed.connect(btns[i][1])
		v.add_child(b)
		bl.append(b)
	c.set_meta("title", t)
	c.set_meta("text", p)
	c.set_meta("btns", bl)
	c.resized.connect(func():
		var w := minf(640.0, c.size.x - 48.0)
		t.custom_minimum_size.x = w
		p.custom_minimum_size.x = w)
	return c

func _build_menu() -> void:
	menu = _screen("Ira del Olimpo", "Tebas, Creta, el Inframundo y el Olimpo. Un hoplita sin dios contra los monstruos de los dioses.", [["Nuevo juego", func(): play_pressed.emit()], ["Continuar", func(): continue_pressed.emit()], ["Música: sí", func(): toggle_pressed.emit("music")], ["Narrador: sí", func(): toggle_pressed.emit("voice")]])
	for i in [2, 3]:
		var b: Button = menu.get_meta("btns")[i]
		b.custom_minimum_size = Vector2(240, 48)
		b.add_theme_font_size_override("font_size", 20)

func set_toggles(music_on: bool, voice_on: bool) -> void:
	menu.get_meta("btns")[2].text = "Música: " + ("sí" if music_on else "no")
	menu.get_meta("btns")[3].text = "Narrador: " + ("sí" if voice_on else "no")

func _build_over() -> void:
	over = _screen("Has caído", "", [["Reintentar", func(): retry_pressed.emit()]])
	over.visible = false
	story = _screen("", "", [["Continuar", func(): story_done.emit(story_tag)]])
	story.visible = false

func hide_screens() -> void:
	menu.visible = false
	over.visible = false
	story.visible = false

func show_story(title: String, text: String, btn: String, tag: String) -> void:
	hide_screens()
	set_playing(false)
	story_tag = tag
	story.get_meta("title").text = title
	story.get_meta("text").text = text
	story.get_meta("btns")[0].text = btn
	story.visible = true

func set_playing(on: bool) -> void:
	playing = on
	menu.visible = false if on else menu.visible
	root.get_node("hudpanel").visible = on
	score_l.visible = on
	wave_l.visible = on
	pad.queue_redraw()

func show_menu(can_continue := false, world_name := "") -> void:
	hide_screens()
	menu.visible = true
	var cb: Button = menu.get_meta("btns")[1]
	cb.visible = can_continue
	cb.text = "Continuar: " + world_name
	set_playing(false)

func show_over(txt: String) -> void:
	over.get_meta("text").text = txt
	hide_screens()
	over.visible = true
	playing = false
	pad.queue_redraw()

func set_banner(t: String) -> void:
	banner.text = t
	banner_t = 2.2

func hurt_flash() -> void:
	flash.color = Color(0.6, 0.1, 0.05, flash.color.a)
	flash_v = 0.35

func screen_flash(col: Color, a: float) -> void:
	flash.color = Color(col.r, col.g, col.b, flash.color.a)
	flash_v = a

func update_hud(hero: Hero, score: int, wave_txt: String, boss: Enemy) -> void:
	hp_bar.size.x = 222.0 * clampf(hero.hp / hero.max_hp, 0, 1)
	ira_bar.size.x = 222.0 * clampf(hero.rage / 100.0, 0, 1)
	score_l.text = str(score)
	wave_l.text = wave_txt
	boss_box.visible = playing and boss != null
	if boss:
		boss_bar.size.x = 336.0 * clampf(boss.hp / boss.max_hp, 0, 1)
	var gv := hero.guard / 100.0
	var rf := hero.rage >= 100.0
	if absf(gv - guard_v) > 0.01 or rf != rage_full:
		guard_v = gv
		rage_full = rf
		pad.queue_redraw()

func _process(dt: float) -> void:
	banner_t -= dt
	banner.modulate.a = clampf(banner_t * 2.0, 0, 1) if playing else 0.0
	flash_v = maxf(0.0, flash_v - dt * 1.6)
	flash.color.a = flash_v

# ---------- controles ----------
func _layout() -> Dictionary:
	var s := root.get_viewport_rect().size
	var u := clampf(minf(s.x, s.y) / 420.0, 0.8, 1.6)
	return {
		"atk": {"c": Vector2(s.x - 84 * u, s.y - 94 * u), "r": 50 * u, "t": "Golpe"},
		"roll": {"c": Vector2(s.x - 196 * u, s.y - 60 * u), "r": 37 * u, "t": "Esquivar"},
		"blk": {"c": Vector2(s.x - 70 * u, s.y - 218 * u), "r": 38 * u, "t": "Escudo"},
		"ira": {"c": Vector2(s.x - 182 * u, s.y - 178 * u), "r": 34 * u, "t": "Ira"},
		"joy_r": 58 * u,
		"joy_home": Vector2(110 * u, s.y - 120 * u),
	}

func _draw_pad() -> void:
	if not playing:
		return
	var L := _layout()
	var base: Vector2 = joy_base if joy_on else L.joy_home
	pad.draw_circle(base, L.joy_r, Color(0.1, 0.06, 0.04, 0.35))
	pad.draw_arc(base, L.joy_r, 0, TAU, 48, Color(0.94, 0.79, 0.58, 0.5), 2.0)
	pad.draw_circle(base + (joy_knob if joy_on else Vector2.ZERO), L.joy_r * 0.42, Color(0.94, 0.79, 0.58, 0.9))
	for k in ["atk", "roll", "blk", "ira"]:
		if k == "ira" and not rage_full:
			continue
		var b: Dictionary = L[k]
		var on := _btn_ids.values().has(k)
		var base_c := Color(0.55, 0.1, 0.05, 0.85) if k == "ira" else Color(0.1, 0.06, 0.04, 0.6)
		pad.draw_circle(b.c, b.r, Color(0.77, 0.4, 0.18, 0.9) if on else base_c)
		pad.draw_arc(b.c, b.r, 0, TAU, 48, Color(0.94, 0.79, 0.58), 2.0)
		if k == "blk":
			pad.draw_arc(b.c, b.r + 5, -PI / 2, -PI / 2 + TAU * guard_v, 48, Color(0.55, 0.75, 0.95, 0.9) if guard_v > 0.3 else Color(0.9, 0.3, 0.2), 4.0)
		var fs := int(b.r * (0.34 if k == "atk" else (0.42 if k == "ira" else 0.3)))
		var w := font_b.get_string_size(b.t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		pad.draw_string(font_b, b.c + Vector2(-w / 2, fs * 0.35), b.t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.94, 0.79, 0.58))

func _input(e: InputEvent) -> void:
	if not playing:
		return
	if e is InputEventScreenTouch:
		var L := _layout()
		if e.pressed:
			for k in ["atk", "roll", "blk", "ira"]:
				if k == "ira" and not rage_full:
					continue
				if e.position.distance_to(L[k].c) < L[k].r * 1.15:
					_btn_ids[e.index] = k
					if k == "atk": atk_edge = true
					elif k == "roll": roll_edge = true
					elif k == "ira": ira_edge = true
					pad.queue_redraw()
					return
			var s := root.get_viewport_rect().size
			if e.position.x < s.x * 0.45 and e.position.y > s.y * 0.38 and _joy_id < 0:
				_joy_id = e.index
				joy_on = true
				joy_base = e.position
				joy_knob = Vector2.ZERO
				move = Vector2.ZERO
				pad.queue_redraw()
				return
			if _cam_id < 0:
				_cam_id = e.index
				_cam_last = e.position
		else:
			if _btn_ids.has(e.index):
				_btn_ids.erase(e.index)
			if e.index == _joy_id:
				_joy_id = -1
				joy_on = false
				move = Vector2.ZERO
			if e.index == _cam_id:
				_cam_id = -1
			pad.queue_redraw()
	elif e is InputEventScreenDrag:
		if e.index == _joy_id:
			var L := _layout()
			var d: Vector2 = e.position - joy_base
			if d.length() > L.joy_r:
				d = d.normalized() * L.joy_r
			joy_knob = d
			move = d / L.joy_r
			pad.queue_redraw()
		elif e.index == _cam_id:
			cam_delta += e.position - _cam_last
			_cam_last = e.position

func read() -> Dictionary:
	var kmove := Vector2(Input.get_axis("ui_left", "ui_right"), Input.get_axis("ui_up", "ui_down"))
	if Input.is_physical_key_pressed(KEY_A): kmove.x -= 1
	if Input.is_physical_key_pressed(KEY_D): kmove.x += 1
	if Input.is_physical_key_pressed(KEY_W): kmove.y -= 1
	if Input.is_physical_key_pressed(KEY_S): kmove.y += 1
	var m := move + kmove
	if m.length() > 1.0:
		m = m.normalized()
	var blk := _btn_ids.values().has("blk") or Input.is_physical_key_pressed(KEY_L) or Input.is_physical_key_pressed(KEY_SHIFT)
	var r := {"move": m, "atk": atk_edge, "roll": roll_edge, "cam": cam_delta, "blk": blk, "ira": ira_edge}
	atk_edge = false
	roll_edge = false
	ira_edge = false
	cam_delta = Vector2.ZERO
	return r

func _unhandled_key_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		if e.physical_keycode == KEY_J: atk_edge = true
		if e.physical_keycode == KEY_K: roll_edge = true
