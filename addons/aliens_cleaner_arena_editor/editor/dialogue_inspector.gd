@tool
extends EditorInspectorPlugin
## A big "Open Dialogue Editor" button at the top of a Dialogue Trigger's Inspector.

var open: Callable  # func(trigger: ArenaTrigger)


func _can_handle(object: Object) -> bool:
	return object is ArenaTrigger


func _parse_begin(object: Object) -> void:
	var t := object as ArenaTrigger
	if t.action != ArenaTrigger.Action.MESSAGE:
		return
	var b := Button.new()
	b.text = "Open Dialogue Editor"
	var th := EditorInterface.get_editor_theme()
	b.icon = th.get_icon("RichTextLabel", "EditorIcons")
	b.custom_minimum_size.y = 34 * EditorInterface.get_editor_scale()
	b.tooltip_text = "Characters, faces, lines, text size and effects, with a live preview.\n(Or double-click the trigger in the 2D view.)"
	b.pressed.connect(func() -> void: open.call(t))
	var info := Label.new()
	info.text = t.dialogue.summary() if t.has_dialogue() else "Single line (speaker / message below)"
	info.modulate = Color(1, 1, 1, 0.55)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var v := VBoxContainer.new()
	v.add_child(b)
	v.add_child(info)
	add_custom_control(v)
