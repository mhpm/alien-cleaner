class_name ArenaDirector
extends Node
## Runs a playing Arena inside GameWorld (ArenaWorld). It owns the arena's services
## and is the one place components talk to:
##   spawner      ArenaSpawnService (pool-ready alien spawning)
##   waves        ArenaWaveManager  (ArenaData.waves)
##   objectives   ArenaObjectives   (ArenaData.objectives + HUD panel)
##   fire()       an arena event ("nest_destroyed", subject id, tags) -> objectives,
##                waves and anything listening to `event_fired` (doors...)
##   give()       hand out a RewardData
##   say()        the dialogue box (play_dialogue() for a whole conversation)
## Objects are activated once at the start; no group or tree searches per frame.

signal event_fired(kind: String, subject: String, tags: PackedStringArray)
signal arena_finished(won: bool, reason: String)

const GUIDE_EVERY := 0.4

var world: GameWorld
var arena: Arena
var data: ArenaData
var spawner: ArenaSpawnService
var waves: ArenaWaveManager
var objectives: ArenaObjectives
var dialogue: ArenaDialogue
var horde: ArenaHorde
var finished := false
var waves_skip := 0  # PLAY ARENA "start at wave": waves before it are skipped
var elapsed := 0.0
var kills := 0
var coins_given := 0
var _by_id: Dictionary = {}
var _by_class: Dictionary = {}  # class name -> Array[ArenaObject]
var _all: Array[ArenaObject] = []
var _exits: Array[ArenaExit] = []
var _extracting := false
var _guide_t := 0.0
var guide_target := Vector2.INF


func setup(game_world: GameWorld, playing: Arena) -> ArenaDirector:
	world = game_world
	arena = playing
	data = arena.data if arena.data != null else ArenaData.new()
	name = "ArenaDirector"
	spawner = ArenaSpawnService.new(world, data)
	return self


## Bring every arena object to life, then start the missions and the waves.
func start() -> void:
	_all = arena.objects()
	for o in _all:
		if not o.object_id.is_empty():
			_by_id[o.object_id] = o
		if o is ArenaExit:
			_exits.append(o as ArenaExit)
	horde = ArenaHorde.new().setup(self)
	add_child(horde)
	if data.roaming_alive > 0 and not data.roaming.is_empty():
		horde.start_stream(data.roaming, data.roaming_rate, data.roaming_alive)
	dialogue = ArenaDialogue.new()
	dialogue.hud = world.hud
	world.hud.safe.add_child(dialogue)
	objectives = ArenaObjectives.new().setup(self)
	add_child(objectives)
	waves = ArenaWaveManager.new().setup(self)
	add_child(waves)
	for o in _all.duplicate():
		o.activate(self)
	# collected / destroyed objects free themselves: forget them so lookups stay safe
	for o in _all:
		o.tree_exited.connect(func() -> void:
			if not is_instance_valid(o) or o.is_queued_for_deletion():
				_all.erase(o))
	_open_world()
	objectives.start()
	waves.start()


## Big maps: see-through tall scenery and, when it does not fit on screen, the minimap.
func _open_world() -> void:
	var tall := _all.filter(func(o: ArenaObject) -> bool: return o is ArenaScenery and (o as ArenaScenery).fade_behind)
	if not tall.is_empty():
		add_child(ArenaSceneryFader.new().setup(world, tall))
	var area := world.room.bounds()
	var view := world.view_size()
	if data.minimap and (area.size.x > view.x * 1.3 or area.size.y > view.y * 1.3):
		world.hud.safe.add_child(ArenaMinimap.new().setup(self, area))


func find(id: String) -> ArenaObject:
	return _by_id.get(id) as ArenaObject


## Objects of one class (cached per class: big maps hold hundreds of objects and the
## minimap / guide arrow ask several times a second).
func objects_of(class_filter: String) -> Array[ArenaObject]:
	if not _by_class.has(class_filter):
		var list: Array[ArenaObject] = []
		for o in _all:
			if is_instance_valid(o) and is_a(o, class_filter):
				list.append(o)
		_by_class[class_filter] = list
	var cached: Array[ArenaObject] = _by_class[class_filter]
	return cached.filter(func(o: ArenaObject) -> bool: return is_instance_valid(o))


## True when `o`'s script (or one it extends) is the global class `class_filter`.
static func is_a(o: Object, class_filter: String) -> bool:
	var s := o.get_script() as Script
	while s != null:
		if s.get_global_name() == class_filter:
			return true
		s = s.get_base_script()
	return false


## Every spawner of a wave id.
func spawners_for(wave_id: String) -> Array[EnemySpawner]:
	var out: Array[EnemySpawner] = []
	for o in _all:
		if is_instance_valid(o) and o is EnemySpawner and (o as EnemySpawner).wave_id == wave_id and (o as EnemySpawner).enabled:
			out.append(o as EnemySpawner)
	return out


func fire(kind: String, subject := "", tags := PackedStringArray()) -> void:
	if finished:
		return
	event_fired.emit(kind, subject, tags)
	objectives.on_event(kind, subject, tags)
	waves.on_event(kind, subject, tags)


func on_enemy_killed(e: Enemy) -> void:
	kills += 1
	fire("enemy_killed", e.type_id, PackedStringArray(["boss"] if e.is_boss else []))


func track_boss(e: Enemy) -> void:
	world.hud.show_boss(e)


func give(reward: RewardData, at: Vector2) -> void:
	if reward == null or reward.is_empty():
		return
	if reward.coins > 0:
		world.drop_pickups(at, mini(reward.coins, 12), 0.0)
		if reward.coins > 12:
			Game.add_coins(reward.coins - 12)
		coins_given += reward.coins
	if reward.xp > 0 and world.survival != null:
		var left := reward.xp
		while left > 0:
			var v := mini(left, 10)
			world.survival._drop("xp", at + Vector2(randf_range(-10, 10), randf_range(-6, 6)), v)
			left -= v
	if reward.heal > 0.0:
		Game.heal(float(Game.stats.max_hp) * reward.heal)
		world.popup_text(world.player.global_position + Vector2(0, -28), "+HP", Color("a7f070"), 13)
	if reward.upgrade and world.survival != null:
		world.survival.pending_levels += 1
		world.survival._offer.call_deferred()
	var msg := reward.message if not reward.message.is_empty() else reward.describe().to_upper()
	world.popup_text(at + Vector2(0, -20), msg, Color("ffcd75"), 11)


func say(speaker: String, text: String, portrait: Texture2D = null, color := Color("73eff7")) -> void:
	if not text.strip_edges().is_empty():
		dialogue.show_line(speaker, text, portrait, color)


## A whole conversation (DialogueData from a Dialogue Trigger).
func play_dialogue(conversation: DialogueData) -> void:
	if conversation != null and not conversation.is_empty():
		dialogue.play(conversation)


## Every MAIN objective is done: open the exits (or win right away without one).
func main_objectives_done() -> void:
	if finished or _extracting:
		return
	if _exits.is_empty():
		finish(true, "")
		return
	_extracting = true
	for x in _exits:
		x.open()
	world.hud.banner("EXTRACT!", Color("a7f070"), 40, 1.3)
	world.hud.set_wave_text("TO THE EXIT")
	say("MISSION CONTROL", "Area secure. Get to the extraction portal!", null, Color("a7f070"))


func exit_reached(_x: ArenaExit) -> void:
	if not objectives.main_done() and not _extracting:
		return
	finish(true, "")


func finish(won: bool, reason: String) -> void:
	if finished:
		return
	finished = true
	waves.stop_all()
	for st in horde.streams:
		horde.stop(st)
	if won:
		give(data.rewards, world.player.global_position)
	arena_finished.emit(won, reason)


func _physics_process(delta: float) -> void:
	if finished or world.state != "survive":
		return
	elapsed += delta
	var s := world.survival
	if s != null:
		world.hud.set_xp(float(s.xp) / float(s.need(s.level)), s.level)
	world.hud.room_label.text = "%02d:%02d" % [floori(elapsed / 60.0), int(elapsed) % 60]
	_guide_t -= delta
	if _guide_t <= 0.0:
		_guide_t = GUIDE_EVERY
		guide_target = _find_guide()


## Nearest unfinished thing the current objectives are about (the open exit first).
func _find_guide() -> Vector2:
	var p := world.player.global_position
	if _extracting:
		for x in _exits:
			return x.global_position
	var best := Vector2.INF
	for o in objectives.pointed_objects():
		if not is_instance_valid(o) or o.is_resolved():
			continue
		var at := o.focus_point()
		if best == Vector2.INF or p.distance_squared_to(at) < p.distance_squared_to(best):
			best = at
	# only worth an arrow when it is off screen-ish
	if best != Vector2.INF and p.distance_to(best) < 90.0:
		return Vector2.INF
	return best
