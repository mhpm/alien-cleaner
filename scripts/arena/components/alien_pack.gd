@tool
class_name AlienPack
extends ArenaObject
## Aliens placed by hand: `count` aliens of one kind that stay until they are eliminated
## (no waves needed). Before they notice the astronaut they follow a calm `routine`
## (AlienMind): GUARD their post looking around, WANDER their area, PATROL a path of
## points, or SLEEP. They look (`sight`, `fov`, walls block the view) and listen
## (`hearing`); seen: "?" then "!" and they hunt with their usual attacks, calling the
## pack and any calm alien within `call_radius`. Lost: they search, go home, calm down.
## When they show up (`appear`):
##   ON_START     there from the beginning
##   PLAYER_NEAR  when the astronaut comes within `activation_radius`
##   TRIGGER      when an ArenaTrigger (START_SPAWNERS) targets this pack's object_id
##   ALARM        when a SecurityCamera sounds the alarm (any, or the one named in
##                `alarm_source`): reinforcements
## (`entrance` MARKER = a warning marker first; `arrive_alert` = they come hunting).
## Each one killed fires "placed_alien_killed" (subject = object_id) for ELIMINATE
## objectives; the whole pack killed gives `reward`.

const COLOR := Color("ff7b5c")

enum Appear { ON_START, PLAYER_NEAR, TRIGGER, ALARM }
enum Entrance { INSTANT, MARKER }

## The alien (EnemyData id).
@export var enemy_id := "slime":
	set(value):
		enemy_id = value
		queue_redraw()
@export_range(1, 20) var count := 1:
	set(value):
		count = value
		queue_redraw()
## How far apart the pack stands around this point.
@export_range(0.0, 200.0, 1.0) var spread := 26.0:
	set(value):
		spread = value
		queue_redraw()
@export var elite := false
@export_range(0.2, 10.0, 0.1) var hp_mult := 1.0

@export_group("Calm behaviour")
@export var routine := AlienMind.Kind.WANDER:
	set(value):
		routine = value
		queue_redraw()
## GUARD / SLEEP: the way it faces. 90 = down the screen, 0 = right.
@export_range(-180.0, 180.0, 1.0) var facing_deg := 90.0:
	set(value):
		facing_deg = value
		queue_redraw()
## WANDER: how far from its spot it strolls.
@export_range(10.0, 600.0, 1.0) var wander_radius := 90.0:
	set(value):
		wander_radius = value
		queue_redraw()
## PATROL: the path (offsets from this point, in order).
@export var patrol_points := PackedVector2Array([Vector2(-80, 0), Vector2(80, 0)]):
	set(value):
		patrol_points = value
		queue_redraw()
## PATROL: back to the first point after the last (off = back and forth).
@export var patrol_loop := true
@export_range(0.0, 10.0, 0.1) var patrol_wait := 0.8

@export_group("Senses")
@export_range(0.0, 600.0, 1.0) var sight := 150.0:
	set(value):
		sight = value
		queue_redraw()
@export_range(10.0, 360.0, 1.0) var fov_deg := 110.0:
	set(value):
		fov_deg = value
		queue_redraw()
## Notices the astronaut this close whatever it faces (a sleeper: about half).
@export_range(0.0, 300.0, 1.0) var hearing := 45.0:
	set(value):
		hearing = value
		queue_redraw()
## Seconds of "?" before "!" (0 = at once).
@export_range(0.0, 3.0, 0.05) var notice_time := 0.5
## Calls in every calm alien this close when it starts hunting.
@export_range(0.0, 600.0, 1.0) var call_radius := 140.0
## Loses the astronaut beyond this (then searches, then goes home).
@export_range(50.0, 2000.0, 10.0) var give_up := 320.0

@export_group("Appearance")
@export var appear := Appear.ON_START:
	set(value):
		appear = value
		queue_redraw()
@export_range(20.0, 800.0, 1.0) var activation_radius := 160.0:
	set(value):
		activation_radius = value
		queue_redraw()
## ALARM: only this camera's alarm (its object_id); empty = any alarm.
@export var alarm_source := ""
@export var entrance := Entrance.MARKER
## They arrive hunting ("!") instead of calm (ambushes, alarm reinforcements).
@export var arrive_alert := false
## Given when the whole pack is eliminated.
@export var reward: RewardData

var members: Array[Enemy] = []
var _director: Node
var _appeared := false
var _killed := 0
var _check_t := 0.0


func _validate_property(property: Dictionary) -> void:
	if property.name == "enemy_id":
		property.hint = PROPERTY_HINT_ENUM_SUGGESTION
		property.hint_string = ",".join(ArenaArt.enemy_ids(false) + ArenaArt.enemy_ids(true))


func arena_layer() -> String:
	return "GameplayObjects"


func palette_icon() -> Texture2D:
	return ArenaArt.enemy_icon(enemy_id)


func palette_width() -> float:
	return 24.0


func activate(director: Node) -> void:
	_director = director
	set_physics_process(false)
	match appear:
		Appear.ON_START:
			appear_now(true)
		Appear.PLAYER_NEAR:
			set_physics_process(true)
		Appear.ALARM:
			director.event_fired.connect(func(kind: String, subject: String, _tags: PackedStringArray) -> void:
				if kind == "alarm_raised" and (alarm_source.is_empty() or alarm_source == subject):
					appear_now())


## Brings the pack in (triggers, alarms; ON_START at activation). Once only.
func appear_now(at_start := false) -> void:
	if _appeared or _director == null:
		return
	_appeared = true
	set_physics_process(false)
	var room: Room = _director.world.room
	var marker := entrance == Entrance.MARKER and not at_start
	for i in count:
		var spot := _member_spot(i)
		var pos := room.open_near(spot)
		_director.spawner.spawn(enemy_id, pos, elite, not marker, _on_spawned.bind(pos - global_position), hp_mult)


func _on_spawned(e: Enemy, offset: Vector2) -> void:
	members.append(e)
	var r := AlienMind.make_routine(routine)
	var mind := AlienMind.new()
	mind.sight = sight
	mind.fov = deg_to_rad(fov_deg)
	mind.hearing = hearing
	mind.notice_time = notice_time
	mind.call_radius = call_radius
	mind.give_up = give_up
	mind.facing = Vector2.from_angle(deg_to_rad(facing_deg))
	if r is AlienMind.GuardRoutine:
		(r as AlienMind.GuardRoutine).base = mind.facing
	elif r is AlienMind.WanderRoutine:
		(r as AlienMind.WanderRoutine).radius = wander_radius
	elif r is AlienMind.PatrolRoutine:
		var pr := r as AlienMind.PatrolRoutine
		pr.loop = patrol_loop
		pr.wait = patrol_wait
		for p in patrol_points:  # the pack walks the path in formation (each keeps its offset)
			pr.points.append(_director.world.room.open_near(global_position + p + offset))
	mind.attach(e, r)
	if r is AlienMind.WanderRoutine:
		mind.home = global_position + offset * 0.5  # a pack strolls around its common spot
	if arrive_alert:
		mind.alert(false)
	e.tree_exiting.connect(_on_member_gone.bind(e), CONNECT_ONE_SHOT)


func _on_member_gone(e: Enemy) -> void:
	members.erase(e)
	if not e.dead or _director == null:
		return  # removed, not killed (the arena closing)
	_killed += 1
	_director.fire("placed_alien_killed", object_id, PackedStringArray(["placed", e.type_id]))
	if _killed >= count:
		_director.give(reward, e.global_position)


## PLAYER_NEAR: waits for the astronaut (checked a few times a second).
func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or _director == null or _appeared:
		return
	_check_t -= delta
	if _check_t > 0.0:
		return
	_check_t = 0.2
	var p: Player = _director.world.player
	if p != null and not p.dead and p.global_position.distance_to(global_position) <= activation_radius:
		appear_now()


## Spots of the pack: the first on this point, the rest around it.
func _member_spot(i: int) -> Vector2:
	if i == 0 or count == 1:
		return global_position
	var a := TAU * float(i) / float(count - 1) + 0.4
	return global_position + Vector2.from_angle(a) * spread * (0.7 + 0.3 * float(i % 2))


func is_resolved() -> bool:
	return _appeared and _killed >= count


func focus_point() -> Vector2:
	for e in members:
		if is_instance_valid(e) and not e.dead:
			return e.global_position
	return global_position


## Aliens of this pack that can be alive at once (ArenaValidator.peak_alive).
func alive_cap() -> int:
	return count


func validate_arena(report: ArenaReport, _arena: Arena) -> void:
	if not EnemyData.TYPES.has(enemy_id):
		report.error("Alien pack %s: unknown alien \"%s\"." % [name, enemy_id], self)
	if appear == Appear.TRIGGER and object_id.is_empty():
		report.warning("Alien pack %s appears on a trigger but has no object_id for the trigger to target." % name, self)
	if routine == AlienMind.Kind.PATROL and patrol_points.size() < 2:
		report.warning("Alien pack %s patrols with fewer than 2 points (it will stand still)." % name, self)
	if appear == Appear.PLAYER_NEAR and activation_radius < 60.0:
		report.info("Alien pack %s appears very close to the astronaut (%d)." % [name, int(activation_radius)], self)


func _draw_editor() -> void:
	var col := COLOR
	var details := show_details()  # (dock GRID > Gizmos: cones and paths only when selected)
	if not details:
		# collapsed: who and how many, plus a tick where it faces
		draw_line(Vector2(0, -6), Vector2(0, -6) + Vector2.from_angle(deg_to_rad(facing_deg)) * 10.0, Color(1.0, 0.85, 0.3, 0.8), 1.5)
	# senses: hearing all around, sight as a wedge where it faces (a sleeper does not see)
	if details and hearing > 0.0:
		_dashed_circle(hearing, Color(col, 0.5), 1.0, 24)
	if details and routine != AlienMind.Kind.SLEEP and sight > 0.0:
		var f := deg_to_rad(facing_deg)
		var half := deg_to_rad(fov_deg) * 0.5
		var pts := PackedVector2Array([Vector2.ZERO])
		for k in 13:
			pts.append(Vector2.from_angle(f - half + 2.0 * half * k / 12.0) * sight)
		draw_colored_polygon(pts, Color(1.0, 0.85, 0.3, 0.07))
		for k in pts.size() - 1:
			draw_line(pts[k], pts[k + 1], Color(1.0, 0.85, 0.3, 0.35), 1.0)
		draw_line(Vector2.ZERO, pts[pts.size() - 1], Color(1.0, 0.85, 0.3, 0.35), 1.0)
	match routine if details else -1:
		AlienMind.Kind.WANDER:
			_dashed_circle(wander_radius, Color(0.6, 1.0, 0.6, 0.6), 1.0, 40)
		AlienMind.Kind.PATROL:
			var prev := Vector2.ZERO
			for k in patrol_points.size():
				var p := patrol_points[k]
				draw_line(prev if k > 0 else p, p, Color(0.45, 0.94, 0.97, 0.8), 1.5)
				draw_circle(p, 3.0, Color(0.45, 0.94, 0.97))
				_editor_label(str(k + 1), p + Vector2(0, -5), Color(0.45, 0.94, 0.97), 7)
				prev = p
			if patrol_loop and patrol_points.size() > 2:
				draw_line(patrol_points[patrol_points.size() - 1], patrol_points[0], Color(0.45, 0.94, 0.97, 0.4), 1.0)
	if details and appear == Appear.PLAYER_NEAR:
		_dashed_circle(activation_radius, Color(1.0, 0.4, 0.4, 0.55), 1.5, 48)
	var icon := ArenaArt.enemy_icon(enemy_id)
	for i in count:
		var at := _member_spot(i) - global_position
		draw_set_transform(at)
		_standing(icon, 22.0, Color(1.3, 0.9, 0.85) if elite else Color.WHITE)
		draw_set_transform(Vector2.ZERO)
	if not details and count > 1:  # the pack size stays readable when collapsed
		_badge("x%d" % count, Vector2(9, -20), col)
	var how: String = ["GUARD", "WANDER", "PATROL", "SLEEP"][routine]
	var when: String = ["", " · near", " · trigger", " · alarm"][appear]
	_editor_label("%s x%d · %s%s" % [ArenaArt.enemy_name(enemy_id), count, how, when], Vector2(0, 10), col)
	_id_caption(Vector2(0, 19), col)
