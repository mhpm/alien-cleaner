@tool
class_name SpawnEntry
extends Resource
## One alien kind a spawner (or nest) can send, with its relative weight.
## Weights are relative: 40 / 30 / 20 / 10 = 40% / 30% / 20% / 10%.

## Key of EnemyData.TYPES.
@export var enemy_id := "slime"
@export_range(0.0, 100.0, 0.5) var weight := 10.0
## Chance (0-1) this alien comes as a golden elite.
@export_range(0.0, 1.0, 0.05) var elite_chance := 0.0


func _validate_property(property: Dictionary) -> void:
	if property.name == "enemy_id":
		property.hint = PROPERTY_HINT_ENUM_SUGGESTION
		property.hint_string = ",".join(ArenaArt.enemy_ids(false))


static func make(id: String, w := 10.0) -> SpawnEntry:
	var e := SpawnEntry.new()
	e.enemy_id = id
	e.weight = w
	return e


## Weighted pick from `entries` (null when empty / all zero).
static func pick(entries: Array, rng: RandomNumberGenerator) -> SpawnEntry:
	var total := 0.0
	for e: SpawnEntry in entries:
		if e != null:
			total += maxf(e.weight, 0.0)
	if total <= 0.0:
		return null
	var r := rng.randf() * total
	for e: SpawnEntry in entries:
		if e == null:
			continue
		r -= maxf(e.weight, 0.0)
		if r <= 0.0:
			return e
	return entries.back()
