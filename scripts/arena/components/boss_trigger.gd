@tool
class_name BossTrigger
extends ArenaObject
## Boss encounter: when the astronaut walks into the trigger area the arena locks
## (the game's electric BossFence, which the bosses already use for their moves),
## the boss music starts, an intro banner plays and the boss drops in at `boss_offset`.
## When it falls the fence powers down, the reward is given and "boss_defeated" is
## reported (BOSS objectives / BOSS_DEFEATED waves).

const COLOR := Color("ff5566")

## Key of EnemyData.TYPES (a boss).
@export var boss_id := "big_red_boss":
	set(value):
		boss_id = value
		queue_redraw()
## Trigger area, centred on this node.
@export var trigger_size := Vector2(160, 120):
	set(value):
		trigger_size = value.max(Vector2(16, 16)).round()
		queue_redraw()
## Where the boss lands, from this node.
@export var boss_offset := Vector2(0, -90):
	set(value):
		boss_offset = value
		queue_redraw()
## Ring the fight with the electric fence.
@export var lock_arena := true
@export_range(80.0, 500.0, 5.0) var fence_radius := 230.0:
	set(value):
		fence_radius = value
		queue_redraw()
@export var boss_music := true
## Banner before the boss lands ("" = the boss's name).
@export var intro_text := ""
@export_range(0.0, 10.0, 0.1) var intro_time := 1.6
## Boss health on top of the arena difficulty.
@export_range(0.25, 10.0, 0.05) var hp_mult := 1.0
@export var reward: RewardData
## Counts for this objective even when it lists other ids.
@export var objective_id := ""

var boss: Enemy
var _director: Node
var _state := "wait"  # wait / intro / fight / done
var _fence: BossFence


func _ready() -> void:
	super._ready()
	set_physics_process(false)


func _validate_property(property: Dictionary) -> void:
	if property.name == "boss_id":
		property.hint = PROPERTY_HINT_ENUM  # dropdown with every boss in EnemyData
		property.hint_string = ",".join(ArenaArt.enemy_ids(true))


func arena_layer() -> String:
	return "Triggers"


func palette_icon() -> Texture2D:
	return ArenaArt.enemy_icon(boss_id)


func palette_width() -> float:
	return 40.0


func activate(director: Node) -> void:
	_director = director
	set_physics_process(true)


func trigger_rect() -> Rect2:
	return Rect2(global_position - trigger_size * 0.5, trigger_size)


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint() or _state != "wait":
		return
	var p: Player = _director.world.player
	if not p.dead and trigger_rect().has_point(p.global_position):
		start()


## Begin the encounter (also usable from code / triggers).
func start() -> void:
	if _state != "wait":
		return
	_state = "intro"
	set_physics_process(false)
	var w: GameWorld = _director.world
	var center := global_position + boss_offset * 0.5
	if lock_arena:
		_fence = BossFence.new().setup(center, fence_radius)
		w.effects.add_child(_fence)
		w.survival.fence = _fence  # bosses bounce off it and keep their fights inside
	if boss_music:
		Sfx.play_music("boss")
	Sfx.play("alert", 0.0)
	w.hud.banner(intro_text if not intro_text.is_empty() else ArenaArt.enemy_name(boss_id), COLOR, 34, intro_time)
	w.shake(0.4)
	get_tree().create_timer(intro_time, false).timeout.connect(func() -> void:
		_state = "fight"
		_director.spawner.spawn_boss(boss_id, global_position + boss_offset, _on_boss, hp_mult))


func _on_boss(e: Enemy) -> void:
	boss = e
	_director.track_boss(e)
	e.tree_exiting.connect(_on_boss_gone, CONNECT_ONE_SHOT | CONNECT_DEFERRED)


func _on_boss_gone() -> void:
	if _state == "done" or _director == null:
		return
	_state = "done"
	var w: GameWorld = _director.world
	if is_instance_valid(_fence):
		_fence.dissolve()
	if w.survival.fence == _fence:
		w.survival.fence = null
	w.hud.hide_boss()
	if boss_music:
		Sfx.play_music(_director.data.music if _director.data != null else "level")
	w.hud.banner("BOSS DOWN!", Color("a7f070"), 36, 1.2)
	_director.give(reward, w.player.global_position)
	var tags := PackedStringArray(["boss", boss_id])
	if not objective_id.is_empty():
		tags.append("obj:" + objective_id)
	_director.fire("boss_defeated", object_id, tags)


func is_resolved() -> bool:
	return _state == "done"


func focus_point() -> Vector2:
	return boss.global_position if is_instance_valid(boss) else global_position


func validate_arena(report: ArenaReport, arena: Arena) -> void:
	if not EnemyData.TYPES.has(boss_id) or not bool(EnemyData.TYPES[boss_id].get("boss", false)):
		report.error("Boss trigger %s: \"%s\" is not a boss (EnemyData)." % [name, boss_id], self)
	var b := arena.get_bounds()
	if b != null:
		if not b.global_rect().intersects(trigger_rect()):
			report.error("Boss trigger %s area is outside the arena." % name, self)
		if not b.contains(global_position + boss_offset):
			report.warning("Boss %s lands outside the arena bounds." % name, self)


func _draw_editor() -> void:
	var r := Rect2(-trigger_size * 0.5, trigger_size)
	_zone(r, COLOR)
	_editor_label("BOSS TRIGGER", Vector2(0, r.position.y + 9), COLOR)
	var land := boss_offset
	if lock_arena:
		draw_arc(boss_offset * 0.5, fence_radius, 0.0, TAU, 64, Color("5fe6ff", 0.55), 1.0)
	draw_line(Vector2.ZERO, land, Color(COLOR, 0.6), 1.0)
	var tex := ArenaArt.enemy_icon(boss_id)
	if tex != null:
		var h := 40.0
		var w := h * tex.get_width() / tex.get_height()
		draw_texture_rect(tex, Rect2(land - Vector2(w * 0.5, h), Vector2(w, h)), false, Color(1, 1, 1, 0.85))
	draw_circle(land, 3.0, COLOR)
	_editor_label(ArenaArt.enemy_name(boss_id), land + Vector2(0, 10), COLOR, 9)
	_id_caption(Vector2(0, r.end.y - 3), COLOR)
