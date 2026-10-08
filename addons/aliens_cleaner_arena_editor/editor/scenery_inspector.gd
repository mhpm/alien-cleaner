@tool
extends EditorInspectorPlugin
## "Apply to all copies" at the top of a placed decoration's Inspector: change one piece
## (size, collision, wind, shadow, tint, animation...) and copy those settings to every
## other piece of the arena with the same picture in one undoable step. They are also
## saved as the picture's defaults in its kit.json, so new copies come out the same.
## Position, flip and object_id stay per piece.

const Objects := preload("object_library.gd")
## Properties copied to the other pieces.
const PROPS := ["width", "tint", "footprint", "blocks_bullets", "sway", "fade_behind", "flat",
	"bridge", "shadow", "columns", "rows", "frame_count", "fps", "play_once"]

var undo: EditorUndoRedoManager


func _can_handle(object: Object) -> bool:
	return object is ArenaScenery and (object as ArenaScenery).texture != null


func _parse_begin(object: Object) -> void:
	var src := object as ArenaScenery
	var copies := _copies(src)
	var b := Button.new()
	b.text = "Apply to all %d copies" % copies.size()
	b.icon = EditorInterface.get_editor_theme().get_icon("Duplicate", "EditorIcons")
	b.custom_minimum_size.y = 34 * EditorInterface.get_editor_scale()
	b.tooltip_text = "Copy this piece's settings (size, collision, wind, see-through, flat, bridge, shadow, tint, animation) to the other pieces with the same picture, and keep them as its defaults for new copies. Position and flip stay."
	b.disabled = copies.is_empty() and not src.texture.resource_path.begins_with(Objects.DECOR)
	b.pressed.connect(func() -> void:
		apply_to_copies(src)
		b.text = "Applied to %d copies ✓" % _copies(src).size())
	var info := Label.new()
	info.text = "%s · %d other copies in this arena" % [src.texture.resource_path.get_file(), copies.size()]
	info.modulate = Color(1, 1, 1, 0.55)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.clip_text = true
	var v := VBoxContainer.new()
	v.add_child(b)
	v.add_child(info)
	add_custom_control(v)


## Every other ArenaScenery of the edited arena with the same picture.
func _copies(src: ArenaScenery) -> Array[ArenaObject]:
	var arena := EditorInterface.get_edited_scene_root() as Arena
	if arena == null or src.texture == null:
		return []
	var path := src.texture.resource_path
	var out: Array[ArenaObject] = []
	for o in arena.objects("ArenaScenery"):
		var t := (o as ArenaScenery).texture
		if o != src and t != null and (t == src.texture or (not path.is_empty() and t.resource_path == path)):
			out.append(o)
	return out


func apply_to_copies(src: ArenaScenery) -> void:
	var copies := _copies(src)
	var arena := EditorInterface.get_edited_scene_root()
	if not copies.is_empty() and undo != null:
		undo.create_action("Apply %s to %d copies" % [src.texture.resource_path.get_file(), copies.size()], UndoRedo.MERGE_DISABLE, arena)
		for o in copies:
			for prop: String in PROPS:
				var want: Variant = src.get(prop)
				var have: Variant = o.get(prop)
				if typeof(want) == typeof(have) and want == have:
					continue
				undo.add_do_property(o, prop, want)
				undo.add_undo_property(o, prop, have)
		undo.commit_action()
	_save_defaults(src)


## The picture's kit.json entry, so the palette places new copies the same way.
func _save_defaults(src: ArenaScenery) -> void:
	var path := src.texture.resource_path
	if not path.begins_with(Objects.DECOR):
		return
	var values := {
		"width": src.width, "sway": src.sway, "fade": src.fade_behind, "flat": src.flat,
		"bridge": src.bridge, "shadow": src.shadow, "blocks_bullets": src.blocks_bullets,
		"tint": src.tint.to_html(), "solid": [src.footprint.x, src.footprint.y],
		"anim": {"columns": src.columns, "rows": src.rows, "count": src.frame_count,
			"fps": src.fps, "loop": not src.play_once},
	}
	Objects.update_objects([path], values)
