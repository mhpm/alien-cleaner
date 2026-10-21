class_name ArenaSceneryFader
extends Node
## Makes tall scenery (fade_behind) see-through while the astronaut is behind it, so a
## forest never hides him. The pieces are bucketed once in a coarse grid; 10 times a
## second only the buckets around the astronaut are checked.

const CELL := 128.0
const CHECK := 0.1
const SPEED := 6.0  # alpha per second

var world: GameWorld
var _grid: Dictionary = {}  # Vector2i -> Array[ArenaScenery]
var _faded: Dictionary = {}  # ArenaScenery -> true (currently see-through or recovering)
var _t := 0.0


func setup(game_world: GameWorld, pieces: Array) -> ArenaSceneryFader:
	world = game_world
	name = "SceneryFader"
	for s: ArenaScenery in pieces:
		var r := s.cover_rect()
		var a := Vector2i((r.position / CELL).floor())
		var b := Vector2i((r.end / CELL).floor())
		for y in range(a.y, b.y + 1):
			for x in range(a.x, b.x + 1):
				var c := Vector2i(x, y)
				if not _grid.has(c):
					_grid[c] = []
				_grid[c].append(s)
	return self


func _process(delta: float) -> void:
	_t -= delta
	if _t <= 0.0 and not _grid.is_empty():
		_t = CHECK
		_check()
	for k: Variant in _faded.keys():  # untyped: a piece freed meanwhile (the boss ring) stays a key
		if not is_instance_valid(k) or (k as ArenaScenery).sprite == null:
			_faded.erase(k)
			continue
		var s := k as ArenaScenery
		# back to the piece's own opacity (its tint), not always 1
		var want: float = ArenaScenery.FADE_ALPHA * s.tint.a if _faded[s] else s.tint.a
		s.sprite.modulate.a = move_toward(s.sprite.modulate.a, want, delta * SPEED)
		if not _faded[s] and s.sprite.modulate.a >= s.tint.a:
			_faded.erase(s)


func _check() -> void:
	var p := world.player.global_position + Vector2(0, -10)  # the astronaut's middle
	for k: Variant in _faded.keys():
		_faded[k] = false
	var c := Vector2i((p / CELL).floor())
	for k: Variant in _grid.get(c, []):
		if not is_instance_valid(k):
			continue
		var s := k as ArenaScenery
		if p.y < s.global_position.y - 2.0 and s.cover_rect().has_point(p):
			_faded[s] = true
