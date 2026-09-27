class_name WorldData
extends RefCounted
## World -> Rooms -> Waves. Worlds play back to back (world 1 = rooms 1-10, world 2 =
## rooms 11-30); the room marked "final" ends the run. Per world: "theme" (prop art /
## floor, see PropData.THEME_TEX), "enemy_mult" (HP & damage of every alien, bosses too)
## and "difficulty" [start, per room] for the HP/damage ramp inside the world.
## Layouts are ASCII tile grids sized for the world's painted room (Room.ART_THEMES):
## world 1 "ship" 12x27 (the camera scrolls), world 2 "hive" 10x14.
## Legend: . floor  v vent  # crate (## big crate)  T alien crystals  c canister
##         B explosive barrel  t toxic slime  z electric floor
##         M alien mushroom  r space rock  C console  P specimen tube
##         R radioactive tank (bursts into toxic slime)  F cryo tank (freezes aliens)
##         G generator  H med kit (shoot it: heart)  ff fence (bullets pass)  kk forklift
##         > < ^ , booster pads (push toward right / left / up / down)
##         K supply crate (shoot it: coins)  U auto turret (stand by it: it shoots)
##         D machine  l lamp post  pp planter  A satellite dish  xx command desk
##         hh hazard barrier (bullets pass)  N broken robot
##         hive: E alien egg (hatches when you get close)  I pillar  L lamp  S spire
##               w sticky creep (slows you)  OO teleporter pad (floor decal)
##               X object painted into the hive room art (collision comes from the art)
## Survival stage (world 1): {"survival": {...}} - see scripts/survival.gd. "arena" size in
## tiles, "duration" (s) until the final "boss", "hp_per_min" alien toughness ramp,
## "waves" (one per 30 s): "pool", "alive" (aliens on the field), "rate" (spawns/s),
## "elite" (chance), optional "event": "swarm" / "ring" (+ "id", "count") or "boss" (+ "id");
## "final": the spawn settings while the final boss is out.
## The 12x27 world-1 room layouts below are kept for room-style levels.
## Wave: {"fixed": {type: count}} and/or {"budget": n, "pool": [types]} (random by enemy
## cost); optional "elite": n golden elites (default: 1 on the last wave of a room with
## 3+ waves). Each later wave of a room is sturdier (GameWorld.WAVE_HP_STEP). A room
## with "waves" and "boss" sends the boss after its waves.

const LAYOUTS := {
	# ---- world 1: INFESTED SPACESHIP. Big rooms (Room.ART_THEMES.ship, 12x27): the camera
	# follows the astronaut, who enters at the bottom; the exit door is at the top
	# (cols 5-6). Keep rows 24-26 around the middle free for the entrance.
	# docking bay: crates and planters, a supply crate and a first turret to discover
	"docking_bay": [
		"l..C....C..l", "............", "..##....##..", "............", ".K........B.",
		"............", "..pp....pp..", "............", "............", ".T...vv...T.",
		"............", "............", "...#....#...", "............", "U..........H",
		"............", "..c......c..", "............", "............", ".B...##...B.",
		"............", "............", "..pp....pp..", "............", "l..........l",
		"............", "............",
	],
	# cargo hold: forklifts, fenced pens you can shoot through, conveyor pads to the middle
	"cargo_hold": [
		"G..........G", "............", ".##.K..K.##.", "............", ".ff......ff.",
		"............", "...kk..kk...", "............", "B....##....B", "............",
		"............", ".#hh....hh#.", "............", "............", ">>>>....<<<<",
		"............", "............", "..##.K..##..", "............", "U....cc....U",
		"............", ".ff......ff.", "............", "B..........B", "............",
		"............", "............",
	],
	# medical lab: command desks, specimen tubes, cryo tanks to freeze the crowd
	"med_lab": [
		"CC.P....P.CC", "............", "..F......F..", "............", "...xx..xx...",
		"............", ".P........P.", "............", "....N..H....", "............",
		"..#......#..", "............", "C..........C", "....F..F....", "............",
		".P...xx...P.", "............", "............", "U..#....#..U", "............",
		"..K......R..", "............", "............", ".c........c.", "............",
		"............", "............",
	],
	# reactor: radioactive tanks between slime pools, electric grates, booster pads
	"reactor": [
		"G..R....R..G", "............", "..tt....tt..", "..tR....Rt..", "............",
		"....>..<....", "............", ".D........D.", "............", "...zz..zz...",
		"............", "R....DD....R", "............", "tt........tt", "............",
		"...zz..zz...", "............", ".G...,,...G.", "............", "....K..B....",
		"U..........U", "..t......t..", "............", "...B....B...", "............",
		"............", "............",
	],
	# mini boss arena: wide open, barrels to blow up, a turret in every corner
	"brute_arena": [
		"l..........l", "............", "..B......B..", "............", "U..........U",
		"............", "............", "....l..l....", "............", "............",
		".H........K.", "............", "............", "............", ".K........H.",
		"............", "............", "....l..l....", "............", "............",
		"U..........U", "............", "..B......B..", "............", "............",
		"............", "............",
	],
	# hydroponics: rows of crystal planters, alien mushrooms, a toxic spill
	"hydroponics": [
		"l.pp....pp.l", "............", ".M........M.", "...T....T...", "............",
		".pp..pp..pp.", "............", "............", "..M..tt..M..", "............",
		"A..........A", "............", ".pp......pp.", "............", "....T..T....",
		"............", "K....MM....K", "............", "..pp....pp..", "............",
		"U..t....t..U", "............", "............", ".M........M.", "............",
		"............", "............",
	],
	# comms deck: satellite dishes, command desks and live electric grates
	"comms_deck": [
		"A..C....C..A", "............", "..xx....xx..", "............", ".N........N.",
		"............", "..zz....zz..", "............", "...A....A...", "............",
		"U..........U", "............", ".C..zzzz..C.", "............", "............",
		"...D....D...", "............", ".K...xx...B.", "............", "..zz....zz..",
		"............", ".N...H....N.", "............", "l..........l", "............",
		"............", "............",
	],
	# conveyor: two booster loops (clockwise / counter-clockwise) around crate stacks
	"conveyor": [
		"G...C..C...G", "............", "..B......B..", "............", "..>>>>>>>,..",
		"..^......,..", "..^.##K#.,..", "..^......,..", "..^.#..#.,..", "..^......,..",
		"..^<<<<<<<..", "............", "U....hh....U", "............", "..,<<<<<<<..",
		"..,......^..", "..,.#..#.^..", "..,..FF..^..", "..,.c..c.^..", "..,......^..",
		"..>>>>>>>^..", "............", "..ff....ff..", "............", "B..........B",
		"............", "............",
	],
	# hazard hall: electric grates, barrels, slime and tanks everywhere
	"hazard_hall": [
		"R..........R", "............", ".zz.B..B.zz.", "............", "...#....#...",
		"U..........U", "..tt....tt..", "............", "....zzzz....", "............",
		".F..B..B..F.", "............", "...##..##...", "............", "zz...KH...zz",
		"............", "..R......R..", "............", "....t..t....", ".B........B.",
		"............", "...zz..zz...", "............", "U..........U", "............",
		"............", "............",
	],
	# the Slime King's hall: open floor, cryo tanks and turrets to turn the tide
	"throne": [
		"l...C..C...l", "............", "............", ".U........U.", "............",
		"............", "...F....F...", "............", "............", ".B........B.",
		"............", "............", "............", "H....vv....H", "............",
		"............", ".B........B.", "............", "............", "...F....F...",
		"............", ".U........U.", "............", "............", "l..........l",
		"............", "............",
	],
	# ---- world 2: THE HIVE. The painted hive room (Room.ART_THEMES.hive) already has its
	# crates, pods and barrels: X marks them (keep X where it is); the layouts only add
	# eggs, creep, tanks and hazards on free floor. Rows 9-12 cols 4-5 = the way in.
	"hive_entry": [
		"X.......XX", "..XX..XX..", ".E.....X..", "XX......XX", "X.......XX",
		"...ww.....", "..XX...XX.", ".......XX.", "..X....E.X", "XXX....X..",
		"XXXX..XXXX", "........XX", "..........", "XX......XX",
	],
	"nest": [
		"X.......XX", "..XX..XX..", "...E..EX..", "XX.wwww.XX", "X..w..w.XX",
		"...wwww...", "..XX...XX.", ".E.....XX.", "..X......X", "XXX....X.E",
		"XXXX..XXXX", "........XX", "..........", "XX......XX",
	],
	"biolab": [
		"X.......XX", "..XX..XX..", ".F.....XR.", "XX......XX", "X.......XX",
		"H.........", "..XX...XX.", "...E...XX.", "..X......X", "XXX....XF.",
		"XXXX..XXXX", "........XX", "..........", "XX......XX",
	],
	"sludge": [
		"X.......XX", "..XX..XX..", ".......X..", "XXt....tXX", "X.t..B..XX",
		"..........", "..XXtt.XX.", "...E...XX.", "..X...R..X", "XXX....X..",
		"XXXX..XXXX", "tt......XX", "..........", "XX......XX",
	],
	"overgrown_cargo": [
		"X.......XX", "..XX..XX..", "B......X.B", "XX......XX", "X..E....XX",
		"H...ww....", "..XX...XX.", "B......XX.", "..X..E...X", "XXX....X..",
		"XXXX..XXXX", "........XX", "..........", "XX......XX",
	],
	"spires": [
		"X.......XX", "..XX..XX..", ".......X..", "XX.zz.zzXX", "X.......XX",
		"...E..E...", "..XX...XX.", ".......XX.", "..X.zz...X", "XXX....X..",
		"XXXX..XXXX", "........XX", "..........", "XX......XX",
	],
	"pods": [
		"X.......XX", "..XX..XX..", ".......X..", "XX>>..<<XX", "X.......XX",
		"..E....E..", "..XX...XX.", ".......XX.", "..X......X", "XXX.^^.X..",
		"XXXX..XXXX", "........XX", "..........", "XX......XX",
	],
	"reactor_core": [
		"X.......XX", "..XX..XX..", ".R.....XR.", "XX......XX", "X..t..t.XX",
		"....OO....", "..XX...XX.", "...t...XX.", "..X...E..X", "XXX....XB.",
		"XXXX..XXXX", "........XX", "..........", "XX......XX",
	],
	# world 2 boss arenas
	"brood_lair": [
		"X.......XX", "..XX..XX..", ".......X..", "XX......XX", "X..w..w.XX",
		"....OO....", "..XX...XX.", ".......XX.", "..X......X", "XXX....X..",
		"XXXX..XXXX", "........XX", "..........", "XX......XX",
	],
	"mothership_dock": [
		"X.......XX", "..XX..XX..", ".R.....X..", "XX......XX", "X.......XX",
		"....OO....", "..XX...XX.", ".......XX.", "..X......X", "XXX....X..",
		"XXXX..XXXX", "........XX", "..........", "XX......XX",
	],
}

const ALL := ["slime", "runner", "spitter", "droid", "ufo", "octopus"]
const EARLY := ["slime", "runner", "spitter"]
const MID := ["slime", "runner", "spitter", "droid"]
const HIVE := ["slime", "runner", "spitter", "droid", "ufo", "octopus", "ufo_alien"]
const HIVE_ROOMS := ["hive_entry", "nest", "biolab", "sludge", "overgrown_cargo", "spires", "pods", "reactor_core"]

const WORLDS := [
	{
		"name": "INFESTED SPACESHIP", "theme": "ship", "enemy_mult": 1.0, "difficulty": [1.0, 0.08],
		"rooms": [
			# 1: survival stage - a wide arena, 14 waves of 30 s that keep getting harder,
			# the Gloop Brute at wave 6 and the Slime King when the clock hits 7:00
			{"survival": {
				"arena": Vector2i(64, 96), "duration": 420.0, "hp_per_min": 0.32,
				"boss": "slime_king",
				"final": {"pool": ["slime", "runner", "spitter"], "alive": 16, "rate": 1.5},
				"waves": [
					{"pool": ["slime"], "alive": 10, "rate": 1.2},
					{"pool": ["slime"], "alive": 16, "rate": 1.8},
					{"pool": ["slime", "runner"], "alive": 20, "rate": 2.0, "event": "swarm", "id": "runner", "count": 12},
					{"pool": EARLY, "alive": 24, "rate": 2.2},
					{"pool": MID, "alive": 28, "rate": 2.5, "event": "ring", "id": "slime", "count": 20},
					{"pool": EARLY, "alive": 16, "rate": 1.5, "event": "boss", "id": "gloop_brute"},
					{"pool": ["slime", "runner", "spitter", "droid", "ufo"], "alive": 30, "rate": 2.8, "elite": 0.02},
					{"pool": ["slime", "runner", "spitter", "droid", "ufo"], "alive": 34, "rate": 3.0, "elite": 0.03, "event": "swarm", "id": "runner", "count": 20},
					{"pool": ALL, "alive": 38, "rate": 3.2, "elite": 0.03},
					{"pool": ALL, "alive": 42, "rate": 3.4, "elite": 0.04, "event": "ring", "id": "slime", "count": 28},
					{"pool": ALL, "alive": 46, "rate": 3.6, "elite": 0.05},
					{"pool": ALL, "alive": 50, "rate": 3.8, "elite": 0.05, "event": "swarm", "id": "droid", "count": 14},
					{"pool": ALL, "alive": 54, "rate": 4.0, "elite": 0.06, "event": "ring", "id": "runner", "count": 30},
					{"pool": ALL, "alive": 58, "rate": 4.2, "elite": 0.08},
				],
			}},
		],
	},
	{
		# rooms 11-30: aliens get +20% HP and damage on top of the ramp, which picks up
		# where world 1 ended
		"name": "THE HIVE", "theme": "hive", "enemy_mult": 1.2, "difficulty": [1.72, 0.04],
		"rooms": [
			{"layouts": ["hive_entry"], "waves": [{"fixed": {"slime": 3, "runner": 2}}, {"budget": 5, "pool": HIVE}]},  # 11: the hive - mind the eggs
			{"layouts": HIVE_ROOMS, "waves": [{"budget": 8, "pool": HIVE}]},  # 12
			{"layouts": HIVE_ROOMS, "waves": [{"fixed": {"droid": 2, "ufo_alien": 2}}, {"budget": 6, "pool": HIVE}], "upgrade": true},  # 13
			{"layouts": HIVE_ROOMS, "waves": [{"budget": 8, "pool": HIVE}, {"budget": 7, "pool": HIVE}]},  # 14
			{"layouts": HIVE_ROOMS, "waves": [{"fixed": {"octopus": 2, "ufo": 1}}, {"budget": 8, "pool": HIVE}], "upgrade": true},  # 15
			{"layouts": HIVE_ROOMS, "waves": [{"budget": 10, "pool": HIVE}, {"budget": 6, "pool": HIVE}]},  # 16
			{"layouts": HIVE_ROOMS, "waves": [{"budget": 9, "pool": HIVE}, {"budget": 9, "pool": HIVE}], "upgrade": true},  # 17
			{"layouts": HIVE_ROOMS, "waves": [{"budget": 10, "pool": HIVE}, {"budget": 10, "pool": HIVE}]},  # 18
			{"layouts": HIVE_ROOMS, "waves": [{"budget": 11, "pool": HIVE}, {"budget": 11, "pool": HIVE}], "upgrade": true},  # 19
			# 20: mini boss
			{"layouts": ["brood_lair"], "boss": "brood_mother", "upgrade": true},
			{"layouts": HIVE_ROOMS, "waves": [{"budget": 10, "pool": HIVE}, {"budget": 10, "pool": HIVE}]},  # 21
			{"layouts": HIVE_ROOMS, "waves": [{"budget": 11, "pool": HIVE}, {"budget": 11, "pool": HIVE}], "upgrade": true},  # 22
			{"layouts": HIVE_ROOMS, "waves": [{"budget": 12, "pool": HIVE}, {"budget": 10, "pool": HIVE}]},  # 23
			{"layouts": HIVE_ROOMS, "waves": [{"budget": 12, "pool": HIVE}, {"budget": 12, "pool": HIVE}], "upgrade": true},  # 24
			{"layouts": HIVE_ROOMS, "waves": [{"budget": 13, "pool": HIVE}, {"budget": 12, "pool": HIVE}]},  # 25
			{"layouts": HIVE_ROOMS, "waves": [{"budget": 13, "pool": HIVE}, {"budget": 13, "pool": HIVE}], "upgrade": true},  # 26
			{"layouts": HIVE_ROOMS, "waves": [{"budget": 14, "pool": HIVE}, {"budget": 13, "pool": HIVE}]},  # 27
			{"layouts": HIVE_ROOMS, "waves": [{"budget": 14, "pool": HIVE}, {"budget": 14, "pool": HIVE}], "upgrade": true},  # 28
			{"layouts": HIVE_ROOMS, "waves": [{"budget": 15, "pool": HIVE}, {"budget": 15, "pool": HIVE}], "upgrade": true},  # 29
			# 30: final boss - the end of world 2 (and of the run)
			{"layouts": ["mothership_dock"], "boss": "mothership", "final": true},
		],
	},
]


static func world(idx: int) -> Dictionary:
	return WORLDS[clampi(idx, 0, WORLDS.size() - 1)]


static func room(world_idx: int, room_idx: int) -> Dictionary:
	var rooms: Array = world(world_idx).rooms
	return rooms[clampi(room_idx, 0, rooms.size() - 1)]


static func room_count(world_idx: int) -> int:
	var rooms: Array = world(world_idx).rooms
	return rooms.size()


## Room number across worlds (world 2 starts at 11).
static func global_room(world_idx: int, room_idx: int) -> int:
	var n := room_idx + 1
	for w in mini(world_idx, WORLDS.size()):
		n += room_count(w)
	return n


static func total_rooms() -> int:
	return global_room(WORLDS.size() - 1, room_count(WORLDS.size() - 1) - 1)


static func is_last_room(world_idx: int, room_idx: int) -> bool:
	return room_idx >= room_count(world_idx) - 1
