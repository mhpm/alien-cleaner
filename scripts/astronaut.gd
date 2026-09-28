class_name Astronaut
extends Node2D
## The astronaut: always the reference-sheet sprite (assets/sprites/player), plus the
## equipped blaster as a separate sprite that rotates around its grip toward `aim`.
## Blaster images and joints: tools/make_suit_parts.py -> assets/suits/<variant>_weapon.png
## + weapons.json (grip / tip in image pixels). Origin = feet. The blaster is always
## drawn in front of the body, except while walking up (back view): then it goes behind.
## Used by the Player and by the CHARACTER screen preview.
## set_form("infected") swaps in the mutant (Infected mode, assets/sprites/infected): its
## arm is the cannon, so the blaster hides, and its idle is animated.

const WEAPONS_PATH := "res://assets/suits/weapons.json"
const BODY_SCALE := 0.34  # sprite frame px -> world units (~25 units tall)
const HAND := Vector2(6, -30)  # hands in frame px from the feet (facing right)
const GUN_LEN := 30.0  # grip -> muzzle in frame px

static var _weapons: Dictionary = {}

var body: AnimatedSprite2D
var gun: Sprite2D
var aim := 0.0  # world angle the blaster points at
var facing := 1.0
var recoil := 0.0  # frame px the blaster kicks back
var walk_phase := 0.0  # advances while walking; one hop per half cycle
var walk_amount := 0.0  # 0 standing .. 1 walking
var breathe_t := 0.0
var _grip := Vector2.ZERO
var _tip := Vector2.ZERO
var form := "player"
var body_scale := BODY_SCALE


func _ready() -> void:
	body = Art.make_anim("player", BODY_SCALE)
	body.animation = "idle"  # frozen on frame 0 (see play)
	add_child(body)
	gun = Sprite2D.new()
	gun.centered = false
	gun.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(gun)
	refresh()


## Re-read the equipped blaster (call after buying / equipping).
func refresh() -> void:
	var v := weapon_variant()
	var w: Dictionary = weapons_data()[v]
	_grip = Vector2(float(w.grip[0]), float(w.grip[1]))
	_tip = Vector2(float(w.tip[0]), float(w.tip[1]))
	gun.texture = Art.suit_tex(v, "weapon")
	gun.offset = -_grip
	_pose()


static func weapon_variant() -> String:
	return GearData.variant_of(str(Game.gear_equipped["weapon"]))


static func weapons_data() -> Dictionary:
	if _weapons.is_empty():
		_weapons = JSON.parse_string(FileAccess.get_file_as_string(WEAPONS_PATH))
	return _weapons


## "player" (reference-sheet astronaut) or "infected" (the mutant, drawn at the same height).
func set_form(f: String) -> void:
	form = f
	body.sprite_frames = Art.frames(f)
	body.offset = Art.anchor_offset(f)
	body_scale = BODY_SCALE
	if f != "player":
		body_scale = BODY_SCALE * Art.body_height("player") / Art.body_height(f) * 1.3
	body.animation = &""
	play("idle")
	_pose()


func play(anim: String) -> void:
	if body.animation == anim:
		return
	if anim == "idle" and form == "player":
		# standing: a single frame holding the blaster; breathing is procedural
		body.animation = "idle"
		body.stop()
		body.frame = 0
	else:
		body.play(anim)


func set_layer_material(m: Material) -> void:
	body.material = m
	gun.material = m


## Blaster grip (rotation pivot) and muzzle, in this node's coordinates.
func grip_pos() -> Vector2:
	return gun.position


func muzzle_pos() -> Vector2:
	if form != "player":
		# the mutant fires from its arm cannon
		return body.position + Vector2(facing * 6.0, -11.0) + Vector2.from_angle(aim) * 7.0
	return gun.position + Vector2.from_angle(aim) * GUN_LEN * BODY_SCALE


func _process(delta: float) -> void:
	breathe_t += delta
	_pose()


func _pose() -> void:
	if body == null:
		return
	body.flip_h = facing < 0.0
	# walking: a hop per step with a little squash on landing; standing: slow breathing
	var step := absf(sin(walk_phase))
	var hop := -step * 1.8 * walk_amount
	var land := (1.0 - step) * 0.08 * walk_amount
	var breath := sin(breathe_t * 2.6) * 0.018 * (1.0 - walk_amount)
	body.position = Vector2(0, hop)
	body.rotation = sin(walk_phase) * 0.06 * walk_amount * facing
	body.scale = Vector2(1.0 + land - breath * 0.4, 1.0 - land + breath) * body_scale
	var dir := Vector2.from_angle(aim)
	var s := GUN_LEN / (_tip - _grip).length() * BODY_SCALE
	var base := (_tip - _grip).angle()
	# pointing left: mirror the blaster vertically so it is never upside down
	var flip := dir.x < 0.0
	gun.scale = Vector2(s, -s if flip else s)
	gun.rotation = aim + (base if flip else -base)
	var hand := Vector2(HAND.x * facing, HAND.y * (1.0 - land + breath))
	gun.position = hand * BODY_SCALE + Vector2(0, hop) - dir * recoil * BODY_SCALE
	gun.visible = body.animation != "death" and form == "player"
	# only when walking up (back view) is the blaster hidden behind the body
	var behind := body.animation == "walk_up"
	if (gun.get_index() < body.get_index()) != behind:
		move_child(gun, 0 if behind else -1)
