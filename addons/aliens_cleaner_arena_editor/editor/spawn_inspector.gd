@tool
extends EditorInspectorPlugin
## An "Edit Players" button at the top of a Player Spawn's Inspector.

var open: Callable  # func()


func _can_handle(object: Object) -> bool:
	return object is PlayerSpawn


func _parse_begin(object: Object) -> void:
	var sp := object as PlayerSpawn
	var b := Button.new()
	b.text = "Edit Players…"
	b.icon = EditorInterface.get_editor_theme().get_icon("CharacterBody2D", "EditorIcons")
	b.custom_minimum_size.y = 34 * EditorInterface.get_editor_scale()
	b.tooltip_text = "Import a sheet, animations, size, weapon; \"Use in this arena\" sets the character below"
	b.pressed.connect(func() -> void: open.call())
	var info := Label.new()
	info.text = "Plays: " + (sp.character.display_name if sp.character != null else "Astronaut (default)")
	info.modulate = Color(1, 1, 1, 0.55)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var v := VBoxContainer.new()
	v.add_child(b)
	v.add_child(info)
	add_custom_control(v)
