class_name Room
extends Node2D
## A painted room (ART_THEMES: frame, floor and door art per world) plus props from an
## ASCII layout (world 1 "ship": 12x27, the camera follows the player; world 2 "hive":
## 10x14). Builds collisions, runs the environmental hazards (toxic slime, electric
## floor) and the exit door.
## Layout legend: . floor  v vent/grate  B explosive barrel  t toxic slime  z electric floor
##   props (PropData, scripts/combat/prop.gd): # crate (## big)  c canister  T crystals
##     M mushroom  r rock  C console  P specimen tube  G generator  H med kit
##     R radioactive tank  F cryo tank  ff fence (bullets pass)  kk forklift
##     K loot crate (shoot it: coins)  U auto turret (stand next to it: it fires)
##     D machine  l lamp post  pp planter  A satellite dish  xx command desk
##     hh hazard barrier (bullets pass)  N broken robot
##   booster pads (push bodies): > < ^ ,(down)
##   hive (world 2): E alien egg  I pillar  L lamp  S spire  w sticky creep (slows the
##     player)  OO alien teleporter pad (floor decal centred between the two cells)
## The world theme ("ship" / "hive") swaps prop art and the painted room (ART_THEMES):
## the hive art (assets/room/room_hive_bg.webp = tools/room2_ref.webp) has its crates,
## pods and barrels painted in; `feet` are their collision boxes in art pixels and
## the world 2 layouts mark those cells with X.

const TILE := 16
const ART := "res://assets/room/"
## Painted rooms per world theme. origin/scale map the art's interior (the cols x rows
## grid) onto the room (0,0)-(cols*16, rows*16); door/light are world rects of the
## painted door; door_x = the wall gap (world x) the exit leads through.
##   follow  the room is taller/wider than the screen: the camera follows the player
##   grime   scatter oil stains / old splats on free floor cells
##   feet    colliders of objects painted into the art (art px)
## "ship" (world 1) = tools/room_big_ref.webp made taller by tools/make_big_room.py.
const ART_THEMES := {
	"ship": {
		"bg": "room_ship_bg.webp", "origin": Vector2(90, 216),
		"scale": Vector2(0.25033, 0.25033), "size": Vector2(941, 2117),
		"door": Rect2(77.6, -34.3, 35.3, 30.0), "light": Rect2(79.3, -45.3, 31.3, 2.8),
		"cols": 12, "rows": 27, "door_x": Vector2(80, 112), "follow": true, "grime": true,
	},
	"hive": {
		"bg": "room_hive_bg.webp", "origin": Vector2(62, 265),
		"scale": Vector2(160.0 / 903.0, 224.0 / 1125.0), "size": Vector2(1024, 1536),
		"door": Rect2(64.3, -37.2, 30.7, 32.3), "light": Rect2(65.6, -46.8, 28.4, 4.0),
		"cols": 10, "rows": 14, "door_x": Vector2(64, 96),
		"feet": [
			Rect2(62, 190, 88, 100), Rect2(780, 200, 182, 135), Rect2(255, 385, 135, 60),
			Rect2(625, 395, 160, 55), Rect2(65, 540, 157, 72), Rect2(785, 560, 170, 65),
			Rect2(265, 752, 175, 63), Rect2(720, 795, 175, 75), Rect2(262, 928, 70, 37),
			Rect2(865, 945, 70, 55), Rect2(70, 1040, 322, 70), Rect2(625, 1045, 170, 65),
			Rect2(810, 1100, 145, 80), Rect2(62, 1290, 178, 100), Rect2(725, 1295, 107, 45),
			Rect2(835, 1325, 130, 65),
		],
	},
}
## Auto-aim reach in rooms the camera scrolls over (aliens off screen are left alone).
const FOLLOW_AIM_RANGE := 175.0

# ---- survival arena (WorldData "survival"): a wide open floor of plate tiles walled in
# by the walls of the big room art (assets/arena/ from tools/make_arena_tiles.py)
const ARENA := "res://assets/arena/"
## floor cells of tools/arena_floor_ref.webp (floor_atlas.png + .json: plain plates first,
## then plates with a vent grille); each floor tile covers ARENA_FLOOR_TILE world units
const ARENA_FLOOR_TILE := 32.0
const ARENA_VENT_CHANCE := 0.015
const ARENA_WALL := 22.5  # wall thickness in world units (90 art px)
const ARENA_ART_SCALE := 0.25  # wall art px -> world
## painted arenas (WorldData survival "art"): one picture of the whole walled room,
## made bigger by its tool; its .json gives the art size and the walkable floor in px
const ART_ARENAS := {
	# world 2: tools/arena2_ref.webp -> python tools/make_hive_arena.py
	"hive": {"bg": "arena_hive_bg.webp", "data": "arena_hive.json", "scale": 0.55},
	# world 3: built from the tile kit assets/ui/world/world3_elements/ -> python tools/make_void_arena.py
	"void": {"bg": "arena_void_bg.webp", "data": "arena_void.json", "scale": 0.5},
	# world 4: an open-air deck floating in space (tools/make_space_arena.py). "sky" = the
	# space behind it, animated by SpaceBackdrop; the deck picture is transparent round it
	"space": {"bg": "arena_space_deck.webp", "data": "arena_space.json", "scale": 0.5, "sky": "arena_space_sky.webp"},
}
var grid: Array = []
var toxic: Dictionary = {}  # Vector2i -> splat texture
var toxic_until: Dictionary = {}  # Vector2i -> anim_t when a temporary flood dries up
var pads: Dictionary = {}  # Vector2i -> push direction
var tex_pad: Texture2D
var electric: Array[Vector2i] = []
var decor: Array = []  # [cell, texture]
var grime: Array = []  # [position, texture, rotation, scale] floor stains
var spawned: Array[Node] = []
var door_open := false
var door_k := 0.0
var door_shape: CollisionShape2D
var elec_t := 0.0
var elec_state := 0  # 0 off, 1 warning, 2 live
var tick := 0.0
var anim_t := 0.0
var tex_grate: Texture2D
var tex_vent: Texture2D
var tex_splats: Array[Texture2D] = []
var theme := "ship"
var _theme_bg: Dictionary = {}
var creep: Dictionary = {}  # Vector2i -> texture (sticky, slows the player)
var floor_pads: Array = []  # [centre, texture] teleporter pad decals
var baked: StaticBody2D  # colliders of the objects painted into the themed art
var walls_body: StaticBody2D  # the room walls (off in stations)
# room size of the current theme (ART_THEMES cols/rows/door_x)
var cols := 12
var rows := 27
var room_w := 192.0
var room_h := 432.0
var door_l := 80.0
var door_r := 112.0

# ---- space station mode (StationData): a big painted map the camera scrolls over
var station: Dictionary = {}
var st_tex: Texture2D
var st_scale := 1.0
var walk: Image  # 1 px per walk cell, white = floor
var station_body: StaticBody2D
var exit_body: StaticBody2D
var barrier_body: StaticBody2D
var barrier_cells: Array[Vector2i] = []
var sector_i := -1  # sector currently sealed (-1 = none)

# ---- survival arena
var arena := false
var floor_layer: TileMapLayer
var arena_tex: Dictionary = {}
var arena_bg: Texture2D  # painted arena picture (null = tiled floor and walls)
var arena_bg_rect := Rect2()  # where it is drawn, world units (floor origin = 0,0)
var space: SpaceBackdrop  # outer space behind a floating deck (ART_ARENAS "sky")
var exit_pos := Vector2.INF  # arena exit portal (appears when the stage is clean)
var portal_tex: Texture2D

const CREEP_SLOW := 0.55


func _ready() -> void:
	for t: String in ART_THEMES:
		_theme_bg[t] = load(ART + str(ART_THEMES[t].bg))
	tex_grate = load(ART + "prop_grate.png")
	tex_vent = load(ART + "prop_vent.png")
	tex_pad = load(PropData.path(PropData.PAD_TEX))
	for i in 3:
		tex_splats.append(load(ART + "prop_splat%d.png" % (i + 1)))
	for k in ["l", "r", "t", "b"]:
		arena_tex[k] = load(ARENA + "wall_%s.png" % k)
	arena_tex["corner"] = load(ARENA + "corner.png")
	portal_tex = load(PropData.path("a:142"))
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED  # tiled arena walls
	_set_theme(theme)


## Switch the painted room: size, walls and the colliders baked into the art.
func _set_theme(t: String) -> void:
	theme = t
	var d: Dictionary = ART_THEMES[t]
	cols = int(d.cols)
	rows = int(d.rows)
	room_w = cols * TILE
	room_h = rows * TILE
	door_l = (d.door_x as Vector2).x
	door_r = (d.door_x as Vector2).y
	_build_walls()
	_build_baked()


## World-space rect covered by the painted room art (camera framing / limits).
func art_rect() -> Rect2:
	return _art().rect


## True when the room is bigger than the screen and the camera follows the player.
func follows_camera() -> bool:
	return is_station() or arena or bool(ART_THEMES[theme].get("follow", false))


## How far the astronaut's auto-aim reaches.
func aim_range() -> float:
	return FOLLOW_AIM_RANGE if follows_camera() else INF


## The current theme's painted art (texture, world rect) and door rects.
func _art() -> Dictionary:
	if is_station():
		return {"tex": st_tex, "rect": bounds(), "door": to_world(station.exit),
			"light": to_world(station.get("light", Rect2(station.exit.position.x + 10.0, station.exit.position.y - 20.0, station.exit.size.x - 20.0, 8.0)))}
	if arena:
		return {"tex": arena_bg, "rect": arena_bg_rect if arena_bg != null else bounds().grow(ARENA_WALL),
			"door": Rect2(), "light": Rect2()}
	var t: Dictionary = ART_THEMES[theme]
	var sc: Vector2 = t.scale
	var o: Vector2 = t.origin
	return {"tex": _theme_bg[theme], "rect": Rect2(-o * sc, (t.size as Vector2) * sc),
		"door": t.door, "light": t.light}


## Static colliders for the objects painted into the themed art.
func _build_baked() -> void:
	if baked != null:
		baked.queue_free()
		baked = null
	var t: Dictionary = ART_THEMES.get(theme, {})
	if not t.has("feet"):
		return
	baked = StaticBody2D.new()
	baked.collision_layer = 1
	baked.collision_mask = 0
	add_child(baked)
	for r: Rect2 in t.feet:
		var o: Vector2 = t.origin
		var sc: Vector2 = t.scale
		_wall_rect(baked, Rect2((r.position - o) * sc, r.size * sc))


func _build_walls() -> void:
	if walls_body != null:
		walls_body.queue_free()
	var body := StaticBody2D.new()
	walls_body = body
	body.collision_layer = 0 if is_station() else 1
	body.collision_mask = 0
	add_child(body)
	if arena:
		# closed all round; door_shape is a stand-in far outside
		for r: Rect2 in [Rect2(-16, -16, 16, room_h + 32), Rect2(room_w, -16, 16, room_h + 32),
				Rect2(0, -16, room_w, 16), Rect2(0, room_h, room_w, 16)]:
			_wall_rect(body, r)
		door_shape = _wall_rect(body, Rect2(-200, -200, 4, 4))
		return
	for r: Rect2 in [
		Rect2(-16, -80, 16, room_h + 96), Rect2(room_w, -80, 16, room_h + 96), Rect2(-16, room_h, room_w + 32, 16),
		Rect2(-16, -16, door_l + 16, 16), Rect2(door_r, -16, room_w - door_r + 16, 16),
		Rect2(door_l - 8, -80, 8, 64), Rect2(door_r, -80, 8, 64), Rect2(door_l - 8, -88, door_r - door_l + 16, 8),
	]:
		_wall_rect(body, r)
	door_shape = _wall_rect(body, Rect2(door_l, -16, door_r - door_l, 16))


func _wall_rect(body: StaticBody2D, r: Rect2) -> CollisionShape2D:
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = r.size
	cs.shape = shape
	cs.position = r.position + r.size * 0.5
	body.add_child(cs)
	return cs


func build(layout: Array, entities: Node2D, world_theme := "ship") -> void:
	_clear_station()
	_leave_arena()
	if world_theme != theme or walls_body == null:
		_set_theme(world_theme)
	if layout.size() != rows or (layout[0] as String).length() != cols:
		push_warning("Room layout is %dx%d, theme '%s' expects %dx%d" % [(layout[0] as String).length(), layout.size(), theme, cols, rows])
	creep.clear()
	floor_pads.clear()
	for n in spawned:
		if is_instance_valid(n):
			n.queue_free()
	spawned.clear()
	toxic.clear()
	toxic_until.clear()
	pads.clear()
	electric.clear()
	decor.clear()
	grime.clear()
	grid = layout
	door_open = false
	door_k = 0.0
	door_shape.set_deferred("disabled", false)
	elec_t = 0.0
	elec_state = 0
	var used: Dictionary = {}
	for y in rows:
		var row: String = grid[y]
		for x in cols:
			var cell := Vector2i(x, y)
			if used.has(cell):
				continue
			match row[x]:
				"#":
					if x + 1 < cols and row[x + 1] == "#":
						used[Vector2i(x + 1, y)] = true
						_add_prop(entities, "crate_big", cell, Vector2(x * TILE + 16, y * TILE + 15))
					else:
						_add_prop(entities, "crate", cell, Vector2(x * TILE + 8, y * TILE + 15))
				"B":
					var b := Barrel.new()
					b.position = Vector2(x * TILE + 8, y * TILE + 14)
					entities.add_child(b)
					spawned.append(b)
				"t":
					toxic[cell] = _splat_tex(cell)
				"z":
					electric.append(cell)
				"v":
					decor.append([cell, tex_vent if (x + y) % 2 == 0 else tex_grate])
				"w":
					creep[cell] = PropData.pick(PropData.themed("creep", ["c:080", "c:108"], theme), cell)
				"O":
					var wide := x + 1 < cols and row[x + 1] == "O"
					if wide:
						used[Vector2i(x + 1, y)] = true
					floor_pads.append([cell_center(cell) + Vector2(8 if wide else 0, 0),
							PropData.pick(PropData.themed("pad", ["c:076"], theme), cell)])
				var ch:
					if PropData.LEGEND.has(ch):
						var id: String = PropData.LEGEND[ch]
						if id in PropData.WIDE and x + 1 < cols and row[x + 1] == ch:
							used[Vector2i(x + 1, y)] = true
							_add_prop(entities, id, cell, Vector2(x * TILE + 16, y * TILE + 14))
						else:
							_add_prop(entities, id, cell, Vector2(x * TILE + 8, y * TILE + 14))
					elif PropData.PADS.has(ch):
						pads[cell] = PropData.PADS[ch]
	_scatter_grime()
	queue_redraw()


func _splat_tex(c: Vector2i) -> Texture2D:
	if PropData.THEME_TEX.get(theme, {}).has("toxic"):
		return PropData.pick(PropData.themed("toxic", [], theme), c)
	return tex_splats[(c.x * 7 + c.y * 3) % tex_splats.size()]


## World 2 floor: 32x32 metal plates chosen by weight, stable per layout.
## Movement multiplier at a floor point (sticky creep slows the player).
func slow_factor(p: Vector2) -> float:
	return CREEP_SLOW if creep.has(cell_at(p)) else 1.0


## A few oil stains / old splats on free floor cells so rooms look lived-in
## (stable per layout, never under props, pads or hazards).
func _scatter_grime() -> void:
	var seed_v := 0
	for r: String in grid:
		seed_v = (seed_v * 31 + r.hash()) & 0x7fffffff
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	if not bool(ART_THEMES[theme].get("grime", false)):
		return  # the painted art is already grimy
	var free: Array[Vector2i] = []
	for y in range(1, rows - 1):
		for x in cols:
			if (grid[y] as String)[x] == ".":
				free.append(Vector2i(x, y))
	for i in mini(int(cols * rows / 28.0), free.size()):
		var c := free[rng.randi() % free.size()]
		var tex := PropData.pick(PropData.themed("grime", PropData.GRIME_TEX, theme), c)
		var pos := cell_center(c) + Vector2(rng.randf_range(-4, 4), rng.randf_range(-4, 4))
		grime.append([pos, tex, rng.randf_range(-0.4, 0.4), rng.randf_range(0.85, 1.2)])


func _add_prop(entities: Node2D, id: String, cell: Vector2i, foot: Vector2) -> void:
	var p := Prop.new().setup(id, cell, foot, theme)
	entities.add_child(p)
	spawned.append(p)


## Toxic slime spills over `c` and its free neighbours, drying up after `secs`.
func flood_toxic(c: Vector2i, secs: float) -> void:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var n := c + Vector2i(dx, dy)
			if n.x < 0 or n.y < 0 or n.x >= cols or n.y >= rows:
				continue
			if n != c and absi(dx) + absi(dy) == 2 and randf() < 0.5:
				continue  # ragged edge
			var ch: String = "." if grid.is_empty() else (grid[n.y] as String)[n.x]
			if n == c or ch in [".", "v", "w", "O"] or PropData.PADS.has(ch):
				if not toxic.has(n) or toxic_until.has(n):
					toxic[n] = _splat_tex(n)
					toxic_until[n] = anim_t + secs + randf() * 1.5


# ---------------------------------------------------------------- survival arena

## Build a wide open arena of `size` tiles: quiet floor plates and walls all round,
## no obstacles, so the astronaut and the horde move freely.
func build_arena(size: Vector2i, _entities: Node2D, seed_v: int, art := "") -> void:
	_clear_station()
	for n in spawned:
		if is_instance_valid(n):
			n.queue_free()
	spawned.clear()
	for d: Dictionary in [toxic, toxic_until, pads, creep]:
		d.clear()
	electric.clear()
	decor.clear()
	grime.clear()
	floor_pads.clear()
	grid = []
	arena = true
	theme = "arena"
	exit_pos = Vector2.INF
	door_open = false
	door_k = 0.0
	arena_bg = null
	_clear_space()
	cols = size.x
	rows = size.y
	room_w = cols * TILE
	room_h = rows * TILE
	if art != "":
		_painted_arena(art)
	_build_walls()
	_build_baked()
	if arena_bg == null:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_v
		_arena_floor(rng)
	elif floor_layer != null:
		floor_layer.visible = false
	queue_redraw()


## Painted arena: the room is the picture's floor rectangle, walls follow its edges.
func _painted_arena(id: String) -> void:
	var d: Dictionary = ART_ARENAS[id]
	var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ARENA + str(d.data)))
	var s := float(d.scale)
	var fl: Array = info.floor
	var sz: Array = info.size
	room_w = (float(fl[2]) - float(fl[0])) * s
	room_h = (float(fl[3]) - float(fl[1])) * s
	cols = ceili(room_w / TILE)
	rows = ceili(room_h / TILE)
	arena_bg = load(ARENA + str(d.bg))
	arena_bg_rect = Rect2(-Vector2(float(fl[0]), float(fl[1])) * s, Vector2(float(sz[0]), float(sz[1])) * s)
	if d.has("sky"):
		var beacons: Array = []
		for b: Array in info.get("beacons", []):
			beacons.append((Vector2(float(b[0]), float(b[1])) - Vector2(float(fl[0]), float(fl[1]))) * s)
		space = SpaceBackdrop.new().setup(arena_bg_rect, load(ARENA + str(d.sky)), float(info.get("sky_pad", 0.0)) * s, beacons)
		add_child(space)
		add_child(space.lights)


func _clear_space() -> void:
	if space != null and is_instance_valid(space):
		space.lights.queue_free()
		space.queue_free()
	space = null


func _leave_arena() -> void:
	if not arena:
		return
	arena = false
	_clear_space()
	exit_pos = Vector2.INF
	if floor_layer != null:
		floor_layer.visible = false
	theme = ""  # forces the painted room to rebuild


func _arena_floor(rng: RandomNumberGenerator) -> void:
	var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ARENA + "floor_atlas.json"))
	var plain := int(info.plain)
	var vents := int(info.vent)
	var acols := int(info.cols)
	if floor_layer == null:
		floor_layer = TileMapLayer.new()
		var ts := TileSet.new()
		ts.tile_size = Vector2i(64, 64)
		var src := TileSetAtlasSource.new()
		src.texture = load(ARENA + "floor_atlas.png")
		src.texture_region_size = Vector2i(64, 64)
		for i in plain + vents:
			src.create_tile(Vector2i(i % acols, int(i / float(acols))))
		ts.add_source(src, 0)
		floor_layer.tile_set = ts
		floor_layer.scale = Vector2.ONE * (ARENA_FLOOR_TILE / 64.0)
		floor_layer.show_behind_parent = true  # under the decals Room draws
		floor_layer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		floor_layer.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
		add_child(floor_layer)
	floor_layer.visible = true
	floor_layer.clear()
	for y in ceili(room_h / ARENA_FLOOR_TILE):
		for x in ceili(room_w / ARENA_FLOOR_TILE):
			var i := rng.randi_range(0, plain - 1)
			if vents > 0 and rng.randf() < ARENA_VENT_CHANCE:
				i = plain + rng.randi_range(0, vents - 1)
			floor_layer.set_cell(Vector2i(x, y), 0, Vector2i(i % acols, int(i / float(acols))))


## A free floor spot (no prop within `clear` units) near `p`, inside the arena.
func arena_free_spot(p: Vector2, clear := 12.0) -> Vector2:
	var b := bounds().grow(-14.0)
	for i in 12:
		var q := (p + Vector2.from_angle(randf() * TAU) * randf() * 10.0 * i).clamp(b.position, b.end)
		var ok := true
		for n in spawned:
			if is_instance_valid(n) and (n as Node2D).global_position.distance_to(q) < clear:
				ok = false
				break
		if ok:
			return q
	return p.clamp(b.position, b.end)


func _draw_arena() -> void:
	if arena_bg != null:
		draw_texture_rect(arena_bg, arena_bg_rect, false)
		_draw_arena_extras()
		return
	var s := ARENA_ART_SCALE
	var t := ARENA_WALL
	var wt := 90.0
	draw_set_transform(Vector2(-t, 0), 0.0, Vector2(s, s))
	draw_texture_rect(arena_tex.l, Rect2(0, 0, wt, room_h / s), true)
	draw_set_transform(Vector2(room_w, 0), 0.0, Vector2(s, s))
	draw_texture_rect(arena_tex.r, Rect2(0, 0, wt, room_h / s), true)
	draw_set_transform(Vector2(0, -t), 0.0, Vector2(s, s))
	draw_texture_rect(arena_tex.t, Rect2(0, 0, room_w / s, wt), true)
	draw_set_transform(Vector2(0, room_h), 0.0, Vector2(s, s))
	draw_texture_rect(arena_tex.b, Rect2(0, 0, room_w / s, wt), true)
	# corners (flipped copies of the top-left one)
	for cx in 2:
		for cy in 2:
			var o := Vector2(-t if cx == 0 else room_w + t, -t if cy == 0 else room_h + t)
			draw_set_transform(o, 0.0, Vector2(s if cx == 0 else -s, s if cy == 0 else -s))
			draw_texture_rect(arena_tex.corner, Rect2(0, 0, wt, wt), false)
	draw_set_transform(Vector2.ZERO)
	_draw_arena_extras()


## Toxic slime and the exit portal, over either kind of arena.
func _draw_arena_extras() -> void:
	for c: Vector2i in toxic:
		var tt: Texture2D = toxic[c]
		var glow := 0.85 + sin(anim_t * 3.0 + c.x + c.y) * 0.15
		var tsz := Vector2(22, 22.0 * tt.get_height() / tt.get_width())
		draw_texture_rect(tt, Rect2(cell_center(c) - tsz * 0.5, tsz), false, Color(glow + 0.2, glow + 0.2, glow))
	if exit_pos != Vector2.INF:
		_draw_portal()


## Exit teleporter: a spinning ring of light over the portal art.
func _draw_portal() -> void:
	var k := minf(1.0, door_k)
	var pw := 44.0 * k
	var sz := Vector2(pw, pw * portal_tex.get_height() / portal_tex.get_width())
	var pulse := 0.8 + sin(anim_t * 5.0) * 0.2
	draw_set_transform(exit_pos, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 30.0 * k, Color(0.45, 1.0, 0.55, 0.18 * pulse))
	for i in 3:
		var a := anim_t * (2.0 + i) + i * 2.0
		draw_arc(Vector2.ZERO, (16.0 + i * 6.0) * k, a, a + PI * 1.2, 20, Color(0.65, 1.0, 0.6, 0.7 * pulse), 1.5)
	draw_set_transform(Vector2.ZERO)
	draw_texture_rect(portal_tex, Rect2(exit_pos - Vector2(sz.x * 0.5, sz.y - 6.0), sz), false, Color(1, 1, 1, k))


func cell_at(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / TILE), floori(p.y / TILE))


func cell_center(c: Vector2i) -> Vector2:
	return Vector2(c.x * TILE + 8, c.y * TILE + 8)


## Spawn spots on open floor away from the player. Small rooms: the upper part.
## Big rooms: a ring around the player (not on top of them, not across the map),
## spread out so a wave comes from several sides.
func spawn_points(n: int, avoid: Vector2) -> Array[Vector2]:
	if is_station():
		return _station_spawns(n, avoid)
	var big := follows_camera()
	var free: Array[Vector2] = []
	var far: Array[Vector2] = []
	for y in range(1, rows - 1 if big else 9):
		var row: String = grid[y]
		for x in cols:
			if row[x] in [".", "v", "w", "O"] or PropData.PADS.has(row[x]):
				var p := cell_center(Vector2i(x, y))
				var d := p.distance_to(avoid)
				if d > 80.0 and (not big or d < 200.0):
					free.append(p)
				elif d > 80.0:
					far.append(p)
	if free.size() < n:
		free.append_array(far)
	if free.is_empty():
		free.append(Vector2(room_w * 0.5, 40.0))
	free.shuffle()
	var out: Array[Vector2] = []
	for i in n:
		var best := free[i % free.size()]
		if big:
			# of a few candidates, the one farthest from the spots already taken
			var best_d := -1.0
			for k in mini(6, free.size()):
				var c := free[(i * 5 + k) % free.size()]
				var near := INF
				for o in out:
					near = minf(near, c.distance_to(o))
				if near > best_d:
					best_d = near
					best = c
		out.append(best + Vector2(randf_range(-3, 3), randf_range(-3, 3)))
	return out


func open_door() -> void:
	door_open = true
	if arena:
		queue_redraw()
		return
	if is_station():
		if exit_body != null:
			exit_body.queue_free()
			exit_body = null
		queue_redraw()
		return
	door_shape.set_deferred("disabled", true)


## Playable area in world units (pickups and summons stay inside it).
func bounds() -> Rect2:
	if is_station():
		return Rect2(Vector2.ZERO, st_tex.get_size() * st_scale)
	return Rect2(0, 0, room_w, room_h)


# ---------------------------------------------------------------- space stations

func is_station() -> bool:
	return not station.is_empty()


func build_station(id: String) -> void:
	_clear_station()
	for n in spawned:
		if is_instance_valid(n):
			n.queue_free()
	spawned.clear()
	for d: Dictionary in [toxic, toxic_until, pads, creep]:
		d.clear()
	electric.clear()
	decor.clear()
	grime.clear()
	floor_pads.clear()
	grid = []
	theme = "station"
	if baked != null:
		baked.queue_free()
		baked = null
	station = StationData.get_def(id)
	st_scale = float(station.scale)
	st_tex = load(StationData.DIR + id + ".webp")
	walk = (load(StationData.DIR + id + "_walk.png") as Texture2D).get_image()
	if walk.is_compressed():
		walk.decompress()
	walls_body.collision_layer = 0
	door_shape.set_deferred("disabled", true)
	door_open = false
	door_k = 0.0
	# walls, props and space: one rect per run of blocked cells (runs merged downwards)
	station_body = _static_body()
	var exit_cells := _cells_in(station.exit)
	var open: Dictionary = {}  # "x0,x1" -> [y0, y1] run still growing
	for y in walk.get_height() + 1:
		var runs: Array = []
		if y < walk.get_height():
			var x := 0
			while x < walk.get_width():
				if not _walkable(Vector2i(x, y)) and not exit_cells.has(Vector2i(x, y)):
					var x0 := x
					while x < walk.get_width() and not _walkable(Vector2i(x, y)) and not exit_cells.has(Vector2i(x, y)):
						x += 1
					runs.append("%d,%d" % [x0, x])
				x += 1
		for key: String in open.keys():
			if not runs.has(key):
				var span: Array = open[key]
				var xs := key.split(",")
				_wall_rect(station_body, _cell_rect(int(xs[0]), int(span[0]), int(xs[1]), y))
				open.erase(key)
		for key: String in runs:
			if not open.has(key):
				open[key] = [y]
	# the exit door stays shut until the station is clean
	exit_body = _static_body()
	_wall_rect(exit_body, to_world(station.exit))
	queue_redraw()


func _clear_station() -> void:
	unlock_sector()
	for b: StaticBody2D in [station_body, exit_body]:
		if b != null:
			b.queue_free()
	station_body = null
	exit_body = null
	if not station.is_empty():
		station = {}
		walls_body.collision_layer = 1


func _static_body() -> StaticBody2D:
	var b := StaticBody2D.new()
	b.collision_layer = 1
	b.collision_mask = 0
	add_child(b)
	return b


## Art px -> world units (Vector2 or Rect2).
func to_world(r: Rect2) -> Rect2:
	return Rect2(r.position * st_scale, r.size * st_scale)


func _cell_size() -> float:
	return StationData.CELL * st_scale


func _cell_rect(x0: int, y0: int, x1: int, y1: int) -> Rect2:
	var c := _cell_size()
	return Rect2(x0 * c, y0 * c, (x1 - x0) * c, (y1 - y0) * c)


func st_cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / _cell_size()), floori(p.y / _cell_size()))


func st_cell_center(c: Vector2i) -> Vector2:
	return (Vector2(c) + Vector2(0.5, 0.5)) * _cell_size()


func _walkable(c: Vector2i) -> bool:
	if c.x < 0 or c.y < 0 or c.x >= walk.get_width() or c.y >= walk.get_height():
		return false
	return walk.get_pixel(c.x, c.y).r > 0.5


## Walk cells whose centre lies inside an art-px rect.
func _cells_in(area: Rect2) -> Dictionary:
	var out: Dictionary = {}
	var r := to_world(area)
	var a := st_cell(r.position)
	var b := st_cell(r.end)
	for y in range(a.y, b.y + 1):
		for x in range(a.x, b.x + 1):
			if r.has_point(st_cell_center(Vector2i(x, y))):
				out[Vector2i(x, y)] = true
	return out


func sector_count() -> int:
	return (station.sectors as Array).size() if is_station() else 0


func sector_rect(i: int) -> Rect2:
	return to_world(station.sectors[i].rect)


## Sector whose floor the point stands on (well inside, so sealing never traps the
## player in a barrier), or -1.
func sector_at(p: Vector2) -> int:
	for i in sector_count():
		if sector_rect(i).grow(-_cell_size() * 1.5).has_point(p):
			return i
	return -1


## Seal a sector: an energy barrier on every floor cell just outside it.
func lock_sector(i: int) -> void:
	unlock_sector()
	sector_i = i
	var inside := _cells_in(station.sectors[i].rect)
	var seen: Dictionary = {}
	for c: Vector2i in inside:
		if not _walkable(c):
			continue
		for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n := c + d
			if _walkable(n) and not inside.has(n) and not seen.has(n):
				seen[n] = true
				barrier_cells.append(n)
	barrier_body = _static_body()
	for c in barrier_cells:
		_wall_rect(barrier_body, _cell_rect(c.x, c.y, c.x + 1, c.y + 1))
	Sfx.play("door", 0.0, -4.0)
	queue_redraw()


func unlock_sector() -> void:
	sector_i = -1
	barrier_cells.clear()
	if barrier_body != null:
		barrier_body.queue_free()
		barrier_body = null
	queue_redraw()


## Spawn spots on open floor of the sealed sector, away from the player.
func _station_spawns(n: int, avoid: Vector2) -> Array[Vector2]:
	var free: Array[Vector2] = []
	var near: Array[Vector2] = []
	if sector_i >= 0:
		for c: Vector2i in _cells_in(station.sectors[sector_i].rect):
			var open_around := true
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1)]:
				if not _walkable(c + d):
					open_around = false
			if not _walkable(c) or not open_around:
				continue
			var p := st_cell_center(c)
			(free if p.distance_to(avoid) > 70.0 else near).append(p)
	if free.is_empty():
		free = near
	if free.is_empty():
		free.append(avoid + Vector2(0, -40))
	free.shuffle()
	var out: Array[Vector2] = []
	for i in n:
		out.append(free[i % free.size()] + Vector2(randf_range(-2, 2), randf_range(-2, 2)))
	return out


func exit_reached(p: Vector2) -> bool:
	if arena:
		return door_open and exit_pos != Vector2.INF and p.distance_to(exit_pos) < 14.0
	# the trigger reaches past the threshold so standing at the door is enough
	var cs := _cell_size()
	return door_open and to_world(station.exit).grow_individual(2.0, 2.0, 2.0, cs * 2.0).has_point(p)


func start_pos() -> Vector2:
	return station.start * st_scale


func is_toxic(p: Vector2) -> bool:
	return toxic.has(cell_at(p))


func is_live_electric(p: Vector2) -> bool:
	return elec_state == 2 and electric.has(cell_at(p))


func _physics_process(delta: float) -> void:
	anim_t += delta
	var w := Game.world
	if not electric.is_empty():
		elec_t += delta
		match elec_state:
			0:
				if elec_t > 2.2:
					elec_state = 1
					elec_t = 0.0
			1:
				if elec_t > 0.7:
					elec_state = 2
					elec_t = 0.0
					tick = 1.0
					Sfx.play("zap", 0.1, -6.0)
					for c in electric:
						w.burst(cell_center(c), Color("73eff7"), 4, 50.0, 0.3, 1.5)
			2:
				if elec_t > 0.6:
					elec_state = 0
					elec_t = 0.0
	if door_open:
		door_k = minf(1.0, door_k + delta * 3.0)
	for c: Vector2i in toxic_until.keys():
		if anim_t >= float(toxic_until[c]):
			toxic.erase(c)
			toxic_until.erase(c)
	if not pads.is_empty():
		_push_pads(delta)
	if not toxic.is_empty() and randf() < delta * 5.0:
		var keys := toxic.keys()
		var c: Vector2i = keys[randi() % keys.size()]
		w.burst(cell_center(c) + Vector2(randf_range(-5, 5), randf_range(-4, 4)), Color("a7f070"), 1, 6.0, 0.7, 2.0, -20.0)
	tick += delta
	if tick >= 0.3:
		tick = 0.0
		_hazard_tick()
	queue_redraw()


## Booster pads shove whoever stands on them (player, aliens on the ground).
func _push_pads(delta: float) -> void:
	var p := Game.world.player
	if not p.dead and pads.has(cell_at(p.global_position)):
		p.knock = (p.knock + pads[cell_at(p.global_position)] * 1300.0 * delta).limit_length(150.0)
	for n in get_tree().get_nodes_in_group("enemies"):
		var e := n as Enemy
		if e != null and not e.is_boss and e.air < 4.0 and pads.has(cell_at(e.global_position)):
			e.knock = (e.knock + pads[cell_at(e.global_position)] * 1100.0 * delta).limit_length(130.0)


func _hazard_tick() -> void:
	var w := Game.world
	var p := w.player
	if not p.dead:
		if is_toxic(p.global_position):
			p.take_damage(6.0, Vector2.INF, true)
		if is_live_electric(p.global_position):
			p.take_damage(12.0, Vector2.INF, true)
	for n in get_tree().get_nodes_in_group("enemies"):
		var e := n as Enemy
		if e == null or not e.targetable:
			continue
		if is_toxic(e.global_position):
			e.take_damage(6.0, Vector2.ZERO)
			w.burst(e.global_position, Color("a7f070"), 3, 25.0, 0.3, 1.5, -30.0)
		elif is_live_electric(e.global_position):
			e.take_damage(18.0, Vector2.ZERO)
			e.stun(0.4)
			var l := Lightning.new()
			l.a = e.global_position + Vector2(0, 2)
			l.b = e.hit_center()
			w.effects.add_child(l)


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	if arena:
		_draw_arena()
		return
	draw_rect(Rect2(-400, -500, room_w + 800, room_h + 1000), Color("0a0d1a"))
	var art := _art()
	draw_texture_rect(art.tex, art.rect, false)
	if is_station():
		_draw_barriers()
		_draw_door()
		return
	if grid.is_empty():
		return
	# teleporter pads (floor decals)
	for fp: Array in floor_pads:
		var ptex: Texture2D = fp[1]
		var psz := Vector2(52, 52.0 * ptex.get_height() / ptex.get_width())
		draw_texture_rect(ptex, Rect2(fp[0] - psz * 0.5, psz), false, Color(1, 1, 1, 0.9 + sin(anim_t * 2.0) * 0.1))
	# sticky alien creep: pink puddles that slowly pulse
	for c: Vector2i in creep:
		var ctex: Texture2D = creep[c]
		var k := 1.0 + sin(anim_t * 2.2 + c.x * 1.3 + c.y) * 0.05
		var csz := Vector2(21, 21.0 * ctex.get_height() / ctex.get_width()) * k
		draw_texture_rect(ctex, Rect2(cell_center(c) - csz * 0.5, csz), false)
	# floor grime (under everything else)
	for g: Array in grime:
		var tex: Texture2D = g[1]
		var sz := Vector2(20, 20.0 * tex.get_height() / tex.get_width()) * float(g[3])
		draw_set_transform(g[0], float(g[2]), Vector2.ONE)
		draw_texture_rect(tex, Rect2(-sz * 0.5, sz), false, Color(1, 1, 1, 0.55))
		draw_set_transform(Vector2.ZERO)
	# floor decor (vents / grates)
	for d: Array in decor:
		var c: Vector2i = d[0]
		var tex: Texture2D = d[1]
		var r := Rect2(Vector2(c * TILE) + Vector2(1, 2), Vector2(14, 14.0 * tex.get_height() / tex.get_width()))
		draw_texture_rect(tex, r, false)
	# booster pads: arrow plates pulsing along the push direction
	for c: Vector2i in pads:
		var d: Vector2 = pads[c]
		draw_set_transform(cell_center(c), d.angle(), Vector2.ONE)
		var ph := sin(anim_t * 8.0 - (c.x * d.x + c.y * d.y)) * 0.5 + 0.5
		draw_texture_rect(tex_pad, Rect2(-8, -4.2, 16, 8.4), false, Color(0.85 + ph * 0.4, 0.85 + ph * 0.4, 1.0 + ph * 0.3))
		# a bright chevron slides across in the push direction so it reads at a glance
		var k := fmod(anim_t * 1.6 + (c.x + c.y) * 0.25, 1.0)
		var cx := -6.0 + k * 12.0
		var col := Color(0.75, 1.0, 1.0, sin(k * PI))
		draw_polyline(PackedVector2Array([Vector2(cx - 2.5, -3.0), Vector2(cx, 0), Vector2(cx - 2.5, 3.0)]), col, 1.2)
		draw_set_transform(Vector2.ZERO)
	# toxic slime: glowing painted splats
	for c: Vector2i in toxic:
		var tex: Texture2D = toxic[c]
		var glow := 0.85 + sin(anim_t * 3.0 + c.x + c.y) * 0.15
		var sz := Vector2(22, 22.0 * tex.get_height() / tex.get_width())
		var pos := cell_center(c) - sz * 0.5
		draw_circle(cell_center(c), 9.0, Color(0.45, 0.95, 0.25, 0.18 * glow))
		draw_texture_rect(tex, Rect2(pos, sz), false, Color(glow + 0.2, glow + 0.2, glow))
	# electric floor: grate + warning frame + arcs when live
	for c in electric:
		var pos := Vector2(c * TILE)
		draw_texture_rect(tex_grate, Rect2(pos + Vector2(1, 3), Vector2(14, 11)), false)
		var warn := elec_state == 1 and fmod(elec_t, 0.2) < 0.1
		var col := Color("ffcd75") if warn or elec_state == 2 else Color(1.0, 0.8, 0.3, 0.45)
		draw_rect(Rect2(pos + Vector2(0.5, 0.5), Vector2(15, 15)), col, false, 1.0)
		if elec_state == 2:
			draw_rect(Rect2(pos, Vector2(16, 16)), Color(0.45, 0.94, 0.97, 0.3))
			for i in 2:
				var pts := PackedVector2Array()
				var a := pos + Vector2(randf_range(0, 16), 0)
				for j in 5:
					pts.append(a + Vector2(randf_range(-3, 3), j * 4.0))
				draw_polyline(pts, Color(1, 1, 1, 0.9), 1.0)
	_draw_door()


## Energy barriers sealing the active sector: flickering cyan field with scan lines.
func _draw_barriers() -> void:
	var cs := _cell_size()
	for c in barrier_cells:
		var r := _cell_rect(c.x, c.y, c.x + 1, c.y + 1)
		var k := 0.55 + sin(anim_t * 9.0 + c.x * 0.7 + c.y * 0.5) * 0.2
		draw_rect(r, Color(0.35, 0.9, 1.0, 0.28 * k))
		var y := r.position.y + fmod(anim_t * 12.0 + c.x, cs)
		draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color(0.7, 1.0, 1.0, 0.7 * k), 0.8)
		draw_rect(r, Color(0.45, 0.95, 1.0, 0.55 * k), false, 0.6)


func _draw_door() -> void:
	# painted art shows the door open (green chevrons); slide panels over it when closed
	var r: Rect2 = _art().door
	var half := r.size.x * 0.5
	var pw := half * (1.0 - door_k)
	if pw > 0.3:
		var panel := Color("3b4256")
		var edge := Color("1a1d29")
		for side in 2:
			var x := r.position.x if side == 0 else r.end.x - pw
			var pr := Rect2(x, r.position.y, pw, r.size.y)
			draw_rect(pr, panel)
			draw_rect(Rect2(pr.position, Vector2(pw, 1.5)), Color("5b647c"))
			draw_rect(pr, edge, false, 0.6)
			# hazard stripes along the seam
			var sx := pr.end.x - 3.0 if side == 0 else pr.position.x
			var y := r.position.y + 1.0
			while y < r.end.y - 2.0:
				draw_rect(Rect2(sx, y, 3.0, 2.0), Color("e0a82e"))
				y += 4.0
			for k in 3:
				draw_rect(Rect2(pr.position.x + 2.0, r.position.y + 7.0 + k * 7.0, maxf(0.0, pw - 6.0), 0.8), Color("2a2f3f"))
	var light := Color("a7f070") if door_open else Color("ff4d5a")
	if not door_open and fmod(anim_t, 1.0) < 0.5:
		light = light.darkened(0.45)
	draw_rect(_art().light, light)
