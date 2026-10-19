@tool
class_name PlayerSpawn
extends ArenaObject
## Where the player appears when the arena starts (origin = feet). One per arena.
## `character` = who plays it (CharacterData, made in the dock > Players); empty = the
## crew member picked in CREW (the editor shows that one too, read from the save).

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
	var c := shown_character()
	return c.icon() if c != null and c.icon() != null else load(ICON)


func palette_width() -> float:
	var c := shown_character()
	return c.icon().get_width() * c.px_scale() if c != null and c.icon() != null else 92.0 * ICON_SCALE


## Who will play: the chosen character, or when empty the one picked in CREW.
func shown_character() -> CharacterData:
	return character if character != null else CharacterData.picked()


func validate_arena(report: ArenaReport, arena: Arena) -> void:
	var spawns := arena.find_children("*", "PlayerSpawn", true, false)
	if spawns.size() > 1 and spawns[0] != self:
		report.error("More than one Player Spawn (keep one).", self)


func _draw_editor() -> void:
	draw_set_transform(Vector2(0, 0), 0.0, Vector2(1.0, 0.5))
	draw_arc(Vector2.ZERO, 14.0, 0.0, TAU, 32, COLOR, 1.5)
	draw_set_transform(Vector2.ZERO)
	var c := shown_character()
	if c != null and c.icon() != null:
		var t := c.icon()
		draw_texture_rect(t, Rect2(-c.anchor * c.px_scale(), Vector2(t.get_size()) * c.px_scale()), false)
	else:
		if _icon == null:
			_icon = load(ICON)
		draw_texture_rect(_icon, Rect2(-ICON_ANCHOR * ICON_SCALE, Vector2(_icon.get_size()) * ICON_SCALE), false)
	var who := (c.display_name.to_upper() if c != null and c.display_name != "" else "") 		+ ("" if character != null else " (PICKED CREW)")
	_editor_label("PLAYER SPAWN" + ("  ·  " + who if who != "" else ""), Vector2(0, 12), COLOR)
	var arena := Arena.of(self)
	var rules := arena.data.player_rules if arena != null and arena.data != null else null
	if rules != null and not rules.is_default():  # the arena's PlayerRules, at a glance
		_editor_label(rules.summary(), Vector2(0, 21), Color(1.0, 0.75, 0.35), 7)
