@tool
class_name EnemySpawner
extends ArenaObject
## Sends aliens from a weighted list around its position. It starts on its own
## (`auto_start`), when a wave with its `wave_id` begins, or when an ArenaTrigger fires
## at it (`trigger_required`). Aliens arrive through ArenaSpawnService (pool-ready),
## never more than `max_alive` at once. No per-frame searches: it counts its own aliens
## through their tree_exiting signal.

signal finished  # sent everything and all of it is gone

const COLOR := Color("ff6a4d")

@export var enabled := true
## Joins waves with this id (ArenaData.waves). Empty = not part of a wave.
@export var wave_id := "w1":
	set(value):
		wave_id = value
		queue_redraw()
## Weighted alien list, e.g. slime 40, runner 30, spitter 20, big_red 10.
@export var enemies: Array[SpawnEntry] = []:
	set(value):
		enemies = value
		queue_redraw()
## Aliens to send in total (0 = endless until its wave ends).
@export_range(0, 999) var spawn_count := 10:
	set(value):
		spawn_count = value
		queue_redraw()
@export_range(0.1, 30.0, 0.1) var spawn_interval := 1.2
## Aliens per tick.
@export_range(1, 20) var burst := 2
@export_range(0.0, 400.0, 1.0) var spawn_radius := 60.0:
	set(value):
		spawn_radius = value
		queue_redraw()
@export_range(0.0, 120.0, 0.5) var start_delay := 0.0
@export_range(1, 200) var max_alive := 12
## Start when the arena starts (spawners in a wave wait for their wave anyway).
@export var auto_start := false
## Wait for an ArenaTrigger (action START_SPAWNERS) that targets this object_id.
@export var trigger_required := false
## Anywhere inside the radius (off = on the spot, with a little jitter).
@export var random_spawn_position := true
## Only works while the astronaut is this close (0 = anywhere): spawners spread over a
## big map wake up as you explore.
@export_range(0.0, 2000.0, 10.0) var activation_range := 0.0:
	set(value):
		activation_range = value
		queue_redraw()
## Keep this far from the astronaut when picking a spot.
@export_range(0.0, 200.0, 1.0) var min_player_distance := 48.0

var _director: Node
var _active := false
var _quota := 0
var _sent := 0
var _pending := 0
var _alive := 0
var _elites := 0
var _hp := 1.0
var _t := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	super._ready()
	set_physics_process(false)


func arena_layer() -> String:
	return "EnemySpawners"


func palette_editor_icon() -> String:
	return "GPUParticles2D"


func activate(director: Node) -> void:
	_director = director
	_rng.seed = hash(str(get_path()))
	if enabled and auto_start and not trigger_required:
		start()


## Start sending (`quota` < 0 = spawn_count). `elites`: the last N sent are elites.
func start(quota := -1, elites := 0, hp_mult := 1.0) -> void:
	if not enabled or _director == null:
		return
	_active = true
	_quota = spawn_count if quota < 0 else quota
	_elites = elites
	_hp = hp_mult
	_sent = 0
	_t = -start_delay
	set_physics_process(true)


## Stop sending (the aliens already out stay).
func stop() -> void:
	_active = false
	set_physics_process(false)


func is_active() -> bool:
	return _active


func alive() -> int:
	return _alive + _pending


## Sent its whole quota and every alien of it is gone (endless spawners never are).
func is_done() -> bool:
	return _quota > 0 and _sent >= _quota and alive() == 0


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or not _active:
		return
	if activation_range > 0.0 and _director.world.player.global_position.distance_to(global_position) > activation_range:
		return
	_t += delta
	if _t < spawn_interval:
		return
	_t = 0.0
	for i in burst:
		if (_quota > 0 and _sent >= _quota) or alive() >= max_alive:
			break
		_spawn_one()
	if _quota > 0 and _sent >= _quota:
		_active = false
		set_physics_process(false)


func _spawn_one() -> void:
	var entry := SpawnEntry.pick(enemies, _rng)
	if entry == null:
		return
	_sent += 1
	_pending += 1
	var elite := (_quota > 0 and _sent > _quota - _elites) or _rng.randf() < entry.elite_chance
	_director.spawner.spawn(entry.enemy_id, _spot(), elite, false, _on_spawned, _hp)


func _spot() -> Vector2:
	var player_pos: Vector2 = _director.world.player.global_position
	var p := global_position
	for i in 8:
		if random_spawn_position:
			p = global_position + Vector2.from_angle(_rng.randf() * TAU) * sqrt(_rng.randf()) * spawn_radius
		else:
			p = global_position + Vector2(_rng.randf_range(-6, 6), _rng.randf_range(-6, 6))
		if p.distance_to(player_pos) >= min_player_distance:
			break
	return p


func _on_spawned(e: Enemy) -> void:
	_pending -= 1
	_alive += 1
	e.tree_exiting.connect(_on_gone, CONNECT_ONE_SHOT)


func _on_gone() -> void:
	_alive -= 1
	if is_done():
		finished.emit()


func validate_arena(report: ArenaReport, arena: Arena) -> void:
	if enemies.is_empty():
		report.error("Spawner %s has no enemies." % name, self)
	for e in enemies:
		if e == null or not EnemyData.TYPES.has(e.enemy_id):
			report.error("Spawner %s lists an unknown enemy \"%s\"." % [name, e.enemy_id if e != null else "<empty>"], self)
	var b := arena.get_bounds()
	if b != null and not b.contains(global_position):
		report.error("Spawner %s is outside the arena." % name, self)
	if trigger_required and object_id.is_empty():
		report.error("Spawner %s waits for a trigger but has no object_id to be targeted." % name, self)
	if not wave_id.is_empty() and arena.data != null and not arena.data.waves.any(func(w: WaveData) -> bool: return w != null and w.wave_id == wave_id):
		report.warning("Spawner %s is in wave \"%s\", which no wave uses." % [name, wave_id], self)
	if wave_id.is_empty() and not auto_start and not trigger_required:
		report.warning("Spawner %s never starts (no wave, auto start or trigger)." % name, self)


func _draw_editor() -> void:
	var c := COLOR if enabled else Color(0.5, 0.5, 0.5)
	draw_circle(Vector2.ZERO, spawn_radius, Color(c, 0.06))
	_dashed_circle(spawn_radius, c, 1.5)
	if activation_range > 0.0:
		_dashed_circle(activation_range, Color(c, 0.3), 1.0, 64)
	draw_circle(Vector2.ZERO, 3.0, c)
	var shown := 0
	for e in enemies:
		if e == null or shown >= 4:
			continue
		var tex := ArenaArt.enemy_icon(e.enemy_id)
		if tex != null:
			var h := 18.0
			var w := h * tex.get_width() / tex.get_height()
			draw_texture_rect(tex, Rect2(Vector2(-w * 0.5 + (shown - 0.5 * (mini(enemies.size(), 4) - 1)) * 14.0, -h - 2.0), Vector2(w, h)), false)
		shown += 1
	var what := "∞" if spawn_count == 0 else "x%d" % spawn_count
	var when := "wave " + wave_id if not wave_id.is_empty() else ("auto" if auto_start else ("trigger" if trigger_required else "idle"))
	_editor_label("SPAWNER %s · %s" % [what, when], Vector2(0, 11), c)
	_id_caption(Vector2(0, 20), c)
