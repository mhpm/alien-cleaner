@tool
class_name ArenaData
extends Resource
## Everything about an arena that is not a placed object: metadata, difficulty,
## missions and waves. Lives inside the arena scene (Arena.data) so a duplicated arena
## carries its own copy. Kept free of node references (objects are linked by object_id)
## so a generator could build one later without touching the editor.

enum Difficulty { EASY, MEDIUM, HARD, NIGHTMARE }
## Alien health / damage per difficulty.
const DIFFICULTY_HP := [0.8, 1.0, 1.35, 1.8]
const DIFFICULTY_DMG := [0.75, 1.0, 1.2, 1.5]
const ENVIRONMENTS := ["Space Station", "Alien Laboratory", "The Hive", "The Void", "Orbital Deck", "Cargo Bay", "Reactor",
	"Earth - Forest", "Earth - Town", "Earth - City", "Earth - Desert", "Earth - Countryside"]

@export_group("Identity")
## Unique id, e.g. "w03_a02". Saves and validation use it.
@export var arena_id := ""
@export var display_name := ""
@export_range(1, 99) var world_id := 1
@export_range(1, 99) var level_id := 1
@export_multiline var description := ""

@export_group("Feel")
@export var difficulty := Difficulty.MEDIUM
@export_range(1, 99) var recommended_level := 1
@export var environment := "Space Station"
## Music while playing ("level", "boss" or "menu"; see Sfx.play_music).
@export_enum("level", "boss", "menu") var music := "level"
## Art variants PropData uses for props ("hive" = world 2 art).
@export_enum("ship", "hive") var prop_theme := "ship"
## Seconds of calm before the first wave.
@export_range(0.0, 30.0, 0.5) var start_delay := 2.0
## Aliens drop XP gems and the astronaut levels up (upgrade choices) like in survival.
@export var level_ups := true

@export_group("Open World")
## Aliens that keep wandering in around the explorer all game long (0 alive = off).
@export var roaming: Array[SpawnEntry] = []
@export_range(0, 250) var roaming_alive := 0
@export_range(0.1, 10.0, 0.1) var roaming_rate := 0.6
## Show the explorer's minimap (maps bigger than the screen).
@export var minimap := true
## Light over the whole map (white = none; orange = dusk, dark blue = night).
@export var ambient := Color.WHITE
## What shows past the map's edges.
@export var background := Color(0.043, 0.055, 0.102)

@export_group("Missions")
## The arena's main boss, if any (key of EnemyData.TYPES). Validation checks it has a way in.
@export var boss_id := ""
@export var objectives: Array[ObjectiveData] = []
@export var waves: Array[WaveData] = []
## Given when the arena is cleared.
@export var rewards: RewardData


func _validate_property(property: Dictionary) -> void:
	match property.name:
		"boss_id":
			property.hint = PROPERTY_HINT_ENUM_SUGGESTION
			property.hint_string = "," + ",".join(ArenaArt.enemy_ids(true))
		"environment":
			property.hint = PROPERTY_HINT_ENUM_SUGGESTION
			property.hint_string = ",".join(ENVIRONMENTS)


func hp_mult() -> float:
	return DIFFICULTY_HP[difficulty]


func dmg_mult() -> float:
	return DIFFICULTY_DMG[difficulty]


func difficulty_name() -> String:
	return Difficulty.keys()[difficulty].capitalize()
