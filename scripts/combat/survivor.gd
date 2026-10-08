class_name Survivor
extends Node2D
## A crew member hiding in an EXPLORE map (SurvivorData). Huddled and shaking, they shout
## for help in speech bubbles that pop over their head (more often when you are near).
## Stand within RESCUE_R for RESCUE_TIME to rescue them: a ring fills (it drains slowly
## when you step away), they say a few nervous things, then jump up happy, thank you,
## give their gift and are beamed out. Y-sorted with the entities (origin = feet).

const HEIGHT := 30.0  # world units, a bit taller than the astronaut huddled
const DRAIN := 0.15  # progress lost per second away from them

signal rescued(survivor: Survivor)

var kind := 0
## Per-instance overrides (arena editor survivors); defaults = SurvivorData.
var rescue_r := SurvivorData.RESCUE_R
var rescue_time := SurvivorData.RESCUE_TIME
var help_lines: Array = SurvivorData.HELP
var display_name := ""  # "" = the crew member's job title
var beam_out := true  # false: stays (escorts follow the astronaut instead)
var look: Texture2D  # their own picture, scared and happy alike (villagers); null = the crew's
var progress := 0.0
var saved := false
var gone := false
var t := 0.0
var near := false
var sprite: Sprite2D
var bubbles: Node2D  # speech bubbles live here (drawn over everything)
var shout_t := 1.0
var hold_said := 0
var k := 1.0  # sprite scale (from the sad picture, shared by the happy one)


func _ready() -> void:
	add_to_group("survivors")
	sprite = Sprite2D.new()
	sprite.texture = _mip(look if look != null else SurvivorData.tex(kind, false))
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.centered = false
	k = HEIGHT / sprite.texture.get_height()
	_place_sprite()
	add_child(sprite)
	bubbles = Node2D.new()
	bubbles.z_index = 40
	add_child(bubbles)
	DarkLights.glow(self)
	sprite.use_parent_material = true
	t = randf() * TAU
	shout_t = randf_range(0.5, 2.5)


static func _mip(src: Texture2D) -> Texture2D:
	var img := src.get_image()
	if img.is_compressed():
		img.decompress()
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _place_sprite() -> void:
	var ts := sprite.texture.get_size()
	sprite.scale = Vector2(k, k)
	sprite.offset = Vector2(-ts.x * 0.5, -ts.y)


func _col() -> Color:
	return SurvivorData.CREW[kind].color


func _process(delta: float) -> void:
	t += delta
	queue_redraw()
	if gone:
		return
	if saved:
		# a happy little hop while they wait for the beam
		sprite.position = Vector2(0, -absf(sin(t * 9.0)) * 3.0)
		return
	var w := Game.world
	if w == null or w.player == null or w.player.dead:
		return
	var d := w.player.global_position.distance_to(global_position + Vector2(0, -6))
	near = d < rescue_r
	# shiver
	sprite.position = Vector2(sin(t * 40.0) * 0.4, 0)
	shout_t -= delta
	if near:
		progress = minf(1.0, progress + delta / rescue_time)
		var step := int(progress * 4.0)
		if step > hold_said and step < 4:
			hold_said = step
			say(SurvivorData.HOLD.pick_random(), Color.WHITE)
		if randf() < delta * 6.0:
			w.burst(global_position + Vector2(randf_range(-12, 12), -randf_range(2, 20)), _col(), 1, 14.0, 0.4, 1.5, -40.0)
		if progress >= 1.0:
			_rescue()
	else:
		progress = maxf(0.0, progress - delta * DRAIN)
		hold_said = int(progress * 4.0)
		if shout_t <= 0.0:
			# louder (more often) when you are around, but they never stop asking
			shout_t = randf_range(1.6, 2.6) if d < 160.0 else randf_range(3.0, 5.0)
			say(str(help_lines.pick_random()), Color("ffdf5a"))
			if d < 220.0:
				Sfx.play("alert", 0.2, -18.0)


## A speech bubble over the head that pops, floats up a little and fades.
func say(text: String, col: Color, hold := 1.3) -> void:
	var b := Bubble.new()
	b.text = text
	b.color = col
	b.position = Vector2(randf_range(-6, 6), -HEIGHT - 6.0)
	bubbles.add_child(b)
	while bubbles.get_child_count() > 2:
		bubbles.get_child(0).free()
	b.scale = Vector2(0.2, 0.2)
	var tw := b.create_tween()
	tw.tween_property(b, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(b, "position:y", b.position.y - 6.0, hold + 0.4)
	tw.tween_interval(hold - 0.18)
	tw.tween_property(b, "modulate:a", 0.0, 0.3)
	tw.tween_callback(b.queue_free)


func _rescue() -> void:
	saved = true
	var w := Game.world
	var def: Dictionary = SurvivorData.CREW[kind]
	sprite.texture = _mip(look if look != null else SurvivorData.tex(kind, true))
	_place_sprite()
	SurvivorData.reward(kind)
	var at := global_position + Vector2(0, -HEIGHT * 0.6)
	w.burst(at, Color("ff6a9a"), 14, 70.0, 0.7, 2.5, -60.0)  # hearts-ish
	w.burst(at, _col(), 18, 110.0, 0.5, 2.0)
	w.ring(at, 26.0, _col(), 0.4, 3.0, true)
	Sfx.play("heal", 0.0)
	Sfx.play("victory", 0.0, -10.0)
	for c in bubbles.get_children():
		c.queue_free()
	say(SurvivorData.THANKS.pick_random(), Color("a7f070"), 1.8)
	w.popup_text(at + Vector2(0, -18), "%s SAVED: %s" % [display_name if display_name != "" else def.name, def.gift], _col().lightened(0.3), 11)
	if w.explore != null:
		w.explore.survivor_saved(self)
	rescued.emit(self)
	# beamed out to safety
	if beam_out:
		get_tree().create_timer(2.4, false).timeout.connect(_beam_out)


func _beam_out() -> void:
	gone = true
	var w := Game.world
	w.ring(global_position + Vector2(0, -10), 18.0, Color("73eff7"), 0.4, 2.0)
	w.burst(global_position + Vector2(0, -10), Color("73eff7"), 16, 40.0, 0.6, 2.0, -120.0)
	Sfx.play("spawn", 0.0, -6.0)
	var tw := create_tween().set_parallel()
	tw.tween_property(sprite, "scale", Vector2(k * 0.2, k * 2.2), 0.35)
	tw.tween_property(sprite, "modulate:a", 0.0, 0.35)
	tw.chain().tween_callback(queue_free)


func _draw() -> void:
	if gone:
		return
	var c := _col()
	if saved:
		# the teleport beam warming up
		var p := 0.5 + 0.5 * sin(t * 12.0)
		draw_rect(Rect2(-9, -60, 18, 60), Color(0.45, 0.95, 1.0, 0.15 + 0.1 * p))
		return
	# a pulsing distress beacon on the floor and the rescue ring
	var pulse := 0.5 + 0.5 * sin(t * 4.0)
	var flat := Transform2D(0.0, Vector2(1.0, 0.38), 0.0, Vector2(0, -1))
	draw_set_transform_matrix(flat)
	FastDraw.disc(self, Vector2.ZERO, 15.0 + pulse * 3.0, Color(c, 0.14 + 0.1 * pulse))
	FastDraw.ring(self, Vector2.ZERO, rescue_r, Color(c, 0.5 if near else 0.22), 1.5)
	if progress > 0.0:
		FastDraw.arc(self, Vector2.ZERO, rescue_r, -PI * 0.5, -PI * 0.5 + TAU * progress, Color(0.65, 1.0, 0.45, 0.95), 3.5, flat)
	draw_set_transform(Vector2.ZERO)
	if near or progress > 0.0:
		var txt := "%d%%" % int(progress * 100.0)
		var f := UiTheme.FONT
		var sz := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8)
		draw_string_outline(f, Vector2(-sz.x * 0.5, 12), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 3, Color(0, 0, 0, 0.85))
		draw_string(f, Vector2(-sz.x * 0.5, 12), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("a7f070"))


## Comic speech bubble: rounded box with a tail, pixel font.
class Bubble extends Node2D:
	const FS := 8
	var text := "HELP!"
	var color := Color.WHITE

	func _ready() -> void:
		DarkLights.glow(self)

	func _draw() -> void:
		var f := UiTheme.FONT
		var sz := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FS)
		var box := Rect2(-sz.x * 0.5 - 4.0, -sz.y - 5.0, sz.x + 8.0, sz.y + 4.0)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.05, 0.06, 0.1, 0.92)
		sb.border_color = color
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(3)
		draw_style_box(sb, box)
		draw_colored_polygon(PackedVector2Array([Vector2(-3, box.end.y - 0.5), Vector2(3, box.end.y - 0.5), Vector2(0, box.end.y + 4)]), Color(0.05, 0.06, 0.1, 0.92))
		draw_line(Vector2(-3, box.end.y), Vector2(0, box.end.y + 4), color, 1.0)
		draw_line(Vector2(3, box.end.y), Vector2(0, box.end.y + 4), color, 1.0)
		draw_string(f, Vector2(-sz.x * 0.5, -5.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, FS, color)
