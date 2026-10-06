@tool
class_name WaveData
extends Resource
## One wave of an arena (ArenaData.waves, played in order by ArenaWaveManager).
## A wave starts every EnemySpawner whose `wave_id` matches and, optionally, a boss.
## It ends when its completion condition is met; then the reward, a pause and the next.

## SPAWNERS: the wave's EnemySpawners send it. AROUND_PLAYER: it arrives just off screen
## wherever the astronaut is (open maps). BOTH: spawners and the horde together.
enum SpawnMode { SPAWNERS, AROUND_PLAYER, BOTH }
enum Completion { ALL_ENEMIES_DEAD, SURVIVE_TIME, DESTROY_NESTS, RESCUE_SURVIVORS, COLLECT_ITEMS, BOSS_DEFEATED }

## Spawners with this wave_id join the wave (e.g. "w1"). Several waves may share one.
@export var wave_id := "w1"
## Banner text ("" = "WAVE n").
@export var title := ""
@export_range(0.0, 60.0, 0.5) var delay_before := 2.0
@export var spawn_mode := SpawnMode.SPAWNERS
## AROUND_PLAYER / BOTH: what the horde is made of (weighted).
@export var horde: Array[SpawnEntry] = []
## Horde aliens per second and how many of them may be alive at once.
@export_range(0.1, 20.0, 0.1) var horde_rate := 1.5
@export_range(1, 250) var horde_alive := 30
## Total aliens the wave sends: split between its spawners (0 = each spawner's own
## count); with a horde, the horde's total (0 = it keeps coming until the wave ends).
@export_range(0, 999) var enemy_count := 0
## Golden elites among them (the last ones sent).
@export_range(0, 50) var elite_count := 0
## Alien toughness for this wave (1 = the arena's).
@export_range(0.5, 5.0, 0.05) var hp_mult := 1.0
@export var completion := Completion.ALL_ENEMIES_DEAD
## SURVIVE_TIME: seconds. Other conditions: how many (0 = all of them in the arena).
@export_range(0.0, 600.0, 1.0) var target := 0.0
## Optional boss that enters when the wave starts (key of EnemyData.TYPES).
@export var boss_id := ""
@export var reward: RewardData
@export_range(0.0, 60.0, 0.5) var next_wave_delay := 3.0


func _validate_property(property: Dictionary) -> void:
	if property.name == "boss_id":
		property.hint = PROPERTY_HINT_ENUM_SUGGESTION
		property.hint_string = "," + ",".join(ArenaArt.enemy_ids(true))


func display_title(index: int) -> String:
	return title if not title.is_empty() else "WAVE %d" % (index + 1)


func describe() -> String:
	var c: String = Completion.keys()[completion].capitalize()
	if completion == Completion.SURVIVE_TIME:
		c = "Survive %ds" % int(target)
	elif target > 0.0 and completion != Completion.ALL_ENEMIES_DEAD:
		c += " x%d" % int(target)
	var s := "[%s] %s" % [wave_id, c]
	if spawn_mode != SpawnMode.SPAWNERS:
		s += " · HORDE" if spawn_mode == SpawnMode.AROUND_PLAYER else " · spawners+horde"
	if enemy_count > 0:
		s += " · %d aliens" % enemy_count
	if elite_count > 0:
		s += " · %d elite" % elite_count
	if not boss_id.is_empty():
		s += " · BOSS " + boss_id
	return s
