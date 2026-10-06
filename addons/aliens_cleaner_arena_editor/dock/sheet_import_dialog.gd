@tool
extends ConfirmationDialog
## Arena dock > PAINT > "Auto-import…": pick one picture of ground art and everything in
## it is sorted on its own (sheet_auto_import.gd) into terrain tiles and decoration. This
## window shows the result per category; click a piece to move it to another category
## or skip it, then Import.

signal imported(report: String)

const Auto := preload("../editor/sheet_auto_import.gd")
const THUMB := 46.0
const HINTS := [
	"brush tiles that fill a floor (seamless, even brightness; New Arena can use them)",
	"brush tiles painted over the floor",
	"flat decoration (paths, strips, corners…)",
	"flat decoration (organic patches)",
	"flat decoration that sways in the wind",
	"flat decoration",
	"left out",
]

var _scale := 1.0
var _file: FileDialog
var _name: LineEdit
var _kit: LineEdit
var _section: LineEdit
var _tile: SpinBox
var _body: VBoxContainer
var _status: Label
var _menu: PopupMenu
var _path := ""
var _pieces: Array = []
var _menu_piece: RefCounted
var _busy := false


func _init() -> void:
	title = "Auto-import ground art"
	ok_button_text = "Import"
	cancel_button_text = "Close"
	dialog_hide_on_ok = false  # stays open to show what was imported
	exclusive = false


func _ready() -> void:
	_scale = EditorInterface.get_editor_scale()
	min_size = Vector2i(Vector2(760, 600) * _scale)
	var v := VBoxContainer.new()
	add_child(v)
	var g := GridContainer.new()
	g.columns = 4
	v.add_child(g)
	_name = _field(g, "Name (terrain group)", LineEdit.new()) as LineEdit
	_name.custom_minimum_size.x = 160 * _scale
	_kit = _field(g, "Decor kit (folder)", LineEdit.new()) as LineEdit
	_kit.tooltip_text = "assets/decor/<kit>/: an existing kit (farm, earth…) or a new one"
	_section = _field(g, "Section", LineEdit.new()) as LineEdit
	_section.tooltip_text = "Sub-folder and category prefix: OBJECTS > <Kit> · <Section> · Pieces"
	_tile = _field(g, "Tile size (px)", SpinBox.new()) as SpinBox
	_tile.min_value = 8
	_tile.max_value = 1024
	_tile.tooltip_text = "Pixels of one square tile in the picture = one arena tile (32 units). Sets the scale of everything."
	var hint := Label.new()
	hint.text = "Click a piece to move it to another category (or skip it)."
	hint.modulate = Color(1, 1, 1, 0.6)
	v.add_child(hint)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_body)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_status)
	_menu = PopupMenu.new()
	for i in Auto.CATS.size():
		_menu.add_item("→ " + Auto.CATS[i], i)
	_menu.id_pressed.connect(func(id: int) -> void:
		if _menu_piece != null:
			_menu_piece.cat = id
			_fill())
	add_child(_menu)
	_file = FileDialog.new()
	_file.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file.access = FileDialog.ACCESS_FILESYSTEM
	_file.filters = PackedStringArray(["*.png, *.webp, *.jpg, *.jpeg ; Images"])
	_file.title = "Ground art (tiles, paths, patches, plants…)"
	_file.file_selected.connect(_chosen)
	# not a child of this (still hidden) window: a window inside a hidden one draws black
	EditorInterface.get_base_control().add_child.call_deferred(_file)
	confirmed.connect(_import)


func _exit_tree() -> void:
	if is_instance_valid(_file):
		_file.queue_free()


## Step 1: pick the picture.
func start() -> void:
	_file.popup_centered_ratio(0.6)


func _chosen(path: String) -> void:
	_path = path
	_status.text = "Looking at the picture…"
	_pieces.clear()
	_fill()
	popup_centered()
	await get_tree().process_frame
	await get_tree().process_frame
	var r: Dictionary = Auto.analyze(path)
	if r.is_empty():
		_status.text = "Could not read %s" % path
		return
	_pieces = r.pieces
	var base := path.get_file().get_basename().replace("_ref", "").replace("_tiles", "").replace("_", " ").strip_edges()
	_name.text = base.capitalize()
	_kit.text = base.split(" ")[0].to_snake_case()
	_section.text = "Ground"
	_tile.value = r.tile if int(r.tile) > 0 else 64
	_fill()
	_status.text = "%d pieces found%s. Check the groups, then Import." % [_pieces.size(),
		", one tile = %d px" % r.tile if int(r.tile) > 0 else " (no square tiles: everything goes to decoration)"]


func _fill() -> void:
	for c in _body.get_children():
		c.queue_free()
	for cat in Auto.CATS.size():
		var list := _pieces.filter(func(p: RefCounted) -> bool: return p.cat == cat)
		if list.is_empty():
			continue
		var head := Label.new()
		head.text = "%s (%d) — %s" % [Auto.CATS[cat], list.size(), HINTS[cat]]
		head.add_theme_color_override("font_color", Color("ffcd75") if cat < Auto.Cat.SKIP else Color(1, 1, 1, 0.45))
		_body.add_child(head)
		var flow := HFlowContainer.new()
		_body.add_child(flow)
		for p: RefCounted in list:
			var b := Button.new()
			b.icon = ImageTexture.create_from_image(p.image)
			b.expand_icon = true
			b.custom_minimum_size = Vector2(THUMB, THUMB) * _scale
			b.tooltip_text = "%d x %d px — click to move" % [p.rect.size.x, p.rect.size.y]
			if cat == Auto.Cat.SKIP:
				b.modulate = Color(1, 1, 1, 0.35)
			b.pressed.connect(func() -> void:
				_menu_piece = p
				_menu.popup(Rect2i(DisplayServer.mouse_get_position(), Vector2i.ZERO)))
			flow.add_child(b)


func _import() -> void:
	if _busy or _pieces.is_empty():
		return
	_busy = true
	get_ok_button().disabled = true
	_status.text = "Importing… (tiles are imported and the TileSet rebuilt; this takes a moment)"
	var report: String = await Auto.apply(_pieces, {
		"name": _name.text.strip_edges() if _name.text.strip_edges() != "" else "Ground",
		"kit": _kit.text.strip_edges() if _kit.text.strip_edges() != "" else "custom",
		"section": _section.text.strip_edges() if _section.text.strip_edges() != "" else "Ground",
		"tile": int(_tile.value), "source": _path})
	_busy = false
	get_ok_button().disabled = false
	_status.text = report + "  Restart Godot so the TileMap painter lists new tile groups."
	imported.emit(report)


func _field(g: GridContainer, text: String, c: Control) -> Control:
	var l := Label.new()
	l.text = text
	g.add_child(l)
	g.add_child(c)
	return c
