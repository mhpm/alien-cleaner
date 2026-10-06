class_name ArenaSession
extends RefCounted
## Which arena scene ArenaWorld plays and how. The editor's PLAY ARENA writes a request
## file (CONFIG, in the project's user:// folder, shared with the game it launches);
## code can also set `arena_path` directly. Test runs (`test`) never touch saves: the
## Game state is captured first and restored when the arena closes (like Playground).

const PLAY_SCENE := "res://scenes/arena_play.tscn"
const CONFIG := "user://arena_editor_play.cfg"
const STATE_KEYS := ["bank", "perm", "best_room", "runs", "worlds_cleared", "best_time",
	"chests", "boss_best", "boss_chests", "total_xp", "guns", "gun", "stats", "upgrades",
	"world_index", "room_index", "run_coins", "boss_rush", "menu_scene", "android_parts"]

static var arena_path := ""
static var test := true
static var invincible := false
static var start_wave := 0  # skip to this wave (0 = from the start)
static var _snapshot: Dictionary = {}


## The editor's request (only when nothing set the path in code).
static func load_request() -> void:
	if not arena_path.is_empty():
		return
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG) != OK:
		return
	arena_path = str(cfg.get_value("play", "arena", ""))
	test = bool(cfg.get_value("play", "test", true))
	invincible = bool(cfg.get_value("play", "invincible", false))
	start_wave = int(cfg.get_value("play", "start_wave", 0))


## Written by the editor before launching PLAY_SCENE.
static func write_request(path: String, god_mode: bool, wave: int) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("play", "arena", path)
	cfg.set_value("play", "test", true)
	cfg.set_value("play", "invincible", god_mode)
	cfg.set_value("play", "start_wave", wave)
	cfg.save(CONFIG)


static func begin(world_id: int) -> void:
	if test and _snapshot.is_empty():
		for key: String in STATE_KEYS:
			var value: Variant = Game.get(key)
			_snapshot[key] = value.duplicate(true) if value is Dictionary or value is Array else value
		Game.playground_active = true  # no saves, no banked rewards
	Game.new_run(clampi(world_id - 1, 0, WorldData.WORLDS.size() - 1), false)


static func finish() -> void:
	if _snapshot.is_empty():
		return
	for key: String in STATE_KEYS:
		Game.set(key, _snapshot[key])
	_snapshot.clear()
	Game.playground_active = false
