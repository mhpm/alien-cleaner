@tool
class_name ObjectiveData
extends Resource
## One mission of an arena (ArenaData.objectives; ~3: one MAIN, the rest SIDE).
## Arena objects report what happens as events ("survivor_rescued", subject id, tags)
## and each objective decides how much an event advances it (`progress_for`).
## A new objective type = a script that extends ObjectiveData and overrides
## `progress_for` / `tick` / `fails_on` (pick Type.CUSTOM), no other code changes.

enum Type { SURVIVE, DESTROY, RESCUE, COLLECT, REACH_LOCATION, DEFEND, BOSS, ACTIVATE, ESCORT, KILL, CLEAR_WAVES, CUSTOM }

## Which event each type counts (SURVIVE / DEFEND count seconds instead).
const EVENTS := {
	Type.DESTROY: "nest_destroyed", Type.RESCUE: "survivor_rescued", Type.COLLECT: "item_collected",
	Type.REACH_LOCATION: "location_reached", Type.BOSS: "boss_defeated", Type.ACTIVATE: "activated",
	Type.ESCORT: "escort_delivered", Type.KILL: "enemy_killed", Type.CLEAR_WAVES: "wave_cleared",
}
## Which arena objects an objective of each type is about (for counts, validation, the guide arrow).
const OBJECT_CLASSES := {
	Type.DESTROY: "AlienNest", Type.RESCUE: "ArenaSurvivor", Type.COLLECT: "AndroidPart",
	Type.REACH_LOCATION: "ArenaTrigger", Type.BOSS: "BossTrigger", Type.ACTIVATE: "ArenaTrigger",
	Type.ESCORT: "ArenaSurvivor", Type.DEFEND: "DefendCore",
}

@export var objective_id := "main"
@export var type := Type.SURVIVE
## Shown in the HUD ("" = automatic, e.g. "Rescue 2 crew").
@export var title := ""
@export_multiline var description := ""
## How many (or seconds for SURVIVE / DEFEND). 0 = every matching object of the arena.
@export_range(0, 9999) var target_count := 0
## SIDE objective: nice to have, never fails the mission.
@export var optional := false
@export var reward: RewardData
## Only these arena objects count (their object_id). Empty = any of the right kind.
@export var required_object_ids: PackedStringArray = []
## KILL: only this alien (EnemyData id). COLLECT: only items with this tag ("android", "chest").
@export var filter := ""
## Seconds to finish it (0 = no limit). A timed-out MAIN objective fails the mission.
@export_range(0.0, 900.0, 1.0) var time_limit := 0.0


## How much `kind` (about `subject`, with `tags`) advances this objective.
func progress_for(kind: String, subject: String, tags: PackedStringArray) -> int:
	if not EVENTS.has(type) or EVENTS[type] != kind:
		return 0
	if not required_object_ids.is_empty() and not required_object_ids.has(subject) and not tags.has("obj:" + objective_id):
		return 0
	if type == Type.REACH_LOCATION and required_object_ids.is_empty() and not tags.has("reach"):
		return 0  # any trigger reports where you walk; only REACH_LOCATION zones count by default
	if not filter.is_empty():
		if type == Type.KILL and subject != filter:
			return 0
		if type == Type.COLLECT and not tags.has(filter):
			return 0
	return 1


## Progress that comes with time (seconds survived / defended).
func tick(delta: float) -> float:
	return delta if type in [Type.SURVIVE, Type.DEFEND] else 0.0


## Events that make it fail outright ("core_destroyed" while defending...).
func fails_on(kind: String, subject: String) -> bool:
	match type:
		Type.DEFEND:
			return kind == "core_destroyed" and (required_object_ids.is_empty() or required_object_ids.has(subject))
		Type.ESCORT:
			return kind == "escort_lost" and (required_object_ids.is_empty() or required_object_ids.has(subject))
	return false


func is_timed() -> bool:
	return type in [Type.SURVIVE, Type.DEFEND]


func label(target: int) -> String:
	if not title.is_empty():
		return title
	match type:
		Type.SURVIVE:
			return "Survive %ds" % target
		Type.DEFEND:
			return "Defend the core %ds" % target
		Type.DESTROY:
			return "Destroy %d alien nest%s" % [target, "s" if target != 1 else ""]
		Type.RESCUE:
			return "Rescue %d crew" % target
		Type.COLLECT:
			return "Collect %d item%s" % [target, "s" if target != 1 else ""]
		Type.REACH_LOCATION:
			return "Reach the marked zone"
		Type.BOSS:
			return "Defeat the boss"
		Type.ACTIVATE:
			return "Activate %d console%s" % [target, "s" if target != 1 else ""]
		Type.ESCORT:
			return "Escort %d crew to safety" % target
		Type.KILL:
			return "Clean %d %s" % [target, filter if not filter.is_empty() else "aliens"]
		Type.CLEAR_WAVES:
			return "Clear %d wave%s" % [target, "s" if target != 1 else ""]
	return objective_id.capitalize()


func describe() -> String:
	return "%s  %s%s" % ["SIDE" if optional else "MAIN", Type.keys()[type],
		"  x%d" % target_count if target_count > 0 else ""]
