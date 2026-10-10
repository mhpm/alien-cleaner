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

const ALL := ["slime", "runner", "splitter", "spitter", "droid", "ufo", "octopus", "eyeclops", "tentacle_plant", "octo_wizard", "alien_trooper"]
const EARLY := ["slime", "runner", "spitter"]
const MID := ["slime", "runner", "spitter", "droid"]
## late world 1: the horde brings the odd Big Red brute (1 in 7 of the chasers)
const ALL_BR := ["slime", "slime", "slime", "runner", "runner", "runner", "big_red", "splitter", "spitter", "droid", "ufo", "octopus", "eyeclops", "tentacle_plant", "octo_wizard", "alien_trooper", "saucer_pilot"]
const HIVE := ["slime", "runner", "spitter", "droid", "ufo", "octopus", "eyeclops", "splitter", "tentacle_plant", "octo_wizard", "ufo_alien", "alien_trooper", "saucer_pilot", "jelly_saucer"]
## world 3: the whole zoo, the sturdy and the shooting
const VOID_MID := ["slime", "runner", "splitter", "spitter", "droid", "octo_wizard"]
## world 3 opens with the new specimens (the splitter does the chasing)
const LAB_START := ["splitter", "splitter", "slime", "eyeclops", "octo_wizard"]
const LAB_EARLY := ["splitter", "runner", "slime", "eyeclops", "tentacle_plant", "octo_wizard"]
const VOID_SHOOTERS := ["eyeclops", "octo_wizard", "tentacle_plant", "jelly_saucer"]
const VOID := ["slime", "runner", "splitter", "spitter", "droid", "ufo", "octopus", "eyeclops", "tentacle_plant", "octo_wizard", "big_red", "jelly_saucer"]
## world 4: UFO crews and the new saucers (scout from the start, gunship from wave 3)
const SPACE_START := ["ufo_alien", "comet_hopper", "comet_baby", "comet_baby", "slime", "runner", "scout", "ring_bug", "nebula_pod"]
const SPACE_MID := ["ufo_alien", "comet_hopper", "slime", "runner", "splitter", "scout", "gunship", "jelly_pod", "spike_mine", "ring_bug", "drill_orbiter", "nova_puffer", "blade_drone", "tesla_drone", "goo_hopper", "bubble_brain", "comet_baby", "nebula_pod", "ring_eye", "tadpole_saucer", "plasma_pupil", "martian_scout", "cyclops_pod", "blink_saucer", "bean_cruiser"]
const SPACE := ["ufo_alien", "comet_hopper", "comet_hopper", "slime", "runner", "splitter", "scout", "gunship", "jelly_pod", "spike_mine", "ring_bug", "drill_orbiter", "nova_puffer", "blade_drone", "tesla_drone", "crab_drone", "prism_drone", "goo_hopper", "bubble_brain", "meteor_peeper", "bell_cruiser", "comet_baby", "nebula_pod", "ring_eye", "puddle_radar", "tadpole_saucer", "plasma_pupil", "tentacle_pod", "pearl_flyer", "martian_scout", "cyclops_pod", "tentacle_orbiter", "slime_comet", "blink_saucer", "bean_cruiser", "nugget_ship", "goo_lantern", "droid", "ufo", "octopus", "eyeclops", "octo_wizard", "big_red"]
const SPACE_SHOOTERS := ["scout", "gunship", "jelly_pod", "ring_bug", "drill_orbiter", "nova_puffer", "tesla_drone", "prism_drone", "crab_drone", "meteor_peeper", "bell_cruiser", "bubble_brain", "ring_eye", "puddle_radar", "tadpole_saucer", "plasma_pupil", "tentacle_pod", "pearl_flyer", "cyclops_pod", "tentacle_orbiter", "slime_comet", "blink_saucer", "nugget_ship"]
## world 5 (THE FORGE): its 3 new aliens (orbit_raider, orbit_spawn, eye_blob) and the
## world-4 ones that suit a lava plant; the oldest chasers (slime, runner, splitter) are out
const FORGE_START := ["orbit_spawn", "orbit_spawn", "orbit_spawn", "eye_blob", "orbit_raider", "comet_baby", "goo_hopper"]
const FORGE_MID := ["orbit_spawn", "orbit_spawn", "eye_blob", "orbit_raider", "comet_baby", "comet_hopper", "goo_hopper", "spike_mine", "tesla_drone", "blade_drone", "meteor_peeper"]
const FORGE := ["orbit_spawn", "orbit_spawn", "orbit_spawn", "eye_blob", "orbit_raider", "comet_baby", "comet_hopper", "goo_hopper", "big_red", "spike_mine", "tesla_drone", "blade_drone", "crab_drone", "prism_drone", "meteor_peeper", "nugget_ship", "goo_lantern", "gunship"]
const FORGE_SHOOTERS := ["eye_blob", "orbit_raider", "tesla_drone", "prism_drone", "meteor_peeper", "nugget_ship"]
## world 6 (GENE VAULT): the cloning lab's specimens. New in the waves: Slimelets
## (mini_slime) and Splitlets, cloned in bulk; the octopus / tentacle / jelly aliens of
## the earlier worlds are the lab's experiments; the world-5 hatchlings, eye blobs and
## comet babies are out. The vats (SpecimenVat) breed more on their own.
const GENE_START := ["mini_slime", "mini_slime", "mini_slime", "splitlet", "splitlet", "jelly_pod", "octo_wizard"]
const GENE_MID := ["mini_slime", "mini_slime", "splitlet", "splitlet", "splitter", "jelly_pod", "octo_wizard", "tentacle_pod", "tentacle_plant", "bubble_brain", "plasma_pupil"]
const GENE := ["mini_slime", "mini_slime", "mini_slime", "splitlet", "splitlet", "splitter", "jelly_pod", "octo_wizard", "tentacle_pod", "tentacle_plant", "bubble_brain", "plasma_pupil", "tentacle_orbiter", "eyeclops", "jelly_saucer", "goo_lantern", "bell_cruiser", "pearl_flyer"]
const GENE_SHOOTERS := ["jelly_pod", "octo_wizard", "tentacle_pod", "bubble_brain", "plasma_pupil", "tentacle_orbiter", "jelly_saucer", "bell_cruiser"]
## world 7 (WARP NEXUS): its 4 new drones (laser_drone, spider_bot, gravity_sentinel,
## saw_drone) with the world-4 machines; the cloned slimelets / splitlets / jelly pods of
## world 6 are out
const WARP_START := ["saw_drone", "saw_drone", "spider_bot", "spider_bot", "laser_drone", "scout", "blade_drone"]
const WARP_MID := ["saw_drone", "saw_drone", "spider_bot", "spider_bot", "laser_drone", "laser_drone", "gravity_sentinel", "scout", "blade_drone", "tesla_drone", "martian_scout", "comet_hopper"]
const WARP := ["saw_drone", "saw_drone", "spider_bot", "spider_bot", "laser_drone", "laser_drone", "gravity_sentinel", "gravity_sentinel", "scout", "blade_drone", "tesla_drone", "martian_scout", "comet_hopper", "crab_drone", "prism_drone", "gunship", "ring_eye", "blink_saucer", "nugget_ship"]
const WARP_SHOOTERS := ["laser_drone", "spider_bot", "gravity_sentinel", "tesla_drone", "prism_drone", "ring_eye", "nugget_ship"]
## world 8 (BIODOME): its 4 new aliens (bio_droid, spike_bloom, vine_crawler, spore_drone)
## with the flower pods of its boss and some world-7 drones; the gravity sentinels, laser
## drones and martian scouts of world 7 are out
const BIO_START := ["vine_crawler", "vine_crawler", "bio_droid", "bio_droid", "spike_bloom", "bloom_sprout", "saw_drone"]
const BIO_MID := ["vine_crawler", "vine_crawler", "bio_droid", "bio_droid", "spike_bloom", "spore_drone", "bloom_sprout", "bloom_sprout", "saw_drone", "spider_bot", "blade_drone", "comet_hopper"]
const BIO := ["vine_crawler", "vine_crawler", "bio_droid", "bio_droid", "spike_bloom", "spike_bloom", "spore_drone", "spore_drone", "bloom_sprout", "bloom_sprout", "saw_drone", "spider_bot", "blade_drone", "comet_hopper", "tesla_drone", "goo_lantern", "jelly_pod", "tentacle_plant"]
const BIO_SHOOTERS := ["bio_droid", "spike_bloom", "spore_drone", "spider_bot", "tesla_drone", "jelly_pod"]
const HIVE_ROOMS := ["hive_entry", "nest", "biolab", "sludge", "overgrown_cargo", "spires", "pods", "reactor_core"]

const WORLDS := [
	{
		"music": "levels.mp3", "name": "INFESTED SPACESHIP", "theme": "ship", "enemy_mult": 1.0, "difficulty": [1.0, 0.08],
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
					{"pool": ["slime", "runner", "splitter", "spitter", "droid", "ufo", "alien_trooper"], "alive": 48, "total": 110, "elite": 0.04, "event": "swarm", "id": "runner", "count": 28, "events": [
						{"at": 12.0, "event": "boss", "id": "blobulus", "label": "BLOBULUS!"}]},
					{"pool": ALL_BR, "alive": 52, "total": 120, "elite": 0.04, "event": "ring", "id": "slime", "count": 26, "events": [
						{"at": 18.0, "event": "crossfire", "id": "alien_trooper", "count": 5, "label": "TROOPER SQUAD!"}]},
					{"pool": ALL_BR, "alive": 56, "total": 300, "elite": 0.05, "invasion": 180},
					{"pool": ALL_BR, "alive": 36, "total": 90, "elite": 0.05, "event": "boss", "id": "gloop_brute", "count": 2},
					{"pool": ALL_BR, "alive": 64, "total": 140, "elite": 0.06, "event": "swarm", "id": "slime", "count": 24},
					{"pool": ALL_BR, "alive": 70, "total": 150, "elite": 0.07, "event": "ring", "id": "runner", "count": 36, "events": [
						{"at": 16.0, "event": "crossfire", "id": "saucer_pilot", "count": 4, "label": "SAUCER SQUADRON!"}]},
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
		"music": "levels2.mp3", "name": "THE HIVE", "theme": "hive", "enemy_mult": 1.15, "difficulty": [1.0, 0.0],
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
					{"pool": HIVE, "alive": 46, "rate": 4.0, "elite": 0.05, "event": "swarm", "id": "ufo_alien", "count": 30, "events": [
						{"at": 16.0, "event": "crossfire", "id": "jelly_saucer", "count": 4, "label": "JELLY FLEET!"}]},
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
		"music": "levels3.mp3", "name": "THE VOID", "theme": "void", "enemy_mult": 1.3, "difficulty": [1.0, 0.0],
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
		"music": "Sub UFO.mp3", "boss_music": "Sub UFO 2.mp3", "name": "ORBITAL DECK", "theme": "space", "enemy_mult": 1.45, "difficulty": [1.0, 0.0],
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
					{"pool": SPACE, "alive": 36, "rate": 3.4, "elite": 0.06, "event": "boss", "id": "brood_mother", "count": 2, "events": [
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
	{
		# world 5: THE FORGE, a reactor plant glowing with lava, played as an EXPLORE map
		# built wall by wall from the forge kit (ForgeMap: halls, corridors, mazes, pillared
		# halls, lava pits, machinery in the corners; kit "w5" in the middle of the halls).
		# Besides chests and crew to rescue, 4 rooms hold an overheating REACTOR CORE: it
		# sends out heat waves while you are near (they burn the aliens too) and venting it
		# on its coolant pad heals you; vent all 4 and every boss arrives with 25% less
		# health. New aliens: Orbit Hatchling, Orbit Raider, Eye Blob Saucer (ricochet
		# laser); mini bosses ORBIT WARDEN and THE SLIME KING; final boss MAGMA DRAKE.
		"music": "levels2.mp3", "name": "THE FORGE", "theme": "forge", "enemy_mult": 1.6, "difficulty": [1.0, 0.0],
		"pic": "world_5.png", "chest": 1500,
		"rooms": [
			{"final": true, "survival": {
				"arena": Vector2i(64, 96), "duration": 450.0, "hp_per_min": 0.25,
				"explore": {"build": "forge", "cells": [18, 14], "chests": 8, "alarms": true,
					"maze": 0.35, "interior": "w5", "cores": 4},
				"t_offset": 240.0, "boss": "magma_drake",
				"boss_help": {"pool": ["orbit_spawn", "orbit_spawn", "comet_baby", "orbit_raider"], "max": 8, "every": [15.0, 7.0], "squad": 3},
				"final": {"pool": FORGE, "alive": 34, "rate": 3.0},
				"waves": [
					# 1-4: the hatchlings swarm out of the vents, the new saucers join one by one
					{"pool": FORGE_START, "alive": 20, "rate": 2.4, "shooters": 0.25, "events": [
						{"at": 12.0, "event": "breach", "id": "orbit_spawn", "count": 12, "points": 3, "label": "VENT BURST!"}]},
					{"pool": FORGE_START, "alive": 24, "rate": 2.7, "shooters": 0.3, "events": [
						{"at": 6.0, "event": "crossfire", "id": "eye_blob", "count": 3, "label": "RICOCHET!"},
						{"at": 18.0, "event": "swarm", "id": "orbit_spawn", "count": 14}]},
					{"pool": FORGE_MID, "alive": 28, "rate": 3.0, "elite": 0.03, "events": [
						{"at": 0.0, "event": "escort", "id": "orbit_raider", "minion": "orbit_spawn", "count": 6, "label": "RAIDER PACK!"},
						{"at": 16.0, "event": "meteor", "pool": ["orbit_spawn", "comet_baby"], "count": 8, "hatch": 0.4, "label": "LAVA RAIN!"}]},
					{"pool": FORGE_MID, "alive": 32, "rate": 3.2, "elite": 0.04, "event": "pincer", "id": "comet_baby", "count": 16, "events": [
						{"at": 15.0, "event": "breach", "pool": ["orbit_spawn", "goo_hopper"], "count": 16, "points": 4, "label": "VENT BURST!"}]},
					# 5: invasion
					{"pool": FORGE_MID, "alive": 38, "rate": 3.4, "elite": 0.04, "invasion": 120, "events": [
						{"at": 18.0, "event": "crossfire", "pool": FORGE_SHOOTERS, "count": 5}]},
					# 6: first mini boss
					{"pool": FORGE_MID, "alive": 26, "rate": 2.6, "elite": 0.04, "events": [
						{"at": 6.0, "event": "boss", "id": "orbit_warden", "label": "ORBIT WARDEN!"},
						{"at": 20.0, "event": "swarm", "id": "orbit_spawn", "count": 10}]},
					# 7-10: two events a wave
					{"pool": FORGE, "alive": 42, "rate": 3.8, "elite": 0.05, "events": [
						{"at": 0.0, "event": "spiral", "id": "orbit_spawn", "count": 24},
						{"at": 15.0, "event": "crossfire", "id": "eye_blob", "count": 5, "label": "RICOCHET!"}]},
					{"pool": FORGE, "alive": 46, "rate": 4.0, "elite": 0.05, "events": [
						{"at": 0.0, "event": "meteor", "pool": FORGE_MID, "count": 14, "hatch": 0.35, "label": "LAVA RAIN!"},
						{"at": 15.0, "event": "escort", "id": "big_red", "minion": "comet_baby", "count": 8, "label": "MOLTEN SQUAD!"}]},
					{"pool": FORGE, "alive": 50, "rate": 4.2, "elite": 0.06, "event": "pincer", "id": "orbit_raider", "count": 8, "events": [
						{"at": 14.0, "event": "breach", "pool": ["orbit_spawn", "goo_hopper", "comet_baby"], "count": 24, "points": 4, "label": "VENT BURST!"}]},
					{"pool": FORGE, "alive": 54, "rate": 4.4, "elite": 0.06, "invasion": 180, "events": [
						{"at": 18.0, "event": "spiral", "id": "spike_mine", "count": 8, "label": "MINEFIELD!"}]},
					# 11: second mini boss
					{"pool": FORGE, "alive": 34, "rate": 3.2, "elite": 0.06, "events": [
						{"at": 4.0, "event": "boss", "id": "slime_king", "label": "THE SLIME KING!"},
						{"at": 18.0, "event": "crossfire", "pool": FORGE_SHOOTERS, "count": 6}]},
					# 12-15: the forge melts down
					{"pool": FORGE, "alive": 62, "rate": 4.8, "elite": 0.07, "events": [
						{"at": 0.0, "event": "escort", "id": "goo_lantern", "minion": "orbit_raider", "count": 4, "label": "FIELD MEDIC!"},
						{"at": 12.0, "event": "meteor", "pool": FORGE_MID, "count": 18, "hatch": 0.35, "label": "LAVA RAIN!"},
						{"at": 22.0, "event": "swarm", "id": "comet_baby", "count": 14}]},
					{"pool": FORGE, "alive": 68, "rate": 5.0, "elite": 0.08, "events": [
						{"at": 0.0, "event": "crossfire", "id": "eye_blob", "count": 6, "label": "RICOCHET!"},
						{"at": 14.0, "event": "breach", "pool": FORGE_MID, "count": 30, "points": 5, "label": "MELTDOWN!"}]},
					{"pool": FORGE, "alive": 74, "rate": 5.3, "elite": 0.09, "events": [
						{"at": 0.0, "event": "escort", "id": "big_red", "minion": "big_red", "count": 3, "label": "BRUTE SQUAD!"},
						{"at": 10.0, "event": "spiral", "pool": ["orbit_spawn", "comet_baby"], "count": 32},
						{"at": 21.0, "event": "pincer", "id": "orbit_raider", "count": 8}]},
					{"pool": FORGE, "alive": 80, "rate": 5.6, "elite": 0.1, "invasion": 230, "events": [
						{"at": 16.0, "event": "meteor", "pool": FORGE_MID, "count": 22, "hatch": 0.3, "label": "LAVA RAIN!"}]},
				],
			}},
		],
	},
	{
		# world 6: GENE VAULT, the cloning lab where the mothership grows its specimens:
		# an EXPLORE map built wall by wall from the bio-lab kit (ForgeMap set "w6": halls,
		# corridors, mazes, pillared halls, goo pits, cloning machinery in the corners).
		# Besides chests and crew to rescue, 5 halls hold a SPECIMEN VAT that keeps breeding
		# specimens while you are near (egg clusters around the map hatch octolings as you
		# pass by): shoot them all down to purge the vault (coins, and
		# the final boss fights with no reinforcements). New in the waves: Slimelets and
		# Splitlets cloned in bulk; mini bosses BLOBULUS and TOXIC ANGLER; final boss THE
		# MOTHERSHIP (its first appearance).
		"music": "levels3.mp3", "name": "GENE VAULT", "theme": "gene", "enemy_mult": 1.7, "difficulty": [1.0, 0.0],
		"pic": "world_6.png", "chest": 1800,
		"rooms": [
			{"final": true, "survival": {
				"arena": Vector2i(64, 96), "duration": 450.0, "hp_per_min": 0.25,
				"explore": {"build": "kit", "set": "w6", "cells": [18, 14], "chests": 8, "alarms": true,
					"maze": 0.4, "mazes": 3, "vats": 5, "eggs": 14},
				"t_offset": 270.0, "boss": "mothership",
				"boss_help": {"pool": ["mini_slime", "mini_slime", "splitlet", "jelly_pod"], "max": 8, "every": [15.0, 7.0], "squad": 3},
				"final": {"pool": GENE, "alive": 34, "rate": 3.0},
				"waves": [
					# 1-4: clones pour out of the lab, the experiments join one by one
					{"pool": GENE_START, "alive": 22, "rate": 2.6, "shooters": 0.2, "events": [
						{"at": 12.0, "event": "breach", "id": "mini_slime", "count": 14, "points": 3, "label": "VAT LEAK!"}]},
					{"pool": GENE_START, "alive": 26, "rate": 2.8, "shooters": 0.25, "events": [
						{"at": 6.0, "event": "escort", "id": "octo_wizard", "minion": "mini_slime", "count": 6, "label": "LAB COAT!"},
						{"at": 18.0, "event": "swarm", "id": "splitlet", "count": 16}]},
					{"pool": GENE_MID, "alive": 30, "rate": 3.0, "elite": 0.03, "events": [
						{"at": 0.0, "event": "ring", "id": "mini_slime", "count": 18, "label": "CLONE RING!"},
						{"at": 16.0, "event": "crossfire", "id": "jelly_pod", "count": 4, "label": "JELLY BLOOM!"}]},
					{"pool": GENE_MID, "alive": 34, "rate": 3.2, "elite": 0.04, "event": "pincer", "id": "splitlet", "count": 18, "events": [
						{"at": 15.0, "event": "breach", "pool": ["mini_slime", "splitlet", "splitter"], "count": 18, "points": 4, "label": "VAT LEAK!"}]},
					# 5: invasion
					{"pool": GENE_MID, "alive": 40, "rate": 3.4, "elite": 0.04, "invasion": 120, "events": [
						{"at": 18.0, "event": "crossfire", "pool": GENE_SHOOTERS, "count": 5}]},
					# 6: first mini boss
					{"pool": GENE_MID, "alive": 26, "rate": 2.6, "elite": 0.04, "events": [
						{"at": 6.0, "event": "boss", "id": "blobulus", "label": "BLOBULUS!"},
						{"at": 22.0, "event": "swarm", "id": "mini_slime", "count": 12}]},
					# 7-10: two events a wave
					{"pool": GENE, "alive": 44, "rate": 3.8, "elite": 0.05, "events": [
						{"at": 0.0, "event": "spiral", "id": "splitlet", "count": 26},
						{"at": 15.0, "event": "escort", "id": "tentacle_orbiter", "minion": "mini_slime", "count": 8, "label": "GRAVITY TEST!"}]},
					{"pool": GENE, "alive": 48, "rate": 4.0, "elite": 0.05, "events": [
						{"at": 0.0, "event": "crossfire", "id": "plasma_pupil", "count": 5, "label": "EYES EVERYWHERE!"},
						{"at": 15.0, "event": "escort", "id": "goo_lantern", "minion": "splitter", "count": 5, "label": "FIELD MEDIC!"}]},
					{"pool": GENE, "alive": 52, "rate": 4.2, "elite": 0.06, "event": "pincer", "id": "tentacle_pod", "count": 8, "events": [
						{"at": 14.0, "event": "breach", "pool": ["mini_slime", "splitlet", "jelly_pod"], "count": 26, "points": 4, "label": "VAT LEAK!"}]},
					{"pool": GENE, "alive": 56, "rate": 4.4, "elite": 0.06, "invasion": 180, "events": [
						{"at": 18.0, "event": "ring", "id": "jelly_saucer", "count": 6, "label": "JELLY FLEET!"}]},
					# 11: second mini boss
					{"pool": GENE, "alive": 34, "rate": 3.2, "elite": 0.06, "events": [
						{"at": 4.0, "event": "boss", "id": "toxic_angler", "label": "TOXIC ANGLER!"},
						{"at": 18.0, "event": "crossfire", "pool": GENE_SHOOTERS, "count": 6}]},
					# 12-15: containment breach
					{"pool": GENE, "alive": 64, "rate": 4.8, "elite": 0.07, "events": [
						{"at": 0.0, "event": "escort", "id": "eyeclops", "minion": "splitlet", "count": 8},
						{"at": 12.0, "event": "spiral", "pool": ["mini_slime", "splitlet"], "count": 30},
						{"at": 22.0, "event": "swarm", "id": "mini_slime", "count": 16}]},
					{"pool": GENE, "alive": 70, "rate": 5.0, "elite": 0.08, "events": [
						{"at": 0.0, "event": "crossfire", "id": "bell_cruiser", "count": 5},
						{"at": 14.0, "event": "breach", "pool": GENE_MID, "count": 32, "points": 5, "label": "CONTAINMENT BREACH!"}]},
					{"pool": GENE, "alive": 76, "rate": 5.3, "elite": 0.09, "events": [
						{"at": 0.0, "event": "escort", "id": "pearl_flyer", "minion": "tentacle_pod", "count": 4, "label": "BUBBLE FLEET!"},
						{"at": 10.0, "event": "ring", "pool": ["mini_slime", "splitlet"], "count": 28},
						{"at": 21.0, "event": "pincer", "id": "octo_wizard", "count": 8}]},
					{"pool": GENE, "alive": 82, "rate": 5.6, "elite": 0.1, "invasion": 230, "events": [
						{"at": 16.0, "event": "breach", "pool": GENE_MID, "count": 26, "points": 5, "label": "CONTAINMENT BREACH!"}]},
				],
			}},
		],
	},
	{
		# world 7: WARP NEXUS, the station that holds the warp gate: an EXPLORE map built wall
		# by wall from its kit (ForgeMap set "w7": halls, corridors, mazes, pillared halls,
		# holes into open space, warp machinery in the corners). Besides chests and crew, 5
		# WARP CELLS hide in the far corners of the map: each one taken sets off a WARP
		# AMBUSH; with all 5 the gate is charged and the final boss comes weaker and cannot
		# warp. New aliens: Orbital Laser Drone (sweeping laser), Quantum Spider Bot (swaps
		# with its anchor), Gravity Core Sentinel (clumps the horde and flings it), Plasma
		# Saw Drone (pincer saws); mini bosses CLAWDOZER and ORBIT WARDEN; final boss WARP
		# OVERSEER.
		"music": "Sub UFO.mp3", "boss_music": "Sub UFO 2.mp3", "name": "WARP NEXUS", "theme": "warp", "enemy_mult": 1.8, "difficulty": [1.0, 0.0],
		"pic": "world_7.png", "chest": 2100,
		"rooms": [
			{"final": true, "survival": {
				"arena": Vector2i(64, 96), "duration": 450.0, "hp_per_min": 0.25,
				"explore": {"build": "kit", "set": "w7", "cells": [18, 14], "chests": 8, "alarms": true,
					"maze": 0.4, "mazes": 3, "warp_cells": 5},
				"t_offset": 300.0, "boss": "overseer",
				"boss_help": {"pool": ["saw_drone", "spider_bot", "laser_drone"], "max": 8, "every": [15.0, 7.0], "squad": 3},
				"final": {"pool": WARP, "alive": 34, "rate": 3.0},
				"waves": [
					# 1-4: the drones come online one by one
					{"pool": WARP_START, "alive": 22, "rate": 2.6, "shooters": 0.25, "events": [
						{"at": 12.0, "event": "swarm", "id": "saw_drone", "count": 10, "label": "SAW SWARM!"}]},
					{"pool": WARP_START, "alive": 26, "rate": 2.8, "shooters": 0.3, "events": [
						{"at": 6.0, "event": "crossfire", "id": "laser_drone", "count": 3, "label": "LASER GRID!"},
						{"at": 18.0, "event": "pincer", "id": "spider_bot", "count": 12}]},
					{"pool": WARP_MID, "alive": 30, "rate": 3.0, "elite": 0.03, "events": [
						{"at": 0.0, "event": "escort", "id": "gravity_sentinel", "minion": "saw_drone", "count": 8, "label": "GRAVITY WELL!"},
						{"at": 16.0, "event": "breach", "pool": ["spider_bot", "saw_drone"], "count": 14, "points": 3, "label": "WARP BREACH!"}]},
					{"pool": WARP_MID, "alive": 34, "rate": 3.2, "elite": 0.04, "event": "ring", "id": "saw_drone", "count": 14, "events": [
						{"at": 15.0, "event": "crossfire", "pool": WARP_SHOOTERS, "count": 5}]},
					# 5: invasion
					{"pool": WARP_MID, "alive": 40, "rate": 3.4, "elite": 0.04, "invasion": 120, "events": [
						{"at": 18.0, "event": "spiral", "id": "spider_bot", "count": 20, "label": "QUANTUM SWARM!"}]},
					# 6: first mini boss
					{"pool": WARP_MID, "alive": 26, "rate": 2.6, "elite": 0.04, "events": [
						{"at": 4.0, "event": "boss", "id": "clawdozer", "label": "CLAWDOZER!"},
						{"at": 22.0, "event": "swarm", "id": "saw_drone", "count": 12}]},
					# 7-10: two events a wave
					{"pool": WARP, "alive": 44, "rate": 3.8, "elite": 0.05, "events": [
						{"at": 0.0, "event": "escort", "id": "gravity_sentinel", "minion": "spider_bot", "count": 8, "label": "GRAVITY WELL!"},
						{"at": 15.0, "event": "crossfire", "id": "laser_drone", "count": 5, "label": "LASER GRID!"}]},
					{"pool": WARP, "alive": 48, "rate": 4.0, "elite": 0.05, "events": [
						{"at": 0.0, "event": "dropship", "pool": WARP_MID, "count": 8},
						{"at": 15.0, "event": "breach", "pool": ["saw_drone", "spider_bot", "laser_drone"], "count": 22, "points": 4, "label": "WARP BREACH!"}]},
					{"pool": WARP, "alive": 52, "rate": 4.2, "elite": 0.06, "event": "pincer", "id": "saw_drone", "count": 14, "events": [
						{"at": 14.0, "event": "escort", "id": "crab_drone", "minion": "blade_drone", "count": 6, "label": "DRONE SWARM!"}]},
					{"pool": WARP, "alive": 56, "rate": 4.4, "elite": 0.06, "invasion": 180, "events": [
						{"at": 18.0, "event": "ring", "id": "laser_drone", "count": 6, "label": "LASER RING!"}]},
					# 11: second mini boss
					{"pool": WARP, "alive": 34, "rate": 3.2, "elite": 0.06, "events": [
						{"at": 4.0, "event": "boss", "id": "orbit_warden", "label": "ORBIT WARDEN!"},
						{"at": 18.0, "event": "crossfire", "pool": WARP_SHOOTERS, "count": 6}]},
					# 12-15: the gate overloads
					{"pool": WARP, "alive": 64, "rate": 4.8, "elite": 0.07, "events": [
						{"at": 0.0, "event": "escort", "id": "gravity_sentinel", "minion": "gravity_sentinel", "count": 2, "label": "SINGULARITY!"},
						{"at": 12.0, "event": "spiral", "pool": ["saw_drone", "spider_bot"], "count": 30},
						{"at": 22.0, "event": "swarm", "id": "spider_bot", "count": 14}]},
					{"pool": WARP, "alive": 70, "rate": 5.0, "elite": 0.08, "events": [
						{"at": 0.0, "event": "crossfire", "id": "laser_drone", "count": 6, "label": "LASER GRID!"},
						{"at": 14.0, "event": "breach", "pool": WARP_MID, "count": 32, "points": 5, "label": "GATE OVERLOAD!"}]},
					{"pool": WARP, "alive": 76, "rate": 5.3, "elite": 0.09, "events": [
						{"at": 0.0, "event": "dropship", "pool": WARP, "count": 10},
						{"at": 10.0, "event": "ring", "pool": ["saw_drone", "spider_bot"], "count": 28},
						{"at": 21.0, "event": "pincer", "id": "laser_drone", "count": 8}]},
					{"pool": WARP, "alive": 82, "rate": 5.6, "elite": 0.1, "invasion": 230, "events": [
						{"at": 16.0, "event": "breach", "pool": WARP_MID, "count": 26, "points": 5, "label": "GATE OVERLOAD!"}]},
				],
			}},
		],
	},
	{
		# world 8: BIODOME, the greenhouse station on an asteroid: an EXPLORE map built wall by
		# wall from its kit (ForgeMap set "w8": white walls with blue lights and greenery,
		# loose floor tiles, 10 greenhouse corner blocks). Objective: DEFEND the 5 SEED TANKS
		# (aliens nearby march on them and gnaw at them); every tank still standing when the
		# final fight starts heals you. Final boss BLOOM COLOSSUS. PROVISIONAL: the world-7
		# aliens until its own enemies arrive.
		"music": "levels2.mp3", "name": "BIODOME", "theme": "bio", "enemy_mult": 1.9, "difficulty": [1.0, 0.0],
		"pic": "world_8.png", "chest": 2400,
		"rooms": [
			{"final": true, "survival": {
				"arena": Vector2i(64, 96), "duration": 450.0, "hp_per_min": 0.25,
				"explore": {"build": "kit", "set": "w8", "cells": [18, 14], "chests": 8, "alarms": true,
					"maze": 0.4, "mazes": 3, "tanks": 5},
				"t_offset": 330.0, "boss": "bloom_colossus",
				"boss_help": {"pool": ["bloom_sprout", "bloom_sprout", "bio_droid"], "max": 8, "every": [15.0, 7.0], "squad": 3},
				"final": {"pool": BIO, "alive": 34, "rate": 3.0},
				"waves": [
					# 1-4: the drones come online one by one
					{"pool": BIO_START, "alive": 22, "rate": 2.6, "shooters": 0.25, "events": [
						{"at": 12.0, "event": "swarm", "id": "vine_crawler", "count": 10, "label": "VINE SWARM!"}]},
					{"pool": BIO_START, "alive": 26, "rate": 2.8, "shooters": 0.3, "events": [
						{"at": 6.0, "event": "crossfire", "id": "spore_drone", "count": 3, "label": "SPORE STORM!"},
						{"at": 18.0, "event": "pincer", "id": "bio_droid", "count": 12}]},
					{"pool": BIO_MID, "alive": 30, "rate": 3.0, "elite": 0.03, "events": [
						{"at": 0.0, "event": "escort", "id": "spike_bloom", "minion": "vine_crawler", "count": 8, "label": "THORN GARDEN!"},
						{"at": 16.0, "event": "breach", "pool": ["bio_droid", "vine_crawler"], "count": 14, "points": 3, "label": "ROOT BREACH!"}]},
					{"pool": BIO_MID, "alive": 34, "rate": 3.2, "elite": 0.04, "event": "ring", "id": "vine_crawler", "count": 14, "events": [
						{"at": 15.0, "event": "crossfire", "pool": BIO_SHOOTERS, "count": 5}]},
					# 5: invasion
					{"pool": BIO_MID, "alive": 40, "rate": 3.4, "elite": 0.04, "invasion": 120, "events": [
						{"at": 18.0, "event": "spiral", "id": "bio_droid", "count": 20, "label": "ROGUE GARDENERS!"}]},
					# 6: first mini boss
					{"pool": BIO_MID, "alive": 26, "rate": 2.6, "elite": 0.04, "events": [
						{"at": 4.0, "event": "boss", "id": "clawdozer", "label": "CLAWDOZER!"},
						{"at": 22.0, "event": "swarm", "id": "vine_crawler", "count": 12}]},
					# 7-10: two events a wave
					{"pool": BIO, "alive": 44, "rate": 3.8, "elite": 0.05, "events": [
						{"at": 0.0, "event": "escort", "id": "spike_bloom", "minion": "bio_droid", "count": 8, "label": "THORN GARDEN!"},
						{"at": 15.0, "event": "crossfire", "id": "spore_drone", "count": 5, "label": "SPORE STORM!"}]},
					{"pool": BIO, "alive": 48, "rate": 4.0, "elite": 0.05, "events": [
						{"at": 0.0, "event": "dropship", "pool": BIO_MID, "count": 8},
						{"at": 15.0, "event": "breach", "pool": ["vine_crawler", "bio_droid", "spore_drone"], "count": 22, "points": 4, "label": "ROOT BREACH!"}]},
					{"pool": BIO, "alive": 52, "rate": 4.2, "elite": 0.06, "event": "pincer", "id": "vine_crawler", "count": 14, "events": [
						{"at": 14.0, "event": "escort", "id": "crab_drone", "minion": "blade_drone", "count": 6, "label": "WEED SWARM!"}]},
					{"pool": BIO, "alive": 56, "rate": 4.4, "elite": 0.06, "invasion": 180, "events": [
						{"at": 18.0, "event": "ring", "id": "spore_drone", "count": 6, "label": "SPORE RING!"}]},
					# 11: second mini boss
					{"pool": BIO, "alive": 34, "rate": 3.2, "elite": 0.06, "events": [
						{"at": 4.0, "event": "boss", "id": "orbit_warden", "label": "ORBIT WARDEN!"},
						{"at": 18.0, "event": "crossfire", "pool": BIO_SHOOTERS, "count": 6}]},
					# 12-15: the gate overloads
					{"pool": BIO, "alive": 64, "rate": 4.8, "elite": 0.07, "events": [
						{"at": 0.0, "event": "escort", "id": "spike_bloom", "minion": "spike_bloom", "count": 2, "label": "OVERGROWTH!"},
						{"at": 12.0, "event": "spiral", "pool": ["vine_crawler", "bio_droid"], "count": 30},
						{"at": 22.0, "event": "swarm", "id": "bio_droid", "count": 14}]},
					{"pool": BIO, "alive": 70, "rate": 5.0, "elite": 0.08, "events": [
						{"at": 0.0, "event": "crossfire", "id": "spore_drone", "count": 6, "label": "SPORE STORM!"},
						{"at": 14.0, "event": "breach", "pool": BIO_MID, "count": 32, "points": 5, "label": "DOME BREACH!"}]},
					{"pool": BIO, "alive": 76, "rate": 5.3, "elite": 0.09, "events": [
						{"at": 0.0, "event": "dropship", "pool": BIO, "count": 10},
						{"at": 10.0, "event": "ring", "pool": ["vine_crawler", "bio_droid"], "count": 28},
						{"at": 21.0, "event": "pincer", "id": "spore_drone", "count": 8}]},
					{"pool": BIO, "alive": 82, "rate": 5.6, "elite": 0.1, "invasion": 230, "events": [
						{"at": 16.0, "event": "breach", "pool": BIO_MID, "count": 26, "points": 5, "label": "DOME BREACH!"}]},
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
