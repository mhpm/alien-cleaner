class_name ArenaHorde
extends Node
## Open-map aliens that come to the astronaut instead of from a fixed spot: streams of
## aliens that arrive just off screen (mostly ahead of where he is going), never more
## than a stream's `alive` at once. Used by AROUND_PLAYER waves and by ArenaData.roaming
## (the map's wandering aliens). Its own aliens that fall far behind are walked back to
## the edge of the screen ("leash"), so exploring never leaves the horde stuck across
## the map. Aliens from spawners and nests are left where they belong.

const LEASH_EVERY := 0.5
const LEASH_EXTRA := 160.0  # past the screen edge before an alien is brought back

class Stream:
	var entries: Array = []
	var rate := 1.0
	var alive_cap := 30
	var quota := 0  # 0 = endless
	var elites := 0
	var hp := 1.0
	var sent := 0
	var alive := 0
	var acc := 0.0
	var active := true

	func done() -> bool:
		return quota > 0 and sent >= quota and alive == 0

var director: ArenaDirector
var streams: Array[Stream] = []
var _mine: Dictionary = {}  # Enemy -> true (the leash only moves these)
var _leash_t := 0.0
var _rng := RandomNumberGenerator.new()


func setup(d: ArenaDirector) -> ArenaHorde:
	director = d
	name = "Horde"
	_rng.randomize()
	return self


func start_stream(entries: Array, rate: float, alive_cap: int, quota := 0, elites := 0, hp := 1.0) -> Stream:
	var s := Stream.new()
	s.entries = entries
	s.rate = rate
	s.alive_cap = alive_cap
	s.quota = quota
	s.elites = elites
	s.hp = hp
	streams.append(s)
	return s


func stop(s: Stream) -> void:
	if s != null:
		s.active = false


func _physics_process(delta: float) -> void:
	if director.finished or director.world.state != "survive":
		return
	for s in streams:
		if not s.active or s.entries.is_empty():
			continue
		if s.quota > 0 and s.sent >= s.quota:
			continue
		s.acc += s.rate * delta
		while s.acc >= 1.0 and s.alive < s.alive_cap and (s.quota == 0 or s.sent < s.quota):
			s.acc -= 1.0
			_send(s)
		s.acc = minf(s.acc, 3.0)
	_leash_t -= delta
	if _leash_t <= 0.0:
		_leash_t = LEASH_EVERY
		_leash()


func _send(s: Stream) -> void:
	var e := SpawnEntry.pick(s.entries, _rng)
	if e == null:
		return
	s.sent += 1
	s.alive += 1
	var elite := (s.quota > 0 and s.sent > s.quota - s.elites) or _rng.randf() < e.elite_chance
	director.spawner.spawn(e.enemy_id, _arrival(), elite, false, func(en: Enemy) -> void:
		_mine[en] = true
		en.tree_exiting.connect(func() -> void:
			s.alive -= 1
			_mine.erase(en), CONNECT_ONE_SHOT), s.hp)


## Just off screen, ahead of the astronaut's walk two times out of three.
func _arrival() -> Vector2:
	var w := director.world
	var dir := w.player.input_dir
	var a := dir.angle() + _rng.randf_range(-1.1, 1.1) if dir.length() > 0.2 and _rng.randf() < 0.66 else _rng.randf() * TAU
	return w.survival._edge_pos(a)


func _leash() -> void:
	var w := director.world
	var p := w.player.global_position
	for en: Enemy in _mine.keys():
		if not is_instance_valid(en) or en.dead or en.is_boss:
			continue
		var off := en.global_position - p
		if off.length() > w.survival.edge_dist(off.angle(), LEASH_EXTRA):
			en.global_position = _arrival()
