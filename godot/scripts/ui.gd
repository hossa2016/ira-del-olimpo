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
var hud: Control
var vig: TextureRect
var hp_v := 1.0
var hp_ghost := 1.0
var ghost_t := 0.0
var rage_v := 0.0
var boss_v := 1.0
var boss_ghost := 1.0
var boss_on := false
var boss_name := ""
var clock := 0.0
var _press := {}

func _ready() -> void:
	font_b = load("res://assets/fonts/cinzel.woff2")
	font = load("res://assets/fonts/alegreya.woff2")
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	vig = TextureRect.new()
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
	panel.self_modulate.a = 0.0
	for c in panel.get_children():
		c.visible = false
	boss_box.modulate.a = 0.0
	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.draw.connect(_draw_hud)
	root.add_child(hud)
	root.move_child(hud, panel.get_index())

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
	var nh := clampf(hero.hp / hero.max_hp, 0, 1)
	if nh < hp_v - 0.001:
		ghost_t = 0.55
	hp_v = nh
	rage_v = clampf(hero.rage / 100.0, 0, 1)
	score_l.text = str(score)
	wave_l.text = wave_txt
	boss_on = playing and boss != null
	if boss:
		var nb := clampf(boss.hp / boss.max_hp, 0, 1)
		if not boss_on or boss_name != boss.title:
			boss_ghost = nb
		boss_v = nb
		boss_name = boss.title
	hud.queue_redraw()
	var gv := hero.guard / 100.0
	var rf := hero.rage >= 100.0
	if absf(gv - guard_v) > 0.01 or rf != rage_full:
		guard_v = gv
		rage_full = rf
		pad.queue_redraw()

func _process(dt: float) -> void:
	clock += dt
	ghost_t -= dt
	if ghost_t <= 0.0:
		hp_ghost = move_toward(hp_ghost, hp_v, dt * 0.6)
	if hp_ghost < hp_v:
		hp_ghost = hp_v
	boss_ghost = move_toward(boss_ghost, boss_v, dt * 0.25)
	for k in _press.keys():
		_press[k] = move_toward(_press[k], 1.0 if _btn_ids.values().has(k) else 0.0, dt * 14.0)
	# vida baja: los bordes laten en rojo
	var low := clampf((0.3 - hp_v) / 0.3, 0.0, 1.0) if playing else 0.0
	vig.modulate = Color(1.0 + low * 1.5, 1.0 - low * 0.4, 1.0 - low * 0.4, 1.0 + low * (0.5 + 0.5 * sin(clock * 6.0)))
	if playing and (rage_full or not _press.is_empty()):
		pad.queue_redraw()
	banner_t -= dt
	banner.modulate.a = clampf(banner_t * 2.0, 0, 1) if playing else 0.0
	flash_v = maxf(0.0, flash_v - dt * 1.6)
	flash.color.a = flash_v

# ---------- HUD ----------
const BRONZE := Color(0.86, 0.66, 0.38)
const BRONZE_D := Color(0.42, 0.28, 0.15)
const INK := Color(0.07, 0.045, 0.03, 0.78)

func _bar_shape(o: Vector2, w: float, h: float, slant: float) -> PackedVector2Array:
	return PackedVector2Array([o + Vector2(slant, 0), o + Vector2(w, 0), o + Vector2(w - slant, h), o + Vector2(0, h)])

func _fill_bar(o: Vector2, w: float, h: float, v: float, ghost: float, c1: Color, c2: Color, slant := 6.0) -> void:
	var shp := _bar_shape(o, w, h, slant)
	hud.draw_colored_polygon(shp, INK)
	var iw := w - 4.0
	if ghost > v:
		hud.draw_colored_polygon(_bar_shape(o + Vector2(2, 2), iw * ghost, h - 4, slant * 0.8), Color(0.95, 0.86, 0.7, 0.85))
	if v > 0.0:
		var fw := iw * v
		var q := _bar_shape(o + Vector2(2, 2), fw, h - 4, slant * 0.8)
		hud.draw_polygon(q, PackedColorArray([c1, c1, c2, c2]))
		# brillo superior
		hud.draw_line(o + Vector2(2 + slant * 0.8, 3), o + Vector2(2 + fw, 3), Color(1, 1, 1, 0.28), 1.5)
	hud.draw_polyline(PackedVector2Array([shp[0], shp[1], shp[2], shp[3], shp[0]]), BRONZE, 1.6, true)

func _draw_hud() -> void:
	if not playing:
		return
	var s := root.get_viewport_rect().size
	var u := clampf(minf(s.x, s.y) / 420.0, 0.8, 1.6)
	# medallón con perfil de casco corintio
	var mc := Vector2(44, 44) * u
	var mr := 30.0 * u
	hud.draw_circle(mc, mr, INK)
	hud.draw_arc(mc, mr, 0, TAU, 48, BRONZE, 2.5 * u, true)
	hud.draw_arc(mc, mr - 4 * u, 0, TAU, 48, BRONZE_D, 1.2 * u, true)
	var hel := PackedVector2Array()
	for k in range(17):
		var a := PI + k / 16.0 * PI
		hel.append(mc + Vector2(cos(a), sin(a) * 1.05) * 14 * u + Vector2(0, 2 * u))
	hel.append(mc + Vector2(14, 14) * u)
	hel.append(mc + Vector2(4, 16) * u)
	hel.append(mc + Vector2(3, 6) * u)
	hel.append(mc + Vector2(-3, 6) * u)
	hel.append(mc + Vector2(-4, 16) * u)
	hel.append(mc + Vector2(-14, 14) * u)
	hud.draw_colored_polygon(hel, BRONZE)
	hud.draw_line(mc + Vector2(-10, -1) * u, mc + Vector2(-3, -1) * u, INK, 2.5 * u)
	hud.draw_line(mc + Vector2(3, -1) * u, mc + Vector2(10, -1) * u, INK, 2.5 * u)
	var crest := PackedVector2Array()
	for k in range(11):
		var a := PI * 1.1 + k / 10.0 * PI * 0.8
		crest.append(mc + Vector2(cos(a), sin(a)) * 21 * u + Vector2(0, 2 * u))
	for k in range(10, -1, -1):
		var a := PI * 1.1 + k / 10.0 * PI * 0.8
		crest.append(mc + Vector2(cos(a), sin(a)) * 14.5 * u + Vector2(0, 2 * u))
	hud.draw_colored_polygon(crest, Color(0.62, 0.1, 0.07))
	# barras
	var bx := 80.0 * u
	var bw := 210.0 * u
	var low := hp_v < 0.3
	var pulse := 0.5 + 0.5 * sin(clock * 7.0)
	_fill_bar(Vector2(bx, 22 * u), bw, 15 * u, hp_v, hp_ghost, Color(0.85, 0.2, 0.12).lightened(pulse * 0.25 if low else 0.0), Color(0.45, 0.05, 0.03), 7 * u)
	var rc1 := Color(1.0, 0.82, 0.45)
	if rage_v >= 1.0:
		rc1 = rc1.lightened(0.3 * pulse)
	_fill_bar(Vector2(bx, 44 * u), bw * 0.82, 9 * u, rage_v, 0.0, rc1, Color(0.85, 0.42, 0.1), 5 * u)
	if rage_v >= 1.0:
		hud.draw_rect(Rect2(Vector2(bx - 2, 42 * u), Vector2(bw * 0.82 + 4, 13 * u)), Color(1, 0.6, 0.2, 0.15 + 0.15 * pulse))
	# barra de jefe
	if boss_on:
		var w := minf(s.x * 0.5, 520.0 * u)
		var o := Vector2((s.x - w) / 2.0, 62 * u)
		_fill_bar(o, w, 14 * u, boss_v, boss_ghost, Color(0.8, 0.18, 0.1), Color(0.4, 0.04, 0.03), 8 * u)
		for side in [-1.0, 1.0]:
			var cx: float = s.x / 2.0 + side * (w / 2.0 + 10 * u)
			var cy := o.y + 7 * u
			hud.draw_colored_polygon(PackedVector2Array([Vector2(cx, cy - 9 * u), Vector2(cx + 7 * u, cy), Vector2(cx, cy + 9 * u), Vector2(cx - 7 * u, cy)]), BRONZE)
		var fs := int(17 * u)
		var tw := font_b.get_string_size(boss_name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		hud.draw_string(font_b, Vector2((s.x - tw) / 2.0 + 1, o.y - 7 * u + 1), boss_name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.8))
		hud.draw_string(font_b, Vector2((s.x - tw) / 2.0, o.y - 7 * u), boss_name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.96, 0.84, 0.62))

# ---------- iconos de botones ----------
func _icon(k: String, c: Vector2, r: float, col: Color) -> void:
	match k:
		"atk":  # xiphos en diagonal
			var d := Vector2(0.7, -0.7)
			var n := Vector2(0.7, 0.7)
			var tip := c + d * r * 0.62
			var base := c - d * r * 0.18
			pad.draw_colored_polygon(PackedVector2Array([tip, base + n * r * 0.09, base - n * r * 0.09]), col)
			pad.draw_line(base + n * r * 0.22, base - n * r * 0.22, col, r * 0.08)
			pad.draw_line(base, c - d * r * 0.5, col.darkened(0.25), r * 0.1)
			pad.draw_circle(c - d * r * 0.55, r * 0.07, col)
		"roll":  # flecha curva
			pad.draw_arc(c, r * 0.4, PI * 0.15, PI * 1.55, 24, col, r * 0.09, true)
			var e := c + Vector2(cos(PI * 0.15), sin(PI * 0.15)) * r * 0.4
			pad.draw_colored_polygon(PackedVector2Array([e + Vector2(r * 0.18, -r * 0.05), e + Vector2(-r * 0.12, -r * 0.14), e + Vector2(-r * 0.02, r * 0.17)]), col)
		"blk":  # aspis
			pad.draw_circle(c, r * 0.46, col.darkened(0.35))
			pad.draw_arc(c, r * 0.46, 0, TAU, 32, col, r * 0.08, true)
			pad.draw_arc(c, r * 0.27, 0, TAU, 32, col, r * 0.05, true)
			pad.draw_circle(c, r * 0.09, col)
		"ira":  # llama
			var f := PackedVector2Array()
			for k2 in range(21):
				var t := k2 / 20.0
				var a := t * TAU
				var rr := r * 0.42 * (0.55 + 0.45 * absf(sin(a * 1.5)))
				var p := Vector2(sin(a) * rr * 0.7, -cos(a) * rr * (1.3 if cos(a) > 0 else 0.8))
				f.append(c + p + Vector2(0, r * 0.08))
			pad.draw_colored_polygon(f, col)

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
	pad.draw_circle(base, L.joy_r, Color(0.05, 0.03, 0.02, 0.32))
	pad.draw_arc(base, L.joy_r, 0, TAU, 56, Color(0.86, 0.66, 0.38, 0.55), 2.0, true)
	for k in range(4):
		var a := k * PI / 2
		var p: Vector2 = base + Vector2(cos(a), sin(a)) * L.joy_r * 0.8
		pad.draw_colored_polygon(PackedVector2Array([p + Vector2(cos(a), sin(a)) * 6, p + Vector2(cos(a + 2.2), sin(a + 2.2)) * 5, p + Vector2(cos(a - 2.2), sin(a - 2.2)) * 5]), Color(0.86, 0.66, 0.38, 0.45))
	var kp: Vector2 = base + (joy_knob if joy_on else Vector2.ZERO)
	pad.draw_circle(kp, L.joy_r * 0.42, Color(0.12, 0.08, 0.05, 0.75))
	pad.draw_circle(kp + Vector2(0, -2), L.joy_r * 0.36, Color(0.86, 0.66, 0.38, 0.9))
	pad.draw_arc(kp, L.joy_r * 0.42, 0, TAU, 32, Color(0.42, 0.28, 0.15), 2.0, true)
	for k in ["atk", "roll", "blk", "ira"]:
		if k == "ira" and not rage_full:
			continue
		var b: Dictionary = L[k]
		if not _press.has(k):
			_press[k] = 0.0
		var pr: float = _press[k]
		var r: float = b.r * (1.0 - pr * 0.08)
		var ira: bool = k == "ira"
		var glow := 0.5 + 0.5 * sin(clock * 5.0)
		if ira:
			pad.draw_circle(b.c, r * (1.18 + glow * 0.1), Color(1, 0.4, 0.1, 0.18 + glow * 0.12))
		# cuerpo: disco oscuro con degradado, anillo de bronce y reflejo
		pad.draw_circle(b.c, r, Color(0.05, 0.03, 0.02, 0.55))
		pad.draw_circle(b.c + Vector2(0, -r * 0.08), r * 0.88, (Color(0.55, 0.12, 0.05, 0.75) if ira else Color(0.16, 0.1, 0.06, 0.55)).lerp(Color(0.85, 0.5, 0.2, 0.85), pr))
		pad.draw_arc(b.c, r, 0, TAU, 56, BRONZE_D, 4.0, true)
		pad.draw_arc(b.c, r - 1.5, 0, TAU, 56, BRONZE, 1.8, true)
		pad.draw_arc(b.c, r - 4, PI * 1.1, PI * 1.6, 16, Color(1, 0.95, 0.85, 0.35), 2.0, true)
		if k == "blk":
			pad.draw_arc(b.c, r + 6, -PI / 2, -PI / 2 + TAU * guard_v, 48, Color(0.6, 0.8, 1.0, 0.9) if guard_v > 0.3 else Color(0.95, 0.3, 0.2), 3.5, true)
		var icol := Color(0.96, 0.86, 0.66).lerp(Color(1, 1, 1), pr)
		_icon(k, b.c + Vector2(0, -r * 0.1), r, icol)
		var fs := int(maxf(10.0, r * 0.2))
		var w := font_b.get_string_size(b.t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		pad.draw_string(font_b, b.c + Vector2(-w / 2, r * 0.62), b.t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.96, 0.86, 0.66, 0.85))

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
