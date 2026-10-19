@tool
extends HBoxContainer
## OBJECTS palette: which category is shown, picked from a TREE instead of one long flat
## drop-down. The button shows the path of the category ("Pixel Lab › Maze › Walls");
## pressing it opens the tree: built-in groups (Gameplay, Aliens, Hazards & Decals) and
## one branch per decor kit, nested by the " · " and "/" in kit categories
## (PaletteCatalog.tree_path). Branches fold open / closed (remembered while the editor
## runs, the current category's branch always open), each leaf shows how many objects it
## has, and a filter box narrows the tree (Enter picks the first match).

signal category_selected(category: String)

const Catalog := preload("../editor/palette_catalog.gd")
const SEP := " › "

var _button: Button
var _popup: PopupPanel
var _filter: LineEdit
var _tree: Tree
var _current := ""
var _categories: Array[String] = []
var _counts: Dictionary = {}  # category -> objects in it
var _open: Dictionary = {}  # branch key ("Earth/Trees") -> unfolded by hand
var _filling := false
var _scale := 1.0


func build(scale: float) -> void:
	_scale = scale
	_button = Button.new()
	_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_button.clip_text = true
	_button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_button.custom_minimum_size.x = 90 * scale
	_button.pressed.connect(_show_tree)
	add_child(_button)
	_popup = PopupPanel.new()
	var box := VBoxContainer.new()
	_popup.add_child(box)
	_filter = LineEdit.new()
	_filter.placeholder_text = "Filter categories..."
	_filter.clear_button_enabled = true
	_filter.text_changed.connect(func(_t: String) -> void: _fill())
	_filter.text_submitted.connect(func(_t: String) -> void: _pick_first())
	box.add_child(_filter)
	_tree = Tree.new()
	_tree.hide_root = true
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.custom_minimum_size = Vector2(260, 360) * scale
	_tree.item_selected.connect(_on_item_selected)
	_tree.item_collapsed.connect(_on_item_folded)
	box.add_child(_tree)
	add_child(_popup)
	_update_button()


## New list of categories (PaletteCatalog.categories order) and their object counts.
## The shown category stays when it still exists, else the first one is shown.
func set_categories(categories: Array[String], counts: Dictionary) -> void:
	_categories = categories
	_counts = counts
	if not _categories.has(_current):
		_current = _categories[0] if not _categories.is_empty() else ""
	_update_button()


func current() -> String:
	return _current


func select_category(category: String, notify := false) -> void:
	if not _categories.has(category):
		return
	_current = category
	_update_button()
	if notify:
		category_selected.emit(category)


func _update_button() -> void:
	if _button == null:
		return
	_button.text = (SEP.join(Catalog.tree_path(_current)) if not _current.is_empty() else "(no objects)") + "  ▾"
	_button.tooltip_text = "Category: %s (%d objects)\nClick to choose another one from the tree." % [
		SEP.join(Catalog.tree_path(_current)), int(_counts.get(_current, 0))]


func _show_tree() -> void:
	_filter.text = ""
	_fill()
	# just under the button, at least as wide as it (screen coordinates: the popup is a window)
	var at := _button.get_screen_position() + Vector2(0.0, _button.size.y)
	var size := Vector2i(int(maxf(_button.size.x, 280.0 * _scale)), int(440.0 * _scale))
	_popup.popup(Rect2i(Vector2i(at), size))
	_filter.grab_focus()


## Leaf paths: a category that is also the start of other categories ("Grass" and
## "Grass · Rocks") goes inside its own branch, so a name is never both a leaf and a branch.
func _paths() -> Dictionary:
	var paths := {}
	var branches := {}
	for c in _categories:
		var p := Catalog.tree_path(c)
		paths[c] = p
		for i in range(1, p.size()):
			branches["/".join(p.slice(0, i))] = true
	for c: String in paths:
		var p: PackedStringArray = paths[c]
		if branches.has("/".join(p)):
			p.append(p[p.size() - 1])
			paths[c] = p
	return paths


func _fill() -> void:
	_filling = true
	_tree.clear()
	var root := _tree.create_item()
	var query := _filter.text.strip_edges().to_lower()
	var paths := _paths()
	var current_key := "/".join(paths.get(_current, PackedStringArray()))
	var theme := EditorInterface.get_editor_theme() if Engine.is_editor_hint() else null
	var folder_icon: Texture2D = theme.get_icon("Folder", "EditorIcons") if theme != null and theme.has_icon("Folder", "EditorIcons") else null
	var branches := {}
	var shown: TreeItem = null
	for c in _categories:
		var p: PackedStringArray = paths[c]
		if not query.is_empty() and not " ".join(p).to_lower().contains(query):
			continue
		var parent := root
		var key := ""
		for i in p.size() - 1:
			key = p[i] if key.is_empty() else key + "/" + p[i]
			if not branches.has(key):
				var b := _tree.create_item(parent)
				b.set_text(0, p[i])
				b.set_icon(0, folder_icon)
				b.set_metadata(0, "")
				b.set_custom_color(0, Color(0.75, 0.85, 1.0))
				b.collapsed = query.is_empty() and not _open.get(key, false) and not current_key.begins_with(key + "/")
				branches[key] = b
			parent = branches[key]
		var leaf := _tree.create_item(parent)
		leaf.set_text(0, "%s  (%d)" % [p[p.size() - 1], int(_counts.get(c, 0))])
		leaf.set_metadata(0, c)
		leaf.set_tooltip_text(0, c)
		if c == _current:
			leaf.select(0)
			shown = leaf
	# branch counts: the objects of everything inside
	for key: String in branches:
		var b: TreeItem = branches[key]
		b.set_text(0, "%s  (%d)" % [b.get_text(0), _branch_total(b)])
	if shown != null:
		_tree.scroll_to_item(shown)
	_filling = false


func _branch_total(item: TreeItem) -> int:
	var total := 0
	var child := item.get_first_child()
	while child != null:
		var c := str(child.get_metadata(0))
		total += int(_counts.get(c, 0)) if not c.is_empty() else _branch_total(child)
		child = child.get_next()
	return total


func _branch_key(item: TreeItem) -> String:
	var parts: Array[String] = []
	var it := item
	while it != null and it != _tree.get_root():
		parts.push_front(it.get_text(0).get_slice("  (", 0))
		it = it.get_parent()
	return "/".join(parts)


## A leaf shows its category; a branch just folds open / closed.
func _on_item_selected() -> void:
	if _filling:
		return
	var item := _tree.get_selected()
	if item == null:
		return
	var c := str(item.get_metadata(0))
	if c.is_empty():
		item.collapsed = not item.collapsed
		item.deselect(0)
		return
	_popup.hide()
	select_category(c, true)


func _on_item_folded(item: TreeItem) -> void:
	if not _filling and _filter.text.strip_edges().is_empty():
		_open[_branch_key(item)] = not item.collapsed


## Enter in the filter box: the first category still in the tree.
func _pick_first() -> void:
	var item := _tree.get_root().get_first_child() if _tree.get_root() != null else null
	while item != null and str(item.get_metadata(0)).is_empty():
		item = item.get_first_child()
	if item != null:
		_popup.hide()
		select_category(str(item.get_metadata(0)), true)
