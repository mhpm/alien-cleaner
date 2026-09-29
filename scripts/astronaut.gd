class_name Astronaut
extends Node2D
## The astronaut: always the reference-sheet sprite (assets/sprites/player), plus the
## equipped blaster as a separate sprite that rotates around its grip toward `aim`.
## Blaster images and joints: tools/make_suit_parts.py -> assets/suits/<variant>_weapon.png
## + weapons.json (grip / tip in image pixels). Origin = feet. The blaster is always
## drawn in front of the body, except while walking up (back view): then it goes behind.
## Used by the Player and by the CHARACTER screen preview.
## set_form(MutationData.sprite_set(lv)) swaps in the mutant: the astronaut's own frames
## with the mutated helmet of its phase (same scale and animations); set_mutation_gun(lv)
## then puts the mutation gun bought in the MUTATION LAB in its hands instead of the
## blaster (grip / muzzle from MutationData.points(), GUN_LEN world units long). Sets with
## walk_left/right/up/down are `directional` (never flipped, scaled to the astronaut's
## height).

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
var directional := false  # the set has walk_left/right/up/down (no flip_h)
var mut_gun := 0  # mutation gun in the hands (0 = the equipped blaster)
var gun_len := GUN_LEN  # grip -> muzzle in frame px


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
	mut_gun = 0
	gun_len = GUN_LEN
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


## "player" (reference-sheet astronaut) or a mutant set (a bit taller than the astronaut).
func set_form(f: String) -> void:
	form = f
	body.sprite_frames = Art.frames(f)
	body.offset = Art.anchor_offset(f)
	directional = body.sprite_frames.has_animation("walk_left")
	body_scale = BODY_SCALE
	if directional:
		# a separately drawn mutant: always the astronaut's height
		# (the helmet mutants are the astronaut's own frames: same scale)
		body_scale = BODY_SCALE * Art.body_height("player") / Art.body_height(f)
	body.animation = &""
	play("idle")
	if f == "player" and mut_gun > 0:
		refresh()
	_pose()


## Mutation gun `lv` in the mutant's hands (MutationData); 0 = back to the blaster.
func set_mutation_gun(lv: int) -> void:
	if lv <= 0:
		refresh()
		return
	mut_gun = lv
	var info: Dictionary = MutationData.points().guns[lv - 1]
	var grip: Array = info.grip
	var tip: Array = info.tip
	_grip = Vector2(float(grip[0]), float(grip[1]))
	_tip = Vector2(float(tip[0]), float(tip[1]))
	gun.texture = _mipmapped(MutationData.gun_tex(lv))
	gun.offset = -_grip
	gun_len = MutationData.GUN_LEN / BODY_SCALE
	_pose()


static var _mip_cache: Dictionary = {}


## The painted guns are drawn far smaller than their art: mipmaps keep them clean.
static func _mipmapped(src: Texture2D) -> Texture2D:
	if _mip_cache.has(src.resource_path):
		return _mip_cache[src.resource_path]
	var img := src.get_image()
	if img.is_compressed():
		img.decompress()
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_mip_cache[src.resource_path] = tex
	return tex


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
	return gun.position + Vector2.from_angle(aim) * gun_len * BODY_SCALE


func _process(delta: float) -> void:
	breathe_t += delta
	_pose()


func _pose() -> void:
	if body == null:
		return
	# directional sets have their own left / right frames; their idle and combo poses
	# face right and are mirrored
	var one_way := body.animation == &"idle" or str(body.animation).begins_with("combo_")
	body.flip_h = facing < 0.0 and (not directional or one_way)
	# walking: a hop per step with a little squash on landing; standing: slow breathing
	var step := absf(sin(walk_phase))
	var hop := -step * 1.8 * walk_amount
	var land := (1.0 - step) * 0.08 * walk_amount
	var breath := sin(breathe_t * 2.6) * 0.018 * (1.0 - walk_amount)
	body.position = Vector2(0, hop)
	# directional sets have real walk frames in every direction: no procedural sway
	body.rotation = 0.0 if directional else sin(walk_phase) * 0.06 * walk_amount * facing
	body.scale = Vector2(1.0 + land - breath * 0.4, 1.0 - land + breath) * body_scale
	var dir := Vector2.from_angle(aim)
	var s := gun_len / (_tip - _grip).length() * BODY_SCALE
	var base := (_tip - _grip).angle()
	# pointing left: mirror the blaster vertically so it is never upside down
	var flip := dir.x < 0.0
	gun.scale = Vector2(s, -s if flip else s)
	gun.rotation = aim + (base if flip else -base)
	var hand := Vector2(HAND.x * facing, HAND.y * (1.0 - land + breath))
	gun.position = hand * BODY_SCALE + Vector2(0, hop) - dir * recoil * BODY_SCALE
	gun.visible = body.animation != "death" and (form == "player" or mut_gun > 0)
	# only when walking up (back view) is the blaster hidden behind the body
	var behind := body.animation == "walk_up"
	if (gun.get_index() < body.get_index()) != behind:
		move_child(gun, 0 if behind else -1)
