@tool
extends EditorInspectorPlugin
## A face grid at the top of a Survivor's Inspector: click a crew member to make this
## survivor them (look and gift; undoable).

var undo: EditorUndoRedoManager


func _can_handle(object: Object) -> bool:
	return object is ArenaSurvivor


func _parse_begin(object: Object) -> void:
	var sv := object as ArenaSurvivor
	var scale := EditorInterface.get_editor_scale()
	var box := VBoxContainer.new()
	var title := Label.new()
	title.text = "Crew member"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 5
	box.add_child(grid)
	var info := Label.new()
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.modulate = Color(1, 1, 1, 0.7)
	var describe := func(i: int) -> String:
		var c: Dictionary = SurvivorData.CREW[i]
		return "%s — %s" % [str(c.name).capitalize(), c.gift]
	info.text = describe.call(clampi(sv.crew, 0, SurvivorData.CREW.size() - 1))
	var group := ButtonGroup.new()
	for i in SurvivorData.CREW.size():
		var c: Dictionary = SurvivorData.CREW[i]
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = i == sv.crew
		b.icon = SurvivorData.tex(i, false)
		b.expand_icon = true
		b.custom_minimum_size = Vector2(40, 46) * scale
		b.tooltip_text = describe.call(i)
		b.pressed.connect(func() -> void:
			if sv.crew == i:
				return
			undo.create_action("Survivor: %s" % str(c.name).capitalize(), UndoRedo.MERGE_DISABLE, sv)
			undo.add_do_property(sv, "crew", i)
			undo.add_undo_property(sv, "crew", sv.crew)
			undo.commit_action()
			info.text = describe.call(i))
		grid.add_child(b)
	box.add_child(info)
	add_custom_control(box)
