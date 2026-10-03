class_name SupplyChest
extends Node2D
## Exploration chest (Explore): stand within ChestData.OPEN_R for OPEN_TIME to open it.
## A ring fills while you stay (it slowly drains when you leave, keeping most of it),
## the chest shakes harder near the end, then bursts open and grants its ChestData perk.
## Y-sorted with the entities (origin = bottom of the chest).

const WIDTH := 28.0  # world units
const DRAIN := 0.25  # progress lost per second away from it

var kind := 0  # index in ChestData.CHESTS
var progress := 0.0  # 0..1
var opened := false
var t := 0.0
var sprite: Sprite2D
var near := false
var _tick := 0.0


func _ready() -> void:
	add_to_group("chests")
	sprite = Sprite2D.new()
	sprite.texture = ChestData.tex(kind)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var img := sprite.texture.get_image()
	if img.is_compressed():
		img.decompress()
	img.generate_mipmaps()
	sprite.texture = ImageTexture.create_from_image(img)
	sprite.centered = false
	var ts := sprite.texture.get_size()
	var k := WIDTH / ts.x
	sprite.scale = Vector2(k, k)
	sprite.offset = Vector2(-ts.x * 0.5, -ts.y)
	add_child(sprite)
	t = randf() * TAU
	DarkLights.glow(self)  # chests glow in the dark to draw you exploring
	sprite.use_parent_material = true


func _process(delta: float) -> void:
	t += delta
	queue_redraw()
	if opened:
		return
	var w := Game.world
	if w == null or w.player == null or w.player.dead:
		return
	near = w.player.global_position.distance_to(global_position + Vector2(0, -6)) < ChestData.OPEN_R
	if near:
		progress = minf(1.0, progress + delta / ChestData.OPEN_TIME)
		_tick -= delta
		if _tick <= 0.0:
			_tick = lerpf(0.5, 0.12, progress)
			Sfx.play("select", 0.0, -14.0 + progress * 6.0)
		if randf() < delta * 12.0:
			w.burst(global_position + Vector2(randf_range(-10, 10), -randf_range(4, 18)), _col(), 1, 14.0, 0.4, 1.5, -40.0)
		if progress >= 1.0:
			_open()
	else:
		progress = maxf(0.0, progress - delta * DRAIN)
	# idle bob; shakes harder as it is about to open
	var shake := progress * progress * 2.2 if near else 0.0
	sprite.position = Vector2(randf_range(-shake, shake), -absf(sin(t * 2.0)) * 1.2)


func _col() -> Color:
	return ChestData.CHESTS[kind].color


func _open() -> void:
	opened = true
	var w := Game.world
	var at := global_position + Vector2(0, -10)
	ChestData.apply(kind, w, at)
	var c := _col()
	var def: Dictionary = ChestData.CHESTS[kind]
	w.burst(at, c, 30, 120.0, 0.6, 2.5, 60.0)
	w.burst(at, Color.WHITE, 12, 70.0, 0.35, 2.0)
	w.ring(at, 34.0, c, 0.4, 3.0, true)
	w.shake(0.3)
	Sfx.play("upgrade", 0.0)
	w.hud.banner(str(def.name), c, 32, 1.0)
	w.popup_text(at + Vector2(0, -16), str(def.desc), c.lightened(0.3), 13)
	if w.explore != null:
		w.explore.chest_opened(self)
	sprite.modulate = Color(0.55, 0.55, 0.65, 0.85)
	var tw := sprite.create_tween()
	tw.tween_property(sprite, "scale", sprite.scale * Vector2(1.25, 0.8), 0.08)
	tw.tween_property(sprite, "scale", sprite.scale, 0.2).set_trans(Tween.TRANS_BACK)


func _draw() -> void:
	var c := _col()
	if opened:
		# a faint light column left behind
		draw_set_transform(Vector2(0, -2), 0.0, Vector2(1.0, 0.35))
		draw_circle(Vector2.ZERO, 14.0, Color(c, 0.12))
		draw_set_transform(Vector2.ZERO)
		return
	# glow pad on the floor, pulsing
	var p := 0.5 + 0.5 * sin(t * 3.0)
	draw_set_transform(Vector2(0, -2), 0.0, Vector2(1.0, 0.38))
	draw_circle(Vector2.ZERO, 18.0 + p * 2.0, Color(c, 0.18 + 0.1 * p))
	draw_arc(Vector2.ZERO, ChestData.OPEN_R, 0.0, TAU, 40, Color(c, 0.25 if not near else 0.5), 1.5)
	if progress > 0.0:
		draw_arc(Vector2.ZERO, ChestData.OPEN_R, -PI * 0.5, -PI * 0.5 + TAU * progress, 40, Color(c.lightened(0.4), 0.95), 3.5)
	draw_set_transform(Vector2.ZERO)
	if near or progress > 0.0:
		var secs := ChestData.OPEN_TIME * (1.0 - progress)
		var txt := "%.1f" % secs
		var f := UiTheme.FONT
		var sz := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8)
		draw_string_outline(f, Vector2(-sz.x * 0.5, -30), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 3, Color(0, 0, 0, 0.8))
		draw_string(f, Vector2(-sz.x * 0.5, -30), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.WHITE)
