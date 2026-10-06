@tool
extends "resource_list_page.gd"
## MISSIONS: the arena's objectives (ArenaData.objectives). Pick a type and add it with
## sensible defaults (first one MAIN, the next ones SIDE with a coin reward); click a
## row to tune it in the Inspector. Each row also says how many arena objects it is
## about right now, so a "Rescue" with no survivors placed stands out at once.

const ICONS := {
	ObjectiveData.Type.SURVIVE: "Timer", ObjectiveData.Type.DESTROY: "Skeleton2D",
	ObjectiveData.Type.RESCUE: "CharacterBody2D", ObjectiveData.Type.COLLECT: "Key",
	ObjectiveData.Type.REACH_LOCATION: "Marker2D", ObjectiveData.Type.DEFEND: "Shield",
	ObjectiveData.Type.BOSS: "Skull", ObjectiveData.Type.ACTIVATE: "Unlock",
	ObjectiveData.Type.ESCORT: "Path2D", ObjectiveData.Type.KILL: "GPUParticles2D",
	ObjectiveData.Type.CLEAR_WAVES: "AnimationPlayer", ObjectiveData.Type.CUSTOM: "Script",
}

var _type: OptionButton


func _property() -> String:
	return "objectives"


func _hint() -> String:
	return "Target 0 = every matching object. ~3: one MAIN, the rest SIDE."


func _build_header() -> void:
	var row := HBoxContainer.new()
	add_child(row)
	_type = OptionButton.new()
	for i in ObjectiveData.Type.size():
		_type.add_item(ObjectiveData.Type.keys()[i].replace("_", " ").capitalize(), i)
	_type.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_type)
	var add := Button.new()
	add.text = "Add Objective"
	add.icon = EditorInterface.get_editor_theme().get_icon("Add", "EditorIcons")
	add.pressed.connect(_add)
	row.add_child(add)


func _add() -> void:
	if arena == null or arena.data == null:
		return
	var od := ObjectiveData.new()
	od.type = _type.get_selected_id()
	var n := _items().size()
	od.objective_id = "%s_%d" % [ObjectiveData.Type.keys()[od.type].to_lower(), n + 1]
	od.optional = _items().any(func(o: ObjectiveData) -> bool: return o != null and not o.optional)
	if od.is_timed():
		od.target_count = 60
	if od.optional:
		od.reward = RewardData.new()
		od.reward.coins = 50
	add_item(od)


func _rename_copy(copy: Resource) -> void:
	(copy as ObjectiveData).objective_id += "_copy"


func _row_text(res: Resource, _i: int) -> String:
	var od := res as ObjectiveData
	if od == null:
		return "<empty>"
	var target := od.target_count
	var about := ""
	if target <= 0 and not od.is_timed():
		var n := _count(od)
		target = maxi(1, n)
		about = "  · %d in arena" % n if n >= 0 else ""
	return "%s  %s%s   #%s" % ["SIDE" if od.optional else "MAIN", od.label(target), about, od.objective_id]


func _row_icon(res: Resource) -> Texture2D:
	var od := res as ObjectiveData
	var t := EditorInterface.get_editor_theme()
	var name: String = ICONS.get(od.type, "Node") if od != null else "Node"
	return t.get_icon(name, "EditorIcons") if t.has_icon(name, "EditorIcons") else null


## Objects of the arena this objective is about (-1 = not object based).
func _count(od: ObjectiveData) -> int:
	if not od.required_object_ids.is_empty():
		return od.required_object_ids.size()
	match od.type:
		ObjectiveData.Type.CLEAR_WAVES:
			return arena.data.waves.size()
		ObjectiveData.Type.COLLECT:
			return arena.objects("AndroidPart").size() + arena.objects("ArenaChest").size()
		ObjectiveData.Type.KILL, ObjectiveData.Type.CUSTOM:
			return -1
	var cls: String = ObjectiveData.OBJECT_CLASSES.get(od.type, "")
	return arena.objects(cls).size() if not cls.is_empty() else -1
