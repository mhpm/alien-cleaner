class_name Astronaut
extends Node2D
## The playable character (CharacterData: the astronaut by default, or one made in the
## Arena dock > Players editor; set_character), plus the
## ARMORY weapon it carries (Game.gun) as a separate sprite that rotates around its grip
## toward `aim`. Weapon images and joints: tools/make_armory_assets.py ->
## assets/guns/gun_<n>.png + guns.json (grip / tip in image pixels); bigger weapons are
## held a bit longer. Origin = feet. The weapon is always drawn in front of the body,
## except while walking up (back view): then it goes behind. Used by the Player.
## set_form(MutationData.sprite_set(lv)) swaps in the mutant: the astronaut's own frames
## with the mutated helmet of its phase (same scale and animations); set_mutation_gun(lv)
## then puts the mutation gun bought in the MUTATION LAB in its hands instead of the
## blaster (grip / muzzle from MutationData.points(), GUN_LEN world units long). Sets with
## walk_left/right/up/down are `directional` (never flipped, scaled to the astronaut's
## height). Characters whose art already holds a gun (CharacterData.Weapon.IN_SPRITE)
## hide the weapon sprite, play "shoot" while `shooting` and fire from their `muzzle`.

const GUNS_PATH := "res://assets/guns/guns.json"
const BODY_SCALE := 0.34  # sprite frame px -> world units (~25 units tall)
const HAND := Vector2(6, -30)  # hands in frame px from the feet (facing right)
const GUN_LEN := 30.0
const FLASH_TIME := 0.08  # grip -> muzzle in frame px (the Pulse Blaster; others scale)

static var _guns: Dictionary = {}

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
var gun_len := GUN_LEN  # grip -> muzzle in astronaut frame px (x BODY_SCALE = world)
var character: CharacterData  # null until _ready: the default astronaut
var px := BODY_SCALE  # world units per frame px of the character
var shooting := false  # set by the Player while it fires ("shoot" pose)
var flash: Sprite2D  # the character's muzzle flash (fire_flash)
var flash_t := 0.0


func _ready() -> void:
	body = Art.make_anim("player", BODY_SCALE)
	add_child(body)
	gun = Sprite2D.new()
	gun.centered = false
	gun.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(gun)
	flash = Sprite2D.new()
	flash.centered = false
	flash.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	flash.visible = false
	flash.z_index = 1
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	flash.material = add
	add_child(flash)
	set_character(character)
	refresh()


## Swap the playable character (null = the default player, the kid astronaut). Safe before or after _ready.
func set_character(c: CharacterData) -> void:
	if c == null or c.frames == null:
		c = CharacterData.default_character()
	character = c
	if body == null:
		return
	if c != null and c.frames != null:
		body.sprite_frames = c.frames
		body.offset = c.offset()
		px = c.px_scale()
	else:
		body.sprite_frames = Art.frames("player")
		body.offset = Art.anchor_offset("player")
		px = BODY_SCALE
	form = "player"
	body_scale = px
	directional = false
	body.modulate = Color.WHITE
	body.animation = &""
	play("idle")
	_pose()


## Any character but the helmeted astronaut: keeps its own frames while mutated (only
## the helmeted one has mutant sprite sets).
func _custom() -> bool:
	return character != null and character.character_id != CharacterData.HELMET_ID


func _in_sprite() -> bool:
	return character != null and character.weapon == CharacterData.Weapon.IN_SPRITE


## Re-read the equipped weapon (call after buying / equipping).
func refresh() -> void:
	mut_gun = 0
	var n := GunData.index(Game.gun)
	var all: Array = guns_data().guns
	_grip = _point(all[n].grip)
	_tip = _point(all[n].tip)
	var ref := (_point(all[0].tip) - _point(all[0].grip)).length()
	gun_len = GUN_LEN * sqrt((_tip - _grip).length() / ref)
	gun.texture = GunFire.tex("gun_%d" % (n + 1))
	gun.offset = -_grip
	_pose()


static func _point(a: Array) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))


static func guns_data() -> Dictionary:
	if _guns.is_empty():
		_guns = JSON.parse_string(FileAccess.get_file_as_string(GUNS_PATH))
	return _guns


## "player" (reference-sheet astronaut) or a mutant set (a bit taller than the astronaut).
func set_form(f: String) -> void:
	if _custom() or f == "player":
		# other characters keep their own frames while mutated: a magenta tint instead
		var keep := character
		set_character(keep)
		if f != "player":
			form = f
			body.modulate = Color(1.0, 0.55, 1.0)
		if mut_gun > 0 and f == "player":
			refresh()
		return
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
	if character != null and (form == "player" or _custom()):
		if shooting and (_in_sprite() or character.aim_pose) and anim in ["idle", "walk", "walk_up"]:
			var pose := _shoot_pose()
			# walk frames that already aim: keep walking while firing to the side
			if not (pose == "shoot" and anim == "walk" and character.walk_aims):
				anim = pose
		anim = character.resolve(anim)
	if body.animation == anim:
		return
	if anim == "idle" and form == "player" and (character == null or character.still_idle):
		# standing: a single frame holding the blaster; breathing is procedural
		body.animation = "idle"
		body.stop()
		body.frame = 0
	else:
		body.play(anim)


## The shoot pose for the current aim: more than 45 degrees down / up = shoot_down /
## shoot_up (if the character has them), else the side pose.
func _shoot_pose() -> String:
	var y := sin(aim)
	if y > 0.7:
		return "shoot_down"
	if y < -0.7:
		return "shoot_up"
	return "shoot"


## A shot left the muzzle: show the character's muzzle flash for a moment.
func fire_flash() -> void:
	if character != null and character.muzzle_flash != null:
		flash_t = FLASH_TIME
		flash.texture = character.muzzle_flash


func set_layer_material(m: Material) -> void:
	body.material = m
	gun.material = m


## Blaster grip (rotation pivot) and muzzle, in this node's coordinates.
func grip_pos() -> Vector2:
	return gun.position


func muzzle_pos() -> Vector2:
	if _in_sprite() and mut_gun == 0:
		return body.position + Vector2(character.muzzle.x * facing, character.muzzle.y) * px
	return gun.position + Vector2.from_angle(aim) * gun_len * BODY_SCALE


func _process(delta: float) -> void:
	breathe_t += delta
	flash_t = maxf(0.0, flash_t - delta)
	_pose()


func _pose() -> void:
	if body == null:
		return
	# directional sets have their own left / right frames; their idle and combo poses
	# face right and are mirrored
	var one_way := body.animation == &"idle" or str(body.animation).begins_with("combo_")
	body.flip_h = facing < 0.0 and (not directional or one_way)
	# walking: a hop per step with a little squash on landing; standing: slow breathing
	var bounce := walk_amount if character == null or character.hop else 0.0
	var step := absf(sin(walk_phase))
	var hop := -step * 1.8 * bounce
	var land := (1.0 - step) * 0.08 * bounce
	var breath := sin(breathe_t * 2.6) * 0.018 * (1.0 - walk_amount)
	body.position = Vector2(0, hop)
	# directional sets have real walk frames in every direction: no procedural sway
	body.rotation = 0.0 if directional else sin(walk_phase) * 0.06 * bounce * facing
	body.scale = Vector2(1.0 + land - breath * 0.4, 1.0 - land + breath) * body_scale
	var dir := Vector2.from_angle(aim)
	# weapons keep their world size whoever holds them (gun_len is in astronaut frame px)
	var s := gun_len / (_tip - _grip).length() * BODY_SCALE
	var base := (_tip - _grip).angle()
	# pointing left: mirror the blaster vertically so it is never upside down
	var flip := dir.x < 0.0
	gun.scale = Vector2(s, -s if flip else s)
	gun.rotation = aim + (base if flip else -base)
	var h := character.hand if character != null else HAND
	if character != null and character.aim_pose and not _in_sprite() \
			and CharacterData.POSE_HANDS.has(str(body.animation)):
		h = character.get(CharacterData.POSE_HANDS[str(body.animation)])
	elif character != null and character.walk_aims and body.animation == &"walk":
		h = character.walk_hand
	var hand := Vector2(h.x * facing, h.y * (1.0 - land + breath))
	gun.position = hand * px + Vector2(0, hop) - dir * recoil * px
	gun.visible = body.animation != "death" and (form == "player" or _custom() or mut_gun > 0) \
		and (mut_gun > 0 or not _in_sprite())
	flash.visible = flash_t > 0.0 and body.animation != "death"
	if flash.visible:
		var t := flash.texture
		var k := 1.0 - flash_t / FLASH_TIME  # 0 -> 1: pops out, then shrinks
		var len := character.flash_size * (0.75 + 0.45 * sin(k * PI))
		var fs := len / float(t.get_width())
		flash.offset = Vector2(0, -t.get_height() * 0.5)
		flash.position = muzzle_pos()
		flash.rotation = aim
		flash.scale = Vector2(fs, -fs if flip else fs)
		flash.modulate.a = 1.0 - k * 0.5
	# only when walking up (back view) is the blaster hidden behind the body
	var behind := body.animation == "walk_up" or body.animation == "shoot_up"
	if (gun.get_index() < body.get_index()) != behind:
		move_child(gun, 0 if behind else -1)
