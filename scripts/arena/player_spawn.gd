@tool
class_name PlayerSpawn
extends ArenaObject
## Where the player appears when the arena starts (origin = feet). One per arena.
## `character` = who plays it (CharacterData, made in the dock > Players); empty = the
## astronaut.

const ICON := "res://assets/sprites/player/idle_0.png"
const ICON_ANCHOR := Vector2(46, 80)  # feet in the frame (assets/sprites/manifest.json)
const ICON_SCALE := 0.34  # Astronaut.BODY_SCALE
const COLOR := Color("73eff7")

@export var character: CharacterData:
	set(value):
		character = value
		queue_redraw()

var _icon: Texture2D


func arena_layer() -> String:
	return "GameplayObjects"


func palette_icon() -> Texture2D:
	return load(ICON)


func palette_width() -> float:
	return 92.0 * ICON_SCALE


func validate_arena(report: ArenaReport, arena: Arena) -> void:
	var spawns := arena.find_children("*", "PlayerSpawn", true, false)
	if spawns.size() > 1 and spawns[0] != self:
		report.error("More than one Player Spawn (keep one).", self)


func _draw_editor() -> void:
	draw_set_transform(Vector2(0, 0), 0.0, Vector2(1.0, 0.5))
	draw_arc(Vector2.ZERO, 14.0, 0.0, TAU, 32, COLOR, 1.5)
	draw_set_transform(Vector2.ZERO)
	var c := character
	if c != null and c.icon() != null:
		var t := c.icon()
		draw_texture_rect(t, Rect2(-c.anchor * c.px_scale(), Vector2(t.get_size()) * c.px_scale()), false)
	else:
		if _icon == null:
			_icon = load(ICON)
		draw_texture_rect(_icon, Rect2(-ICON_ANCHOR * ICON_SCALE, Vector2(_icon.get_size()) * ICON_SCALE), false)
	var who := c.display_name.to_upper() if c != null and c.display_name != "" else ""
	_editor_label("PLAYER SPAWN" + ("  ·  " + who if who != "" else ""), Vector2(0, 12), COLOR)
