class_name RewardChest
extends TextureButton
## A reward chest button of the world select (the world's chest, the BOSS CHALLENGE's
## golden one). Art: assets/ui/world/chest_closed.png / chest_open.png from
## tools/make_world_chest.py, both at one scale, placed by the chest's feet (`foot`) so the
## box stays put when the lid opens.
##   READY   closed, glowing: a pulsing halo behind it and sparkles rising out of it
##   LOCKED  closed and dim (not earned yet), no glow
##   OPENED  the open art, dimmed: already taken
## `tint` colours the art and the glow (the BOSS CHALLENGE chest is gold).

enum State { LOCKED, READY, OPENED }

const CLOSED := "res://assets/ui/world/chest_closed.png"
const OPEN := "res://assets/ui/world/chest_open.png"
const DIM := Color(0.5, 0.5, 0.62)
const LOCKED_DIM := Color(0.68, 0.68, 0.78)

var foot := Vector2.ZERO  # art px: bottom centre of the box
var width := 194.0  # art px of the closed chest (the open one keeps that scale)
var tint := Color.WHITE
var glow_color := Color("41c8ff")
var state := State.LOCKED

var _closed: Texture2D
var _open: Texture2D
var _glow: Sprite2D
var _sparks: CPUParticles2D
var _t := randf() * TAU


func _init() -> void:
	ignore_texture_size = true
	stretch_mode = TextureButton.STRETCH_SCALE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_closed = load(CLOSED)
	_open = load(OPEN)


func _ready() -> void:
	_glow = Sprite2D.new()
	_glow.texture = DarkLights.light_tex()
	_glow.show_behind_parent = true
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = add
	add_child(_glow)
	_sparks = CPUParticles2D.new()
	_sparks.amount = 18
	_sparks.lifetime = 1.4
	_sparks.preprocess = 1.4
	_sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_sparks.direction = Vector2.UP
	_sparks.spread = 25.0
	_sparks.gravity = Vector2(0, -20)
	_sparks.initial_velocity_min = 30.0
	_sparks.initial_velocity_max = 70.0
	_sparks.scale_amount_min = 2.5
	_sparks.scale_amount_max = 5.0
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	_sparks.color_ramp = fade
	_sparks.material = add
	add_child(_sparks)
	set_state(state)


## Art, size and effects for `s` (call again whenever the chest's state may change).
func set_state(s: State) -> void:
	state = s
	var tex := _open if s == State.OPENED else _closed
	texture_normal = tex
	var k := width / float(_closed.get_width())
	size = Vector2(tex.get_size()) * k
	position = foot - Vector2(size.x * 0.5, size.y)
	pivot_offset = Vector2(size.x * 0.5, size.y)
	match s:
		State.READY:
			self_modulate = tint
		State.LOCKED:
			self_modulate = tint * LOCKED_DIM
		State.OPENED:
			self_modulate = tint * DIM
	if _glow == null:
		return
	var ready := s == State.READY
	_glow.visible = ready
	_sparks.emitting = ready
	_sparks.visible = ready
	var box := Vector2(size.x, size.x * 0.68)  # the closed box (the art is a little taller)
	_glow.position = Vector2(size.x * 0.5, size.y - box.y * 0.5)
	_glow.scale = Vector2.ONE * (box.x * 1.7 / float(_glow.texture.get_width()))
	_glow.modulate = Color(glow_color, 0.55)
	_sparks.position = Vector2(size.x * 0.5, size.y - box.y * 0.55)
	_sparks.emission_rect_extents = Vector2(box.x * 0.4, box.y * 0.25)
	_sparks.color = glow_color.lightened(0.35)


func _process(delta: float) -> void:
	_t += delta
	if state == State.READY and _glow != null:
		var p := 0.5 + 0.5 * sin(_t * 3.0)
		_glow.modulate.a = 0.35 + 0.35 * p
		self_modulate = tint * (1.0 + 0.18 * p)
