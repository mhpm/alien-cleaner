extends Node
## Arena Editor OBJECTS palette: the category tree (dock/category_picker.gd +
## PaletteCatalog.tree_path) with the built-in categories and every real decor kit
## category (assets/decor/<kit>/kit.json, named "Kit · Category" like the catalog does).
##   godot --headless --path . res://tests/category_tree_test.tscn

const Picker := preload("res://addons/aliens_cleaner_arena_editor/dock/category_picker.gd")
const Catalog := preload("res://addons/aliens_cleaner_arena_editor/editor/palette_catalog.gd")
const BUILT_IN := ["Gameplay", "Survivors", "Enemies", "Bosses", "Spawners", "Triggers", "Hazards",
	"Pickups", "Environment", "Contamination"]

var failures := 0


func _ready() -> void:
	var cats: Array[String] = []
	cats.assign(BUILT_IN)
	var counts := {}
	for kit in DirAccess.get_directories_at("res://assets/decor/"):
		var path := "res://assets/decor/%s/kit.json" % kit
		if not FileAccess.file_exists(path):
			continue
		var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		for item: Dictionary in cfg.get("items", []):
			var c := "%s · %s" % [kit.capitalize(), str(item.get("category", "Misc"))]
			_check(not c.contains("Â") and not c.contains("Ã") and not c.contains("�"), "clean category name: " + c)
			if not cats.has(c):
				cats.append(c)
			counts[c] = int(counts.get(c, 0)) + 1
	for c in BUILT_IN:
		counts[c] = 3
	var picker := Picker.new()
	add_child(picker)
	picker.build(1.0)
	picker.set_categories(cats, counts)
	# pressing the button opens the tree (the real path the dock takes)
	picker._button.pressed.emit()
	_check(picker._popup.visible, "the button opens the category tree")
	picker._popup.hide()
	picker._fill()
	var tree: Tree = picker._tree
	var roots := _names(tree.get_root())
	print("ROOTS ", roots)
	for want in ["Gameplay", "Aliens", "Hazards & Decals", "Earth", "Farm", "Pixel Lab"]:
		_check(roots.has(want), "root branch " + want)
	_check(roots.size() <= 8, "few roots (%d), not one per category" % roots.size())
	_check(_find(tree, ["Aliens", "Bosses"]) != null, "Aliens > Bosses")
	_check(_find(tree, ["Farm", "Buildings", "Barns"]) != null, "Farm > Buildings > Barns")
	_check(_find(tree, ["Farm", "Grass", "Grass"]) != null and _find(tree, ["Farm", "Grass", "Rocks"]) != null,
		"Farm > Grass holds both Grass and Rocks (a name is never leaf and branch at once)")
	_check(_find(tree, ["Pixel Lab", "Maze", "Walls"]) != null, "Pixel Lab > Maze > Walls")
	_check(_find(tree, ["Earth", "Farm", "Farm Elements"]) != null, "Earth > Farm > Farm Elements")
	var maze := _find(tree, ["Pixel Lab", "Maze"])
	_check(maze != null and maze.get_text(0).contains("("), "branches show their object count")
	# picking a leaf selects its category and says so
	var got := [""]
	picker.category_selected.connect(func(c: String) -> void: got[0] = c)
	var walls := _find(tree, ["Pixel Lab", "Maze", "Walls"])
	walls.select(0)
	_check(got[0] == "Pixel Lab · Maze · Walls" and picker.current() == got[0], "picking Maze > Walls shows it (got %s)" % got[0])
	_check(picker._button.text.begins_with("Pixel Lab › Maze › Walls"), "the button shows the path: " + picker._button.text)
	# the filter keeps only matching branches, unfolded
	picker._filter.text = "barns"
	picker._fill()
	var left := _names(tree.get_root())
	_check(left == ["Farm"], "filter 'barns' leaves only Farm (%s)" % [left])
	picker._pick_first()
	_check(picker.current() == "Farm · Buildings · Barns", "Enter picks the first match (%s)" % picker.current())
	# a reload keeps the shown category
	picker.set_categories(cats, counts)
	_check(picker.current() == "Farm · Buildings · Barns", "a reload keeps the category")
	_check(Catalog.tree_path("Enemies") == PackedStringArray(["Aliens", "Enemies"]), "tree_path of a built-in")
	print("CATEGORY TREE TEST: %s" % ("PASS" if failures == 0 else "FAILED (%d)" % failures))
	get_tree().quit(0 if failures == 0 else 1)


func _names(item: TreeItem) -> Array[String]:
	var out: Array[String] = []
	var c := item.get_first_child()
	while c != null:
		out.append(c.get_text(0).get_slice("  (", 0))
		c = c.get_next()
	return out


func _find(tree: Tree, path: Array) -> TreeItem:
	var item := tree.get_root()
	for part: String in path:
		var c := item.get_first_child()
		while c != null and c.get_text(0).get_slice("  (", 0) != part:
			c = c.get_next()
		if c == null:
			return null
		item = c
	return item


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL  ", what)
