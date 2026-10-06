@tool
class_name ArenaTrigger
extends ArenaObject
## A rectangular zone that reacts when the astronaut walks in. One component covers the
## arena's trigger kinds through `action`:
##   REACH_LOCATION  just reports "location_reached" (mission / extraction zones; shown)
##   MESSAGE         dialogue box with `speaker` + `message` (dialogue trigger)
##   START_WAVE      starts the waves whose wave_id is in `targets` (wave trigger)
##   START_SPAWNERS  starts the EnemySpawners in `targets`
##   ACTIVATE_HAZARDS switches on the HazardAreas in `targets`
##   OPEN_DOOR       opens the ArenaDoors in `targets` (door trigger)
##   ACTIVATE        a console: stay inside `hold_time` seconds -> "activated"
## Every action also reports "location_reached" with this object_id (except ACTIVATE,
## which reports "activated" when done), so objectives can point at any trigger.

enum Action { REACH_LOCATION, MESSAGE, START_WAVE, START_SPAWNERS, ACTIVATE_HAZARDS, OPEN_DOOR, ACTIVATE }
const COLORS := [Color("a7f070"), Color("73eff7"), Color("ffcd75"), Color("ff6a4d"), Color("ff9a3a"), Color("41a6f6"), Color("c75bd6")]
const CONSOLE := "res://assets/sprites/lab/lab_058.png"

@export var action := Action.REACH_LOCATION:
	set(value):
		action = value
		queue_redraw()
@export var size := Vector2(64, 64):
	set(value):
		size = value.max(Vector2(8, 8)).round()
		queue_redraw()
## object_ids (or wave_ids for START_WAVE) this trigger acts on.
@export var targets: PackedStringArray = []:
	set(value):
		targets = value
		queue_redraw()
## MESSAGE: the conversation (characters + lines). Edit it with the Dialogue Editor:
## double-click the trigger, or "Open Dialogue Editor" here in the Inspector.
@export var dialogue: DialogueData:
	set(value):
		dialogue = value
		queue_redraw()
## MESSAGE without a dialogue: a single line.
@export var speaker := "MISSION CONTROL"
@export_multiline var message := "":
	set(value):
		message = value
		queue_redraw()
@export var portrait: Texture2D
## Fire only the first time.
@export var once := true
## ACTIVATE: seconds to stand inside.
@export_range(0.5, 30.0, 0.5) var hold_time := 3.0
## Draw the zone in the game (default: zones the player must find).
@export var show_in_game := true
@export var reward: RewardData

var _director: Node
var _inside := false
var _fired := false
var _hold := 0.0
var _t := 0.0


func _ready() -> void:
	super._ready()
	set_physics_process(false)


func arena_layer() -> String:
	return "Triggers"


func palette_editor_icon() -> String:
	return ["Marker2D", "RichTextLabel", "AnimationPlayer", "GPUParticles2D", "Warning", "Unlock", "Key"][action]


func palette_width() -> float:
	return size.x


func rect() -> Rect2:
	return Rect2(-size * 0.5, size)


func contains(global_point: Vector2) -> bool:
	return rect().has_point(to_local(global_point))


func activate(director: Node) -> void:
	_director = director
	visible = show_in_game and action in [Action.REACH_LOCATION, Action.ACTIVATE]
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or _director == null or (_fired and once):
		return
	_t += delta
	var p: Player = _director.world.player
	var now := not p.dead and contains(p.global_position)
	if action == Action.ACTIVATE:
		_hold = clampf(_hold + (delta if now else -delta * 0.5), 0.0, hold_time)
		if now and fmod(_t, 0.25) < delta:
			Sfx.play("select", 0.0, -16.0 + 8.0 * _hold / hold_time)
		if _hold >= hold_time:
			_fire()
	elif now and not _inside:
		_fire()
	_inside = now
	if visible:
		queue_redraw()


func _fire() -> void:
	_fired = true
	var d: Node = _director
	d.give(reward, global_position)
	match action:
		Action.MESSAGE:
			if has_dialogue():
				d.play_dialogue(dialogue)
			else:
				d.say(speaker, message, portrait, COLORS[action])
		Action.START_WAVE:
			for id in targets:
				d.waves.start_by_id(id)
		Action.START_SPAWNERS:
			for o in _targets():
				if o is EnemySpawner:
					(o as EnemySpawner).start()
		Action.ACTIVATE_HAZARDS:
			for o in _targets():
				if o is HazardArea:
					(o as HazardArea).set_active(true)
		Action.OPEN_DOOR:
			for o in _targets():
				if o is ArenaDoor:
					(o as ArenaDoor).open()
		Action.ACTIVATE:
			d.world.burst(global_position, COLORS[action], 24, 90.0, 0.5, 2.0, -40.0)
			d.world.ring(global_position, maxf(size.x, size.y) * 0.5, COLORS[action], 0.4, 3.0)
			Sfx.play("upgrade", 0.0)
			d.world.hud.banner("ACTIVATED", COLORS[action], 24, 0.8)
			d.fire("activated", object_id)
			queue_redraw()
			return
	if action == Action.REACH_LOCATION:
		d.world.ring(global_position, maxf(size.x, size.y) * 0.5, COLORS[action], 0.4, 2.0)
		Sfx.play("select", 0.0)
	d.fire("location_reached", object_id, PackedStringArray(["reach"] if action == Action.REACH_LOCATION else []))
	if once:
		visible = false


func has_dialogue() -> bool:
	return dialogue != null and not dialogue.is_empty()


## The dialogue to edit: this trigger's, or one made from its single line.
func editable_dialogue() -> DialogueData:
	if dialogue != null:
		return dialogue
	var d := DialogueData.new()
	var who := DialogueSpeaker.new()
	who.name = speaker
	who.portrait = portrait
	who.color = COLORS[Action.MESSAGE]
	d.cast.append(who)
	var line := DialogueLine.new()
	line.text = message
	d.lines.append(line)
	return d


func _targets() -> Array[ArenaObject]:
	var out: Array[ArenaObject] = []
	for id in targets:
		var o: ArenaObject = _director.find(id)
		if o != null:
			out.append(o)
	return out


func is_resolved() -> bool:
	return _fired


func validate_arena(report: ArenaReport, arena: Arena) -> void:
	var b := arena.get_bounds()
	if b != null and not b.global_rect().intersects(Rect2(global_position - size * 0.5, size)):
		report.error("Trigger %s is outside the arena bounds." % name, self)
	if action in [Action.START_SPAWNERS, Action.ACTIVATE_HAZARDS, Action.OPEN_DOOR, Action.START_WAVE] and targets.is_empty():
		report.warning("Trigger %s (%s) has no targets." % [name, Action.keys()[action]], self)
	for id in targets:
		if action == Action.START_WAVE:
			if arena.data != null and not arena.data.waves.any(func(w: WaveData) -> bool: return w != null and w.wave_id == id):
				report.error("Trigger %s starts wave \"%s\", which does not exist." % [name, id], self)
		elif arena.find_object(id) == null:
			report.error("Trigger %s targets missing object \"%s\"." % [name, id], self)
	if action == Action.MESSAGE and message.strip_edges().is_empty() and not has_dialogue():
		report.warning("Dialogue trigger %s has no message." % name, self)


func _draw() -> void:
	if Engine.is_editor_hint():
		_draw_editor()
		return
	var c: Color = COLORS[action]
	var pulse := 0.5 + 0.5 * sin(_t * 4.0)
	var r := rect()
	if action == Action.ACTIVATE:
		_standing(ArenaArt.tex(CONSOLE), 16.0, Color.WHITE if not _fired else Color(0.6, 0.7, 0.8))
		draw_set_transform(Vector2(0, -1), 0.0, Vector2(1.0, 0.45))
		var rad := maxf(r.size.x, r.size.y) * 0.5
		draw_arc(Vector2.ZERO, rad, 0.0, TAU, 40, Color(c, 0.35 + 0.25 * pulse), 1.5)
		if _hold > 0.0:
			draw_arc(Vector2.ZERO, rad, -PI * 0.5, -PI * 0.5 + TAU * _hold / hold_time, 40, c, 3.0)
		draw_set_transform(Vector2.ZERO)
		return
	draw_rect(r, Color(c, 0.06 + 0.06 * pulse))
	var k := 6.0 + 3.0 * pulse
	for corner: Vector2 in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
		var sx := 1.0 if corner.x < 0.0 else -1.0
		var sy := 1.0 if corner.y < 0.0 else -1.0
		draw_line(corner, corner + Vector2(k * sx, 0), c, 2.0)
		draw_line(corner, corner + Vector2(0, k * sy), c, 2.0)


## Canvas preview of a MESSAGE trigger: the faces of the cast and the first line.
func _draw_dialogue_preview(c: Color) -> void:
	if not has_dialogue():
		if not message.is_empty():
			_editor_label("\"%s\"" % message.left(28), Vector2(0, 4), Color(1, 1, 1, 0.8), 7)
		_editor_label("double-click: write dialogue", Vector2(0, 13), Color(c, 0.75), 7)
		return
	var faces: Array[Texture2D] = []
	for s in dialogue.cast:
		if s != null and s.portrait != null:
			faces.append(s.portrait)
	var fw := 14.0
	var x := -faces.size() * (fw + 2.0) * 0.5
	for f in faces:
		var k := fw / maxf(f.get_width(), f.get_height())
		draw_rect(Rect2(x, -18, fw, fw), Color(c, 0.2))
		draw_texture_rect(f, Rect2(Vector2(x + (fw - f.get_width() * k) * 0.5, -18 + fw - f.get_height() * k), f.get_size() * k), false)
		x += fw + 2.0
	var first := ""
	for l in dialogue.lines:
		if l != null and not l.text.is_empty():
			first = l.text
			break
	_editor_label("\"%s\"" % first.left(28), Vector2(0, 4), Color(1, 1, 1, 0.85), 7)
	_editor_label(dialogue.summary().left(36), Vector2(0, 13), Color(c, 0.9), 7)


func _draw_editor() -> void:
	var c: Color = COLORS[action]
	_zone(rect(), c)
	if action == Action.ACTIVATE:
		_standing(ArenaArt.tex(CONSOLE), 16.0)
	_editor_label(Action.keys()[action].replace("_", " "), Vector2(0, rect().position.y + 9), c)
	if action == Action.MESSAGE:
		_draw_dialogue_preview(c)
	_id_caption(Vector2(0, rect().end.y - 3), c)
	var arena := Arena.of(self)
	if arena == null or action == Action.START_WAVE:
		return
	for id in targets:
		var o := arena.find_object(id)
		if o != null:
			draw_dashed_line(Vector2.ZERO, to_local(o.focus_point()), c, 1.0, 5.0)
			draw_circle(to_local(o.focus_point()), 3.0, c)
