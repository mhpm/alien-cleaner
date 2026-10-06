@tool
class_name AndroidPart
extends ArenaObject
## A hidden piece of the damaged android, collected across arenas (Game.android_parts,
## saved). Hidden: only a faint shimmer until the astronaut comes within
## `reveal_radius`, then it lights up, floats and pulls a scan beam. Walk over it to
## take it ("item_collected", tag "android"). A piece already found on another run
## shows as a ghost and only gives its coins.

enum Part { HEAD, CORE, LEFT_ARM, RIGHT_ARM, LEG_MODULE }
const ART := ["head", "core", "left_arm", "right_arm", "leg"]
const COLOR := Color("73eff7")
const PICK_R := 14.0
const SIZE := 18.0

@export var part := Part.HEAD:
	set(value):
		part = value
		queue_redraw()
## Unique across every arena ("android_head_w1"...): the save remembers it.
@export var part_id := "":
	set(value):
		part_id = value
		queue_redraw()
@export var part_name := ""
## Picture ("" = the piece's own art, assets/sprites/android/).
@export var sprite: Texture2D
@export var reward: RewardData
## Counts towards unlocking the android.
@export var required_for_unlock := true
@export var stealth := true
@export_range(10.0, 300.0, 1.0) var reveal_radius := 70.0:
	set(value):
		reveal_radius = value
		queue_redraw()

var _director: Node
var _taken := false
var _owned := false
var _t := 0.0
var _seen := 0.0  # 0 stealth .. 1 revealed


func _ready() -> void:
	super._ready()
	set_process(not Engine.is_editor_hint())
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


func arena_layer() -> String:
	return "GameplayObjects"


func palette_icon() -> Texture2D:
	return texture()


func palette_width() -> float:
	return SIZE


func texture() -> Texture2D:
	return sprite if sprite != null else ArenaArt.tex("res://assets/sprites/android/%s.png" % ART[part])


func display_name() -> String:
	return part_name if not part_name.is_empty() else "ANDROID " + Part.keys()[part].replace("_", " ")


func activate(director: Node) -> void:
	_director = director
	_owned = Game.android_parts.has(part_id)
	_seen = 0.0 if stealth else 1.0
	# drawn with the entities so the astronaut can stand in front of it
	reparent(director.world.entities)


func _process(delta: float) -> void:
	if _director == null or _taken:
		return
	_t += delta
	var p: Player = _director.world.player
	var d := p.global_position.distance_to(global_position)
	if stealth:
		var was := _seen
		_seen = move_toward(_seen, 1.0 if d < reveal_radius else 0.0, delta * 2.0)
		if was < 0.5 and _seen >= 0.5:
			Sfx.play("select", 0.0, -4.0)
			_director.world.popup_text(global_position + Vector2(0, -26), "SIGNAL DETECTED", COLOR, 10)
	queue_redraw()
	if d < PICK_R and not p.dead:
		_take()


func _take() -> void:
	_taken = true
	var w: GameWorld = _director.world
	var fresh := not _owned
	if fresh and not part_id.is_empty():
		Game.android_parts[part_id] = true
		Game.save()  # no-op in editor test runs (their Game state is restored afterwards)
	w.burst(global_position + Vector2(0, -12), COLOR, 30, 110.0, 0.6, 2.5, -40.0)
	w.ring(global_position + Vector2(0, -10), 26.0, COLOR, 0.4, 3.0, true)
	Sfx.play("upgrade", 0.0)
	w.hud.banner(display_name() + ("!" if fresh else " (KNOWN)"), COLOR, 22, 1.1)
	if fresh:
		_director.give(reward, global_position)
		_director.say("ANDROID", "Part recovered: %s. %d / 5 found." % [display_name().to_lower(), _found()], texture(), COLOR)
	else:
		w.drop_pickups(global_position, 3, 0.0)
	_director.fire("item_collected", object_id, PackedStringArray(["android", part_id]))
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.6, 0.2), 0.25)
	tw.tween_callback(queue_free)


func _found() -> int:
	var n := 0
	for k: String in Game.android_parts:
		n += 1 if bool(Game.android_parts[k]) else 0
	return n


func is_resolved() -> bool:
	return _taken


func validate_arena(report: ArenaReport, arena: Arena) -> void:
	if part_id.is_empty():
		report.error("Android part %s has no part_id (it must be unique in the whole game)." % name, self)
		return
	for o in arena.objects("AndroidPart"):
		if o != self and (o as AndroidPart).part_id == part_id and o.get_index() < get_index():
			report.error("Android part id \"%s\" is used twice in this arena." % part_id, self)


func _draw() -> void:
	if Engine.is_editor_hint():
		_draw_editor()
		return
	if _taken:
		return
	var tex := texture()
	var bob := sin(_t * 3.0) * 2.0 * _seen
	var a := lerpf(0.12 + 0.08 * sin(_t * 5.0), 1.0, _seen) * (0.45 if _owned else 1.0)
	# floor glow and scan beam once revealed
	draw_set_transform(Vector2(0, -1), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 12.0, Color(COLOR, 0.25 * _seen))
	draw_set_transform(Vector2.ZERO)
	if _seen > 0.05:
		var beam := Color(COLOR, 0.12 * _seen * (0.7 + 0.3 * sin(_t * 8.0)))
		draw_rect(Rect2(-5, -60, 10, 60), beam)
	var size := Vector2(SIZE, SIZE * tex.get_height() / tex.get_width())
	draw_texture_rect(tex, Rect2(Vector2(-size.x * 0.5, -size.y - 4.0 + bob), size), false, Color(1, 1, 1, a))


func _draw_editor() -> void:
	draw_circle(Vector2.ZERO, reveal_radius, Color(COLOR, 0.04))
	_dashed_circle(reveal_radius, Color(COLOR, 0.5), 1.0, 40)
	_standing(texture(), SIZE, Color(1, 1, 1, 0.55 if stealth else 1.0), 4.0)
	_editor_label("%s%s" % [display_name(), "  (stealth)" if stealth else ""], Vector2(0, 10), COLOR)
	_editor_label(part_id if not part_id.is_empty() else "NO part_id!", Vector2(0, 18), COLOR if not part_id.is_empty() else Color("ff5566"), 7)
