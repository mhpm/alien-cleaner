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

const ALL := ["slime", "runner", "splitter", "spitter", "droid", "ufo", "octopus", "eyeclops", "tentacle_plant", "octo_wizard"]
const EARLY := ["slime", "runner", "spitter"]
const MID := ["slime", "runner", "spitter", "droid"]
## late world 1: the horde brings the odd Big Red brute (1 in 7 of the chasers)
const ALL_BR := ["slime", "slime", "slime", "runner", "runner", "runner", "big_red", "splitter", "spitter", "droid", "ufo", "octopus", "eyeclops", "tentacle_plant", "octo_wizard"]
const HIVE := ["slime", "runner", "spitter", "droid", "ufo", "octopus", "eyeclops", "splitter", "tentacle_plant", "octo_wizard", "ufo_alien"]
## world 3: the whole zoo, the sturdy and the shooting
const VOID_MID := ["slime", "runner", "splitter", "spitter", "droid", "octo_wizard"]
## world 3 opens with the new specimens (the splitter does the chasing)
const LAB_START := ["splitter", "splitter", "slime", "eyeclops", "octo_wizard"]
const LAB_EARLY := ["splitter", "runner", "slime", "eyeclops", "tentacle_plant", "octo_wizard"]
const VOID_SHOOTERS := ["eyeclops", "octo_wizard", "tentacle_plant"]
const VOID := ["slime", "runner", "splitter", "spitter", "droid", "ufo", "octopus", "eyeclops", "tentacle_plant", "octo_wizard", "big_red"]
## world 4: UFO crews and the new saucers (scout from the start, gunship from wave 3)
const SPACE_START := ["ufo_alien", "comet_hopper", "comet_baby", "comet_baby", "slime", "runner", "scout", "ring_bug", "nebula_pod"]
const SPACE_MID := ["ufo_alien", "comet_hopper", "slime", "runner", "splitter", "scout", "gunship", "jelly_pod", "spike_mine", "ring_bug", "drill_orbiter", "nova_puffer", "blade_drone", "tesla_drone", "goo_hopper", "bubble_brain", "comet_baby", "nebula_pod", "ring_eye", "tadpole_saucer", "plasma_pupil", "martian_scout", "cyclops_pod", "blink_saucer", "bean_cruiser"]
const SPACE := ["ufo_alien", "comet_hopper", "comet_hopper", "slime", "runner", "splitter", "scout", "gunship", "jelly_pod", "spike_mine", "ring_bug", "drill_orbiter", "nova_puffer", "blade_drone", "tesla_drone", "crab_drone", "prism_drone", "goo_hopper", "bubble_brain", "meteor_peeper", "bell_cruiser", "comet_baby", "nebula_pod", "ring_eye", "puddle_radar", "tadpole_saucer", "plasma_pupil", "tentacle_pod", "pearl_flyer", "martian_scout", "cyclops_pod", "tentacle_orbiter", "slime_comet", "blink_saucer", "bean_cruiser", "nugget_ship", "goo_lantern", "droid", "ufo", "octopus", "eyeclops", "octo_wizard", "big_red"]
const SPACE_SHOOTERS := ["scout", "gunship", "jelly_pod", "ring_bug", "drill_orbiter", "nova_puffer", "tesla_drone", "prism_drone", "crab_drone", "meteor_peeper", "bell_cruiser", "bubble_brain", "ring_eye", "puddle_radar", "tadpole_saucer", "plasma_pupil", "tentacle_pod", "pearl_flyer", "cyclops_pod", "tentacle_orbiter", "slime_comet", "blink_saucer", "nugget_ship"]
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
				# EXPLORE prototype: a 3x4 grid of painted lab rooms (LabRoomData) with 8
				# chests that grant run perks (Explore); "arena" is replaced by the room grid
				"arena": Vector2i(96, 144), "duration": 450.0, "hp_per_min": 0.25,
				"explore": {"grid": [3, 4], "chests": 8, "dark": true},
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
					{"pool": ["slime", "runner", "splitter", "spitter", "droid", "ufo"], "alive": 44, "total": 100, "elite": 0.03, "event": "swarm", "id": "runner", "count": 20},
					{"pool": ["slime", "runner", "splitter", "spitter", "droid", "ufo"], "alive": 48, "total": 110, "elite": 0.04, "event": "swarm", "id": "runner", "count": 28, "events": [
						{"at": 12.0, "event": "boss", "id": "blobulus", "label": "BLOBULUS!"}]},
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
		"name": "THE HIVE", "theme": "hive", "enemy_mult": 1.15, "difficulty": [1.0, 0.0],
		"pic": "world_2.png", "chest": 600,
		"rooms": [
			{"final": true, "survival": {
				# EXPLORE: 3x4 rooms of the "w2" set (the hive's hatchery decks), 8 chests and a
				# few discreet red alarm lights (no darkness, no ZONE ZERO)
				"arena": Vector2i(56, 75), "art": "hive", "duration": 420.0, "hp_per_min": 0.25,
				"explore": {"grid": [3, 4], "chests": 8, "set": "w2", "zero": false, "alarms": true},
				"t_offset": 60.0, "boss": "hive_queen",
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
					{"pool": HIVE, "alive": 54, "rate": 4.4, "elite": 0.06, "event": "swarm", "id": "slime", "count": 24, "events": [
						{"at": 10.0, "event": "boss", "id": "drillback", "label": "DRILLBACK!"}]},
					{"pool": HIVE, "alive": 58, "rate": 4.6, "elite": 0.06, "event": "ring", "id": "runner", "count": 36},
					{"pool": HIVE, "alive": 34, "rate": 3.2, "elite": 0.06, "event": "boss", "id": "gloop_brute", "count": 2},
					{"pool": HIVE, "alive": 66, "rate": 5.0, "elite": 0.07, "event": "swarm", "id": "ufo_alien", "count": 24},
					{"pool": HIVE, "alive": 72, "rate": 5.2, "elite": 0.08, "event": "ring", "id": "runner", "count": 40},
					{"pool": HIVE, "alive": 80, "rate": 5.5, "elite": 0.1, "event": "boss", "id": "brood_mother"},
				],
			}},
		],
	},
	{
		# world 3: an infested alien lab (painted arena "void"), everything +60%; carries on
		# from 5:00 of toughness. The new aliens are there from the first wave, and the
		# horde comes in lab-style events: containment breaches out of the floor hatches,
		# pincers, vortexes, elite squads and crossfire rings of shooters, several per
		# wave ("events" with "at"). Final boss: the VOID ARCHMAGE.
		"name": "THE VOID", "theme": "void", "enemy_mult": 1.3, "difficulty": [1.0, 0.0],
		"pic": "world_3.png", "chest": 900,
		"rooms": [
			{"final": true, "survival": {
				# EXPLORE: a maze of 3x4 rooms of the "w3" set (spanning tree + 35% extra
				# doorways), kit pieces in the middle of the rooms, 8 chests, 5 crew
				"arena": Vector2i(64, 96), "art": "void", "duration": 450.0, "hp_per_min": 0.25,
				"explore": {"grid": [3, 4], "chests": 8, "set": "w3", "zero": false, "alarms": true,
					"maze": 0.35, "interior": "w3"},
				"t_offset": 120.0, "boss": "archmage",
				"boss_help": {"pool": ["splitter", "runner", "eyeclops", "octo_wizard"], "max": 8, "every": [16.0, 8.0], "squad": 3},
				"final": {"pool": VOID, "alive": 34, "rate": 3.0},
				"waves": [
					# 1-4: the new specimens get out one kind of event at a time
					{"pool": LAB_START, "alive": 20, "rate": 2.4, "shooters": 0.3, "events": [
						{"at": 14.0, "event": "breach", "pool": ["splitter", "slime"], "count": 9, "points": 3}]},
					{"pool": LAB_EARLY, "alive": 26, "rate": 2.8, "shooters": 0.3, "event": "pincer", "id": "runner", "count": 16, "events": [
						{"at": 16.0, "event": "escort", "id": "eyeclops", "minion": "splitter", "count": 5}]},
					{"pool": VOID_MID, "alive": 30, "rate": 3.2, "elite": 0.03, "events": [
						{"at": 0.0, "event": "spiral", "pool": ["slime", "splitter"], "count": 20},
						{"at": 15.0, "event": "crossfire", "pool": ["octo_wizard", "eyeclops"], "count": 6}]},
					{"pool": VOID, "alive": 34, "rate": 3.4, "elite": 0.04, "event": "swarm", "id": "runner", "count": 24, "events": [
						{"at": 15.0, "event": "breach", "pool": ["runner", "splitter", "slime"], "count": 16, "points": 4}]},
					# 5: invasion, and the shooters flank you while it lasts
					{"pool": VOID_MID, "alive": 40, "rate": 3.6, "elite": 0.04, "invasion": 110, "events": [
						{"at": 18.0, "event": "crossfire", "pool": VOID_SHOOTERS, "count": 6}]},
					{"pool": VOID_MID, "alive": 28, "rate": 2.6, "elite": 0.04, "event": "boss", "id": "brood_mother", "events": [
						{"at": 12.0, "event": "escort", "id": "octo_wizard", "minion": "runner", "count": 6}]},
					# 7-9: two events per wave
					{"pool": VOID, "alive": 46, "rate": 4.0, "elite": 0.05, "events": [
						{"at": 0.0, "event": "spiral", "id": "tentacle_plant", "count": 8, "label": "OVERGROWTH!"},
						{"at": 15.0, "event": "pincer", "pool": ["runner", "splitter"], "count": 22}]},
					{"pool": VOID, "alive": 50, "rate": 4.2, "elite": 0.05, "event": "pincer", "id": "runner", "count": 28, "events": [
						{"at": 8.0, "event": "boss", "id": "toxic_angler", "label": "TOXIC ANGLER!"},
						{"at": 18.0, "event": "breach", "pool": VOID_MID, "count": 20, "points": 4}]},
					{"pool": VOID, "alive": 54, "rate": 4.4, "elite": 0.06, "events": [
						{"at": 0.0, "event": "escort", "id": "big_red", "minion": "splitter", "count": 8, "label": "BRUTE SQUAD!"},
						{"at": 15.0, "event": "spiral", "id": "slime", "count": 30}]},
					{"pool": VOID, "alive": 58, "rate": 4.6, "elite": 0.06, "invasion": 170, "events": [
						{"at": 20.0, "event": "breach", "pool": ["splitter", "runner"], "count": 16, "points": 3}]},
					{"pool": VOID, "alive": 34, "rate": 3.2, "elite": 0.06, "event": "boss", "id": "gloop_brute", "count": 2, "events": [
						{"at": 15.0, "event": "crossfire", "pool": VOID_SHOOTERS, "count": 8}]},
					# 12-15: the lab falls apart, three events a wave
					{"pool": VOID, "alive": 66, "rate": 5.0, "elite": 0.07, "events": [
						{"at": 0.0, "event": "breach", "pool": ["splitter", "slime", "runner"], "count": 36, "points": 5, "label": "HATCHERY!"},
						{"at": 15.0, "event": "escort", "id": "eyeclops", "minion": "runner", "count": 8}]},
					{"pool": VOID, "alive": 72, "rate": 5.2, "elite": 0.08, "events": [
						{"at": 0.0, "event": "spiral", "pool": ["runner", "slime", "splitter"], "count": 36},
						{"at": 12.0, "event": "pincer", "id": "runner", "count": 30},
						{"at": 22.0, "event": "crossfire", "pool": VOID_SHOOTERS, "count": 8}]},
					{"pool": VOID, "alive": 78, "rate": 5.5, "elite": 0.09, "events": [
						{"at": 0.0, "event": "escort", "id": "big_red", "minion": "big_red", "count": 3, "label": "BRUTE SQUAD!"},
						{"at": 10.0, "event": "breach", "pool": VOID_MID, "count": 30, "points": 4},
						{"at": 21.0, "event": "spiral", "id": "tentacle_plant", "count": 8, "label": "OVERGROWTH!"}]},
					{"pool": VOID, "alive": 84, "rate": 5.8, "elite": 0.1, "invasion": 220, "events": [
						{"at": 18.0, "event": "spiral", "pool": VOID_MID, "count": 30}]},
				],
			}},
		],
	},
	{
		# world 4: an open-air deck floating in space (painted arena "space", space all
		# round it alive with asteroids, UFOs and comets: SpaceBackdrop). Everything +75%,
		# carries on from 7:00 of toughness. Its own events: DROPSHIPs crossing the screen
		# beaming aliens down and METEOR SHOWERs (rocks on marked spots that hurt everyone,
		# some hatch an alien). Final boss: COMMANDER ZORP.
		"name": "ORBITAL DECK", "theme": "space", "enemy_mult": 1.45, "difficulty": [1.0, 0.0],
		"pic": "world_4.png", "chest": 1200,
		"rooms": [
			{"final": true, "survival": {
				"arena": Vector2i(52, 68), "art": "space", "duration": 450.0, "hp_per_min": 0.25,
				"t_offset": 180.0, "boss": "zorp",
				"boss_help": {"pool": ["ufo_alien", "ufo_alien", "runner", "scout"], "max": 8, "every": [15.0, 7.0], "squad": 3},
				"final": {"pool": SPACE, "alive": 36, "rate": 3.2},
				"waves": [
					# 1-4: the dropships and the first rocks
					{"pool": SPACE_START, "alive": 22, "rate": 2.6, "events": [
						{"at": 12.0, "event": "dropship", "id": "ufo_alien", "count": 8},
						{"at": 22.0, "event": "swarm", "id": "comet_hopper", "count": 10, "label": "HOPPER PACK!"}]},
					{"pool": SPACE_START, "alive": 26, "rate": 2.9, "events": [
						{"at": 0.0, "event": "meteor", "pool": ["slime", "ufo_alien"], "count": 6, "hatch": 0.5},
						{"at": 17.0, "event": "dropship", "pool": ["ufo_alien", "runner"], "count": 10}]},
					{"pool": SPACE_MID, "alive": 30, "rate": 3.2, "elite": 0.03, "event": "pincer", "id": "runner", "count": 20, "events": [
						{"at": 15.0, "event": "meteor", "pool": ["splitter", "slime"], "count": 8, "hatch": 0.4}]},
					{"pool": SPACE_MID, "alive": 34, "rate": 3.4, "elite": 0.04, "events": [
						{"at": 0.0, "event": "crossfire", "pool": ["scout", "scout", "gunship"], "count": 6, "label": "SAUCER RING!"},
						{"at": 10.0, "event": "dropship", "id": "ufo_alien", "count": 10},
						{"at": 21.0, "event": "dropship", "pool": ["runner", "splitter"], "count": 8}]},
					# 5: invasion under a rain of rocks
					{"pool": SPACE_MID, "alive": 40, "rate": 3.6, "elite": 0.04, "invasion": 140, "events": [
						{"at": 17.0, "event": "meteor", "id": "ufo_alien", "count": 10, "hatch": 0.3}]},
					{"pool": SPACE_MID, "alive": 30, "rate": 2.8, "elite": 0.04, "event": "boss", "id": "gloop_brute", "events": [
						{"at": 12.0, "event": "dropship", "pool": ["ufo_alien", "slime"], "count": 12, "label": "REINFORCEMENTS!"},
						{"at": 22.0, "event": "pincer", "id": "scout", "count": 8, "label": "SCOUT WING!"},
						{"at": 4.0, "event": "ring", "id": "martian_scout", "count": 6, "label": "MARTIAN SQUAD!"},
						{"at": 26.0, "event": "crossfire", "id": "ring_eye", "count": 4, "label": "SNIPERS!"}]},
					# 7-10: two or three events a wave
					{"pool": SPACE, "alive": 46, "rate": 4.0, "elite": 0.05, "events": [
						{"at": 0.0, "event": "spiral", "id": "ufo_alien", "count": 24},
						{"at": 8.0, "event": "ring", "id": "jelly_pod", "count": 6, "label": "JELLY BLOOM!"},
						{"at": 15.0, "event": "meteor", "pool": ["splitter", "runner"], "count": 10, "hatch": 0.5},
						{"at": 24.0, "event": "swarm", "id": "goo_hopper", "count": 8, "label": "GOO STAMPEDE!"}]},
					{"pool": SPACE, "alive": 50, "rate": 4.2, "elite": 0.05, "event": "escort", "id": "gunship", "minion": "scout", "count": 5, "label": "UFO SQUADRON!", "events": [
						{"at": 4.0, "event": "boss", "id": "clawdozer", "label": "CLAWDOZER!"},
						{"at": 12.0, "event": "dropship", "pool": SPACE_MID, "count": 14},
						{"at": 23.0, "event": "crossfire", "pool": ["meteor_peeper", "bell_cruiser", "bubble_brain"], "count": 6, "label": "SAUCER SIEGE!"}]},
					{"pool": SPACE, "alive": 54, "rate": 4.4, "elite": 0.06, "events": [
						{"at": 0.0, "event": "meteor", "pool": SPACE_MID, "count": 16, "hatch": 0.35, "label": "METEOR STORM!"},
						{"at": 16.0, "event": "pincer", "pool": ["runner", "ufo_alien"], "count": 24},
						{"at": 20.0, "event": "spiral", "id": "plasma_pupil", "count": 6, "label": "EYES EVERYWHERE!"},
						{"at": 26.0, "event": "pincer", "id": "bean_cruiser", "count": 4, "label": "GOO TRAP!"},
						{"at": 24.0, "event": "spiral", "id": "spike_mine", "count": 8, "label": "MINEFIELD!"}]},
					{"pool": SPACE, "alive": 58, "rate": 4.6, "elite": 0.06, "invasion": 200, "events": [
						{"at": 16.0, "event": "dropship", "id": "big_red", "count": 4, "label": "HEAVY DROP!"},
						{"at": 24.0, "event": "swarm", "id": "comet_baby", "count": 14, "label": "BABY RUSH!"},
						{"at": 8.0, "event": "pincer", "id": "slime_comet", "count": 4, "label": "SLIME RUN!"}]},
					{"pool": SPACE, "alive": 36, "rate": 3.4, "elite": 0.06, "event": "boss", "id": "magma_drake", "label": "MAGMA DRAKE!", "events": [
						{"at": 14.0, "event": "crossfire", "pool": SPACE_SHOOTERS, "count": 8},
						{"at": 24.0, "event": "ring", "id": "tesla_drone", "count": 6, "label": "TESLA CAGE!"}]},
					# 12-15: the whole fleet
					{"pool": SPACE, "alive": 66, "rate": 5.0, "elite": 0.07, "events": [
						{"at": 0.0, "event": "dropship", "id": "ufo_alien", "count": 12},
						{"at": 8.0, "event": "dropship", "pool": ["runner", "splitter"], "count": 12},
						{"at": 18.0, "event": "spiral", "pool": SPACE_MID, "count": 30},
						{"at": 26.0, "event": "escort", "id": "crab_drone", "minion": "blade_drone", "count": 6, "label": "DRONE SWARM!"}]},
					{"pool": SPACE, "alive": 72, "rate": 5.2, "elite": 0.08, "events": [
						{"at": 0.0, "event": "meteor", "pool": SPACE_MID, "count": 20, "hatch": 0.4, "label": "METEOR STORM!"},
						{"at": 8.0, "event": "escort", "id": "pearl_flyer", "minion": "tentacle_pod", "count": 4, "label": "BUBBLE FLEET!"},
						{"at": 20.0, "event": "escort", "id": "goo_lantern", "minion": "big_red", "count": 3, "label": "FIELD MEDIC!"},
						{"at": 15.0, "event": "escort", "id": "big_red", "minion": "big_red", "count": 3, "label": "BRUTE SQUAD!"},
						{"at": 24.0, "event": "crossfire", "pool": ["drill_orbiter", "nova_puffer", "ring_bug"], "count": 6, "label": "ORBIT LOCK!"}]},
					{"pool": SPACE, "alive": 78, "rate": 5.5, "elite": 0.09, "event": "pincer", "id": "runner", "count": 36, "events": [
						{"at": 10.0, "event": "dropship", "pool": SPACE, "count": 16, "label": "MOTHERSHIP!"},
						{"at": 21.0, "event": "crossfire", "pool": SPACE_SHOOTERS, "count": 8}]},
					{"pool": SPACE, "alive": 84, "rate": 5.8, "elite": 0.1, "invasion": 260, "events": [
						{"at": 14.0, "event": "meteor", "pool": SPACE_MID, "count": 22, "hatch": 0.3, "label": "METEOR STORM!"}]},
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
