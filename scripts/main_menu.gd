extends Control
## Title screen, put together from the loose art in assets/ui/main/ (image_NNN.png) and
## the layers made by tools/make_title_assets.py (assets/ui/title/). Everything lives on
## a 720x1280 stage fitted into the safe area (UiTheme.fit_stage).
## Layers, back to front: deep-space sky with twinkling stars, shooting stars, drifting
## asteroids and ships; the hangar with the planet (base.png, ships removed); pulsing door
## lights; the astronaut (seen from behind, in the middle, facing the hangar) blasting up at
## the germs that come out of the door (they pop into goo, tap one to pop it yourself); foreground crates; the logo (drops in, bobs, drips
## slime, a shine sweeps it); the coin counter, the settings gear and PLAY.
## Only PLAY and settings remain here: shop, gear and the rest live on the world select.

const WORLD_SCENE := "res://scenes/world_select.tscn"
const ART_SIZE := Vector2(720, 1280)
const MAIN := "res://assets/ui/main/image_%03d.png"
const TITLE := "res://assets/ui/title/"

const LOGO_POS := Vector2(360, 262)  # centre of the logo (image_001, 557x318)
const LOGO_DRIPS: Array[Vector2] = [Vector2(129, 310), Vector2(426, 310), Vector2(471, 314)]  # logo px
const WALL_DRIPS: Array[Vector2] = [Vector2(62, 650), Vector2(662, 650)]
const DOOR := Vector2(360, 780)  # where germs come out of the hangar
const FLOOR_Y := 1030.0
const ASTRO_FEET := Vector2(360, 1052)  # the astronaut stands in the middle, back to us, facing the door
const ASTRO_SCALE := 0.68
const ASTRO_CANVAS := Vector2(260, 722)  # astro_N.png: body centre at x=130, feet on the bottom edge
const MUZZLE := Vector2(370, 843)  # the barrel's tip
const SPAWN_Y := 690.0  # germs come out of the far end of the hangar corridor
const TARGET := Vector2(366, 712)  # where the beam catches a germ
const ZAP_FRAMES := [1, 2, 3, 2, 3, 2, 3, 4]  # astro_N.png sequence while firing (muzzle burst, beam, big beam, fade)
const ZAP_FPS := 13.0
const GERMS := [36, 32, 33]  # blue, pink, green
const STARS := [3, 7, 8, 9, 10, 11, 12, 13, 14, 17, 18, 19, 20, 21, 22, 27, 29, 30]
const BIG_STARS := [4, 6, 28]
const COMETS := [24, 26, 31]
const GOO := [48, 50, 51, 52, 53, 55, 56, 57]
const ZAP_TIME := 2.2

var t := 0.0
var stage: Control
var sky_layer: Node2D
var fx_layer: Node2D  # additive glows
var actors: Node2D
var logo: Sprite2D
var play_btn: TextureButton
var gear_btn: TextureButton
var bank_label: Label
var hint: Label
var toast: Label
var shine_mat: ShaderMaterial

var stars: Array = []  # [Sprite2D, speed, phase]
var rocks: Array = []  # [Sprite2D, vel x, spin]
var station: Sprite2D
var ufo: Sprite2D
var ufo_t := 0.0
var comet_t := 1.5
var bits: Array = []  # flying bits: {spr, vel, life, max, grav, spin, fade}
var drip_t := 1.0

var astro: Sprite2D
var astro_frames: Array[Texture2D] = []
var zap_t := 0.0
var muzzle_glow: Sprite2D
var astro_mat: ShaderMaterial
var hit_pos := Vector2.ZERO  # where the beam meets the germ
var impact: Sprite2D
var flare: Sprite2D
var germ: Sprite2D
var germ_i := 0
var germ_state := "wait"
var germ_t := 0.3
var germ_from := Vector2.ZERO
var idlers: Array = []  # small germs hovering at the door: [Sprite2D, centre, phase]
var shadows: Node2D


func _ready() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	theme = UiTheme.build()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	resized.connect(_fit_stage)
	_fit_stage()
	_intro()
	Sfx.play_music("menu")
	if PlaygroundSession.enabled():
		var test_button := UiTheme.button("PLAYGROUND", Color("263e5f"), 15, Vector2(180, 36))
		test_button.name = "PlaygroundButton"
		test_button.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		test_button.position = Vector2(get_viewport_rect().size.x * 0.5 - 90, get_viewport_rect().size.y - 50)
		test_button.size = Vector2(180, 36)
		test_button.pressed.connect(func() -> void: get_tree().change_scene_to_file(PlaygroundSession.PICKER))
		add_child(test_button)


func _tex(n: int) -> Texture2D:
	return load(MAIN % n)


func _spr(parent: Node, tex: Texture2D, pos: Vector2, s := 1.0) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = tex
	sp.position = pos
	sp.scale = Vector2(s, s)
	parent.add_child(sp)
	return sp


func _rect(tex: Texture2D, pos: Vector2) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.position = pos
	r.size = tex.get_size()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(r)
	return r


func _layer(additive := false) -> Node2D:
	var n := Node2D.new()
	if additive:
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		n.material = m
	stage.add_child(n)
	return n


func _build() -> void:
	stage = Control.new()
	stage.size = ART_SIZE
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(stage)
	UiTheme.add_backdrop(self, stage, load(TITLE + "bg_full.webp"))

	_rect(load(TITLE + "sky.webp"), Vector2.ZERO)
	sky_layer = _layer()
	_build_sky()
	_rect(load(TITLE + "base.png"), Vector2.ZERO)
	fx_layer = _layer(true)
	fx_layer.draw.connect(_draw_glows)
	shadows = _layer()
	shadows.draw.connect(_draw_shadows)
	actors = _layer()
	_build_actors()

	# foreground props at the bottom corners
	_spr(stage, _tex(44), Vector2(48, 1204), 0.9)
	_spr(stage, _tex(45), Vector2(668, 1214), 0.8)

	shine_mat = ShaderMaterial.new()
	shine_mat.shader = _shine_shader()
	logo = _spr(stage, _tex(1), LOGO_POS)
	logo.material = shine_mat

	# top bar: coins and settings
	_rect(load(TITLE + "coin_pill.png"), Vector2(20, 22))
	bank_label = UiTheme.label("", 48, Color("fbe7b5"))
	bank_label.position = Vector2(84, 37)
	bank_label.size = Vector2(130, 47)
	bank_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bank_label.add_theme_constant_override("outline_size", 10)
	stage.add_child(bank_label)
	gear_btn = _button(_tex(40), Vector2(640, 64), 0.85, _open_settings)

	play_btn = _button(_tex(34), Vector2(360, 1140), 1.0, _play)
	play_btn.material = shine_mat
	hint = UiTheme.label("", 22, Color("9fc3ef"))
	hint.position = Vector2(60, 1208)
	hint.size = Vector2(600, 40)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_constant_override("outline_size", 8)
	stage.add_child(hint)

	toast = UiTheme.label("", 18, Color("ffcd75"))
	toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	toast.size = Vector2(320, 40)
	toast.position -= toast.size * 0.5
	toast.modulate.a = 0.0
	add_child(toast)
	_refresh()


func _button(tex: Texture2D, centre: Vector2, s: float, cb: Callable) -> TextureButton:
	var b := TextureButton.new()
	b.texture_normal = tex
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_SCALE
	b.size = tex.get_size() * s
	b.position = centre - b.size * 0.5
	b.pivot_offset = b.size * 0.5
	b.button_down.connect(_press_fx.bind(b, true))
	b.button_up.connect(_press_fx.bind(b, false))
	b.pressed.connect(func() -> void:
		Sfx.play("select", 0.0)
		cb.call())
	stage.add_child(b)
	return b


## The beam is cut where it hits the germ: fade its cut edge out instead of a hard line.
func _beam_shader() -> Shader:
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
uniform float cut = 0.0;   // UV.y where the visible part starts
uniform float fade = 0.15; // how much of it fades in
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	c.a *= smoothstep(cut, cut + fade, UV.y);
	COLOR = c * COLOR;
}
"""
	return sh


func _shine_shader() -> Shader:
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
uniform float sweep = -1.0; // -0.5..1.5 moves a bright diagonal band across
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float d = abs((UV.x + UV.y * 0.35) - sweep);
	float band = smoothstep(0.09, 0.0, d);
	c.rgb += band * 0.55 * c.a;
	COLOR = c * COLOR;
}
"""
	return sh


# ---------------------------------------------------------------- sky

func _build_sky() -> void:
	for i in 34:
		var big := i < 4
		var id: int = BIG_STARS[i % BIG_STARS.size()] if big else STARS[randi() % STARS.size()]
		var p := Vector2(randf_range(10, 710), randf_range(10, 600))
		var sp := _spr(sky_layer, _tex(id), p, randf_range(0.35, 0.6) if big else randf_range(0.6, 1.0))
		stars.append([sp, randf_range(1.2, 3.2), randf() * TAU, sp.scale.x])
	var rock_ids := [60, 66, 61, 62, 67, 68, 69, 61, 68]
	for i in rock_ids.size():
		var s := 0.42 if int(rock_ids[i]) in [60, 66] else randf_range(0.6, 0.9)
		var sp := _spr(sky_layer, _tex(int(rock_ids[i])), Vector2(randf_range(0, 720), randf_range(90, 560)), s)
		sp.rotation = randf() * TAU
		sp.modulate = Color(0.8, 0.8, 0.95)
		rocks.append([sp, randf_range(-7.0, 7.0), randf_range(-0.25, 0.25)])
	station = _spr(sky_layer, _tex(58), Vector2(560, 190), 0.55)
	ufo = _spr(sky_layer, _tex(59), Vector2(-100, 470), 0.5)
	ufo_t = 2.0


func _update_sky(delta: float) -> void:
	for st: Array in stars:
		var sp: Sprite2D = st[0]
		var k := 0.5 + 0.5 * sin(t * float(st[1]) + float(st[2]))
		sp.modulate.a = 0.25 + 0.75 * k * k
		sp.scale = Vector2.ONE * float(st[3]) * (0.7 + 0.45 * k)
	for r: Array in rocks:
		var sp: Sprite2D = r[0]
		sp.position.x += float(r[1]) * delta
		sp.position.y += sin(t * 0.6 + sp.position.x * 0.01) * 2.0 * delta
		sp.rotation += float(r[2]) * delta
		if sp.position.x < -60.0:
			sp.position.x = 780.0
		elif sp.position.x > 780.0:
			sp.position.x = -60.0
	# the station drifts slowly right to left, its lights flickering
	station.position.x -= 9.0 * delta
	station.position.y = 190.0 + sin(t * 0.7) * 6.0
	if station.position.x < -140.0:
		station.position.x = 860.0
	station.modulate = Color(1, 1, 1) * (0.92 + 0.08 * sin(t * 9.0))
	# the UFO zips across now and then, wobbling
	if ufo_t > 0.0:
		ufo_t -= delta
		if ufo_t <= 0.0:
			ufo.position = Vector2(-90.0, randf_range(380, 560))
			ufo.set_meta("dir", 1.0 if randf() < 0.5 else -1.0)
			if float(ufo.get_meta("dir")) < 0.0:
				ufo.position.x = 810.0
	else:
		var dir := float(ufo.get_meta("dir", 1.0))
		ufo.position.x += dir * 70.0 * delta
		ufo.position.y += sin(t * 3.0) * 30.0 * delta
		ufo.rotation = sin(t * 3.0) * 0.12
		if ufo.position.x > 820.0 or ufo.position.x < -100.0:
			ufo_t = randf_range(3.0, 7.0)
	# shooting stars
	comet_t -= delta
	if comet_t <= 0.0:
		comet_t = randf_range(2.5, 6.0)
		var a := randf_range(0.25, 0.6)
		var sp := _spr(sky_layer, _tex(COMETS[randi() % COMETS.size()]), Vector2(randf_range(-40, 420), randf_range(20, 320)), randf_range(0.7, 1.1))
		sp.rotation = a
		bits.append({"spr": sp, "vel": Vector2.from_angle(a) * randf_range(380, 520), "life": 0.9, "max": 0.9, "grav": 0.0, "spin": 0.0, "fade": true})


# ---------------------------------------------------------------- actors

func _build_actors() -> void:
	for i in 2:
		var sp := _spr(actors, _tex(GERMS[1 + i]), Vector2.ZERO, 0.16)
		idlers.append([sp, DOOR + Vector2(-70 + 140 * i, -40 + 20 * i), randf() * TAU])
	germ = _spr(actors, _tex(GERMS[0]), DOOR, 0.1)
	germ.visible = false
	impact = _spr(actors, _tex(25), TARGET + Vector2(0, 34), 0.6)
	flare = _spr(actors, _tex(2), TARGET + Vector2(0, 34), 0.5)
	impact.visible = false
	flare.visible = false
	# the astronaut first (the beam crosses the germ) ...
	for i in 5:
		astro_frames.append(load(TITLE + "astro_%d.png" % i))
	astro = _spr(actors, astro_frames[0], ASTRO_FEET, ASTRO_SCALE)
	astro.centered = false
	astro_mat = ShaderMaterial.new()
	astro_mat.shader = _beam_shader()
	astro.material = astro_mat
	astro.position = ASTRO_FEET - Vector2(ASTRO_CANVAS.x * 0.5, ASTRO_CANVAS.y) * ASTRO_SCALE
	muzzle_glow = _spr(actors, _tex(15), MUZZLE, 0.5)
	actors.move_child(germ, -1)  # ... and the germ over the beam, so you see it being zapped
	actors.move_child(impact, -1)
	actors.move_child(flare, -1)


func _germ_scale() -> float:
	return 88.0 / germ.texture.get_width()


## The germ loop: out of the door -> floats to the beam -> zapped -> pops into goo.
func _update_germ(delta: float) -> void:
	germ_t -= delta
	var firing := germ_state == "zap"
	match germ_state:
		"wait":
			if germ_t <= 0.0:
				germ.texture = _tex(GERMS[germ_i % GERMS.size()])
				germ_i += 1
				germ_from = Vector2(DOOR.x + randf_range(-55, 55), SPAWN_Y)
				germ.position = germ_from
				germ.modulate = Color.WHITE
				germ.visible = true
				germ_state = "approach"
				germ_t = 1.7
		"approach":
			var k := 1.0 - clampf(germ_t / 1.7, 0.0, 1.0)
			var e := k * k * (3.0 - 2.0 * k)
			var p := germ_from.lerp(TARGET, e)
			p.x += sin(k * TAU * 1.5) * 22.0 * (1.0 - k)  # wobbles in towards the beam
			germ.position = p
			var s := lerpf(0.15, 1.0, e) * _germ_scale()
			germ.scale = Vector2(s, s)
			germ.rotation = sin(t * 6.0) * 0.15
			if germ_t <= 0.0:
				germ_state = "zap"
				germ_t = ZAP_TIME
				zap_t = 0.0
				Sfx.play("zap", 0.1, -16.0)
		"zap":
			var s := _germ_scale()
			var sq := sin(t * 38.0) * 0.07
			germ.scale = Vector2(s * (1.0 + sq), s * (1.0 - sq))
			# the beam pushes it back a little
			var push := 1.0 - germ_t / ZAP_TIME
			germ.position = TARGET + Vector2(randf_range(-3, 3), -22.0 * push + randf_range(-2, 2))
			germ.modulate = Color(1.6, 1.6, 1.8) if fmod(t, 0.16) < 0.06 else Color.WHITE
			if randf() < 0.35:
				_spark(germ.position + Vector2(randf_range(-30, 30), randf_range(10, 30)))
			if germ_t <= 0.0:
				_pop()
		"pop":
			if germ_t <= 0.0:
				germ.visible = false
				germ_state = "wait"
				germ_t = randf_range(0.5, 1.1)
			else:
				var k := 1.0 - germ_t / 0.18
				var s := _germ_scale() * (1.0 + 0.5 * k)
				germ.scale = Vector2(s, s)
				germ.modulate.a = 1.0 - k
	# the blaster: a charging orb while waiting, the muzzle burst / beam / fade frames while zapping
	impact.visible = firing
	flare.visible = firing
	var feet := ASTRO_FEET
	if firing:
		zap_t += delta
		astro.texture = astro_frames[ZAP_FRAMES[int(zap_t * ZAP_FPS) % ZAP_FRAMES.size()]]
		# the beam stops where it hits the germ's belly
		var hit_y := germ.position.y + germ.texture.get_height() * germ.scale.y * 0.3
		var top := feet.y - ASTRO_CANVAS.y * ASTRO_SCALE
		var cut := clampf((hit_y - top) / ASTRO_SCALE, 0.0, ASTRO_CANVAS.y - 40.0) - 30.0  # 30 px of the beam fade out under the hit
		impact.position = Vector2(germ.position.x, hit_y)
		flare.position = impact.position
		hit_pos = impact.position
		astro_mat.set_shader_parameter("cut", maxf(cut, 0.0) / ASTRO_CANVAS.y)
		astro_mat.set_shader_parameter("fade", 50.0 / ASTRO_CANVAS.y if cut > 5.0 else 0.0001)
		for i in 2:
			_hit_spark(hit_pos)
		impact.rotation += delta * 9.0
		impact.scale = Vector2.ONE * (0.5 + 0.12 * sin(t * 30.0))
		flare.scale = Vector2.ONE * (0.45 + 0.2 * randf())
		feet += Vector2(randf_range(-1.0, 1.0), randf_range(-0.6, 0.6))  # recoil
		muzzle_glow.scale = Vector2.ONE * (0.6 + 0.1 * randf())
		muzzle_glow.modulate.a = 1.0
	else:
		astro.texture = astro_frames[0]
		feet.y += sin(t * 2.2) * 1.2
		var c := 0.5 + 0.5 * sin(t * 7.0)
		muzzle_glow.scale = Vector2.ONE * (0.2 + 0.1 * c)
		muzzle_glow.modulate.a = 0.0  # frame 0 already paints the charging orb
	astro.position = feet - Vector2(ASTRO_CANVAS.x * 0.5, ASTRO_CANVAS.y) * ASTRO_SCALE
	if not firing:
		astro_mat.set_shader_parameter("cut", 0.0)
		astro_mat.set_shader_parameter("fade", 0.0001)
	muzzle_glow.position = MUZZLE + (feet - ASTRO_FEET)
	for idl: Array in idlers:
		var sp: Sprite2D = idl[0]
		var ph := float(idl[2])
		sp.position = (idl[1] as Vector2) + Vector2(sin(t * 0.9 + ph) * 26.0, sin(t * 1.7 + ph) * 10.0)
		var b := 0.16 + 0.015 * sin(t * 5.0 + ph)
		sp.scale = Vector2(b, b)
	shadows.queue_redraw()


func _pop() -> void:
	germ_state = "pop"
	germ_t = 0.18
	Sfx.play("pop", 0.15, -10.0)
	var c := germ.position
	for i in 14:
		var sp := _spr(actors, _tex(GOO[randi() % GOO.size()]), c + Vector2(randf_range(-20, 20), randf_range(-20, 20)), randf_range(0.8, 1.4))
		var v := Vector2.from_angle(randf_range(-PI, 0.0)) * randf_range(120, 360)
		# thrown up, they fall to the floor, splat there and fade (no lasting puddle)
		bits.append({"spr": sp, "vel": v, "life": 1.3, "max": 1.3, "grav": 900.0, "spin": 0.0, "fade": true, "floor": FLOOR_Y + randf_range(-10, 30)})
	var burst := _spr(actors, _tex(2), c, 0.6)
	bits.append({"spr": burst, "vel": Vector2.ZERO, "life": 0.25, "max": 0.25, "grav": 0.0, "spin": 3.0, "fade": true, "grow": 3.0})


## Energy splashing off the germ where the beam lands: bright motes thrown in every direction.
func _hit_spark(p: Vector2) -> void:
	var sp := _spr(actors, _tex([6, 4, 28, 8, 11, 12, 13][randi() % 7]), p + Vector2(randf_range(-10, 10), randf_range(-4, 4)), randf_range(0.5, 1.1))
	var v := Vector2.from_angle(randf_range(PI * 1.05, PI * 1.95) if randf() < 0.7 else randf_range(0.0, PI)) * randf_range(70, 240)
	bits.append({"spr": sp, "vel": v, "life": 0.5, "max": 0.5, "grav": 120.0, "spin": randf_range(-6, 6), "fade": true})


func _spark(p: Vector2) -> void:
	var sp := _spr(actors, _tex([17, 19, 21, 22, 23, 27][randi() % 6]), p, randf_range(0.8, 1.3))
	var v := Vector2.from_angle(randf_range(-2.4, 2.4) + PI) * randf_range(60, 200)
	bits.append({"spr": sp, "vel": v, "life": 0.4, "max": 0.4, "grav": 300.0, "spin": 0.0, "fade": true})


## Goo drips off the logo and the walls.
func _update_drips(delta: float) -> void:
	drip_t -= delta
	if drip_t > 0.0:
		return
	drip_t = randf_range(0.6, 1.6)
	var p: Vector2
	var bottom: float
	if randf() < 0.65:
		var d: Vector2 = LOGO_DRIPS[randi() % LOGO_DRIPS.size()]
		p = logo.position + (d - logo.texture.get_size() * 0.5) * logo.scale.x
		bottom = p.y + randf_range(160, 260)
	else:
		p = WALL_DRIPS[randi() % WALL_DRIPS.size()]
		bottom = FLOOR_Y - 90.0
	var sp := _spr(stage, _tex([55, 56, 57, 48][randi() % 4]), p, 0.2)
	stage.move_child(sp, logo.get_index() + 1)
	# swells on the tip, then falls
	var tw := sp.create_tween()
	tw.tween_property(sp, "scale", Vector2(0.9, 1.2), 0.5)
	tw.tween_callback(func() -> void:
		bits.append({"spr": sp, "vel": Vector2(0, 30), "life": 1.4, "max": 1.4, "grav": 700.0, "spin": 0.0, "fade": false, "floor": bottom}))


func _update_bits(delta: float) -> void:
	var i := 0
	while i < bits.size():
		var b: Dictionary = bits[i]
		var sp: Sprite2D = b.spr
		b.life = float(b.life) - delta
		if float(b.life) <= 0.0 or not is_instance_valid(sp):
			if is_instance_valid(sp):
				sp.queue_free()
			bits.remove_at(i)
			continue
		var v: Vector2 = b.vel
		v.y += float(b.grav) * delta
		b.vel = v
		sp.position += v * delta
		sp.rotation += float(b.spin) * delta
		if b.has("grow"):
			sp.scale += Vector2.ONE * float(b.grow) * delta
		if b.has("floor") and sp.position.y >= float(b.floor):
			# lands: a tiny splash, then gone
			sp.position.y = float(b.floor)
			b.vel = Vector2.ZERO
			b.grav = 0.0
			b.erase("floor")
			sp.scale = Vector2(sp.scale.x * 1.4, sp.scale.y * 0.5)
			b.life = minf(float(b.life), 0.35)
			b.fade = true
			b.max = 0.35
		if bool(b.fade):
			sp.modulate.a = clampf(float(b.life) / float(b.max) * 1.5, 0.0, 1.0)
		i += 1


func _draw_shadows() -> void:
	if germ.visible and germ_state != "wait":
		var w := germ.scale.x * germ.texture.get_width() * 0.4
		var a := clampf((germ.position.y - SPAWN_Y) / (TARGET.y - SPAWN_Y), 0.0, 1.0) * 0.35
		shadows.draw_set_transform(Vector2(germ.position.x, germ.position.y + 52.0 * germ.scale.x / _germ_scale()), 0.0, Vector2(1.0, 0.28))
		shadows.draw_circle(Vector2.ZERO, w, Color(0, 0, 0, a))
	shadows.draw_set_transform(Vector2(ASTRO_FEET.x, ASTRO_FEET.y - 4), 0.0, Vector2(1.0, 0.25))
	shadows.draw_circle(Vector2.ZERO, 82.0, Color(0, 0, 0, 0.4))
	shadows.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_glows() -> void:
	# hangar door lights and their reflection on the wet floor pulse slowly
	var k := 0.5 + 0.5 * sin(t * 2.4)
	var red := Color(1.0, 0.25, 0.1)
	for i in 6:
		var g := float(i) * 3.0
		fx_layer.draw_rect(Rect2(292 - g, 634 - g * 0.5, 136 + g * 2.0, 10 + g), Color(red, (0.05 + 0.06 * k) * (1.0 - i / 6.0)))
	fx_layer.draw_rect(Rect2(300, 900, 120, 120), Color(red, 0.04 + 0.05 * k))
	# the planet's rim breathes
	fx_layer.draw_arc(Vector2(378, 492), 248.0, PI * 1.02, PI * 1.98, 64, Color(0.3, 0.7, 1.0, 0.08 + 0.08 * k), 10.0)
	# the zap lights up the floor
	if germ_state == "zap":
		fx_layer.draw_circle(germ.position, 60.0 + randf() * 12.0, Color(0.2, 0.7, 1.0, 0.12))
		# a hot bloom where the beam lands, and electric arcs crawling over the germ
		for i in 4:
			fx_layer.draw_circle(hit_pos, 46.0 - i * 10.0 + randf() * 5.0, Color(0.4, 0.85, 1.0, 0.1 + 0.07 * i))
		var r := germ.texture.get_width() * germ.scale.x * 0.5
		for a in 3:
			var pts := PackedVector2Array()
			var ang := randf() * TAU
			for n in 6:
				var q := Vector2.from_angle(ang + n * 0.35 + randf_range(-0.15, 0.15)) * (r * (0.75 + randf() * 0.5))
				pts.append(germ.position + q)
			fx_layer.draw_polyline(pts, Color(0.75, 0.95, 1.0, 0.85), 2.0)
		fx_layer.draw_circle(MUZZLE, 46.0 + randf() * 8.0, Color(0.2, 0.7, 1.0, 0.1))
		fx_layer.draw_rect(Rect2(ASTRO_FEET.x - 150, FLOOR_Y - 30, 300, 40), Color(0.2, 0.6, 1.0, 0.05 + 0.04 * randf()))


# ---------------------------------------------------------------- intro

func _intro() -> void:
	logo.position = LOGO_POS + Vector2(0, -420)
	var tw := logo.create_tween()
	tw.tween_interval(0.15)
	tw.tween_property(logo, "position", LOGO_POS, 0.75).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	for c: CanvasItem in [play_btn, hint]:
		c.modulate.a = 0.0
	play_btn.position.y += 160.0
	var tp := play_btn.create_tween().set_parallel()
	tp.tween_property(play_btn, "position:y", play_btn.position.y - 160.0, 0.6).set_delay(0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tp.tween_property(play_btn, "modulate:a", 1.0, 0.3).set_delay(0.55)
	tp.tween_property(hint, "modulate:a", 1.0, 0.5).set_delay(1.0)


# ---------------------------------------------------------------- loop

func _process(delta: float) -> void:
	t += delta
	_update_sky(delta)
	_update_germ(delta)
	_update_drips(delta)
	_update_bits(delta)
	fx_layer.queue_redraw()
	if t > 1.0:
		logo.position.y = LOGO_POS.y + sin((t - 1.0) * 1.6) * 6.0
		logo.rotation = sin((t - 1.0) * 0.8) * 0.015
	# a shine sweeps the logo and PLAY every few seconds
	var cyc := fmod(t, 3.5)
	shine_mat.set_shader_parameter("sweep", -0.5 + cyc * 1.6 if cyc < 1.25 else -1.0)
	if not play_btn.is_pressed() and t > 1.3:
		var k := 1.0 + sin(t * 3.2) * 0.03
		play_btn.scale = Vector2(k, k)
	gear_btn.rotation = t * 0.5


## Tap a germ to pop it yourself.
func _gui_input(ev: InputEvent) -> void:
	var pressed := (ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed) \
			or (ev is InputEventScreenTouch and (ev as InputEventScreenTouch).pressed)
	if not pressed or not germ.visible or germ_state == "pop":
		return
	var p := (ev as InputEventMouseButton).position if ev is InputEventMouseButton else (ev as InputEventScreenTouch).position
	var local := (p - stage.position) / stage.scale.x
	if local.distance_to(germ.position) < germ.scale.x * germ.texture.get_width() * 0.6:
		_pop()


func _fit_stage() -> void:
	if stage == null:
		return
	UiTheme.fit_stage(self, stage, ART_SIZE)


func _press_fx(b: TextureButton, down: bool) -> void:
	var tw := b.create_tween().set_parallel()
	tw.tween_property(b, "scale", Vector2(0.93, 0.93) if down else Vector2.ONE, 0.07)
	tw.tween_property(b, "modulate", Color(0.8, 0.8, 0.85) if down else Color.WHITE, 0.07)


func _refresh() -> void:
	bank_label.text = str(Game.bank)
	if Game.runs > 0:
		hint.text = "WORLDS CLEARED: %d/%d" % [Game.worlds_cleared, WorldData.WORLDS.size()]
	else:
		hint.text = "DRAG TO MOVE - CLEANING IS AUTOMATIC!"


## PLAY opens the world select (pick a world, shop, gear...).
func _play() -> void:
	var fade := ColorRect.new()
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.color = Color(0.03, 0.04, 0.08, 0.0)
	add_child(fade)
	var tw := fade.create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.25)
	tw.tween_callback(func() -> void: get_tree().change_scene_to_file(WORLD_SCENE))


func _open_settings() -> void:
	MenuPanels.settings(self)
