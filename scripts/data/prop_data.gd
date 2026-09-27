class_name PropData
extends RefCounted
## Room props from the environment sprite folders:
##   "a:NNN" = assets/sprites/enviroment/enviroment_elements/enviroment_NNN.png
##   "b:NNN" = assets/sprites/enviroment/enviroment_elements2/enviroment_NNN.png
##   "c:NNN" = assets/sprites/enviroment/world2/enviroment2_NNN.png (world 2, theme "hive")
## Each layout character maps to a prop; `tex` lists interchangeable variants (the
## room picks one per cell, stable for that layout) so rooms look varied but tidy.
##   width   sprite width in world units (1 tile = 16)
##   box     collision box at the feet
##   bullets false = bullets fly through (fences); bodies are still blocked
##   glow    soft light under the prop (optional)
##   kind    "" static | "spark" sparks when shot | "toxic" / "cryo" destructible tank
##           | "medkit" shoot it open for a heart (once)
##           | "egg" hatches Greenies when the player gets close during a fight
##           | "loot" supply crate: breaks open into coins (and maybe a heart)
##           | "turret" wakes up when the player stands next to it mid-fight and
##             fires at the aliens for a while, then recharges
##   hp      hits a destructible prop takes

const DIRS := {
	"a": "res://assets/sprites/enviroment/enviroment_elements/enviroment_%s.png",
	"b": "res://assets/sprites/enviroment/enviroment_elements2/enviroment_%s.png",
	"c": "res://assets/sprites/enviroment/world2/enviroment2_%s.png",
}
## Collision layer of props that stop bodies but not bullets (player/alien masks include it).
const LAYER_BODIES_ONLY := 8

const PROPS := {
	# '#' metal crate (## = big crate)
	"crate": {"tex": ["a:116", "a:117", "b:028", "a:120", "b:025", "b:030", "b:057", "b:058", "b:029"],
		"width": 16.0, "box": Vector2(15, 11)},
	"crate_big": {"tex": ["a:112", "b:036", "b:026", "b:037"], "width": 31.0, "box": Vector2(30, 12)},
	# 'c' drum / canister (inert)
	"canister": {"tex": ["b:039", "b:040", "b:129", "a:101", "b:041", "b:131", "a:122", "b:042"],
		"width": 10.0, "box": Vector2(9, 7)},
	# 'T' alien crystals: wild clusters and hydroponic crystal planters
	"crystal": {"tex": ["b:071", "a:159", "b:072", "a:158", "b:073", "a:106", "b:074", "a:163"],
		"width": 17.0, "box": Vector2(13, 8), "glow": Color(0.45, 0.55, 1.0, 0.35)},
	# 'M' glowing alien mushroom
	"mushroom": {"tex": ["a:157", "a:162"], "width": 16.0, "box": Vector2(9, 7),
		"glow": Color(1.0, 0.35, 0.85, 0.35)},
	# 'r' space rock / rubble
	"rock": {"tex": ["a:060", "b:108", "a:019", "b:110", "a:063", "b:093", "a:164", "a:165"],
		"width": 17.0, "box": Vector2(15, 9)},
	# 'C' computer console (sparks when shot)
	"console": {"tex": ["a:094", "b:061", "a:095", "b:062", "a:096", "b:066", "a:098"],
		"width": 17.0, "box": Vector2(15, 9), "glow": Color(0.35, 0.8, 1.0, 0.3), "kind": "spark"},
	# 'P' specimen tube / energy cell
	"tube": {"tex": ["a:090", "a:092", "a:088", "a:093", "b:044"], "width": 12.0, "box": Vector2(11, 7),
		"glow": Color(0.5, 1.0, 0.5, 0.3)},
	# 'G' power generator (sparks when shot)
	"generator": {"tex": ["b:087", "b:085", "b:121", "b:123", "b:091"], "width": 16.0, "box": Vector2(14, 9),
		"glow": Color(1.0, 0.6, 0.25, 0.3), "kind": "spark"},
	# 'f' chain-link fence: blocks bodies, bullets pass through
	"fence": {"tex": ["b:100", "b:099", "b:101"], "width": 30.0, "box": Vector2(28, 5), "bullets": false},
	# 'k' cargo forklift (2 tiles)
	"forklift": {"tex": ["b:125"], "width": 26.0, "box": Vector2(22, 9)},
	# 'H' med kit: shoot it open to release a heart
	"medkit": {"tex": ["b:055"], "width": 13.0, "box": Vector2(11, 7),
		"glow": Color(1.0, 0.4, 0.4, 0.3), "kind": "medkit", "hp": 1},
	# 'E' alien egg / pod (hive): hatches 2 Greenies when you come close mid-fight;
	# shoot it first (3 hits) to destroy it
	"egg": {"tex": ["c:072", "c:087", "c:088"], "width": 15.0, "box": Vector2(12, 7),
		"glow": Color(1.0, 0.3, 0.7, 0.35), "kind": "egg", "hp": 3},
	# 'I' support pillar with warning lights
	"pillar": {"tex": ["c:011", "c:016", "c:026", "c:018"], "width": 9.0, "box": Vector2(9, 6),
		"glow": Color(1.0, 0.3, 0.25, 0.25)},
	# 'L' lamp post
	"lamp": {"tex": ["c:034", "c:039", "c:042"], "width": 7.0, "box": Vector2(5, 4),
		"glow": Color(1.0, 0.6, 0.25, 0.4)},
	# 'S' tentacle spire (hive growth)
	"spire": {"tex": ["c:098", "c:100", "c:107"], "width": 15.0, "box": Vector2(10, 6),
		"glow": Color(1.0, 0.25, 0.65, 0.3)},
	# 'R' radioactive tank: bursts and floods the cells around it with toxic slime
	"toxic_tank": {"tex": ["a:068", "b:047", "b:049", "a:067"], "width": 13.0, "box": Vector2(11, 7),
		"glow": Color(0.55, 1.0, 0.3, 0.4), "kind": "toxic", "hp": 3},
	# 'F' cryo tank: bursts into a freezing cloud that ices nearby aliens
	"cryo_tank": {"tex": ["a:089", "b:048"], "width": 12.0, "box": Vector2(11, 7),
		"glow": Color(0.4, 0.8, 1.0, 0.4), "kind": "cryo", "hp": 3},
	# ---- world 1 big rooms
	# 'K' supply crate: 3 hits (or a blast) and it bursts into coins, maybe a heart
	"loot_crate": {"tex": ["b:056", "b:029", "a:119"], "width": 15.0, "box": Vector2(14, 9),
		"glow": Color(1.0, 0.8, 0.3, 0.25), "kind": "loot", "hp": 3},
	# 'U' auto turret: stand next to it during a fight and it shoots the aliens
	"turret": {"tex": ["a:110"], "width": 15.0, "box": Vector2(10, 7),
		"glow": Color(0.4, 0.9, 1.0, 0.3), "kind": "turret"},
	# 'D' machinery block / reactor (sparks when shot)
	"machine": {"tex": ["b:085", "b:087", "b:121", "b:091", "a:133"], "width": 21.0, "box": Vector2(19, 10),
		"glow": Color(0.35, 0.8, 1.0, 0.3), "kind": "spark"},
	# 'l' lamp post
	"lamp_post": {"tex": ["b:063", "b:067", "b:068", "a:113", "b:069", "a:115"], "width": 7.0, "box": Vector2(5, 4),
		"glow": Color(1.0, 0.6, 0.25, 0.45)},
	# 'pp' hydroponic planter (2 tiles)
	"planter": {"tex": ["b:070", "b:071", "b:072", "b:073"], "width": 27.0, "box": Vector2(25, 9),
		"glow": Color(0.6, 0.4, 1.0, 0.25)},
	# 'A' satellite dish
	"dish": {"tex": ["b:060", "a:107"], "width": 22.0, "box": Vector2(15, 8)},
	# 'xx' command desk (2 tiles, sparks when shot)
	"command": {"tex": ["b:053"], "width": 34.0, "box": Vector2(32, 9),
		"glow": Color(0.35, 0.8, 1.0, 0.35), "kind": "spark"},
	# 'hh' hazard barrier (2 tiles): blocks bodies, bullets pass
	"barrier": {"tex": ["a:152", "a:153", "b:082"], "width": 30.0, "box": Vector2(28, 5), "bullets": false},
	# 'N' broken service robot (sparks when shot)
	"robot": {"tex": ["a:138", "a:139"], "width": 15.0, "box": Vector2(12, 7), "kind": "spark"},
}

## World themes swap the art of a prop for their own (same behaviour).
const THEME_TEX := {
	"hive": {
		"crate": ["c:031", "c:032", "c:033", "c:044", "c:048", "c:049", "c:051", "c:052", "c:058", "c:059", "c:065", "c:067"],
		"crate_big": ["c:043", "c:105", "c:104", "c:066"],
		"canister": ["c:036", "c:037", "c:054", "c:056", "c:057", "c:063"],
		"crystal": ["c:070", "c:069", "c:102"],
		"mushroom": ["c:068", "c:084", "c:088", "c:094", "c:095"],
		"rock": ["c:074", "c:082", "c:103", "c:089"],
		"console": ["c:028", "c:029", "c:013"],
		"tube": ["c:019", "c:020", "c:027", "c:060"],
		"generator": ["c:035", "c:090"],
		"fence": ["c:046", "c:047", "c:050"],
		"forklift": ["c:053"],
		"medkit": ["c:064"],
		"toxic_tank": ["c:040", "c:060"],
		"barrel": ["c:055"],
		"grime": ["c:083", "c:110", "c:081", "c:085", "c:078", "c:101", "b:076", "c:099"],
		"toxic": ["c:077", "c:081", "c:079"],
		"creep": ["c:080", "c:108", "c:071", "c:106"],
		"pad": ["c:076"],
	},
}

## 'B' explosive barrel art (red hazard drums), see scripts/combat/barrel.gd.
const BARREL_TEX := ["b:038", "b:120", "b:130"]
## Floor grime scattered on free cells: oil stains, slime and old alien splats.
const GRIME_TEX := ["b:076", "b:078", "b:095", "b:090", "b:105", "b:097"]

## Layout character -> prop id.
const LEGEND := {
	"#": "crate", "c": "canister", "T": "crystal", "M": "mushroom", "r": "rock",
	"C": "console", "P": "tube", "G": "generator", "f": "fence", "k": "forklift",
	"H": "medkit", "R": "toxic_tank", "F": "cryo_tank",
	"E": "egg", "I": "pillar", "L": "lamp", "S": "spire",
	"K": "loot_crate", "U": "turret", "D": "machine", "l": "lamp_post", "p": "planter",
	"A": "dish", "x": "command", "h": "barrier", "N": "robot",
}
## Props two tiles wide (the layout repeats the character, like "##").
const WIDE := ["fence", "forklift", "planter", "command", "barrier"]

## Booster pads (floor, push bodies): character -> direction. Art: arrow pad 145.
const PADS := {">": Vector2.RIGHT, "<": Vector2.LEFT, "^": Vector2.UP, ",": Vector2.DOWN}
const PAD_TEX := "a:145"


static func path(ref: String) -> String:
	return DIRS[ref.get_slice(":", 0)] % ref.get_slice(":", 1)


## Variant texture for a cell (deterministic, so a layout always looks the same).
static func texture_for(id: String, cell: Vector2i, theme := "ship") -> Texture2D:
	return pick(themed(id, PROPS[id].tex if PROPS.has(id) else [], theme), cell)


## The theme's art list for `id`, or `fallback` when the theme keeps the default.
static func themed(id: String, fallback: Array, theme: String) -> Array:
	var t: Dictionary = THEME_TEX.get(theme, {})
	return t.get(id, fallback)


static func pick(list: Array, cell: Vector2i) -> Texture2D:
	return load(path(str(list[(cell.x * 7 + cell.y * 13) % list.size()])))
