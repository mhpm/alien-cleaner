@tool
extends AcceptDialog
## Players window (Arena dock > Players, or the Player Spawn's Inspector button): every
## playable character (assets/characters/<id>/<id>.tres). New from a sheet: pick an image,
## each detected row of drawings becomes an animation you choose (idle, walk, walk_up,
## shoot, hurt, death or skip). Edit name, size, weapon style, fps / loop per animation,
## and click the preview to place the hand (held weapon) or the muzzle (gun in the art).
## "Use in this arena" puts the character on the arena's Player Spawn.

signal characters_changed

const Importer := preload("../editor/character_importer.gd")
const ROW_ANIMS := ["idle", "walk", "walk_up", "shoot", "shoot_down", "shoot_up", "hurt", "death", "(skip)"]
const GUNS_JSON := "res://assets/guns/guns.json"
const GUN_UNITS := 10.2  # a held weapon's grip -> muzzle in world units (Astronaut.GUN_LEN * BODY_SCALE)
const POINTS := ["hand", "walk_hand", "shoot_hand", "shoot_down_hand", "shoot_up_hand", "muzzle"]

var undo: EditorUndoRedoManager
var arena: Arena
var _scale := 1.0
var _list: ItemList
var _chars: Array[CharacterData] = []
var _cur: CharacterData
var _name: LineEdit
var _height: SpinBox
var _weapon: OptionButton
var _still: CheckBox
var _hop: CheckBox
var _aim: CheckBox
var _walk_aims: CheckBox
var _flash_size: SpinBox
var _frames_file: FileDialog
var _flash_file: FileDialog
var _frames_dlg: ConfirmationDialog
var _frames_mode: OptionButton
var _frames_height: SpinBox
var _frames_paths: PackedStringArray
var _gun_tex: Texture2D
var _drag_prop := ""  # point being dragged in the preview
var _drag_from := Vector2.ZERO
var _gun_grip := Vector2.ZERO
var _gun_tip := Vector2(30, 0)
var _anim: OptionButton
var _fps: SpinBox
var _loop: CheckBox
var _click: OptionButton
var _flip: CheckBox
var _preview: Control
var _status: Label
var _use_btn: Button
var _file: FileDialog
var _map: ConfirmationDialog
var _map_rows: VBoxContainer
var _map_name: LineEdit
var _map_height: SpinBox
var _map_cols: SpinBox
var _map_grid_rows: SpinBox
var _frames_cols: SpinBox
var _frames_rows: SpinBox
var _sheet: Image
var _found: Dictionary
var _reimport_id := ""  # re-import into this character ("" = a new one)
var _frame := 0
var _t := 0.0
var _loading := false


func _init() -> void:
	title = "Players"
	ok_button_text = "Close"
	exclusive = false


func _ready() -> void:
	_scale = EditorInterface.get_editor_scale()
	min_size = Vector2i(Vector2(860, 560) * _scale)
	var split := HSplitContainer.new()
	add_child(split)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 210 * _scale
	split.add_child(left)
	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.icon_mode = ItemList.ICON_MODE_LEFT
	_list.fixed_icon_size = Vector2i(Vector2(40, 40) * _scale)
	_list.item_selected.connect(func(i: int) -> void: _select(_chars[i]))
	left.add_child(_list)
	left.add_child(_btn("New from sheet…", "Add", func() -> void: _pick_sheet("")))
	var row := HBoxContainer.new()
	left.add_child(row)
	row.add_child(_btn("Duplicate", "Duplicate", _duplicate))
	row.add_child(_btn("Delete", "Remove", _delete))
	_use_btn = _btn("Use in this arena", "PlayStart", _use_in_arena)
	_use_btn.tooltip_text = "Put this character on the arena's Player Spawn (Ctrl+Z undoes it)"
	left.add_child(_use_btn)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(right)
	var g := GridContainer.new()
	g.columns = 4
	right.add_child(g)
	_name = _field(g, "Name", LineEdit.new()) as LineEdit
	_name.custom_minimum_size.x = 160 * _scale
	_name.text_changed.connect(func(t: String) -> void: _set_prop("display_name", t))
	_height = _field(g, "Height (units)", SpinBox.new()) as SpinBox
	_height.min_value = 8
	_height.max_value = 80
	_height.step = 0.5
	_height.tooltip_text = "How tall it stands in game (the astronaut is 25.5)"
	_height.value_changed.connect(func(v: float) -> void: _set_prop("height", v))
	_weapon = _field(g, "Weapon", OptionButton.new()) as OptionButton
	_weapon.add_item("ARMORY weapon in the hand", CharacterData.Weapon.HELD)
	_weapon.add_item("Gun drawn in the art (shoot anim)", CharacterData.Weapon.IN_SPRITE)
	_weapon.item_selected.connect(func(i: int) -> void:
		_set_prop("weapon", _weapon.get_item_id(i))
		_click.select(0 if _weapon.get_item_id(i) == CharacterData.Weapon.HELD else POINTS.size() - 1))
	var flags := HBoxContainer.new()
	_field(g, "Motion", flags)
	_still = CheckBox.new()
	_still.text = "Still idle"
	_still.tooltip_text = "Standing = first idle frame + breathing in code (the astronaut)"
	_still.toggled.connect(func(on: bool) -> void: _set_prop("still_idle", on))
	flags.add_child(_still)
	_hop = CheckBox.new()
	_hop.text = "Hop"
	_hop.tooltip_text = "Little bounce and sway while walking"
	_hop.toggled.connect(func(on: bool) -> void: _set_prop("hop", on))
	flags.add_child(_hop)
	_aim = CheckBox.new()
	_aim.text = "Shoot pose"
	_aim.tooltip_text = "Held weapon: play \"shoot\" while firing (arm out) with the weapon at SHOOT HAND"
	_aim.toggled.connect(func(on: bool) -> void: _set_prop("aim_pose", on))
	flags.add_child(_aim)
	_walk_aims = CheckBox.new()
	_walk_aims.text = "Walk aims"
	_walk_aims.tooltip_text = "The walk frames hold the arm out: weapon at WALK HAND, and walking while firing to the side keeps walking"
	_walk_aims.toggled.connect(func(on: bool) -> void: _set_prop("walk_aims", on))
	flags.add_child(_walk_aims)

	var bar := HBoxContainer.new()
	right.add_child(bar)
	_anim = OptionButton.new()
	_anim.item_selected.connect(func(_i: int) -> void: _show_anim())
	bar.add_child(_anim)
	_fps = SpinBox.new()
	_fps.min_value = 1
	_fps.max_value = 30
	_fps.suffix = "fps"
	_fps.value_changed.connect(func(v: float) -> void:
		if not _loading and _cur != null and _cur.frames.has_animation(_anim_name()):
			_cur.frames.set_animation_speed(_anim_name(), v))
	bar.add_child(_fps)
	_loop = CheckBox.new()
	_loop.text = "Loop"
	_loop.toggled.connect(func(on: bool) -> void:
		if not _loading and _cur != null and _cur.frames.has_animation(_anim_name()):
			_cur.frames.set_animation_loop(_anim_name(), on))
	bar.add_child(_loop)
	var lbl := Label.new()
	lbl.text = "  Click sets:"
	bar.add_child(lbl)
	_click = OptionButton.new()
	_click.add_item("Hand (held weapon)")
	_click.add_item("Walk hand")
	_click.add_item("Shoot hand (side pose)")
	_click.add_item("Shoot-down hand")
	_click.add_item("Shoot-up hand")
	_click.add_item("Muzzle (gun in the art)")
	bar.add_child(_click)
	_flip = CheckBox.new()
	_flip.text = "Face left"
	bar.add_child(_flip)

	_preview = Control.new()
	_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview.custom_minimum_size = Vector2(300, 300) * _scale
	_preview.clip_contents = true
	_preview.draw.connect(_draw_preview)
	_preview.gui_input.connect(_preview_input)
	right.add_child(_preview)
	var foot := HBoxContainer.new()
	right.add_child(foot)
	foot.add_child(_btn("Replace frames from a sheet…", "Reload", func() -> void:
		if _cur != null:
			_pick_sheet(_cur.character_id)))
	var tools := HBoxContainer.new()
	right.add_child(tools)
	var add_frames := _btn("Frames from images…", "ImageTexture", func() -> void:
		if _cur != null:
			_frames_file.popup_centered_ratio(0.6))
	add_frames.tooltip_text = "Add or replace the frames of the animation above with loose pictures (one drawing each)"
	tools.add_child(add_frames)
	var flash_btn := _btn("Muzzle flash…", "CPUParticles2D", func() -> void:
		if _cur != null:
			_flash_file.popup_centered_ratio(0.6))
	flash_btn.tooltip_text = "Picture shown at the muzzle on every shot (drawn pointing right)"
	tools.add_child(flash_btn)
	tools.add_child(_btn("No flash", "Remove", func() -> void:
		if _cur != null and Importer.set_flash(_cur, ""):
			_after_scan(_cur.character_id, "Muzzle flash removed.")))
	_flash_size = SpinBox.new()
	_flash_size.min_value = 2
	_flash_size.max_value = 40
	_flash_size.step = 0.5
	_flash_size.prefix = "flash"
	_flash_size.suffix = "u"
	_flash_size.tooltip_text = "Flash length in world units"
	_flash_size.value_changed.connect(func(v: float) -> void: _set_prop("flash_size", v))
	tools.add_child(_flash_size)
	foot.add_child(_btn("Save", "Save", _save))
	_status = Label.new()
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.clip_text = true
	_status.modulate = Color(1, 1, 1, 0.6)
	foot.add_child(_status)

	_file = FileDialog.new()
	_file.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file.access = FileDialog.ACCESS_FILESYSTEM
	_file.filters = PackedStringArray(["*.png, *.webp, *.jpg, *.jpeg ; Images"])
	_file.title = "Character sheet"
	_file.file_selected.connect(_sheet_chosen)
	add_child(_file)
	_frames_file = FileDialog.new()
	_frames_file.file_mode = FileDialog.FILE_MODE_OPEN_FILES
	_frames_file.access = FileDialog.ACCESS_FILESYSTEM
	_frames_file.filters = _file.filters
	_frames_file.title = "Frames (one drawing per picture, in order)"
	_frames_file.files_selected.connect(_frames_chosen)
	add_child(_frames_file)
	_flash_file = FileDialog.new()
	_flash_file.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_flash_file.access = FileDialog.ACCESS_FILESYSTEM
	_flash_file.filters = _file.filters
	_flash_file.title = "Muzzle flash picture"
	_flash_file.file_selected.connect(func(path: String) -> void:
		if _cur != null and Importer.set_flash(_cur, path):
			_after_scan(_cur.character_id, "Muzzle flash set: tune its size (flash) and check it on \"shoot\"."))
	add_child(_flash_file)
	_build_frames_dialog()
	var guns: Variant = JSON.parse_string(FileAccess.get_file_as_string(GUNS_JSON)) if FileAccess.file_exists(GUNS_JSON) else null
	if guns is Dictionary and not (guns.guns as Array).is_empty():
		var g0: Dictionary = guns.guns[0]
		_gun_grip = Vector2(float(g0.grip[0]), float(g0.grip[1]))
		_gun_tip = Vector2(float(g0.tip[0]), float(g0.tip[1]))
		_gun_tex = load("res://assets/guns/gun_1.png")
	_build_map_dialog()


func open(for_arena: Arena) -> void:
	arena = for_arena
	_use_btn.disabled = arena == null
	_reload(_cur.character_id if _cur != null else "")
	popup_centered()


func _process(delta: float) -> void:
	if not visible or _cur == null or _cur.frames == null:
		return
	var a := _anim_name()
	if not _cur.frames.has_animation(a):
		return
	_t += delta
	var step := 1.0 / maxf(1.0, _cur.frames.get_animation_speed(a))
	if _t >= step:
		_t = 0.0
		var n := _cur.frames.get_frame_count(a)
		if _cur.frames.get_animation_loop(a) or _frame < n - 1:
			_frame = (_frame + 1) % n
			if not _cur.frames.get_animation_loop(a) and _frame == n - 1:
				_t = -0.7  # one-shot: hold the last frame a moment, then replay
		else:
			_frame = 0
		_preview.queue_redraw()


# ---------------------------------------------------------------- list

func _reload(select_id: String) -> void:
	_chars = CharacterData.all()
	characters_changed.emit()
	_list.clear()
	for c in _chars:
		var label := c.display_name if c.display_name != "" else c.character_id
		_list.add_item(label, c.icon())
	var pick := 0
	for i in _chars.size():
		if _chars[i].character_id == select_id:
			pick = i
	if _chars.is_empty():
		_select(null)
	else:
		_list.select(pick)
		_select(_chars[pick])


func _select(c: CharacterData) -> void:
	_cur = c
	_loading = true
	var on := c != null
	for w: Control in [_name, _height, _weapon, _still, _hop, _aim, _walk_aims, _anim, _fps, _loop, _flash_size]:
		if w is BaseButton:
			(w as BaseButton).disabled = not on
		elif w is LineEdit:
			(w as LineEdit).editable = on
		elif w is Range:
			(w as SpinBox).editable = on
	if on:
		_name.text = c.display_name
		_height.value = c.height
		_weapon.select(_weapon.get_item_index(c.weapon))
		_click.select((2 if c.aim_pose else 0) if c.weapon == CharacterData.Weapon.HELD else POINTS.size() - 1)
		_aim.button_pressed = c.aim_pose
		_walk_aims.button_pressed = c.walk_aims
		_flash_size.value = c.flash_size
		_still.button_pressed = c.still_idle
		_hop.button_pressed = c.hop
		_anim.clear()
		for a: String in CharacterData.ANIMS:
			var n := c.frames.get_frame_count(a) if c.frames != null and c.frames.has_animation(a) else 0
			_anim.add_item("%s (%d)" % [a, n] if n > 0 else "%s → %s" % [a, c.resolve(a)])
			_anim.set_item_metadata(_anim.item_count - 1, a)
		_status.text = CharacterData.path_of(c.character_id)
	_loading = false
	_show_anim()


func _anim_name() -> String:
	return str(_anim.get_item_metadata(_anim.selected)) if _anim.item_count > 0 and _anim.selected >= 0 else "idle"


func _show_anim() -> void:
	_frame = 0
	_t = 0.0
	if _cur != null and _cur.frames != null:
		var a := _cur.resolve(_anim_name())
		_loading = true
		_fps.value = _cur.frames.get_animation_speed(a) if _cur.frames.has_animation(a) else 8.0
		_loop.button_pressed = _cur.frames.get_animation_loop(a) if _cur.frames.has_animation(a) else false
		_loading = false
	_preview.queue_redraw()


func _set_prop(prop: String, value: Variant) -> void:
	if _loading or _cur == null:
		return
	_cur.set(prop, value)
	_preview.queue_redraw()


func _save() -> void:
	if _cur == null:
		return
	var err := ResourceSaver.save(_cur, CharacterData.path_of(_cur.character_id))
	_status.text = "Saved." if err == OK else "Could not save (%s)" % error_string(err)
	var keep := _cur.character_id
	_reload(keep)
	_redraw_spawns()


func _duplicate() -> void:
	if _cur == null:
		return
	var id := _free_id(_cur.character_id + "_copy")
	var c := _cur.duplicate(true) as CharacterData
	c.character_id = id
	c.display_name = _cur.display_name + " copy"
	DirAccess.make_dir_recursive_absolute(CharacterData.DIR + id)
	ResourceSaver.save(c, CharacterData.path_of(id))
	EditorInterface.get_resource_filesystem().update_file(CharacterData.path_of(id))
	_reload(id)


func _delete() -> void:
	if _cur == null:
		return
	if _cur.is_default():
		_status.text = "The astronaut is the default player: it cannot be deleted."
		return
	var c := _cur
	var ask := ConfirmationDialog.new()
	ask.dialog_text = "Delete \"%s\" and its frames (%s)?\nArenas that use it go back to the astronaut." % [
		c.display_name, CharacterData.DIR + c.character_id]
	ask.confirmed.connect(func() -> void:
		var dir := CharacterData.DIR + c.character_id
		for f in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir + "/" + f)
		DirAccess.remove_absolute(dir)
		EditorInterface.get_resource_filesystem().scan()
		_reload("")
		ask.queue_free())
	ask.canceled.connect(ask.queue_free)
	add_child(ask)
	ask.popup_centered()


func _use_in_arena() -> void:
	if arena == null or _cur == null:
		return
	var spawns := arena.find_children("*", "PlayerSpawn", true, false)
	if spawns.is_empty():
		_status.text = "This arena has no Player Spawn (OBJECTS > Gameplay > Player Spawn)."
		return
	var sp := spawns[0] as PlayerSpawn
	var value: CharacterData = null if _cur.is_default() else _cur
	undo.create_action("Player: %s" % _cur.display_name, UndoRedo.MERGE_DISABLE, arena)
	undo.add_do_property(sp, "character", value)
	undo.add_undo_property(sp, "character", sp.character)
	undo.commit_action()
	_status.text = "%s plays this arena." % _cur.display_name


func _redraw_spawns() -> void:
	if arena != null:
		for sp in arena.find_children("*", "PlayerSpawn", true, false):
			(sp as CanvasItem).queue_redraw()


func _free_id(base: String) -> String:
	var id := base
	var k := 2
	while DirAccess.dir_exists_absolute(CharacterData.DIR + id):
		id = "%s_%d" % [base, k]
		k += 1
	return id


# ---------------------------------------------------------------- preview

## Preview transform: frame px -> preview px, feet at the bottom middle.
func _view() -> Array:
	var sz := _cur.frame_size()
	var area := _preview.size - Vector2(40, 50)
	var k := minf(area.x / sz.x, area.y / sz.y)
	var feet := Vector2(_preview.size.x * 0.5, _preview.size.y - 30)
	return [k, feet]


func _draw_preview() -> void:
	var r := Rect2(Vector2.ZERO, _preview.size)
	_preview.draw_rect(r, Color(0.08, 0.09, 0.13))
	if _cur == null or _cur.frames == null:
		return
	var a := _cur.resolve(_anim_name())
	if not _cur.frames.has_animation(a):
		return
	var v := _view()
	var k: float = v[0]
	var feet: Vector2 = v[1]
	var dirx := -1.0 if _flip.button_pressed else 1.0
	_preview.draw_line(Vector2(0, feet.y), Vector2(_preview.size.x, feet.y), Color(1, 1, 1, 0.15), 1.0)
	_preview.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var f := clampi(maxi(_frame, 0), 0, _cur.frames.get_frame_count(a) - 1)
	var tex := _cur.frames.get_frame_texture(a, f)
	var sz := Vector2(tex.get_size()) * k
	var top_left := feet - Vector2(_cur.anchor.x * k * dirx, _cur.anchor.y * k)
	if dirx < 0.0:
		_preview.draw_set_transform(Vector2(top_left.x, 0), 0.0, Vector2(-1, 1))
		_preview.draw_texture_rect(tex, Rect2(Vector2(0, top_left.y), sz), false)
		_preview.draw_set_transform(Vector2.ZERO)
	else:
		_preview.draw_texture_rect(tex, Rect2(top_left, sz), false)
	# feet, the weapon in the hand (the Pulse Blaster stands for any ARMORY weapon), flash
	_preview.draw_circle(feet, 3.0, Color("73eff7"))
	var held := _cur.weapon == CharacterData.Weapon.HELD
	var posing := held and _cur.aim_pose and CharacterData.POSE_HANDS.has(a)
	var rest: Vector2 = _cur.walk_hand if _cur.walk_aims and a == "walk" else _cur.hand
	var hand := feet + Vector2(rest.x * dirx, rest.y) * k
	var pose_pt: Vector2 = _cur.get(CharacterData.POSE_HANDS[a]) if posing else _cur.shoot_hand
	var shoot_hand := feet + Vector2(pose_pt.x * dirx, pose_pt.y) * k
	var aim := {"shoot_down": PI * 0.5, "shoot_up": -PI * 0.5}.get(a, 0.0) as float
	var muzzle := feet + Vector2(_cur.muzzle.x * dirx, _cur.muzzle.y) * k
	if held and _gun_tex != null and a != "death":
		var at := shoot_hand if posing else hand
		var gs := GUN_UNITS / _cur.px_scale() * k / maxf(1.0, (_gun_tip - _gun_grip).length())
		var base := (_gun_tip - _gun_grip).angle()
		var rot := (aim - base) if dirx > 0.0 or aim != 0.0 else 0.0
		var sx := gs * (dirx if aim == 0.0 else 1.0)
		_preview.draw_set_transform(at, rot, Vector2(sx, gs))
		_preview.draw_texture(_gun_tex, -_gun_grip)
		_preview.draw_set_transform(Vector2.ZERO)
		muzzle = at + ((_gun_tip - _gun_grip) * Vector2(sx, gs)).rotated(rot)
	if _cur.muzzle_flash != null and _cur.muzzle_flash.get_width() > 0 and CharacterData.POSE_HANDS.has(a):
		var ft := _cur.muzzle_flash
		var fk := _cur.flash_size / _cur.px_scale() * k / float(ft.get_width())
		_preview.draw_set_transform(muzzle, aim if aim != 0.0 else (0.0 if dirx > 0.0 else PI), Vector2(fk, fk))
		_preview.draw_texture(ft, Vector2(0, -ft.get_height() * 0.5))
		_preview.draw_set_transform(Vector2.ZERO)
	_marker(hand, Color("a7f070"), "WALK HAND" if _cur.walk_aims and a == "walk" else "HAND", held and not posing)
	if held and _cur.aim_pose:
		_marker(shoot_hand, Color("94b0c2"), str(CharacterData.POSE_HANDS.get(a, "shoot_hand")).to_upper().replace("_", " "), posing)
	_marker(muzzle, Color("ffcd75"), "MUZZLE" if not held else "", not held)
	var font := get_theme_default_font()
	_preview.draw_string(font, Vector2(8, 18), "%s · %s  frame %d/%d  ·  %.1f units tall" % [
		_cur.display_name, a, f + 1, _cur.frames.get_frame_count(a), _cur.height], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.75))
	if a != _anim_name():
		_preview.draw_string(font, Vector2(8, 36), "no \"%s\" frames: the game shows \"%s\"" % [_anim_name(), a],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("ffcd75"))


func _marker(at: Vector2, color: Color, text: String, active: bool) -> void:
	var c := color if active else Color(color, 0.35)
	_preview.draw_arc(at, 6.0, 0.0, TAU, 20, c, 2.0)
	_preview.draw_line(at - Vector2(9, 0), at + Vector2(9, 0), c, 1.0)
	_preview.draw_line(at - Vector2(0, 9), at + Vector2(0, 9), c, 1.0)
	_preview.draw_string(get_theme_default_font(), at + Vector2(9, -7), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, c)


func _preview_input(e: InputEvent) -> void:
	if _cur == null:
		return
	var prop: String = POINTS[clampi(_click.selected, 0, POINTS.size() - 1)]
	var mb := e as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			# only a click on the character's own frame moves a point (a stray click
			# elsewhere in the preview must not throw the weapon off)
			var p := _preview_point(mb.position)
			var frame := Rect2(-_cur.anchor, _cur.frame_size())
			if not frame.has_point(p):
				return
			_drag_prop = prop
			_drag_from = _cur.get(prop)
			_cur.set(prop, p.round())
		elif _drag_prop != "":
			var to: Vector2 = _cur.get(_drag_prop)
			if to != _drag_from:
				undo.create_action("Players: move %s" % _drag_prop.replace("_", " "))
				undo.add_do_property(_cur, _drag_prop, to)
				undo.add_undo_property(_cur, _drag_prop, _drag_from)
				undo.add_do_method(_preview, "queue_redraw")
				undo.add_undo_method(_preview, "queue_redraw")
				undo.commit_action(false)
				_status.text = "%s moved (Ctrl+Z undoes it; Save keeps it)." % _drag_prop.replace("_", " ").to_upper()
			_drag_prop = ""
		_preview.queue_redraw()
		return
	var mm := e as InputEventMouseMotion
	if mm != null and _drag_prop != "" and (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		var p := _preview_point(mm.position)
		var frame := Rect2(-_cur.anchor, _cur.frame_size())
		_cur.set(_drag_prop, p.clamp(frame.position, frame.end).round())
		_preview.queue_redraw()


## Preview pixel -> frame px from the feet, facing right.
func _preview_point(at: Vector2) -> Vector2:
	var v := _view()
	var p: Vector2 = (at - (v[1] as Vector2)) / float(v[0])
	if _flip.button_pressed:
		p.x = -p.x
	return p


# ---------------------------------------------------------------- sheet import

func _pick_sheet(reimport_id: String) -> void:
	_reimport_id = reimport_id
	_file.popup_centered_ratio(0.6)


func _sheet_chosen(path: String) -> void:
	_sheet = Importer.load_sheet(path)
	if _sheet == null:
		_status.text = "Could not read %s" % path
		return
	_map_cols.value = 0
	_map_grid_rows.value = 0
	if not _fill_rows():
		return
	if _reimport_id != "" and _cur != null:
		_map_name.text = _cur.display_name
		_map_height.value = _cur.height
	else:
		_map_name.text = path.get_file().get_basename().replace("_ref", "").replace("_", " ").capitalize()
		_map_height.value = 25.5
	_map_name.editable = _reimport_id == ""
	_map.title = "Replace frames of %s" % _cur.display_name if _reimport_id != "" else "New player from sheet"
	_map.popup_centered()


## Finds the drawings (or cuts the grid when columns x rows are set) and lists one line
## per row with its animation picker. false = nothing found.
func _fill_rows() -> bool:
	var gc := int(_map_cols.value)
	var gr := int(_map_grid_rows.value)
	_found = Importer.detect_grid(_sheet, gc, gr) if gc > 0 and gr > 0 else Importer.detect(_sheet)
	if (_found.rows as Array).is_empty():
		_status.text = "No drawings found in that image."
		return false
	for c in _map_rows.get_children():
		c.queue_free()
	var rows: Array = _found.rows
	for r in rows.size():
		var line := HBoxContainer.new()
		var pick := OptionButton.new()
		for a: String in ROW_ANIMS:
			pick.add_item(a)
		var guess: String = Importer.ROW_ORDER[r] if r < Importer.ROW_ORDER.size() else "(skip)"
		pick.select(ROW_ANIMS.find(guess))
		pick.custom_minimum_size.x = 110 * _scale
		line.add_child(pick)
		var strip := TextureRect.new()
		strip.texture = ImageTexture.create_from_image(_row_strip(rows[r]))
		strip.expand_mode = TextureRect.EXPAND_KEEP_SIZE
		line.add_child(strip)
		var n := Label.new()
		n.text = "%d frames" % (rows[r] as Array).size()
		line.add_child(n)
		_map_rows.add_child(line)
	return true


## The drawings of one row side by side, 56 px tall (row picker thumbnails).
func _row_strip(row: Array) -> Image:
	var hgt := int(56 * _scale)
	var parts: Array[Image] = []
	var w := 0
	for s: int in row:
		var part := Importer.cut(_sheet, _found, s)
		var k := float(hgt) / part.get_height()
		part.resize(maxi(1, int(part.get_width() * k)), hgt, Image.INTERPOLATE_BILINEAR)
		parts.append(part)
		w += part.get_width() + 6
	var out := Image.create(maxi(1, w), hgt, false, Image.FORMAT_RGBA8)
	var x := 0
	for p in parts:
		out.blit_rect(p, Rect2i(Vector2i.ZERO, p.get_size()), Vector2i(x, 0))
		x += p.get_width() + 6
	return out


func _build_map_dialog() -> void:
	_map = ConfirmationDialog.new()
	_map.ok_button_text = "Create"
	var v := VBoxContainer.new()
	_map.add_child(v)
	var g := GridContainer.new()
	g.columns = 4
	v.add_child(g)
	_map_name = _field(g, "Name", LineEdit.new()) as LineEdit
	_map_name.custom_minimum_size.x = 180 * _scale
	_map_height = _field(g, "Height (units)", SpinBox.new()) as SpinBox
	_map_height.min_value = 8
	_map_height.max_value = 80
	_map_height.step = 0.5
	_map_cols = _field(g, "Grid columns", SpinBox.new()) as SpinBox
	_map_grid_rows = _field(g, "Grid rows", SpinBox.new()) as SpinBox
	for sb: SpinBox in [_map_cols, _map_grid_rows]:
		sb.max_value = 64
		sb.tooltip_text = "0 = find each drawing. Set columns x rows when the frames touch each other (a grid of equal cells)"
	var recut := _btn("Cut", "Reload", func() -> void:
		if _sheet != null:
			_fill_rows())
	recut.tooltip_text = "Find the drawings again with the grid settings"
	g.add_child(recut)
	var hint := Label.new()
	hint.text = "Each row of the sheet is one animation (left to right). Rows with the same animation are joined."
	hint.modulate = Color(1, 1, 1, 0.6)
	v.add_child(hint)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(620, 340) * _scale
	v.add_child(scroll)
	_map_rows = VBoxContainer.new()
	scroll.add_child(_map_rows)
	_map.confirmed.connect(_create_from_map)
	add_child(_map)


func _create_from_map() -> void:
	var rows: Array = _found.rows
	var plan: Array = []
	var by_anim := {}
	for r in rows.size():
		var pick := _map_rows.get_child(r).get_child(0) as OptionButton
		var anim: String = ROW_ANIMS[pick.selected]
		if anim == "(skip)":
			continue
		if not by_anim.has(anim):
			by_anim[anim] = {"anim": anim, "parts": [] as Array[Image]}
			plan.append(by_anim[anim])
		for s: int in rows[r]:
			by_anim[anim].parts.append(Importer.cut(_sheet, _found, s))
	if plan.is_empty():
		_status.text = "Every row was skipped: nothing to make."
		return
	var display := _map_name.text.strip_edges()
	var id := _reimport_id
	var keep: CharacterData = _cur if _reimport_id != "" else null
	if id == "":
		id = _free_id(Importer.make_id(display))
	else:
		var dir := CharacterData.DIR + id
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".png") or f.ends_with(".png.import"):
				DirAccess.remove_absolute(dir + "/" + f)
	var c: CharacterData = Importer.build(id, display if display != "" else id, plan, _map_height.value)
	if c == null:
		_status.text = "Could not build the character (see Output)."
		return
	if keep != null:
		# keep the hand-tuned settings that still make sense
		c.still_idle = keep.still_idle
		c.hop = keep.hop
		ResourceSaver.save(c, CharacterData.path_of(id))
	_status.text = "Importing %s's frames…" % c.display_name
	var fs := EditorInterface.get_resource_filesystem()
	var done := func() -> void:
		ResourceLoader.load(CharacterData.path_of(id), "", ResourceLoader.CACHE_MODE_REPLACE_DEEP)
		_reload(id)
		_redraw_spawns()
		_status.text = "%s: %d animations from the sheet. Check HAND / MUZZLE, then Save." % [c.display_name, plan.size()]
	fs.filesystem_changed.connect(done, CONNECT_ONE_SHOT)


# ---------------------------------------------------------------- loose frames

func _build_frames_dialog() -> void:
	_frames_dlg = ConfirmationDialog.new()
	_frames_dlg.ok_button_text = "Add"
	var g := GridContainer.new()
	g.columns = 2
	_frames_dlg.add_child(g)
	_frames_mode = _field(g, "Frames", OptionButton.new()) as OptionButton
	_frames_mode.add_item("Replace this animation's frames")
	_frames_mode.add_item("Add after its frames")
	_frames_cols = _field(g, "Split each picture: columns", SpinBox.new()) as SpinBox
	_frames_rows = _field(g, "rows", SpinBox.new()) as SpinBox
	for sb: SpinBox in [_frames_cols, _frames_rows]:
		sb.min_value = 1
		sb.max_value = 64
		sb.tooltip_text = "A picture holding several frames in a grid: they are read left to right, top to bottom"
	_frames_height = _field(g, "Drawing height (px)", SpinBox.new()) as SpinBox
	_frames_height.min_value = 8
	_frames_height.max_value = 2000
	_frames_height.tooltip_text = "Each picture is resized so its drawing is this tall (the sheet's frames: same size)"
	_frames_dlg.confirmed.connect(_add_frames)
	add_child(_frames_dlg)


func _frames_chosen(paths: PackedStringArray) -> void:
	if _cur == null or paths.is_empty():
		return
	_frames_paths = paths
	var a := _anim_name()
	var h := Importer.drawn_height(_cur, a)
	if h <= 0.0:
		h = Importer.drawn_height(_cur, "idle")
	_frames_height.value = roundf(h if h > 0.0 else _cur.body_height)
	_frames_mode.select(0 if _cur.frames.has_animation(a) else 1)
	_frames_dlg.title = "%d picture(s) → \"%s\"" % [paths.size(), a]
	_frames_dlg.popup_centered()


func _add_frames() -> void:
	var parts: Array[Image] = []
	var gc := int(_frames_cols.value)
	var gr := int(_frames_rows.value)
	for path in _frames_paths:
		var pieces: Array[Image] = []
		if gc * gr > 1:
			var sheet := Importer.load_sheet(path)
			if sheet != null:
				var found := Importer.detect_grid(sheet, gc, gr)
				for row: Array in found.rows:
					for s: int in row:
						pieces.append(Importer.cut(sheet, found, s))
		else:
			var part := Importer.load_part(path)
			if part != null:
				pieces.append(part)
		if pieces.is_empty():
			_status.text = "Could not read %s" % path.get_file()
			return
		# one scale for the whole picture: frames keep their sizes relative to each other
		var tallest := 1
		for pc in pieces:
			tallest = maxi(tallest, pc.get_height())
		for pc in pieces:
			parts.append(Importer.fit_height(pc, pc.get_height() * _frames_height.value / tallest))
	var a := _anim_name()
	if Importer.add_frames(_cur, a, parts, _frames_mode.selected == 0):
		_after_scan(_cur.character_id, "%d frame(s) in \"%s\". Place the hands, then Save." % [parts.size(), a])


## Reload `id` once the editor has imported its new / changed PNGs.
func _after_scan(id: String, message: String) -> void:
	_status.text = "Importing…"
	var done := func() -> void:
		ResourceLoader.load(CharacterData.path_of(id), "", ResourceLoader.CACHE_MODE_REPLACE_DEEP)
		_reload(id)
		_redraw_spawns()
		_status.text = message
	EditorInterface.get_resource_filesystem().filesystem_changed.connect(done, CONNECT_ONE_SHOT)


# ---------------------------------------------------------------- helpers

func _btn(text: String, icon_name: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	if icon_name != "":
		b.icon = EditorInterface.get_editor_theme().get_icon(icon_name, "EditorIcons")
	b.pressed.connect(on_press)
	return b


func _field(g: GridContainer, text: String, c: Control) -> Control:
	var l := Label.new()
	l.text = text
	g.add_child(l)
	g.add_child(c)
	return c
