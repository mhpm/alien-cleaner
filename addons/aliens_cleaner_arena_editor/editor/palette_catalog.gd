@tool
extends RefCounted
## Everything the OBJECTS palette offers, gathered from content instead of a hardcoded list:
##   - every PackedScene in scenes/arena/palette/<category>/ (folder = category; drop a new
##     .tscn there and it appears). They are presets: placing one makes an independent
##     copy (rebuild them with tools/build_arena_palette.tscn). Its layer comes from the root's `arena_layer()` or,
##     failing that, CATEGORY_LAYERS.
##   - every PropData.PROPS prop as an ArenaProp ("Environment"; register props there).
##   - decal sets of scenes/arena/palette/palette.json (textures as ArenaDecal).
##   - one Player Spawn per playable character (assets/characters/, dock > Players).

const Factory := preload("arena_factory.gd")
const SCENES := "res://scenes/arena/palette/"
## Decoration kits: every PNG in assets/decor/<kit>/ (and its sub-folders) becomes an
## ArenaScenery entry. An optional kit.json tunes each file (category, width, solid
## footprint, sway, fade, flat); without it the folder names give the category and the
## size of the picture gives the rest. Drop new art in and press the palette's reload.
const DECOR := "res://assets/decor/"
const CONFIG := "res://scenes/arena/palette/palette.json"
## palette folder -> Arena layer
const CATEGORY_LAYERS := {
	"gameplay": "GameplayObjects", "environment": "Decorations", "obstacles": "Obstacles",
	"decorations": "Decorations", "objectives": "Objectives", "spawners": "EnemySpawners",
	"pickups": "Pickups", "triggers": "Triggers", "hazards": "Hazards",
}


## The palette entry of a scene, by file name ("enemy_spawner"), or null.
func scene_entry(file_basename: String) -> Entry:
	for e in entries:
		if e.kind == "scene" and e.scene_path.get_file().get_basename() == file_basename:
			return e
	return null
## Display order; unknown categories follow alphabetically.
const ORDER := ["Gameplay", "Survivors", "Enemies", "Bosses", "Spawners", "Triggers", "Hazards", "Pickups", "Environment", "Contamination"]


class Entry:
	extends RefCounted
	var name := ""
	var category := ""
	var layer := ""
	var kind := ""  # "scene" | "prop" | "decal"
	var icon: Texture2D
	var tooltip := ""
	var width := 24.0  # ghost width, world units
	var anchor_feet := true  # ghost drawn standing on the point (false = centred)
	var scene_path := ""
	var prop_id := ""
	var texture: Texture2D
	var preset: Dictionary = {}  # properties set on every new instance ("wave_id": "w2")
	var scenery: Dictionary = {}  # kit item settings (kind "scenery")

	func with_preset(values: Dictionary, label: String) -> Entry:
		var e := Entry.new()
		for p in ["category", "layer", "kind", "icon", "tooltip", "width", "anchor_feet", "scene_path", "prop_id", "texture", "scenery"]:
			e.set(p, get(p))
		e.name = label
		e.preset = values
		return e

	func instantiate() -> Node2D:
		var node := _make()
		if node == null:
			return null
		for k: String in preset:
			node.set(k, _fresh(preset[k]))
		return node

	## Presets hand every new object its own copy of embedded resources / arrays of them
	## (a spawner's alien list), so tuning one placed object never edits another. Saved
	## resources (a CharacterData file) stay shared.
	static func _fresh(v: Variant) -> Variant:
		if v is Resource and (v as Resource).resource_path.is_empty():
			return (v as Resource).duplicate(true)
		if v is Array:
			var out := (v as Array).duplicate()
			for i in out.size():
				out[i] = _fresh(out[i])
			return out
		return v

	func _make() -> Node2D:
		match kind:
			"scene":
				# a preset: an independent copy (not an instance), so tuning one placed
				# object never changes the others or the palette scene
				var node := (load(scene_path) as PackedScene).instantiate() as Node2D
				node.scene_file_path = ""
				Factory._unshare(node)
				return node
			"prop":
				var p := ArenaProp.new()
				p.prop_id = prop_id
				p.name = prop_id.to_pascal_case()
				return p
			"scenery":
				var sc := ArenaScenery.new()
				sc.texture = texture
				sc.width = width
				sc.sway = bool(scenery.get("sway", false))
				sc.fade_behind = bool(scenery.get("fade", false))
				sc.flat = bool(scenery.get("flat", false))
				sc.bridge = bool(scenery.get("bridge", false))
				sc.shadow = bool(scenery.get("shadow", false))
				var anim: Dictionary = scenery.get("anim", {})
				if not anim.is_empty():
					sc.columns = int(anim.get("columns", 1))
					sc.rows = int(anim.get("rows", 1))
					sc.frame_count = int(anim.get("count", 0))
					sc.fps = float(anim.get("fps", 8.0))
					sc.play_once = not bool(anim.get("loop", true))
				var fp: Variant = scenery.get("solid")
				if fp is Array and (fp as Array).size() == 2:
					sc.footprint = Vector2(float(fp[0]), float(fp[1]))
				sc.name = name.to_pascal_case()
				return sc
			"decal":
				var d := ArenaDecal.new()
				d.texture = texture
				d.width = width
				d.name = "Decal"
				return d
		return null


var entries: Array[Entry] = []


func rebuild() -> void:
	entries.clear()
	_scan_scenes()
	_add_characters()
	_add_survivors()
	_add_enemies()
	_add_props()
	_add_decals()
	_add_kits()


func categories() -> Array[String]:
	var out: Array[String] = []
	for e in entries:
		if not out.has(e.category):
			out.append(e.category)
	out.sort_custom(func(a: String, b: String) -> bool:
		var ia := ORDER.find(a)
		var ib := ORDER.find(b)
		if ia == -1 and ib == -1:
			return a < b
		return ia != -1 and (ib == -1 or ia < ib))
	return out


func in_category(category: String, search := "") -> Array[Entry]:
	var out: Array[Entry] = []
	var q := search.strip_edges().to_lower()
	for e in entries:
		if e.category == category and (q.is_empty() or e.name.to_lower().contains(q) or e.tooltip.to_lower().contains(q)):
			out.append(e)
	return out


func _scan_scenes() -> void:
	var root := DirAccess.open(SCENES)
	if root == null:
		return
	for folder in root.get_directories():
		var dir := DirAccess.open(SCENES + folder)
		for file in dir.get_files():
			file = file.trim_suffix(".remap")
			if not file.ends_with(".tscn"):
				continue
			var e := Entry.new()
			e.kind = "scene"
			e.scene_path = SCENES + folder + "/" + file
			e.category = folder.capitalize()
			e.name = file.get_basename().capitalize()
			e.layer = str(CATEGORY_LAYERS.get(folder.to_lower(), "GameplayObjects"))
			e.tooltip = e.scene_path
			# read the component's own hints (cheap: a handful of small scenes)
			var probe := (load(e.scene_path) as PackedScene).instantiate()
			if probe is ArenaObject:
				var o := probe as ArenaObject
				if not o.arena_layer().is_empty():
					e.layer = o.arena_layer()
				e.icon = o.palette_icon()
				e.width = o.palette_width()
				if e.icon == null:
					var theme := EditorInterface.get_editor_theme()
					var icon_name := o.palette_editor_icon()
					e.icon = theme.get_icon(icon_name, "EditorIcons") if theme.has_icon(icon_name, "EditorIcons") else null
					e.anchor_feet = false
			probe.free()
			entries.append(e)


## "Player · <name>": the Player Spawn preset with that character (the plain spawn = the
## astronaut). Placing one where a spawn exists swaps it (placement_tool).
## "Survivors": one Survivor preset per crew member (SurvivorData.CREW: face and gift).
## The plain Survivor stays in Gameplay (crew picked in the Inspector).
func _add_survivors() -> void:
	var base := scene_entry("survivor")
	if base == null:
		return
	for i in SurvivorData.CREW.size():
		var crew: Dictionary = SurvivorData.CREW[i]
		var e := base.with_preset({"crew": i}, str(crew.name).capitalize())
		e.category = "Survivors"
		e.icon = SurvivorData.tex(i, false)
		e.tooltip = "%s
Gift: %s" % [str(crew.name).capitalize(), crew.gift]
		entries.append(e)


## "Enemies": an Enemy Spawner preset per alien (its list = that alien; add more in the
## Inspector). "Bosses": a Boss Trigger preset per boss.
func _add_enemies() -> void:
	var spawner := scene_entry("enemy_spawner")
	if spawner != null:
		for id in ArenaArt.enemy_ids(false):
			var e := spawner.with_preset({"enemies": [SpawnEntry.make(id, 10.0)] as Array[SpawnEntry]},
				ArenaArt.enemy_name(id).capitalize())
			e.category = "Enemies"
			e.icon = ArenaArt.enemy_icon(id)
			e.width = 24.0
			e.anchor_feet = true
			e.tooltip = "Spawner of %s (\"%s\").\nInspector: count, rhythm, radius, and + Add alien to mix kinds." % [
				ArenaArt.enemy_name(id).capitalize(), id]
			entries.append(e)
	var boss := scene_entry("boss_trigger")
	if boss != null:
		for id in ArenaArt.enemy_ids(true):
			var e := boss.with_preset({"boss_id": id}, ArenaArt.enemy_name(id).capitalize())
			e.category = "Bosses"
			e.icon = ArenaArt.enemy_icon(id)
			e.width = 48.0
			e.anchor_feet = true
			e.tooltip = "Boss encounter: %s (\"%s\"). It drops in when the astronaut enters the trigger area." % [
				ArenaArt.enemy_name(id).capitalize(), id]
			entries.append(e)


func _add_characters() -> void:
	var base := scene_entry("player_spawn")
	if base == null:
		return
	var at := entries.find(base)
	var added: Array[Entry] = []
	for c in CharacterData.all():
		var label := "Player · " + (c.display_name if c.display_name != "" else c.character_id)
		var e := base
		if c.is_default():
			base.name = label
		else:
			e = base.with_preset({"character": c}, label)
			added.append(e)
		e.tooltip = "%s
One per arena: placing it replaces the current Player Spawn.
%s" % [
			label, CharacterData.path_of(c.character_id)]
		if c.icon() != null:
			e.icon = c.icon()
			e.width = c.frame_size().x * c.px_scale()
	for k in added.size():
		entries.insert(at + 1 + k, added[k])


func _add_props() -> void:
	var ids: Array = PropData.PROPS.keys()
	ids.sort()
	for id: String in ids:
		var def: Dictionary = PropData.PROPS[id]
		var e := Entry.new()
		e.kind = "prop"
		e.prop_id = id
		e.category = "Environment"
		e.layer = "Obstacles"
		e.name = id.capitalize()
		e.icon = PropData.texture_for(id, Vector2i.ZERO)
		e.width = float(def.width)
		var kind := str(def.get("kind", ""))
		e.tooltip = "%s  (PropData \"%s\"%s%s)" % [e.name, id, ", " + kind if kind != "" else "",
			", bullets pass" if not bool(def.get("bullets", true)) else ""]
		entries.append(e)


func _add_decals() -> void:
	if not FileAccess.file_exists(CONFIG):
		return
	var cfg: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG))
	if not cfg is Dictionary:
		push_warning("Arena Editor: %s is not valid JSON." % CONFIG)
		return
	for set_def: Dictionary in cfg.get("decal_sets", []):
		for ref: String in set_def.get("textures", []):
			var path := ref if ref.begins_with("res://") else PropData.path(ref)
			if not ResourceLoader.exists(path):
				push_warning("Arena Editor: decal texture not found: " + path)
				continue
			var e := Entry.new()
			e.kind = "decal"
			e.category = str(set_def.get("category", "Decals"))
			e.layer = "Decorations"
			e.texture = load(path)
			e.icon = e.texture
			e.width = float(set_def.get("width", 24.0))
			e.anchor_feet = false
			e.name = path.get_file().get_basename().capitalize()
			e.tooltip = path
			entries.append(e)


func _add_kits() -> void:
	var root := DirAccess.open(DECOR)
	if root == null:
		return
	for kit in root.get_directories():
		var dir := DECOR + kit + "/"
		var meta := {}
		if FileAccess.file_exists(dir + "kit.json"):
			var cfg: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir + "kit.json"))
			if cfg is Dictionary:
				for item: Dictionary in cfg.get("items", []):
					meta[str(item.get("file", ""))] = item
		_kit_folder(kit, dir, "", meta)


func _kit_folder(kit: String, dir: String, rel: String, meta: Dictionary) -> void:
	for sub in DirAccess.get_directories_at(dir + rel):
		_kit_folder(kit, dir, rel + sub + "/", meta)
	for file in DirAccess.get_files_at(dir + rel):
		file = file.trim_suffix(".import")
		if not (file.ends_with(".png") or file.ends_with(".webp")) or file.ends_with(".import"):
			continue
		var path := dir + rel + file
		if not ResourceLoader.exists(path):
			continue
		var key := rel + file
		var item: Dictionary = meta.get(key, meta.get(file, {}))
		var tex: Texture2D = load(path)
		if tex == null:  # a leftover .import whose picture was deleted
			continue
		var e := Entry.new()
		e.kind = "scenery"
		e.texture = tex
		e.icon = tex
		var anim: Dictionary = item.get("anim", {})
		if not anim.is_empty():  # spritesheet: the first frame stands for it
			var first := AtlasTexture.new()
			first.atlas = tex
			first.region = Rect2(0, 0, tex.get_width() / float(maxi(1, int(anim.get("columns", 1)))),
				tex.get_height() / float(maxi(1, int(anim.get("rows", 1)))))
			e.icon = first
		var folder_cat := rel.trim_suffix("/").get_file().capitalize() if not rel.is_empty() else ""
		var cat := str(item.get("category", folder_cat if not folder_cat.is_empty() else "Misc"))
		e.category = "%s · %s" % [kit.capitalize(), cat]
		# no width given: a third of the picture's pixels, like the game's painted props
		e.width = float(item.get("width", clampf(e.icon.get_width() * 0.33, 8.0, 200.0)))
		e.scenery = item
		e.anchor_feet = true
		e.layer = "Decorations" if bool(item.get("flat", false)) else "Obstacles"
		e.name = file.get_basename().capitalize()
		e.tooltip = "%s
%s%s" % [path, "solid" if item.get("solid") != null else "walk-through",
			"
animated: %d frames @ %s fps" % [int(anim.get("count", 0)) if int(anim.get("count", 0)) > 0 else int(anim.get("columns", 1)) * int(anim.get("rows", 1)), anim.get("fps", 8)] if not anim.is_empty() else ""]
		if not entries.any(func(x: Entry) -> bool: return x.kind == "scenery" and x.texture == tex):
			entries.append(e)
