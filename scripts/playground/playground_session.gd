class_name PlaygroundSession
extends RefCounted
## Editor opt-in; unavailable in release exports even if the setting was left on.
const SETTING := "debug/playground/enabled"
const PICKER := "res://scenes/playground.tscn"
const COMBAT := "res://scenes/playground_combat.tscn"
const MAX_TOTAL := 100
const STATE_KEYS := ["bank", "perm", "best_room", "runs", "worlds_cleared", "best_time",
	"chests", "boss_best", "total_xp", "gear_owned", "gear_equipped", "stats", "upgrades",
	"world_index", "room_index", "run_coins", "boss_rush", "menu_scene"]

static var counts: Dictionary = {}
static var boss_id := ""
static var invulnerable := false
static var enemies_invincible := false
static var boss_invincible := false
static var snapshot: Dictionary = {}


static func enabled() -> bool:
	return OS.is_debug_build() and bool(ProjectSettings.get_setting(SETTING, false))


static func catalog(bosses: bool) -> Array[String]:
	var ids: Array[String] = []
	for id: String in EnemyData.TYPES:
		if bool(EnemyData.TYPES[id].get("boss", false)) == bosses:
			ids.append(id)
	ids.sort_custom(func(a: String, b: String) -> bool:
		return str(EnemyData.TYPES[a].name).naturalnocasecmp_to(str(EnemyData.TYPES[b].name)) < 0)
	return ids


static func total() -> int:
	var n := 0
	for id: String in counts:
		n += int(counts[id])
	return n


static func valid() -> bool:
	if not enabled() or total() > MAX_TOTAL or (total() == 0 and boss_id.is_empty()):
		return false
	for id: String in counts:
		if not EnemyData.TYPES.has(id) or bool(EnemyData.TYPES[id].get("boss", false)) or int(counts[id]) < 0:
			return false
	return boss_id.is_empty() or (EnemyData.TYPES.has(boss_id) and bool(EnemyData.TYPES[boss_id].get("boss", false)))


static func begin() -> void:
	if not snapshot.is_empty():
		return
	for key: String in STATE_KEYS:
		var value: Variant = Game.get(key)
		snapshot[key] = value.duplicate(true) if value is Dictionary or value is Array else value
	Game.playground_active = true
	Game.new_run(0, false)
	Game.menu_scene = PICKER


static func finish() -> void:
	if snapshot.is_empty():
		return
	for key: String in STATE_KEYS:
		Game.set(key, snapshot[key])
	snapshot.clear()
	Game.playground_active = false
