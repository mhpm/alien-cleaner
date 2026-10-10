class_name IntroScreen
extends Control
## First-run intro cinematic: how the invasion began, told with the user's 9 scenes
## (tools/intro/scene_<n>.webp -> python tools/make_intro_assets.py -> assets/ui/intro/).
## Shown once, the first time a new player starts WORLD 1 (Game.intro_seen, saved), then
## the level starts. The STORY button on WORLD 1 replays it (`replay`: back to the world
## select afterwards). Each panel pops in like a comic frame, drifts and zooms slowly (Ken
## Burns) while its caption types out underneath; some panels add a beat of their own
## (glass shatter + shake, red alarm, the blaster's shot). Tap = finish the text / next
## panel, SKIP = straight to the game. Music: levels3.mp3 (the darker, longer track).

const ART := "res://assets/ui/intro/"
const GAME_SCENE := "res://scenes/game.tscn"
const WORLD_SCENE := "res://scenes/world_select.tscn"

## Set by the STORY button of the world select: watch it again and go back there.
static var replay := false
const MUSIC := "res://assets/music/levels/levels3.mp3"
const LOGO := "res://assets/ui/main/image_001.png"
const TYPE_CPS := 38.0  # caption letters per second
const HOLD := 2.4  # seconds a finished caption stays before the next panel
const SHOT := 5.5  # Ken Burns length of one panel

## Story beats (one per scene tools/intro/scene_<n>.webp): caption, zoom from -> to,
## drift (fraction of the panel), effect.
const PANELS := [
	{"text": "Year 2187. Research station HOPE-9 orbits a quiet blue world at the edge of known space.", "z": [1.0, 1.07], "pan": Vector2(-0.02, 0.0), "fx": ""},
	{"text": "Inside an asteroid, the crew found something impossible: a living cell.", "z": [1.05, 1.0], "pan": Vector2(0.0, -0.02), "fx": "hum"},
	{"text": "They studied it. They poked it. They fed it.
It grew... and it watched them back.", "z": [1.0, 1.12], "pan": Vector2(0.01, 0.02), "fx": "pulse"},
	{"text": "Then, one night, the glass gave way.", "z": [1.1, 1.0], "pan": Vector2(0.0, 0.0), "fx": "shatter"},
	{"text": "It split. And split again.
By morning, the lower decks were crawling.", "z": [1.0, 1.08], "pan": Vector2(0.02, 0.0), "fx": "goo"},
	{"text": "ALERT! HULL BREACH!
ALL CREW, EVACUATE NOW!", "z": [1.03, 1.1], "pan": Vector2(0.0, 0.0), "fx": "alarm"},
	{"text": "The slime swallowed the station...
and spilled out toward every world.", "z": [1.08, 1.0], "pan": Vector2(0.02, 0.01), "fx": "goo"},
	{"text": "Everyone ran. Except the cleanup crew.
This mess is our job.", "z": [1.0, 1.08], "pan": Vector2(0.0, -0.02), "fx": "gear"},
	{"text": "Grab your blasters, rookies.
Time to clean up this galaxy!", "z": [1.0, 1.06], "pan": Vector2(0.02, 0.0), "fx": "blast"},
]

var stars: Array[Vector3] = []  # x, y, phase
var frame: Control  # clips the panel
var pic: TextureRect
var flash: ColorRect
var tint: ColorRect
var caption: Label
var cap_box: PanelContainer
var hint: Label
var skip_btn: Button
var dots: HBoxContainer
var idx := -1
var t := 0.0
var shown := 0.0  # letters shown
var shot_t := 0.0
var done_t := 0.0
var shake := 0.0
var ending := false
var _tw: Tween


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	for i in 90:
		stars.append(Vector3(randf(), randf(), randf() * TAU))
	Sfx.play_music("level:" + MUSIC)
	_build()
	resized.connect(_layout)
	_layout()
	_next()


func _build() -> void:
	frame = Control.new()  # not clipped: the scenes are stickers, they zoom past their box
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	pic = TextureRect.new()
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(pic)
	tint = ColorRect.new()
	tint.color = Color(1, 0, 0, 0)
	tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tint)
	cap_box = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.05, 0.12, 0.92)
	sb.border_color = Color("41a6f6")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	cap_box.add_theme_stylebox_override("panel", sb)
	cap_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cap_box)
	caption = UiTheme.body("", 15, Color("eaf4ff"))
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.custom_minimum_size = Vector2(0, 58)
	cap_box.add_child(caption)
	hint = UiTheme.label("TAP", 10, Color("73eff7"))
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint)
	dots = HBoxContainer.new()
	dots.alignment = BoxContainer.ALIGNMENT_CENTER
	dots.add_theme_constant_override("separation", 6)
	dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in PANELS.size():
		var d := ColorRect.new()
		d.custom_minimum_size = Vector2(8, 8)
		d.color = Color("333c57")
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dots.add_child(d)
	add_child(dots)
	skip_btn = UiTheme.button("SKIP >>", Color("263e5f"), 12, Vector2(84, 30))
	skip_btn.focus_mode = Control.FOCUS_NONE
	skip_btn.pressed.connect(_finish)
	add_child(skip_btn)
	flash = ColorRect.new()
	flash.color = Color(1, 1, 1, 0)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)


func _layout() -> void:
	var sr := UiTheme.safe_rect(self)
	var w := minf(sr.size.x - 24.0, 420.0)
	var fh := minf(w * 1.2, sr.size.y * 0.56)  # the scenes are portrait (~0.82 wide per tall)
	frame.size = Vector2(w, fh)
	frame.position = Vector2(sr.position.x + (sr.size.x - w) * 0.5, sr.position.y + sr.size.y * 0.4 - fh * 0.5)
	frame.pivot_offset = frame.size * 0.5
	cap_box.size = Vector2(w, 0)
	cap_box.position = Vector2(frame.position.x, frame.position.y + fh + 18.0)
	hint.position = Vector2(frame.position.x + w - 30.0, cap_box.position.y + 92.0)
	dots.size = Vector2(w, 10)
	dots.position = Vector2(frame.position.x, frame.position.y - 26.0)
	skip_btn.position = Vector2(sr.end.x - 96.0, sr.position.y + 10.0)


func _next() -> void:
	idx += 1
	if idx >= PANELS.size():
		_ending()
		return
	var p: Dictionary = PANELS[idx]
	pic.texture = load(ART + "panel_%d.png" % (idx + 1))
	caption.text = str(p.text)
	caption.visible_characters = 0
	shown = 0.0
	shot_t = 0.0
	done_t = 0.0
	for i in dots.get_child_count():
		(dots.get_child(i) as ColorRect).color = Color("ffcd75") if i == idx else (Color("41a6f6") if i < idx else Color("333c57"))
	# comic pop: in from slightly small and tilted, with a white blink
	if _tw != null:
		_tw.kill()
	frame.scale = Vector2(0.86, 0.86)
	frame.rotation = randf_range(-0.05, 0.05)
	frame.modulate.a = 0.0
	_tw = create_tween().set_parallel()
	_tw.tween_property(frame, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tw.tween_property(frame, "rotation", 0.0, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tw.tween_property(frame, "modulate:a", 1.0, 0.2)
	flash.color.a = 0.35
	create_tween().tween_property(flash, "color:a", 0.0, 0.3)
	Sfx.play("select", 0.1, -10.0)
	_beat(str(p.fx))


## The panel's own beat.
func _beat(fx: String) -> void:
	tint.color = Color(1, 0, 0, 0)
	match fx:
		"shatter":
			shake = 10.0
			flash.color = Color(0.8, 1.0, 0.85, 0.9)
			create_tween().tween_property(flash, "color:a", 0.0, 0.5)
			Sfx.play("explode", 0.0, -2.0)
			Sfx.play("goo", 0.0, -4.0)
		"goo":
			Sfx.play("goo", 0.1, -6.0)
		"hum":
			Sfx.play("charge", 0.0, -10.0)
		"pulse":
			Sfx.play("zap", 0.0, -10.0)
		"alarm":
			Sfx.play("alert", 0.0, -2.0)
			shake = 4.0
		"gear":
			Sfx.play("upgrade", 0.0, -8.0)
		"blast":
			get_tree().create_timer(0.5).timeout.connect(func() -> void:
				if idx == PANELS.size() - 1 and not ending:
					flash.color = Color(0.6, 0.9, 1.0, 0.8)
					create_tween().tween_property(flash, "color:a", 0.0, 0.35)
					shake = 6.0
					Sfx.play("laser", 0.0, -3.0))


func _process(delta: float) -> void:
	t += delta
	queue_redraw()
	if ending:
		return
	var p: Dictionary = PANELS[idx]
	# Ken Burns: slow zoom and drift across the shot
	shot_t += delta
	var k := clampf(shot_t / SHOT, 0.0, 1.0)
	var e := k * k * (3.0 - 2.0 * k)
	var z: Array = p.z
	var zoom := lerpf(float(z[0]), float(z[1]), e)
	var pan: Vector2 = p.pan
	pic.size = frame.size * zoom
	pic.position = (frame.size - pic.size) * 0.5 + pan * frame.size * (e - 0.5) * 2.0
	if shake > 0.0:
		pic.position += Vector2(randf_range(-shake, shake), randf_range(-shake, shake))
		shake = move_toward(shake, 0.0, delta * 18.0)
	match str(p.fx):
		"alarm":
			tint.color = Color(1, 0, 0, 0.12 + 0.12 * sin(t * 9.0))
		"pulse":
			pic.modulate = Color(1.0, 1.0 + 0.12 * sin(t * 4.0), 1.0)
		_:
			pic.modulate = Color.WHITE
	# typewriter caption
	var total := caption.get_total_character_count()
	if shown < total:
		var before := int(shown)
		shown = minf(shown + TYPE_CPS * delta, total)
		caption.visible_characters = int(shown)
		if int(shown) != before and int(shown) % 3 == 0:
			Sfx.play("select", 0.3, -24.0)
	else:
		done_t += delta
		if done_t > HOLD:
			_next()
	hint.visible = shown >= total and fmod(t, 0.8) < 0.5


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("070912"))
	for s in stars:
		var a := 0.35 + 0.35 * sin(t * 1.5 + s.z)
		var p := Vector2(fposmod(s.x * size.x - t * 6.0 * (0.4 + s.z / TAU), size.x), s.y * size.y)
		draw_rect(Rect2(p, Vector2(1.5, 1.5)), Color(0.8, 0.9, 1.0, a))


func _gui_input(ev: InputEvent) -> void:
	var tap: bool = (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT) or (ev is InputEventScreenTouch and ev.pressed)
	if not tap:
		return
	if ending:
		_finish()
		return
	if shown < caption.get_total_character_count():
		shown = caption.get_total_character_count()
		caption.visible_characters = -1
	else:
		_next()


## After the last panel: the game's logo drops in, then the level starts.
func _ending() -> void:
	ending = true
	idx = PANELS.size() - 1
	var tw := create_tween().set_parallel()
	tw.tween_property(frame, "modulate:a", 0.0, 0.4)
	tw.tween_property(cap_box, "modulate:a", 0.0, 0.4)
	tw.tween_property(dots, "modulate:a", 0.0, 0.4)
	hint.visible = false
	var logo := TextureRect.new()
	logo.texture = load(LOGO)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sr := UiTheme.safe_rect(self)
	var lw := minf(sr.size.x - 40.0, 380.0)
	logo.size = Vector2(lw, lw * 318.0 / 557.0)
	logo.position = Vector2(sr.position.x + (sr.size.x - lw) * 0.5, sr.position.y + sr.size.y * 0.3)
	logo.pivot_offset = logo.size * 0.5
	logo.scale = Vector2(1.6, 1.6)
	logo.modulate.a = 0.0
	add_child(logo)
	var lt := logo.create_tween().set_parallel()
	lt.tween_property(logo, "modulate:a", 1.0, 0.3).set_delay(0.3)
	lt.tween_property(logo, "scale", Vector2.ONE, 0.5).set_delay(0.3).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	lt.tween_callback(func() -> void: Sfx.play("land", 0.0, -2.0)).set_delay(0.6)
	var go := UiTheme.title("TAP TO CONTINUE" if replay else "TAP TO START", 18, Color("ffcd75"))
	go.position = Vector2(sr.position.x, logo.position.y + logo.size.y + 30.0)
	go.size = Vector2(sr.size.x, 30)
	go.modulate.a = 0.0
	add_child(go)
	var gt := go.create_tween().set_loops()
	gt.tween_property(go, "modulate:a", 1.0, 0.5).set_delay(0.4)
	gt.tween_property(go, "modulate:a", 0.3, 0.5)
	get_tree().create_timer(6.0).timeout.connect(_finish)


func _finish() -> void:
	if not is_inside_tree() or get_meta("leaving", false):
		return
	set_meta("leaving", true)
	Game.intro_seen = true
	Game.save()
	var to := WORLD_SCENE if replay else GAME_SCENE
	replay = false
	var fade := ColorRect.new()
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.color = Color(0.03, 0.04, 0.08, 0.0)
	add_child(fade)
	var tw := fade.create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.35)
	tw.tween_callback(func() -> void: get_tree().change_scene_to_file(to))
