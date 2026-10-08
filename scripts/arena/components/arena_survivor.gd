@tool
class_name ArenaSurvivor
extends ArenaObject
## A crew member to rescue (the game's own Survivor: shouts, rescue ring, thanks and
## their job's gift). Stand in `rescue_radius` for `rescue_time` (or just touch them
## when `required_interaction` is off). With `escort_to` set they do not beam out:
## they follow the astronaut to that ArenaTrigger zone ("escort_delivered"); aliens that
## reach them hurt them, and if they fall the escort fails ("escort_lost").

const COLOR := Color("a7f070")
const ESCORT_HP := 100.0
const ESCORT_HIT := 22.0  # health lost per second per alien touching them
const FOLLOW := 20.0

## Crew member (SurvivorData.CREW): look and gift.
@export var crew := 0:
	set(value):
		crew = value
		queue_redraw()
## "" = their job title.
@export var character_name := ""
## Their own picture (a villager, scared and happy alike); empty = the crew member's.
## They still give the crew member's gift.
@export var look: Texture2D:
	set(value):
		look = value
		queue_redraw()
## Shown in the dialogue box when rescued ("" = their happy picture).
@export var portrait: Texture2D
## What they shout while waiting ("" = the usual cries for help).
@export var dialogue: PackedStringArray = []
## Said in the dialogue box once rescued ("" = none).
@export var thanks_line := ""
@export_range(10.0, 120.0, 1.0) var rescue_radius := 30.0:
	set(value):
		rescue_radius = value
		queue_redraw()
@export_range(0.5, 30.0, 0.5) var rescue_time := 10.0
## Off = rescued the moment the astronaut touches them.
@export var required_interaction := true
@export var reward: RewardData
## Counts for this objective even when it lists other required ids.
@export var objective_id := ""
## ArenaTrigger object_id to escort them to ("" = beamed out when rescued).
@export var escort_to := "":
	set(value):
		escort_to = value
		queue_redraw()

var survivor: Survivor
var _director: Node
var _rescued := false
var _escorting := false
var _escort_hp := ESCORT_HP
var _escort_zone: ArenaTrigger
var _bar: Node2D


func _ready() -> void:
	super._ready()
	set_physics_process(false)


func arena_layer() -> String:
	return "GameplayObjects"


func palette_icon() -> Texture2D:
	if look != null:
		return look
	return SurvivorData.tex(clampi(crew, 0, SurvivorData.CREW.size() - 1), false)


func palette_width() -> float:
	return 22.0


func _validate_property(property: Dictionary) -> void:
	if property.name == "crew":
		var names: Array[String] = []
		for c: Dictionary in SurvivorData.CREW:
			names.append(str(c.name).capitalize())
		property.hint = PROPERTY_HINT_ENUM
		property.hint_string = ",".join(names)


func activate(director: Node) -> void:
	_director = director
	survivor = Survivor.new()
	survivor.kind = clampi(crew, 0, SurvivorData.CREW.size() - 1)
	survivor.rescue_r = rescue_radius
	survivor.rescue_time = rescue_time if required_interaction else 0.05
	if not dialogue.is_empty():
		survivor.help_lines = Array(dialogue)
	survivor.display_name = character_name
	survivor.look = look
	survivor.beam_out = escort_to.is_empty()
	survivor.position = global_position
	director.world.entities.add_child(survivor)
	survivor.rescued.connect(_on_rescued)
	if not escort_to.is_empty():
		_escort_zone = director.arena.find_object(escort_to) as ArenaTrigger


func _on_rescued(_s: Survivor) -> void:
	_rescued = true
	_director.give(reward, survivor.global_position)
	var who := character_name if not character_name.is_empty() else str(SurvivorData.CREW[survivor.kind].name)
	if not thanks_line.is_empty():
		_director.say(who, thanks_line, portrait if portrait != null else (look if look != null else SurvivorData.tex(survivor.kind, true)), SurvivorData.CREW[survivor.kind].color)
	var tags := PackedStringArray(["crew"])
	if not objective_id.is_empty():
		tags.append("obj:" + objective_id)
	_director.fire("survivor_rescued", object_id, tags)
	if escort_to.is_empty():
		return
	_escorting = true
	_bar = _EscortBar.new()
	_bar.owner_survivor = self
	survivor.add_child(_bar)
	set_physics_process(true)
	_director.world.hud.banner("ESCORT %s!" % who, COLOR, 22, 1.0)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or not _escorting or not is_instance_valid(survivor):
		return
	var w: GameWorld = _director.world
	var p := w.player.global_position
	var to := p - survivor.global_position
	if to.length() > FOLLOW:
		survivor.global_position += to.normalized() * minf(to.length() - FOLLOW, 70.0 * delta)
	# aliens touching them hurt them (only the grid cells around: no searching)
	var touching := 0
	for e in w.enemies_near(survivor.global_position, 8.0):
		if e.global_position.distance_to(survivor.global_position) < e.radius + 8.0:
			touching += 1
	if touching > 0:
		_escort_hp -= ESCORT_HIT * touching * delta
		if randf() < delta * 8.0:
			w.burst(survivor.global_position + Vector2(0, -12), Color("ff5566"), 2, 30.0, 0.3, 1.5)
		if _escort_hp <= 0.0:
			_lost()
			return
	_bar.queue_redraw()
	if _escort_zone != null and _escort_zone.contains(survivor.global_position):
		_escorting = false
		set_physics_process(false)
		_bar.queue_free()
		_director.fire("escort_delivered", object_id, PackedStringArray(["crew"]))
		w.hud.banner("CREW SAFE!" if look == null else "%s SAFE!" % _who().to_upper(), COLOR, 26, 0.9)
		survivor._beam_out()


func _lost() -> void:
	_escorting = false
	set_physics_process(false)
	var w: GameWorld = _director.world
	w.burst(survivor.global_position + Vector2(0, -12), Color("ff5566"), 24, 90.0, 0.5, 2.0)
	w.hud.banner("CREW LOST!" if look == null else "%s LOST!" % _who().to_upper(), Color("ff5566"), 26, 1.0)
	survivor.queue_free()
	_director.fire("escort_lost", object_id)


func _who() -> String:
	return character_name if not character_name.is_empty() else str(SurvivorData.CREW[clampi(crew, 0, SurvivorData.CREW.size() - 1)].name)


func is_resolved() -> bool:
	return _rescued and not _escorting


func focus_point() -> Vector2:
	if _escorting and _escort_zone != null:
		return _escort_zone.focus_point()
	return survivor.global_position if is_instance_valid(survivor) else global_position


func escort_health() -> float:
	return _escort_hp / ESCORT_HP


func validate_arena(report: ArenaReport, arena: Arena) -> void:
	if object_id.is_empty() and objective_id.is_empty():
		report.warning("Survivor %s has no object_id or objective_id: objectives that list ids cannot count them." % name, self)
	if not escort_to.is_empty() and not arena.find_object(escort_to) is ArenaTrigger:
		report.error("Survivor %s escorts to \"%s\", which is not an ArenaTrigger." % [name, escort_to], self)
	if not objective_id.is_empty() and arena.data != null and not arena.data.objectives.any(func(o: ObjectiveData) -> bool: return o != null and o.objective_id == objective_id):
		report.error("Survivor %s points at a missing objective \"%s\"." % [name, objective_id], self)


func _draw_editor() -> void:
	draw_set_transform(Vector2(0, -1), 0.0, Vector2(1.0, 0.38))
	FastDraw.disc(self, Vector2.ZERO, rescue_radius, Color(COLOR, 0.08))
	FastDraw.ring(self, Vector2.ZERO, rescue_radius, COLOR, 1.5)
	draw_set_transform(Vector2.ZERO)
	_standing(palette_icon(), 22.0)
	var who := character_name if not character_name.is_empty() else str(SurvivorData.CREW[clampi(crew, 0, SurvivorData.CREW.size() - 1)].name)
	_editor_label("RESCUE %s · %ds" % [who, rescue_time], Vector2(0, 10), COLOR)
	if not escort_to.is_empty():
		_editor_label("ESCORT → #" + escort_to, Vector2(0, 18), Color("ffcd75"), 7)
		var arena := Arena.of(self)
		var target := arena.find_object(escort_to) if arena != null else null
		if target != null:
			draw_dashed_line(Vector2.ZERO, to_local(target.focus_point()), Color("ffcd75"), 1.0, 6.0)
	_id_caption(Vector2(0, 26), COLOR)


## Health bar over an escorted survivor.
class _EscortBar:
	extends Node2D
	var owner_survivor: ArenaSurvivor

	func _ready() -> void:
		z_index = 30

	func _draw() -> void:
		var k := owner_survivor.escort_health()
		draw_rect(Rect2(-10, -40, 20, 3), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(-10, -40, 20 * k, 3), Color("a7f070") if k > 0.4 else Color("ff5566"))
