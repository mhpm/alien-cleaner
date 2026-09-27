class_name WorldData
extends RefCounted
## World -> Rooms -> Waves. Rooms are 10x14 tile layouts (see Room for the legend).
## Legend: . floor  v vent  # crate (## big crate)  T crystal planter  c canister
##         B explosive barrel  t toxic slime  z electric floor
## Wave: {"fixed": {type: count}} and/or {"budget": n, "pool": [types]} (random by enemy cost).

const LAYOUTS := {
	"tutorial": [
		"..........", "..........", "..v....v..", "..........", "..........",
		"..........", "..........", "..........", "....vv....", "..........",
		"..........", "..........", "..........", "..........",
	],
	"open": [
		"..........", "..........", ".T......T.", "..........", "..........",
		"..........", "....vv....", "..........", "..........", "..........",
		"..v....v..", "..........", "..........", "..........",
	],
	"crates": [
		"..........", "..........", ".##....##.", "...B..B...", "..........",
		"..........", "..##..##..", "..........", "....B.....", "..........",
		"..........", "..........", "..........", "..........",
	],
	"toxic": [
		"..........", "..........", "..t....t..", "..t....t..", "..........",
		"....##....", "..........", "tt......tt", "..........", "..c....c..",
		"..........", "..........", "..........", "..........",
	],
	"arena": [
		"..........", ".B......B.", "..........", "..........", "....vv....",
		"..........", "..........", "..........", "..........", "..........",
		".B......B.", "..........", "..........", "..........",
	],
	"pillars": [
		"..........", "..........", ".##....##.", "..........", "..........",
		"..T....T..", "..........", "..........", "..##..##..", "..........",
		"..........", ".c......c.", "..........", "..........",
	],
	"cross": [
		"..........", "..........", "....##....", "....B.....", "..........",
		"t........t", "tt.#..#.tt", "t........t", "..........", "....##....",
		"..........", "..........", "..........", "..........",
	],
	"zap": [
		"..........", "..........", ".zz....zz.", "..........", "...#..#...",
		"..........", "zz......zz", "..........", "...B..B...", "..........",
		"..zz..zz..", "..........", "..........", "..........",
	],
	"barrels": [
		"..........", "..B....B..", "..........", ".##.B..##.", "..........",
		"..........", "B........B", "..........", "...#..#...", "..........",
		"..c....c..", "..........", "..........", "..........",
	],
	"throne": [
		"..........", "..........", "..........", "..........", "v........v",
		"..........", "..........", "..........", "..........", "..........",
		"v........v", "..........", "..........", "..........",
	],
}

const ALL := ["slime", "runner", "spitter"]

const WORLDS := [
	{
		"name": "INFESTED SPACESHIP",
		"rooms": [
			# 1: tutorial - two slimes, learn to move & auto-clean
			{"layouts": ["tutorial"], "waves": [{"fixed": {"slime": 2}}]},
			# 2: meet the runner
			{"layouts": ["open"], "waves": [{"fixed": {"slime": 2, "runner": 1}}]},
			# 3: first obstacles: crates + explosive barrels
			{"layouts": ["crates"], "waves": [{"fixed": {"slime": 3, "runner": 1}}]},
			# 4: bigger wave, meet the spitter, toxic slime; upgrade afterwards
			{"layouts": ["toxic"], "waves": [{"fixed": {"slime": 2, "spitter": 1}}, {"budget": 4, "pool": ["slime", "runner"]}], "upgrade": true},
			# 5: mini boss
			{"layouts": ["arena"], "boss": "gloop_brute", "upgrade": true},
			# 6-9: random encounters from the full pool
			{"layouts": ["pillars", "cross", "barrels"], "waves": [{"budget": 6, "pool": ALL}]},
			{"layouts": ["zap", "cross", "toxic"], "waves": [{"budget": 5, "pool": ALL}, {"budget": 5, "pool": ALL}], "upgrade": true},
			{"layouts": ["barrels", "pillars", "zap"], "waves": [{"budget": 7, "pool": ALL}, {"budget": 6, "pool": ALL}]},
			{"layouts": ["zap", "cross", "crates"], "waves": [{"budget": 8, "pool": ALL}, {"budget": 8, "pool": ALL}], "upgrade": true},
			# 10: final boss
			{"layouts": ["throne"], "boss": "slime_king", "final": true},
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
