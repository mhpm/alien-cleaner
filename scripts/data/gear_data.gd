class_name GearData
extends RefCounted
## Astronaut equipment: 6 slots x 8 variants, bought and levelled with banked coins
## on the CHARACTER screen and applied to the run stats in Game.new_run().
## Item id = "<slot>_<variant>". Icons: assets/ui/character/item_<id>.png

const SLOTS := ["helmet", "armor", "arms", "legs", "backpack", "weapon"]
const SLOT_NAMES := {
	"helmet": "Helmet", "armor": "Armor", "arms": "Gauntlets",
	"legs": "Boots", "backpack": "Jetpack", "weapon": "Blaster",
}
const TAB_TITLES := {
	"helmet": "HELMETS", "armor": "ARMOR", "arms": "GAUNTLETS",
	"legs": "BOOTS", "backpack": "JETPACKS", "weapon": "BLASTERS",
}
const VARIANTS := ["standard", "recon", "heavy", "stealth", "hazard", "exploration", "titan", "final"]
const PRICES := [0, 120, 250, 250, 400, 400, 600, 900]
const MAX_LEVEL := 5

## Level-1 profile of each variant (hp flat, spd fraction, dmg flat) + perk.
const PROFILE := {
	"standard": {"name": "Crew", "hp": 5.0, "spd": 0.0, "dmg": 1.0, "perk": {},
		"desc": "Standard-issue cleanup crew gear. Cheap to upgrade."},
	"recon": {"name": "Recon", "hp": 10.0, "spd": 0.02, "dmg": 0.0, "perk": {"magnet": true},
		"desc": "Built-in scanner pulls coins toward you from far away."},
	"heavy": {"name": "Heavy", "hp": 25.0, "spd": -0.03, "dmg": 1.0, "perk": {"knockback": 20.0},
		"desc": "Thick plating. Your hits knock aliens back harder."},
	"stealth": {"name": "Stealth", "hp": 5.0, "spd": 0.06, "dmg": 1.0, "perk": {"crit": 0.08},
		"desc": "Night-ops visor: +8% critical cleaning chance."},
	"hazard": {"name": "Hazard", "hp": 15.0, "spd": 0.0, "dmg": 1.0, "perk": {"hazard_mult": -0.25},
		"desc": "Sealed suit: 25% less damage from toxic slime and zaps."},
	"exploration": {"name": "Medic", "hp": 15.0, "spd": 0.03, "dmg": 1.0, "perk": {"room_heal": 6, "coin_bonus": 1},
		"desc": "Med-kit: heal 6 HP each time a room is CLEAN, +1 coin per alien."},
	"titan": {"name": "Crystal", "hp": 35.0, "spd": 0.0, "dmg": 2.0, "perk": {"shield": true, "freeze": 0.1},
		"desc": "Cryo crystal: Bubble Shield every room, +10% freeze chance."},
	"final": {"name": "Legend", "hp": 30.0, "spd": 0.05, "dmg": 3.0, "perk": {"chain": 1, "crit": 0.05},
		"desc": "Golden prototype: hits arc to a nearby alien, +5% crit."},
}

## How much of each stat a slot carries.
const SLOT_MULT := {
	"helmet": {"hp": 1.0, "spd": 0.5, "dmg": 0.5},
	"armor": {"hp": 1.6, "spd": 0.0, "dmg": 0.3},
	"arms": {"hp": 0.6, "spd": 0.0, "dmg": 1.5},
	"legs": {"hp": 0.6, "spd": 2.0, "dmg": 0.3},
	"backpack": {"hp": 0.8, "spd": 1.0, "dmg": 0.5},
	"weapon": {"hp": 0.3, "spd": 0.0, "dmg": 2.0},
}

const SET_BONUS := [
	{"parts": 2, "label": "2 Parts Equipped", "bonus": "+10% Max HP"},
	{"parts": 4, "label": "4 Parts Equipped", "bonus": "+10% Damage"},
	{"parts": 6, "label": "6 Parts Equipped", "bonus": "+10% Speed"},
]


static func item_id(slot: String, variant: String) -> String:
	return slot + "_" + variant


static func slot_of(id: String) -> String:
	return id.get_slice("_", 0)


static func variant_of(id: String) -> String:
	return id.get_slice("_", 1)


static func item_name(id: String) -> String:
	var p: Dictionary = PROFILE[variant_of(id)]
	return "%s %s" % [p.name, SLOT_NAMES[slot_of(id)]]


static func price(id: String) -> int:
	return PRICES[VARIANTS.find(variant_of(id))]


static func upgrade_cost(id: String, level: int) -> int:
	var base := price(id)
	if base == 0:
		base = 60
	return int(base * 0.5 * (level + 1))


static func icon_path(id: String) -> String:
	return "res://assets/ui/character/item_%s.png" % id


static func _level_mult(level: int) -> float:
	return 0.0 if level <= 0 else 1.0 + 0.5 * (level - 1)


## {"hp": int, "spd": float (fraction), "dmg": int} for an item at a level.
static func stats(id: String, level: int) -> Dictionary:
	var p: Dictionary = PROFILE[variant_of(id)]
	var m: Dictionary = SLOT_MULT[slot_of(id)]
	var k := _level_mult(level)
	var dmg := float(p.dmg) * float(m.dmg) * k
	return {
		"hp": roundi(float(p.hp) * float(m.hp) * k),
		"spd": float(p.spd) * float(m.spd) * k,
		"dmg": ceili(dmg) if dmg > 0.0 else 0,
	}


## Starting blaster tiers granted by a weapon item.
static func weapon_bonus(id: String) -> int:
	if slot_of(id) != "weapon":
		return 0
	return floori(VARIANTS.find(variant_of(id)) / 3.0)


static func description(id: String) -> String:
	var p: Dictionary = PROFILE[variant_of(id)]
	var text := str(p.desc)
	var wb := weapon_bonus(id)
	if wb > 0:
		text += " Starts runs at Blaster LV %d." % (1 + wb)
	return text
