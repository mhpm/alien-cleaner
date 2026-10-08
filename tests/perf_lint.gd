extends Node
## Performance rules for every script in res://scripts (new worlds, enemies and effects
## included). Prints each violation and quits with how many there are.
##  1. No draw_circle / draw_arc / draw_polyline in game code: in Godot 4.7 they cost
##     ~40-70 us per call when redrawn every frame. Use FastDraw (disc, ring, arc,
##     polyline). Menus and editor-only drawing are allowed (ALLOW_FILES, ALLOW_FUNCS).
##  2. No get_tree().get_nodes_in_group("enemies") in a per-frame function: use
##     Game.world.enemy_cache, or Game.world.enemies_near(pos, r) for hit tests.

const ROOT := "res://scripts/"
const SLOW_DRAW := ["draw_circle(", "draw_arc(", "draw_polyline("]
const PER_FRAME := ["_process", "_physics_process", "_draw"]
## Screens outside the game (drawn rarely or with nothing else running).
const ALLOW_FILES := ["main_menu.gd", "world_select.gd", "armory_screen.gd", "lab_screen.gd",
	"victory_screen.gd", "gun_demo.gd", "neon_frame.gd", "neon_wings.gd", "fast_draw.gd"]
## Editor-only drawing of arena objects.
const ALLOW_FUNCS := ["_draw_editor", "_dashed_circle"]

var problems := 0


func _ready() -> void:
	_scan(ROOT)
	print("PERF_LINT: %s" % ("PASS" if problems == 0 else "FAIL (%d)" % problems))
	get_tree().quit(problems)


func _scan(dir: String) -> void:
	for sub in DirAccess.get_directories_at(dir):
		_scan(dir + sub + "/")
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".gd"):
			_lint(dir + file)


func _lint(path: String) -> void:
	var allow_draw := ALLOW_FILES.has(path.get_file())
	var fn := ""
	var n := 0
	for line in FileAccess.get_file_as_string(path).split("\n"):
		n += 1
		var code := line.strip_edges()
		if code.begins_with("#"):
			continue
		var m := code.trim_prefix("static ")
		if m.begins_with("func "):
			fn = m.substr(5).get_slice("(", 0).strip_edges()
		if not allow_draw and not ALLOW_FUNCS.has(fn) and not code.contains("FastDraw."):
			for call: String in SLOW_DRAW:
				if code.contains(call):
					_report(path, n, "%s is slow to redraw: use FastDraw" % call.trim_suffix("("))
		if PER_FRAME.has(fn) and code.contains("get_nodes_in_group(\"enemies\")") and not code.contains("enemy_cache ="):
			_report(path, n, "scans the enemies group every frame: use enemy_cache / enemies_near")


func _report(path: String, line: int, what: String) -> void:
	problems += 1
	print("PERF_LINT %s:%d %s" % [path, line, what])
