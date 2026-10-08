@tool
class_name CharacterData
extends Resource
## A playable character: its animations and how it holds its weapon. One per folder
## assets/characters/<id>/<id>.tres (frames <anim>_<i>.png next to it), made with the
## Arena dock > Players editor (sheet import, rows -> animations, hand / muzzle).
## Animations: idle, walk, walk_up (back view), shoot (aiming to the side), shoot_down /
## shoot_up (aiming down / up), hurt, death; missing ones fall back (walk_up -> walk,
## shoot_down / shoot_up -> shoot -> idle, hurt -> idle, death -> hurt). Frames share one canvas whose
## feet (`anchor`) sit on the horizontal middle, so flip_h is safe. The Player Spawn of an
## arena picks the character; empty = the default player (`default_character`, the kid
## astronaut without a helmet).

const DIR := "res://assets/characters/"
const DEFAULT_ID := "kid_astronaut"
## The helmeted astronaut: the only one with Infected-mode mutant sets (mutant<n>).
const HELMET_ID := "astronaut"
const ANIMS := ["idle", "walk", "walk_up", "shoot", "shoot_down", "shoot_up", "hurt", "death"]
## Shoot pose -> the hand point that holds the weapon in it.
const POSE_HANDS := {"shoot": "shoot_hand", "shoot_down": "shoot_down_hand", "shoot_up": "shoot_up_hand"}

enum Weapon { HELD, IN_SPRITE }

@export var character_id := ""
@export var display_name := ""
@export var frames: SpriteFrames
## Feet in frame pixels (all frames share one canvas).
@export var anchor := Vector2.ZERO
## Pixels of the standing body (idle) -> scaled to `height` world units in game.
@export var body_height := 75.0
@export_range(8.0, 80.0, 0.5) var height := 25.5
## HELD = the ARMORY weapon as a separate sprite that turns toward the aim, held at
## `hand`. IN_SPRITE = the art already carries a gun: the "shoot" animation plays while
## firing and shots leave from `muzzle`.
@export var weapon := Weapon.HELD
## Hands in frame px from the feet, facing right.
@export var hand := Vector2(6, -30)
## HELD: play a shoot pose while firing (the weapon held out) with the weapon at its
## hand: "shoot" (to the side) at `shoot_hand`, "shoot_down" / "shoot_up" (aiming more
## than 45 degrees down / up) at `shoot_down_hand` / `shoot_up_hand`.
@export var aim_pose := false
@export var shoot_hand := Vector2(20, -40)
@export var shoot_down_hand := Vector2(0, -30)
@export var shoot_up_hand := Vector2(0, -50)
## The walk frames hold the arm out: the weapon sits at `walk_hand` while walking, and
## walking while firing to the side keeps walking (no side shoot pose).
@export var walk_aims := false
@export var walk_hand := Vector2(20, -40)
## Gun muzzle in frame px from the feet, facing right (IN_SPRITE).
@export var muzzle := Vector2(30, -30)
## Flash drawn at the muzzle on every shot (its left-middle on the muzzle, along the
## aim), or none. `flash_size` = its length in world units.
@export var muzzle_flash: Texture2D
@export_range(2.0, 40.0, 0.5) var flash_size := 9.0
## Standing = the first idle frame, breathing done in code (the astronaut).
@export var still_idle := false
## Little hop and sway while walking (turn off when the walk frames already bounce).
@export var hop := true


## World units per frame pixel.
func px_scale() -> float:
	return height / maxf(1.0, body_height)


## AnimatedSprite2D offset that puts `anchor` on the node's origin (centered sprite).
func offset() -> Vector2:
	var size := frame_size()
	return Vector2(size.x * 0.5 - anchor.x, size.y * 0.5 - anchor.y)


func frame_size() -> Vector2:
	var t := icon()
	return Vector2(t.get_size()) if t != null else Vector2.ONE


## The animation to show for `anim` (falls back when the character lacks it).
func resolve(anim: String) -> String:
	if frames == null:
		return anim
	var chain := [anim]
	match anim:
		"walk_up":
			chain.append("walk")
		"shoot_down", "shoot_up":
			chain.append_array(["shoot", "idle"])
		"shoot", "hurt":
			chain.append("idle")
		"death":
			chain.append_array(["hurt", "idle"])
	chain.append("idle")
	for a: String in chain:
		if frames.has_animation(a) and frames.get_frame_count(a) > 0:
			return a
	var names := frames.get_animation_names()
	return names[0] if names.size() > 0 else anim


## First idle frame (palette icons, previews).
func icon() -> Texture2D:
	if frames == null:
		return null
	var a := resolve("idle")
	return frames.get_frame_texture(a, 0) if frames.has_animation(a) else null


func is_default() -> bool:
	return character_id == DEFAULT_ID


static func path_of(id: String) -> String:
	return DIR + id + "/" + id + ".tres"


static func load_id(id: String) -> CharacterData:
	var p := path_of(id)
	return load(p) as CharacterData if ResourceLoader.exists(p) else null


static func default_character() -> CharacterData:
	return load_id(DEFAULT_ID)


## Every character in assets/characters/ (the default player first).
static func all() -> Array[CharacterData]:
	var out: Array[CharacterData] = []
	var d := DirAccess.open(DIR)
	if d == null:
		return out
	var ids := d.get_directories()
	ids.sort()
	for id in ids:
		var c := load_id(id)
		if c != null:
			if c.is_default():
				out.push_front(c)
			else:
				out.append(c)
	return out
