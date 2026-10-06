@tool
extends VBoxContainer
## Shared base of the MISSIONS and WAVES pages: an ordered list of resources stored in
## an ArenaData array property, with add / duplicate / delete / reorder. Every change is
## one undoable action on the whole array; selecting a row opens the resource in the
## Inspector. Subclasses say which property, how a row reads and how a new item looks.

var arena: Arena
var undo: EditorUndoRedoManager
var tree: Tree
var _scale := 1.0


func build(editor_undo: EditorUndoRedoManager) -> void:
	undo = editor_undo
	_scale = EditorInterface.get_editor_scale()
	_build_header()
	tree = Tree.new()
	tree.hide_root = true
	tree.custom_minimum_size = Vector2(0, 90 * _scale)
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree.item_selected.connect(_on_selected)
	add_child(tree)
	var row := HBoxContainer.new()
	add_child(row)
	row.add_child(_icon_button("MoveUp", "Move up", func() -> void: _move(-1)))
	row.add_child(_icon_button("MoveDown", "Move down", func() -> void: _move(1)))
	row.add_child(_icon_button("Duplicate", "Duplicate", _duplicate))
	row.add_child(_icon_button("Remove", "Delete", _delete))
	var hint := Label.new()
	hint.text = _hint()
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.modulate = Color(1, 1, 1, 0.55)
	hint.add_theme_font_size_override("font_size", int(11 * _scale))
	row.add_child(hint)
	undo.version_changed.connect(refresh)


func set_arena(a: Arena) -> void:
	arena = a
	refresh()


func refresh() -> void:
	if tree == null:
		return
	var keep := tree.get_selected().get_metadata(0) if tree.get_selected() != null else null
	tree.clear()
	var root := tree.create_item()
	for i in _items().size():
		var res: Resource = _items()[i]
		var item := tree.create_item(root)
		item.set_text(0, _row_text(res, i))
		item.set_metadata(0, res)
		var icon := _row_icon(res)
		if icon != null:
			item.set_icon(0, icon)
		if res == keep:
			item.select(0)
	_after_refresh()


# ---------------------------------------------------------------- for subclasses

func _property() -> String:
	return ""


func _row_text(_res: Resource, _i: int) -> String:
	return ""


func _row_icon(_res: Resource) -> Texture2D:
	return null


func _hint() -> String:
	return ""


func _build_header() -> void:
	pass


func _after_refresh() -> void:
	pass


# ---------------------------------------------------------------- list editing

func _items() -> Array:
	if arena == null or arena.data == null:
		return []
	return arena.data.get(_property())


func _commit(new_list: Array, label: String) -> void:
	if arena == null or arena.data == null:
		return
	var old: Array = arena.data.get(_property()).duplicate()
	undo.create_action(label, UndoRedo.MERGE_DISABLE, arena)
	undo.add_do_property(arena.data, _property(), new_list)
	undo.add_undo_property(arena.data, _property(), old)
	undo.add_do_method(self, "refresh")
	undo.add_undo_method(self, "refresh")
	undo.commit_action()


func add_item(res: Resource) -> void:
	var list := _items().duplicate()
	list.append(res)
	_commit(list, "Add " + _property().trim_suffix("s"))
	_select(res)


func _selected() -> Resource:
	var item := tree.get_selected()
	return item.get_metadata(0) as Resource if item != null else null


func _select(res: Resource) -> void:
	for item in tree.get_root().get_children():
		if item.get_metadata(0) == res:
			item.select(0)
			EditorInterface.edit_resource(res)
			return


func _on_selected() -> void:
	var res := _selected()
	if res != null:
		EditorInterface.edit_resource(res)


func _move(step: int) -> void:
	var res := _selected()
	var list := _items().duplicate()
	var i := list.find(res)
	if res == null or i + step < 0 or i + step >= list.size():
		return
	list.remove_at(i)
	list.insert(i + step, res)
	_commit(list, "Reorder")
	_select(res)


func _duplicate() -> void:
	var res := _selected()
	if res == null:
		return
	var copy := res.duplicate(true)
	_rename_copy(copy)
	var list := _items().duplicate()
	list.insert(list.find(res) + 1, copy)
	_commit(list, "Duplicate")
	_select(copy)


func _rename_copy(_copy: Resource) -> void:
	pass


func _delete() -> void:
	var res := _selected()
	if res == null:
		return
	var list := _items().duplicate()
	list.erase(res)
	_commit(list, "Delete")


func _icon_button(icon: String, tip: String, on_press: Callable) -> Button:
	var b := Button.new()
	var t := EditorInterface.get_editor_theme()
	b.icon = t.get_icon(icon, "EditorIcons") if t.has_icon(icon, "EditorIcons") else null
	if b.icon == null:
		b.text = tip
	b.tooltip_text = tip
	b.flat = true
	b.pressed.connect(on_press)
	return b
