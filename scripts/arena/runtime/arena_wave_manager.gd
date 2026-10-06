class_name ArenaWaveManager
extends Node
## Plays ArenaData.waves in order: pause (`delay_before`), start the wave's spawners
## (splitting `enemy_count`, last ones elite) and its boss, wait for the completion
## condition (checked 4x per second), give the reward, report "wave_cleared" and move
## on after `next_wave_delay`. A wave whose id an ArenaTrigger targets (START_WAVE)
## waits for it instead of starting by itself.

signal wave_started(index: int)
signal wave_cleared(index: int)
signal all_cleared

const CHECK_EVERY := 0.25

var director: ArenaDirector
var waves: Array[WaveData] = []
var index := -1
var state := "idle"  # idle / delay / wait_trigger / run / gap / done
var _t := 0.0
var _check := 0.0
var _spawners: Array[EnemySpawner] = []
var _stream: ArenaHorde.Stream  # the wave's horde (AROUND_PLAYER / BOTH)
var _bosses: Array[Enemy] = []
var _boss_pending := 0
var _counts: Dictionary = {}  # event kind -> count since the wave began
var _armed: Dictionary = {}  # wave ids a trigger has started
var _gated: Dictionary = {}  # wave ids that wait for a trigger


func setup(d: ArenaDirector) -> ArenaWaveManager:
	director = d
	name = "Waves"
	for w in d.data.waves:
		if w != null:
			waves.append(w)
	return self


func start() -> void:
	# waves a START_WAVE trigger points at wait for it
	for o in director.objects_of("ArenaTrigger"):
		var t := o as ArenaTrigger
		if t.action == ArenaTrigger.Action.START_WAVE:
			for id in t.targets:
				_gated[id] = true
	if waves.is_empty():
		state = "done"
		all_cleared.emit()
		return
	index = clampi(director.waves_skip, 0, waves.size()) - 1
	_next(director.data.start_delay)


func total() -> int:
	return waves.size()


## Trigger START_WAVE: lets a gated wave begin (now, if it is the one waiting).
func start_by_id(id: String) -> void:
	_armed[id] = true
	if state == "wait_trigger" and waves[index].wave_id == id:
		_begin()


func stop_all() -> void:
	if _stream != null:
		_stream.active = false
	for s in _spawners:
		if is_instance_valid(s):
			s.stop()
	state = "done"


func on_event(kind: String, _subject: String, _tags: PackedStringArray) -> void:
	_counts[kind] = int(_counts.get(kind, 0)) + 1


func _next(delay: float) -> void:
	index += 1
	if index >= waves.size():
		state = "done"
		director.world.hud.set_wave_text("ALL WAVES CLEAR")
		all_cleared.emit()
		return
	state = "delay"
	_t = delay + waves[index].delay_before


func _physics_process(delta: float) -> void:
	if director.finished or director.world.state != "survive":
		return
	match state:
		"delay":
			_t -= delta
			_hud()
			if _t <= 0.0:
				var id := waves[index].wave_id
				if _gated.has(id) and not _armed.has(id):
					state = "wait_trigger"
					director.world.hud.set_wave_text("WAVE %d/%d · FIND THE SIGNAL" % [index + 1, waves.size()])
				else:
					_begin()
		"run":
			_t += delta
			_check -= delta
			if _check <= 0.0:
				_check = CHECK_EVERY
				_hud()
				if _complete():
					_end()
		"gap":
			_t -= delta
			if _t <= 0.0:
				_next(0.0)


func _begin() -> void:
	var w := waves[index]
	state = "run"
	_t = 0.0
	_check = CHECK_EVERY
	_counts.clear()
	_bosses.clear()
	_boss_pending = 0
	_spawners = director.spawners_for(w.wave_id)
	_stream = null
	var horde_only := w.spawn_mode == WaveData.SpawnMode.AROUND_PLAYER
	if w.spawn_mode != WaveData.SpawnMode.SPAWNERS and not w.horde.is_empty():
		_stream = director.horde.start_stream(w.horde, w.horde_rate, w.horde_alive,
			w.enemy_count if horde_only else 0, w.elite_count if horde_only else 0, w.hp_mult)
	if horde_only:
		_spawners = []
	# split the wave's total between its spawners; the last ones sent are elites
	var n := _spawners.size()
	for i in n:
		var quota := -1
		var elites := 0
		if w.enemy_count > 0:
			quota = floori(float(w.enemy_count) / n) + (1 if i < w.enemy_count % n else 0)
		if w.elite_count > 0:
			elites = floori(float(w.elite_count) / n) + (1 if i < w.elite_count % n else 0)
		_spawners[i].start(quota, elites, w.hp_mult)
	if not w.boss_id.is_empty() and EnemyData.TYPES.has(w.boss_id):
		_boss_pending = 1
		var at := _boss_spot()
		director.spawner.spawn_boss(w.boss_id, at, func(e: Enemy) -> void:
			_boss_pending = 0
			_bosses.append(e)
			e.tree_exiting.connect(func() -> void:
				if not director.finished:
					director.fire("boss_defeated", w.boss_id, PackedStringArray(["boss", "wave"])), CONNECT_ONE_SHOT | CONNECT_DEFERRED), w.hp_mult)
	var col := Color("ff5566") if not w.boss_id.is_empty() else Color("ffcd75")
	director.world.hud.banner(w.display_title(index), col, 32, 0.9)
	Sfx.play("alert", 0.0, -4.0)
	wave_started.emit(index)
	_hud()


## Upper part of the arena, away from the astronaut.
func _boss_spot() -> Vector2:
	var b := director.world.room.bounds()
	var p := director.world.player.global_position
	var top := Vector2(b.get_center().x, b.position.y + minf(110.0, b.size.y * 0.25))
	var bottom := Vector2(b.get_center().x, b.end.y - minf(110.0, b.size.y * 0.25))
	return top if p.distance_to(top) > p.distance_to(bottom) else bottom


func _alive() -> int:
	var n := _stream.alive if _stream != null else 0
	for s in _spawners:
		n += s.alive()
	return n


func _spawning() -> bool:
	if _stream != null and _stream.active and (_stream.quota == 0 or _stream.sent < _stream.quota):
		return true
	for s in _spawners:
		if s.is_active():
			return true
	return false


func _bosses_alive() -> bool:
	if _boss_pending > 0:
		return true
	for b in _bosses:
		if is_instance_valid(b) and not b.dead:
			return true
	return false


func _complete() -> bool:
	var w := waves[index]
	var target := int(w.target)
	match w.completion:
		WaveData.Completion.ALL_ENEMIES_DEAD:
			return not _spawning() and _alive() == 0 and not _bosses_alive()
		WaveData.Completion.SURVIVE_TIME:
			return _t >= w.target
		WaveData.Completion.DESTROY_NESTS:
			return _reached("nest_destroyed", target, "AlienNest")
		WaveData.Completion.RESCUE_SURVIVORS:
			return _reached("survivor_rescued", target, "ArenaSurvivor")
		WaveData.Completion.COLLECT_ITEMS:
			return _reached("item_collected", target, "")
		WaveData.Completion.BOSS_DEFEATED:
			return not _bosses_alive() and (not w.boss_id.is_empty() or int(_counts.get("boss_defeated", 0)) >= maxi(target, 1))
	return false


## `target` events this wave (0 = every such object of the arena is done).
func _reached(kind: String, target: int, cls: String) -> bool:
	if target > 0:
		return int(_counts.get(kind, 0)) >= target
	var objs := director.objects_of(cls) if not cls.is_empty() else director.objects_of("AndroidPart") + director.objects_of("ArenaChest")
	return objs.all(func(o: ArenaObject) -> bool: return not is_instance_valid(o) or o.is_resolved())


func _end() -> void:
	var w := waves[index]
	state = "gap"
	_t = w.next_wave_delay
	# survive-type waves leave endless spawners running: stop them
	for s in _spawners:
		s.stop()
	director.horde.stop(_stream)
	if w.completion == WaveData.Completion.SURVIVE_TIME:
		for e in director.world.enemy_cache:
			if is_instance_valid(e) and not (e as Enemy).is_boss and not e is AlienNestBody:
				(e as Enemy).take_damage(999999.0, Vector2.ZERO)
	var last := index == waves.size() - 1
	director.world.hud.banner("WAVE CLEAR!" if not last else "ALL WAVES CLEAR!", Color("a7f070"), 34, 0.9)
	Sfx.play("clean", 0.0)
	for pk in get_tree().get_nodes_in_group("pickups"):
		(pk as Pickup).magnet = true
	director.give(w.reward, director.world.player.global_position)
	wave_cleared.emit(index)
	director.fire("wave_cleared", w.wave_id, PackedStringArray(["wave"]))


func _hud() -> void:
	if director.finished:
		return
	var hud := director.world.hud
	if state == "delay":
		hud.set_wave_text("WAVE %d/%d IN %d" % [index + 1, waves.size(), ceili(maxf(_t, 0.0))])
		return
	if state != "run":
		return
	var w := waves[index]
	var txt := "WAVE %d/%d" % [index + 1, waves.size()]
	if w.completion == WaveData.Completion.SURVIVE_TIME:
		txt += "  SURVIVE %d" % ceili(maxf(0.0, w.target - _t))
	elif w.completion == WaveData.Completion.ALL_ENEMIES_DEAD:
		var left := _alive()
		if _stream != null and _stream.quota > 0:
			left += maxi(0, _stream.quota - _stream.sent)
		for s in _spawners:
			left += maxi(0, s._quota - s._sent) if s._quota > 0 else 0
		txt += "  %d LEFT" % left
	hud.set_wave_text(txt)
