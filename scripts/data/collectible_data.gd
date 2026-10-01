class_name CollectibleData
extends RefCounted
## Pickup art (`tex`: a numbered sheet element or a dedicated res:// texture)
## and what every pickup kind does. `size` = world size of the sprite's longest side.
## Survival power-ups (everything but coin / heart / power / xp) are applied by
## Survival.collect(); timed ones (`buff` seconds) become Player buffs shown in the HUD.

const DIR := "res://assets/sprites/enviroment/collectibles_elements/ChatGPT Image Sep 27, 2026, 04_45_58 PM_%s.png"

## XP gems by value: [max value, art]
const XP_TIERS := [[2, "006"], [9, "001"], [29, "002"], [999999, "005"]]

const ITEMS := {
	"coin": {"tex": "007", "size": 7.0},
	"heart": {"tex": "015", "size": 9.0},
	"power": {"tex": "003", "size": 12.0},  # blaster level up
	"gold": {"tex": "008", "size": 11.0, "name": "+10 COINS", "color": Color("ffcd75")},
	"carrot": {"tex": "033", "size": 11.0, "name": "SPACE CARROTS +12", "color": Color("ef7d57")},
	"medkit": {"tex": "012", "size": 12.0, "name": "MED KIT", "color": Color("ff5566")},
	"heart_max": {"tex": "009", "size": 12.0, "name": "HEART CORE +15 MAX", "color": Color("ff5566")},
	"golden_carrot": {"tex": "036", "size": 12.0, "name": "GOLDEN CARROT!", "color": Color("ffcd75")},
	"magnet": {"tex": "042", "size": 12.0, "name": "GRAVITY WELL", "color": Color("c75bd6")},
	"bomb": {"tex": "res://assets/sprites/collectibles/bomb.tres", "size": 12.0, "name": "NUKE!", "color": Color("a7f070")},
	"freeze": {"tex": "030", "size": 12.0, "name": "CRYO WAVE", "color": Color("a6e3ff")},
	"turret": {"tex": "048", "size": 11.0, "name": "TURRET DROP", "color": Color("73eff7")},
	"frenzy": {"tex": "027", "size": 12.0, "name": "OVERCLOCK", "color": Color("c75bd6"), "buff": 8.0},
	"boots": {"tex": "028", "size": 13.0, "name": "JET BOOTS", "color": Color("ff5566"), "buff": 8.0},
	"triple": {"tex": "026", "size": 12.0, "name": "TRIPLE SHOT", "color": Color("ff9a4d"), "buff": 10.0},
	"rage": {"tex": "025", "size": 12.0, "name": "DOUBLE DAMAGE", "color": Color("ff5566"), "buff": 10.0},
	"shield": {"tex": "011", "size": 12.0, "name": "SHIELD", "color": Color("73eff7"), "buff": 6.0},
	"star": {"tex": "004", "size": 12.0, "name": "SUPER STAR", "color": Color("ffcd75"), "buff": 6.0},
	"ufo": {"tex": "034", "size": 13.0, "name": "UFO BUDDIES", "color": Color("a7f070"), "buff": 15.0},
}

## Everything a bit bigger so pickups read at the wide survival zoom.
const SIZE_MULT := 1.35

static var _cache: Dictionary = {}


static func tex_file(file: String) -> Texture2D:
	if not _cache.has(file):
		_cache[file] = load(file if file.begins_with("res://") else DIR % file)
	return _cache[file]


static func tex(kind: String, value := 1) -> Texture2D:
	if kind == "xp":
		for t: Array in XP_TIERS:
			if value <= int(t[0]):
				return tex_file(str(t[1]))
	return tex_file(str(ITEMS[kind].tex))


## Scale for a sprite of this kind so its longest side is `size` world units.
static func scale_for(kind: String, value := 1) -> float:
	var t := tex(kind, value)
	var size := 6.0 + minf(value, 30.0) * 0.12 if kind == "xp" else float(ITEMS[kind].size)
	return size * SIZE_MULT / maxf(t.get_width(), t.get_height())


static func is_buff(kind: String) -> bool:
	return ITEMS.has(kind) and ITEMS[kind].has("buff")
