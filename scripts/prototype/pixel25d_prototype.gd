extends Node
## scenes/prototype_pixel25d.tscn: plays the pixel 2.5D prototype arena
## (scenes/arenas/arena_proto_pixel25d.tscn, tools/build_pixel25d_arena.gd) with the real
## game (ArenaWorld) rendered the way a pixel game would be:
##   * the window renders at the 360x640 base size and is scaled up (content scale mode
##     VIEWPORT) instead of drawing every sprite at the phone's full resolution;
##   * 2D transforms and vertices snap to whole pixels;
##   * the camera zoom is 1, so 1 art pixel = 1 world unit = 1 render pixel (times the
##     arena's own ArenaData.camera_zoom: lower = farther).
## P (or the PIXEL button) switches back to the normal render to compare. Everything is
## restored when the scene closes: the rest of the game keeps its settings.
## The same script plays other pixel arenas for real (scenes/rescue_ops.tscn, from the
## title screen): `arena`, `test` = editor-style run (no saves, EXIT closes the game) and
## `compare` = the PIXEL button.

const ARENA := "res://scenes/arenas/arena_proto_pixel25d.tscn"

@export_file("*.tscn") var arena := ARENA
@export var test := true
@export var compare := true

var pixel := true
var _mode: Window.ContentScaleMode
var _snap_t := false
var _snap_v := false
var _zoom := Vector2.ONE
var _world: GameWorld
var _button: Button


func _ready() -> void:
	var win := get_window()
	_mode = win.content_scale_mode
	_snap_t = win.snap_2d_transforms_to_pixel
	_snap_v = win.snap_2d_vertices_to_pixel
	ArenaSession.arena_path = arena
	ArenaSession.test = test
	ArenaSession.invincible = false
	ArenaSession.start_wave = 0
	var host := (load(ArenaSession.PLAY_SCENE) as PackedScene).instantiate()
	add_child(host)
	_world = host.get_child(0) as GameWorld
	_zoom = _world.camera.zoom
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	_button = Button.new()
	_button.focus_mode = Control.FOCUS_NONE
	_button.add_theme_font_size_override("font_size", 8)
	_button.position = Vector2(6, 64)
	_button.pressed.connect(toggle)
	layer.add_child(_button)
	_button.visible = compare
	_apply()


func _exit_tree() -> void:
	var win := get_window()
	win.content_scale_mode = _mode
	win.snap_2d_transforms_to_pixel = _snap_t
	win.snap_2d_vertices_to_pixel = _snap_v
	ArenaSession.arena_path = ""


func _unhandled_input(event: InputEvent) -> void:
	if compare and event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_P:
		toggle()


func toggle() -> void:
	pixel = not pixel
	_apply()


func _apply() -> void:
	var win := get_window()
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT if pixel else _mode
	win.snap_2d_transforms_to_pixel = pixel
	win.snap_2d_vertices_to_pixel = pixel
	if is_instance_valid(_world) and _world.camera != null:
		var d := (_world as ArenaWorld).arena.data if _world is ArenaWorld else null
		_world.camera.zoom = Vector2.ONE * ArenaWorld.zoom_for(d, 1.0) if pixel else _zoom
	_button.text = "PIXEL: ON (P)" if pixel else "PIXEL: OFF (P)"
