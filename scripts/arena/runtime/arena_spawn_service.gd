class_name ArenaSpawnService
extends RefCounted
## How arena aliens come into the world. Spawners, nests and waves only ever call
## `spawn()`: to switch to an object pool later, extend this class, override `_create`
## (e.g. `return ObjectPool.spawn(id)` and set it up) and hand that service to the
## ArenaDirector; nothing in the spawners changes.
## Toughness: the arena's difficulty on top of the survival director's own scaling
## (alien hits relative to the crew's health), so arenas feel like the real worlds.

const MARKER_TIME := 0.7

var world: GameWorld
var hp_mult := 1.0
var dmg_mult := 1.0


func _init(game_world: GameWorld, data: ArenaData) -> void:
	world = game_world
	if data != null:
		hp_mult = data.hp_mult()
		dmg_mult = data.dmg_mult()


## Brings alien `id` in at `pos` (a warning marker first unless `instant`) and calls
## `on_spawned(enemy)` once it exists. `extra_hp` multiplies its health (waves, nests).
func spawn(id: String, pos: Vector2, elite := false, instant := false, on_spawned := Callable(), extra_hp := 1.0) -> void:
	if not EnemyData.TYPES.has(id):
		push_warning("Arena: unknown enemy id " + id)
		return
	var b := world.room.bounds().grow(-10.0)
	pos = world.room.open_near(pos.clamp(b.position, b.end))
	if instant:
		_deliver(_create(id, pos, elite, extra_hp), on_spawned)
		return
	var def: Dictionary = EnemyData.TYPES[id]
	var col: Color = Color("ffcd75") if elite else def.color
	var m := world._marker(pos, MARKER_TIME, 6.0 + float(def.radius) * (1.4 if elite else 1.0), col)
	m.finished.connect(func() -> void: _deliver(_create(id, pos, elite, extra_hp), on_spawned))


## A boss: bigger marker, roar, the HUD boss bar.
func spawn_boss(id: String, pos: Vector2, on_spawned := Callable(), extra_hp := 1.0) -> void:
	var m := world._marker(pos, 1.0, 22.0, Color("ff5566"))
	m.finished.connect(func() -> void:
		var b := _create(id, pos, false, extra_hp)
		world.hud.show_boss(b)
		Sfx.play("roar", 0.0)
		world.shake(0.7)
		_deliver(b, on_spawned))


## Override point for pooling.
func _create(id: String, pos: Vector2, elite: bool, extra_hp: float) -> Enemy:
	var s := world.survival
	var hp := hp_mult * extra_hp * (s._hp_mult() if s != null else 1.0)
	var dmg := dmg_mult * (s._dmg_mult() if s != null else 1.0)
	if bool(EnemyData.TYPES[id].get("boss", false)):
		dmg *= Survival.BOSS_DMG
	return world.spawn_enemy(id, pos, hp, 1.0, elite, false, dmg)


func _deliver(e: Enemy, on_spawned: Callable) -> void:
	if e != null and on_spawned.is_valid():
		on_spawned.call(e)
