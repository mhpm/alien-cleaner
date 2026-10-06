@tool
extends AcceptDialog
## Dialogue Editor > avatar: a searchable gallery of faces from the game's own art
## (rescuable crew happy / sad, the astronaut, villagers and people of the decor kits,
## aliens, bosses) plus any picture from a file. Double-click (or OK) picks one.

signal picked(texture: Texture2D)

const Objects := preload("../editor/object_library.gd")
const GROUPS := ["All", "Crew", "People", "Astronaut", "Aliens", "Bosses"]

var _search: LineEdit
var _group: OptionButton
var _list: ItemList
var _file: EditorFileDialog
var _all: Array[Dictionary] = []  # {name, group, tex}
var _shown: Array[Dictionary] = []


func _init() -> void:
	title = "Choose an avatar"
	ok_button_text = "Use this face"
	confirmed.connect(_use_selected)


func start() -> void:
	if _list == null:
		_build()
	if _all.is_empty():
		_gather()
	_search.text = ""
	_refresh()
	popup_centered(Vector2i(620, 520) * EditorInterface.get_editor_scale())
	_search.grab_focus.call_deferred()


func _build() -> void:
	var s := EditorInterface.get_editor_scale()
	var v := VBoxContainer.new()
	add_child(v)
	var bar := HBoxContainer.new()
	v.add_child(bar)
	_group = OptionButton.new()
	for g in GROUPS:
		_group.add_item(g)
	_group.item_selected.connect(func(_i: int) -> void: _refresh())
	bar.add_child(_group)
	_search = LineEdit.new()
	_search.placeholder_text = "Search faces (pilot, girl, slime...)"
	_search.clear_button_enabled = true
	_search.right_icon = EditorInterface.get_editor_theme().get_icon("Search", "EditorIcons")
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.text_changed.connect(func(_t: String) -> void: _refresh())
	bar.add_child(_search)
	var none := Button.new()
	none.text = "No face"
	none.tooltip_text = "This character talks without a picture (a voice on the radio)"
	none.pressed.connect(func() -> void:
		picked.emit(null)
		hide())
	bar.add_child(none)
	var from_file := Button.new()
	from_file.text = "From file..."
	from_file.icon = EditorInterface.get_editor_theme().get_icon("Load", "EditorIcons")
	from_file.pressed.connect(_pick_file)
	bar.add_child(from_file)
	_list = ItemList.new()
	_list.icon_mode = ItemList.ICON_MODE_TOP
	_list.max_columns = 0
	_list.same_column_width = true
	_list.fixed_column_width = int(84 * s)
	_list.fixed_icon_size = Vector2i(56, 56) * int(maxf(1.0, s))
	_list.max_text_lines = 2
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.custom_minimum_size = Vector2(560, 380) * s
	_list.item_activated.connect(func(_i: int) -> void:
		_use_selected()
		hide())
	v.add_child(_list)
	_file = EditorFileDialog.new()
	_file.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	_file.access = EditorFileDialog.ACCESS_RESOURCES
	_file.filters = PackedStringArray(["*.png, *.webp ; Pictures"])
	_file.file_selected.connect(func(path: String) -> void:
		picked.emit(load(path) as Texture2D)
		hide())
	add_child(_file)


func _pick_file() -> void:
	_file.popup_file_dialog()


func _use_selected() -> void:
	var sel := _list.get_selected_items()
	if not sel.is_empty():
		picked.emit(_shown[sel[0]].tex)


func _refresh() -> void:
	_list.clear()
	_shown.clear()
	var g: String = GROUPS[_group.selected]
	var q := _search.text.strip_edges().to_lower()
	for f in _all:
		if (g == "All" or f.group == g) and (q.is_empty() or str(f.name).to_lower().contains(q)):
			var i := _list.add_item(f.name, f.tex)
			_list.set_item_tooltip(i, "%s (%s)" % [f.name, f.group])
			_shown.append(f)


func _gather() -> void:
	# rescuable crew: happy first, then the scared face
	for mood in ["happy", "sad"]:
		for file in _pictures("res://assets/sprites/survivors/"):
			if file.get_basename().ends_with("_" + mood):
				_add(file.get_file().get_basename().replace("_", " ").capitalize(), "Crew", load(file))
	for anim in ["idle_0", "hurt_0"]:
		var p := "res://assets/sprites/player/%s.png" % anim
		if ResourceLoader.exists(p):
			_add("Astronaut " + anim.get_slice("_", 0), "Astronaut", load(p))
	# people of the decor kits (any folder called villagers / people / npc / characters)
	_people("res://assets/decor/")
	for boss in [false, true]:
		for id in ArenaArt.enemy_ids(boss):
			var t := ArenaArt.enemy_icon(id)
			if t != null:
				_add(ArenaArt.enemy_name(id).capitalize(), "Bosses" if boss else "Aliens", t)


func _people(dir: String) -> void:
	for sub in DirAccess.get_directories_at(dir):
		var low := sub.to_lower()
		if low in ["villagers", "people", "npc", "npcs", "characters", "crew"]:
			for file in _pictures(dir + sub + "/"):
				_add(file.get_file().get_basename().replace("_", " ").replace("-", " ").capitalize(), "People", _first_frame(file))
		_people(dir + sub + "/")


## A spritesheet of the decor kits stands for its first frame.
func _first_frame(path: String) -> Texture2D:
	var tex: Texture2D = load(path)
	var anim: Dictionary = Objects.settings(path).get("anim", {})
	if anim.is_empty() or tex == null:
		return tex
	var a := AtlasTexture.new()
	a.atlas = tex
	a.region = Rect2(0, 0, tex.get_width() / float(maxi(1, int(anim.get("columns", 1)))),
		tex.get_height() / float(maxi(1, int(anim.get("rows", 1)))))
	return a


func _pictures(dir: String) -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at(dir):
		f = f.trim_suffix(".remap")
		if (f.ends_with(".png") or f.ends_with(".webp")) and ResourceLoader.exists(dir + f):
			out.append(dir + f)
	return out


func _add(label: String, group: String, tex: Texture2D) -> void:
	if tex != null:
		_all.append({"name": label, "group": group, "tex": tex})
