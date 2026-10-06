@tool
extends EditorInspectorPlugin
## Picture editors in the Inspector for the alien lists (spawners and nests `enemies`,
## waves `horde`, the arena's `roaming`) and the boss ids (Boss Trigger, waves).

const EnemyList := preload("enemy_list_property.gd")
const BossPick := preload("boss_pick_property.gd")
const LISTS := ["enemies", "horde", "roaming"]


func _can_handle(object: Object) -> bool:
	return object is EnemySpawner or object is AlienNest or object is WaveData \
		or object is ArenaData or object is BossTrigger


func _parse_property(object: Object, type: Variant.Type, name: String, _hint: PropertyHint,
		_hint_string: String, _usage: int, _wide: bool) -> bool:
	if type == TYPE_ARRAY and name in LISTS:
		add_property_editor(name, EnemyList.new(), false, name.capitalize() + " (aliens)")
		return true
	if type == TYPE_STRING and name == "boss_id":
		var pick := BossPick.new()
		pick.allow_none = not (object is BossTrigger)
		add_property_editor(name, pick, false, "Boss")
		return true
	return false
