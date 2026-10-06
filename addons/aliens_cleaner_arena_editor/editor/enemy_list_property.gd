@tool
extends EditorProperty
## Inspector editor for an alien list (Array[SpawnEntry]: a spawner's or nest's
## `enemies`, a wave's `horde`, the arena's `roaming`): one row per alien with its
## picture, weight, share (and about how many of the object's total), elite chance and
## remove; "+ Add alien" opens a searchable picture grid. Every change is one undoable
## inspector edit.

const ICON := 30.0
## Object properties that say how many aliens the list will send in total.
const TOTALS := ["spawn_count", "enemy_count"]

var _scale := 1.0
var _box: VBoxContainer
var _rows: VBoxContainer
var _summary: Label
var _picker: PopupPanel
var _search: LineEdit
var _grid: GridContainer
var _sig := ""  # alien ids in order: rebuild rows only when they change
var _weights: Array[SpinBox] = []
var _elites: Array[SpinBox] = []
var _shares: Array[Label] = []


func _init() -> void:
	_scale = EditorInterface.get_editor_scale()
	_box = VBoxContainer.new()
	add_child(_box)
	set_bottom_editor(_box)
	_rows = VBoxContainer.new()
	_box.add_child(_rows)
	_summary = Label.new()
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary.modulate = Color(1, 1, 1, 0.65)
	_box.add_child(_summary)
	var add := Button.new()
	add.text = "+ Add alien"
	add.icon = EditorInterface.get_editor_theme().get_icon("Add", "EditorIcons")
	add.pressed.connect(_open_picker)
	_box.add_child(add)
	_build_picker()


func _list() -> Array:
	var v: Variant = get_edited_object().get(get_edited_property())
	return v if v is Array else []


func _total() -> int:
	for k: String in TOTALS:
		var v: Variant = get_edited_object().get(k)
		if v is int and int(v) > 0:
			return int(v)
	return 0


func _update_property() -> void:
	var list := _list()
	var ids: Array[String] = []
	for e: Variant in list:
		ids.append((e as SpawnEntry).enemy_id if e is SpawnEntry else "-")
	var sig := ",".join(ids)
	if sig != _sig:
		_sig = sig
		_rebuild(list)
	var sum := 0.0
	for e: Variant in list:
		if e is SpawnEntry:
			sum += maxf((e as SpawnEntry).weight, 0.0)
	var total := _total()
	for i in list.size():
		var e := list[i] as SpawnEntry
		if e == null or i >= _weights.size():
			continue
		_weights[i].set_value_no_signal(e.weight)
		_elites[i].set_value_no_signal(roundf(e.elite_chance * 100.0))
		var share := e.weight / sum if sum > 0.0 else 0.0
		_shares[i].text = "%d%%" % roundi(share * 100.0) + ("  ≈%d" % roundi(share * total) if total > 0 else "")
	if list.is_empty():
		_summary.text = "No aliens yet: + Add alien. Weights are relative (10 / 10 = half and half)."
	else:
		_summary.text = ("%d aliens in total (%s)." % [total, "spawn_count" if get_edited_object().get("spawn_count") != null else "enemy_count"]) \
			if total > 0 else "Weights are relative: each alien's share of what comes."


func _rebuild(list: Array) -> void:
	for c in _rows.get_children():
		c.queue_free()
	_weights.clear()
	_elites.clear()
	_shares.clear()
	for i in list.size():
		var e := list[i] as SpawnEntry
		var row := HBoxContainer.new()
		_rows.add_child(row)
		var pic := TextureRect.new()
		pic.texture = ArenaArt.enemy_icon(e.enemy_id) if e != null else null
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.custom_minimum_size = Vector2(ICON, ICON) * _scale
		row.add_child(pic)
		var name := Label.new()
		name.text = ArenaArt.enemy_name(e.enemy_id).capitalize() if e != null else "(empty)"
		name.tooltip_text = e.enemy_id if e != null else ""
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name.clip_text = true
		row.add_child(name)
		var w := SpinBox.new()
		w.max_value = 100
		w.step = 1
		w.tooltip_text = "Weight (relative to the others)"
		w.value_changed.connect(func(v: float) -> void: _edit(i, "weight", v))
		row.add_child(w)
		_weights.append(w)
		var share := Label.new()
		share.custom_minimum_size.x = 58 * _scale
		share.tooltip_text = "Share of the aliens (and about how many of the total)"
		row.add_child(share)
		_shares.append(share)
		var el := SpinBox.new()
		el.max_value = 100
		el.step = 5
		el.prefix = "★"
		el.suffix = "%"
		el.tooltip_text = "Chance it comes as a golden elite"
		el.value_changed.connect(func(v: float) -> void: _edit(i, "elite_chance", v / 100.0))
		row.add_child(el)
		_elites.append(el)
		var x := Button.new()
		x.icon = EditorInterface.get_editor_theme().get_icon("Remove", "EditorIcons")
		x.flat = true
		x.tooltip_text = "Remove"
		x.pressed.connect(func() -> void: _remove(i))
		row.add_child(x)


## A copy of the list with fresh entries (undo keeps the old ones untouched).
func _copy() -> Array[SpawnEntry]:
	var out: Array[SpawnEntry] = []
	for e: Variant in _list():
		if e is SpawnEntry:
			out.append((e as SpawnEntry).duplicate() as SpawnEntry)
	return out


func _edit(i: int, prop: String, value: float) -> void:
	var out := _copy()
	if i < out.size():
		out[i].set(prop, value)
		emit_changed(get_edited_property(), out)


func _remove(i: int) -> void:
	var out := _copy()
	if i < out.size():
		out.remove_at(i)
		emit_changed(get_edited_property(), out)


func _add(id: String) -> void:
	_picker.hide()
	var out := _copy()
	for e in out:
		if e.enemy_id == id:
			e.weight = minf(100.0, e.weight + 10.0)
			emit_changed(get_edited_property(), out)
			return
	out.append(SpawnEntry.make(id, 10.0))
	emit_changed(get_edited_property(), out)


# ---------------------------------------------------------------- picker

func _build_picker() -> void:
	_picker = PopupPanel.new()
	var v := VBoxContainer.new()
	_picker.add_child(v)
	_search = LineEdit.new()
	_search.placeholder_text = "Search aliens…"
	_search.clear_button_enabled = true
	_search.text_changed.connect(func(_t: String) -> void: _fill_grid())
	v.add_child(_search)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(430, 360) * _scale
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 5
	scroll.add_child(_grid)
	add_child(_picker)


func _open_picker() -> void:
	_search.text = ""
	_fill_grid()
	_picker.popup_centered()
	_search.grab_focus()


func _fill_grid() -> void:
	for c in _grid.get_children():
		c.queue_free()
	var q := _search.text.strip_edges().to_lower()
	for id in ArenaArt.enemy_ids(false):
		var label := ArenaArt.enemy_name(id).capitalize()
		if q != "" and not (label.to_lower().contains(q) or id.contains(q)):
			continue
		var b := Button.new()
		b.text = label
		b.icon = ArenaArt.enemy_icon(id)
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.custom_minimum_size = Vector2(80, 82) * _scale
		b.clip_text = true
		b.tooltip_text = "%s (\"%s\")" % [label, id]
		b.pressed.connect(_add.bind(id))
		_grid.add_child(b)
