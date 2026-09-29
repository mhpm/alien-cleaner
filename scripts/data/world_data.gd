class_name WorldData
extends RefCounted
## World -> Rooms -> Waves. Each world is picked on the world select and played as one
## survival stage; beating it ("final") ends the run and unlocks the next. World select:
## "pic" (assets/ui/world/, tools/make_world_select_assets.py) and "chest" (coins in the
## world chest, opened once after beating the world). Per world: "theme" (prop art /
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
## Survival stage (worlds 1 and 2): {"survival": {...}} - see scripts/survival.gd. "arena" size in
## tiles, "duration" (s) until the final "boss", "hp_per_min" alien toughness ramp,
## "waves" (one per 30 s): "pool", "alive" (aliens on the field), "rate" (spawns/s),
## "elite" (chance), optional "event": "swarm" / "ring" (+ "id", "count") or "boss" (+ "id",
## optional "count"; bosses scale with the clock, see Survival._boss_hp_mult);
## "final": the spawn settings while the final boss is out. "art": painted arena
## (Room.ART_ARENAS; "arena" is then only a fallback size), "t_offset": seconds the
## toughness ramps start at (world 2 carries on from the end of world 1).
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
## late world 1: the horde brings the odd Big Red brute (1 in 7 of the chasers)
const ALL_BR := ["slime", "slime", "slime", "runner", "runner", "runner", "big_red", "spitter", "droid", "ufo", "octopus"]
const HIVE := ["slime", "runner", "spitter", "droid", "ufo", "octopus", "ufo_alien"]
const HIVE_ROOMS := ["hive_entry", "nest", "biolab", "sludge", "overgrown_cargo", "spires", "pods", "reactor_core"]

const WORLDS := [
	{
		"name": "INFESTED SPACESHIP", "theme": "ship", "enemy_mult": 1.0, "difficulty": [1.0, 0.08],
		"pic": "world_1.png", "chest": 300,
		"rooms": [
			# 1: survival stage - a wide arena, 15 waves of 30 s that keep getting harder.
			# "total" = aliens each wave sends (events included, left-overs carry over):
			# 2000 in all. Every 5th wave an "invasion" horde bursts in after a warning.
			# Gloop Brutes at waves 6 and 11, Big Red brutes from wave 9, and BIG RED
			# himself when the clock hits 7:30 (the horde is wiped and an electric fence
			# closes the fight).
			{"final": true, "survival": {
				"arena": Vector2i(64, 96), "duration": 450.0, "hp_per_min": 0.45,
				"boss": "big_red_boss",
				# during the boss fight: squads slip in through the fence (Survival._boss_help)
				"boss_help": {"pool": ["slime", "slime", "runner"], "max": 8, "every": [18.0, 9.0], "squad": 3},
				"final": {"pool": ["slime", "runner", "spitter", "droid"], "alive": 30, "rate": 2.6},
				"waves": [
					{"pool": ["slime"], "alive": 20, "total": 40},
					{"pool": ["slime", "runner"], "alive": 26, "total": 55},
					{"pool": ["slime", "runner"], "alive": 30, "total": 70, "event": "swarm", "id": "runner", "count": 16},
					{"pool": EARLY, "alive": 34, "total": 80, "event": "ring", "id": "slime", "count": 18},
					{"pool": MID, "alive": 40, "total": 200, "elite": 0.02, "invasion": 120},
					{"pool": EARLY, "alive": 30, "total": 70, "event": "boss", "id": "gloop_brute"},
					{"pool": ["slime", "runner", "spitter", "droid", "ufo"], "alive": 44, "total": 100, "elite": 0.03, "event": "swarm", "id": "runner", "count": 20},
					{"pool": ["slime", "runner", "spitter", "droid", "ufo"], "alive": 48, "total": 110, "elite": 0.04, "event": "swarm", "id": "runner", "count": 28},
					{"pool": ALL_BR, "alive": 52, "total": 120, "elite": 0.04, "event": "ring", "id": "slime", "count": 26},
					{"pool": ALL_BR, "alive": 56, "total": 300, "elite": 0.05, "invasion": 180},
					{"pool": ALL_BR, "alive": 36, "total": 90, "elite": 0.05, "event": "boss", "id": "gloop_brute", "count": 2},
					{"pool": ALL_BR, "alive": 64, "total": 140, "elite": 0.06, "event": "swarm", "id": "slime", "count": 24},
					{"pool": ALL_BR, "alive": 70, "total": 150, "elite": 0.07, "event": "ring", "id": "runner", "count": 36},
					{"pool": ALL_BR, "alive": 76, "total": 160, "elite": 0.08, "event": "swarm", "id": "runner", "count": 30},
					{"pool": ALL_BR, "alive": 80, "total": 315, "elite": 0.09, "invasion": 220},
				],
			}},
		],
	},
	{
		# world 2: a survival stage in the painted hive arena. Picked from the world
		# select with a fresh crew, so the horde starts as if 2.5 minutes in ("t_offset")
		# and every alien, boss included, is 30% stronger, faster and quicker to attack
		# ("enemy_mult").
		"name": "THE HIVE", "theme": "hive", "enemy_mult": 1.3, "difficulty": [1.0, 0.0],
		"pic": "world_2.png", "chest": 600,
		"rooms": [
			{"final": true, "survival": {
				"arena": Vector2i(56, 75), "art": "hive", "duration": 420.0, "hp_per_min": 0.45,
				"t_offset": 150.0, "boss": "hive_queen",
				"boss_help": {"pool": ["ufo_alien", "ufo_alien", "runner", "slime"], "max": 8, "every": [16.0, 8.0], "squad": 3},
				"final": {"pool": HIVE, "alive": 30, "rate": 2.8},
				"waves": [
					{"pool": ["slime", "runner", "ufo_alien"], "alive": 20, "rate": 2.4},
					{"pool": ["slime", "runner", "spitter", "ufo_alien"], "alive": 28, "rate": 3.0, "event": "swarm", "id": "ufo_alien", "count": 20},
					{"pool": MID, "alive": 32, "rate": 3.2, "elite": 0.03, "event": "ring", "id": "runner", "count": 22},
					{"pool": HIVE, "alive": 36, "rate": 3.4, "elite": 0.04, "event": "swarm", "id": "runner", "count": 24},
					{"pool": HIVE, "alive": 40, "rate": 3.6, "elite": 0.04, "event": "ring", "id": "runner", "count": 18},
					{"pool": MID, "alive": 28, "rate": 2.6, "elite": 0.04, "event": "boss", "id": "brood_mother"},
					{"pool": HIVE, "alive": 46, "rate": 4.0, "elite": 0.05, "event": "swarm", "id": "ufo_alien", "count": 30},
					{"pool": HIVE, "alive": 50, "rate": 4.2, "elite": 0.05, "event": "ring", "id": "slime", "count": 34},
					{"pool": HIVE, "alive": 54, "rate": 4.4, "elite": 0.06, "event": "swarm", "id": "slime", "count": 24},
					{"pool": HIVE, "alive": 58, "rate": 4.6, "elite": 0.06, "event": "ring", "id": "runner", "count": 36},
					{"pool": HIVE, "alive": 34, "rate": 3.2, "elite": 0.06, "event": "boss", "id": "gloop_brute", "count": 2},
					{"pool": HIVE, "alive": 66, "rate": 5.0, "elite": 0.07, "event": "swarm", "id": "ufo_alien", "count": 24},
					{"pool": HIVE, "alive": 72, "rate": 5.2, "elite": 0.08, "event": "ring", "id": "runner", "count": 40},
					{"pool": HIVE, "alive": 80, "rate": 5.5, "elite": 0.1, "event": "boss", "id": "brood_mother"},
				],
			}},
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
