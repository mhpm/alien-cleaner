@tool
class_name ArenaArt
extends RefCounted
## Read-only lookups the arena components need both in the editor (where the Art
## autoload does not run) and in the game: enemy lists, portraits, names.

static var _icons: Dictionary = {}


## Sorted EnemyData ids: the bosses or the regular aliens (internal kinds skipped).
static func enemy_ids(bosses: bool) -> Array[String]:
	var ids: Array[String] = []
	for id: String in EnemyData.TYPES:
		var def: Dictionary = EnemyData.TYPES[id]
		if bool(def.get("boss", false)) == bosses and not bool(def.get("internal", false)):
			ids.append(id)
	ids.sort()
	return ids


static func enemy_name(id: String) -> String:
	return str(EnemyData.TYPES[id].name) if EnemyData.TYPES.has(id) else "?" + id


## First walk frame of an alien (assets/sprites/<art>/walk_0.png), cached.
static func enemy_icon(id: String) -> Texture2D:
	if not EnemyData.TYPES.has(id):
		return null
	if not _icons.has(id):
		var path := "res://assets/sprites/%s/walk_0.png" % str(EnemyData.TYPES[id].art)
		_icons[id] = load(path) if ResourceLoader.exists(path) else null
	return _icons[id]


static func tex(path: String) -> Texture2D:
	if not _icons.has(path):
		_icons[path] = load(path) if ResourceLoader.exists(path) else null
	return _icons[path]
