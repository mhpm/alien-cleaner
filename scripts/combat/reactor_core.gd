class_name ReactorCore
extends Node2D
## World 5 (THE FORGE) objective, placed by Explore ("cores": n): an OVERHEATING REACTOR in
## the middle of a room. While it is hot it throbs red and, whenever the astronaut is in
## its room, every ERUPT_EVERY seconds it lets out a HEAT WAVE: a ring of lava marked on
## the floor that bursts a moment later, burning the astronaut AND the aliens caught in
## it (lure the horde onto it). Stand on its coolant pad (the blue ring in front of it)
## for VENT_TIME seconds to vent it (the bar drains slowly if you step off): steam,
## the core turns cold blue, you get healed and "CORE STABILIZED n/m". Venting every core
## before the final boss cools the whole forge: every boss arrives with less health
## (BossBase._size_to_player reads Explore.forge_cooled).
## Y-sorted with the entities; origin = bottom centre of the reactor (its FOOT is solid).

const PIECE := 28  # kit piece (assets/rooms/w5/kit/k_28.png): the big reactor
const SCALE := 0.32
const FOOT := 0.3
const PAD := Vector2(0, 30)  # coolant pad, from the origin
const PAD_R := 26.0
const VENT_TIME := 6.0
const DRAIN := 0.15  # vent progress lost per second off the pad
const ERUPT_EVERY := 7.0
const WARN := 1.1
const WAVE_R := 74.0
const WAVE_DMG := 0.1  # share of max health a heat wave takes
const ROOM_REACH := 300.0  # only erupts while the astronaut is this close
const HOT := Color("ff5a1f")
const COOL := Color("5fd0ff")

var progress := 0.0
var cooled := false
var t := 0.0
var erupt_t := 0.0
var warn_t := -1.0
var near := false
var sprite: Sprite2D
var _tick := 0.0


func _ready() -> void:
	add_to_group("reactor_cores")
	sprite = Sprite2D.new()
	sprite.texture = RoomKit.tex(PIECE, "w5")
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.centered = false
	var ts := sprite.texture.get_size()
	sprite.offset = Vector2(-ts.x * 0.5, -ts.y)
	sprite.scale = Vector2.ONE * SCALE
	add_child(sprite)
	t = randf() * TAU
	erupt_t = ERUPT_EVERY * randf_range(0.5, 1.0)
	DarkLights.glow(self)
	sprite.use_parent_material = true


## Solid rect of a core standing with its bottom centre at `at` (Explore collision).
static func foot(at: Vector2) -> Rect2:
	var sz := RoomKit.tex(PIECE, "w5").get_size() * SCALE
	var h := sz.y * FOOT
	return Rect2(at.x - sz.x * 0.5, at.y - h, sz.x, h)


func _process(delta: float) -> void:
	t += delta
	queue_redraw()
	if cooled:
		return
	var w := Game.world
	if w == null or w.player == null or w.player.dead:
		return
	var p := w.player.global_position
	# heat glow throbbing faster as the next wave nears
	var k := 0.5 + 0.5 * sin(t * lerpf(3.0, 12.0, 1.0 - clampf(erupt_t / ERUPT_EVERY, 0.0, 1.0)))
	sprite.modulate = Color(1.0 + 0.35 * k, 1.0, 1.0 - 0.2 * k)
	if randf() < delta * 5.0:
		w.burst(global_position + Vector2(randf_range(-14, 14), -randf_range(20, 60)), HOT, 1, 18.0, 0.6, 1.5, -30.0)
	# heat waves while the astronaut is around
	if warn_t >= 0.0:
		warn_t -= delta
		if warn_t < 0.0:
			_erupt()
	elif p.distance_to(global_position) < ROOM_REACH:
		erupt_t -= delta
		if erupt_t <= 0.0:
			erupt_t = ERUPT_EVERY
			warn_t = WARN
			w.telegraph_circle(global_position, WAVE_R, WARN)
			Sfx.play("charge", 0.1, -6.0)
	# venting on the coolant pad
	near = p.distance_to(global_position + PAD) < PAD_R
	if near:
		progress = minf(1.0, progress + delta / VENT_TIME)
		_tick -= delta
		if _tick <= 0.0:
			_tick = lerpf(0.45, 0.12, progress)
			Sfx.play("freeze", 0.2, -16.0 + progress * 6.0)
		if randf() < delta * 14.0:
			w.burst(global_position + Vector2(randf_range(-12, 12), -randf_range(10, 50)), Color(0.85, 0.95, 1.0, 0.8), 1, 25.0, 0.5, 2.0, -50.0)
		if progress >= 1.0:
			_vent()
	else:
		progress = maxf(0.0, progress - delta * DRAIN)


## The heat wave: hurts everyone inside the ring (the circle is drawn squashed, y * 0.75).
func _erupt() -> void:
	var w := Game.world
	var c := global_position
	w.ring(c, WAVE_R, HOT, 0.4, 4.0, true)
	w.burst(c + Vector2(0, -10), HOT, 26, 160.0, 0.55, 2.5, 40.0)
	w.burst(c + Vector2(0, -10), Color("ffcd75"), 12, 100.0, 0.4, 2.0)
	w.shake(0.35)
	Sfx.play("explode", 0.1, -4.0)
	var p := w.player
	if not p.dead:
		var off := p.global_position - c
		if Vector2(off.x, off.y / 0.75).length() < WAVE_R:
			p.take_damage(float(Game.stats.max_hp) * WAVE_DMG, c)
	for e in w.enemies_near(c, WAVE_R):
		if is_instance_valid(e) and not e.dead and not e.is_boss:
			var o: Vector2 = e.global_position - c
			if Vector2(o.x, o.y / 0.75).length() < WAVE_R + e.radius:
				e.take_damage(60.0 + e.max_hp * 0.35, o.normalized() * 3.0)


func _vent() -> void:
	cooled = true
	warn_t = -1.0
	var w := Game.world
	var at := global_position + Vector2(0, -30)
	sprite.modulate = Color(0.55, 0.85, 1.25)
	w.burst(at, Color(0.9, 0.95, 1.0, 0.9), 40, 140.0, 0.9, 3.0, -80.0)
	w.burst(at, COOL, 20, 100.0, 0.5, 2.5)
	w.ring(global_position, 40.0, COOL, 0.45, 3.0, true)
	w.shake(0.3)
	Sfx.play("freeze", 0.0, 2.0)
	Sfx.play("upgrade", 0.0, -4.0)
	var s := Game.stats
	s.hp = minf(float(s.max_hp), float(s.hp) + float(s.max_hp) * 0.15)
	Game.hp_changed.emit()
	w.popup_text(at + Vector2(0, -12), "+15% HP", COOL.lightened(0.3), 12)
	if w.explore != null:
		w.explore.core_vented(self)


func _draw() -> void:
	var flat := Transform2D(0.0, Vector2(1.0, 0.38), 0.0, PAD)
	if cooled:
		draw_set_transform_matrix(flat)
		FastDraw.disc(self, Vector2.ZERO, 16.0, Color(COOL, 0.15))
		draw_set_transform(Vector2.ZERO)
		return
	# heat haze on the floor round the core
	var k := 0.5 + 0.5 * sin(t * 4.0)
	draw_set_transform(Vector2(0, -4), 0.0, Vector2(1.0, 0.4))
	FastDraw.disc(self, Vector2.ZERO, 44.0 + 4.0 * k, Color(HOT, 0.1 + 0.06 * k))
	# coolant pad: blue ring that fills while venting
	draw_set_transform_matrix(flat)
	FastDraw.disc(self, Vector2.ZERO, PAD_R * 0.75, Color(COOL, 0.16 + (0.14 if near else 0.06) * k))
	FastDraw.ring(self, Vector2.ZERO, PAD_R, Color(COOL, 0.6 if near else 0.35), 1.5)
	if progress > 0.0:
		FastDraw.arc(self, Vector2.ZERO, PAD_R, -PI * 0.5, -PI * 0.5 + TAU * progress, Color(COOL.lightened(0.4), 0.95), 3.5, flat)
	draw_set_transform(Vector2.ZERO)
	var txt := "VENT %.1f" % (VENT_TIME * (1.0 - progress)) if near or progress > 0.0 else "COOL ME"
	var f := UiTheme.FONT
	var sz := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8)
	var y := -RoomKit.tex(PIECE, "w5").get_size().y * SCALE - 6.0
	draw_string_outline(f, Vector2(-sz.x * 0.5, y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 3, Color(0, 0, 0, 0.8))
	draw_string(f, Vector2(-sz.x * 0.5, y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, COOL.lightened(0.4) if near else Color("ffcd75"))
