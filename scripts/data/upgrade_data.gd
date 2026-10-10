class_name UpgradeData
extends RefCounted
## Run upgrades. `roll` picks random offers, `apply` mutates the run stats.
## Art: assets/ui/upgrades/<id>.png (icon) and <id>_1..5.png (one picture per level)
## from tools/make_upgrade_icons.py (the three upgrade design sheets). Every upgrade has
## 5 levels; the Blaster Upgrade follows the blaster tier (Game.stats.weapon, 1-5).
## Upgrades with "kit": true use the level-up modal kit instead (assets/ui/upgrades/kit/,
## python tools/make_upgrade_kit.py): <id>.png portrait + <id>_1..5.png level pictures
## drawn inside the shared level box, and "levels" = what each level adds.

const ART := "res://assets/ui/upgrades/"
const KIT := "res://assets/ui/upgrades/kit/"
const LEVELS := 5
## Offered on level-up right now (the others stay defined for later).
const ACTIVE := ["overdrive", "martian", "shield", "slime_explode", "rapid", "orbiters", "hunter", "magnet", "bomber"]
## RAPID FIRE: fire-rate multiplier each level adds (total x1.15, 1.32, 1.59, 1.90, 2.38).
const RAPID_STEP := [1.15, 1.15, 1.2, 1.2, 1.25]

## Martian UFO ally per level: plasma shots per volley, seconds between volleys, extra
## aliens each shot chains to (level 5 = a 5-shot fan; the abduction beam is off).
const MARTIAN_LV := [
	{"shots": 1, "rate": 1.1, "chain": 0, "beam": false},
	{"shots": 2, "rate": 1.0, "chain": 0, "beam": false},
	{"shots": 2, "rate": 0.95, "chain": 2, "beam": false},
	{"shots": 3, "rate": 0.75, "chain": 2, "beam": false},
	{"shots": 5, "rate": 0.7, "chain": 2, "beam": false},
]
## Ion Shield per level: hits it blocks, dome radius (world units), seconds to recharge
## one hit. Its colour shows the hits it has left: blue 1, green 2, purple 3, orange 4,
## RED 5 (the strongest). From 3 it shoves aliens away, at 5 it burns them.
const SHIELD_LV := [
	{"hits": 1, "r": 16.0, "cd": 8.0},
	{"hits": 2, "r": 18.5, "cd": 7.0},
	{"hits": 3, "r": 21.0, "cd": 6.0},
	{"hits": 4, "r": 24.0, "cd": 5.0},
	{"hits": 5, "r": 27.0, "cd": 4.0},
]
## Scrub-Bot drone per level (ScrubBot): pods = aliens shot per volley (each pod a
## different one), rate = seconds between volleys, blast = radius the orbs pop in (0 = none),
## spin_every = seconds between SPIN SCRUBS (0 = none), spin_orbs = orbs per spiral arm.
const SCRUB_LV := [
	{"pods": 1, "rate": 1.0, "blast": 0.0, "spin_every": 0, "spin_orbs": 0},
	{"pods": 2, "rate": 0.9, "blast": 0.0, "spin_every": 0, "spin_orbs": 0},
	{"pods": 3, "rate": 0.85, "blast": 16.0, "spin_every": 0, "spin_orbs": 0},
	{"pods": 3, "rate": 0.8, "blast": 16.0, "spin_every": 5, "spin_orbs": 12},
	{"pods": 4, "rate": 0.7, "blast": 20.0, "spin_every": 4, "spin_orbs": 12},
]
## HUNTER DRONE per level (HunterDrone + HunterBlade boomerangs): blades per throw, len =
## loop reach, time = seconds out and back, size = blade size (hit radius 0.7x), dmg = damage
## per cut (share of yours; each alien cut at most every 0.3 s per blade), pinwheel = every
## n-th throw is a PINWHEEL (0 = never), ring = seconds it circles you first.
const HUNTER_LV := [
	{"blades": 1, "len": 95.0, "time": 1.1, "size": 13.0, "dmg": 0.55, "pinwheel": 0, "ring": 0.0},
	{"blades": 2, "len": 100.0, "time": 1.1, "size": 13.0, "dmg": 0.55, "pinwheel": 0, "ring": 0.0},
	{"blades": 3, "len": 110.0, "time": 1.05, "size": 16.0, "dmg": 0.65, "pinwheel": 0, "ring": 0.0},
	{"blades": 3, "len": 115.0, "time": 1.0, "size": 16.0, "dmg": 0.7, "pinwheel": 3, "ring": 1.6},
	{"blades": 3, "len": 125.0, "time": 0.95, "size": 18.0, "dmg": 0.75, "pinwheel": 2, "ring": 1.6},
]
## BOMBER DRONE per level (BomberDrone): cd = seconds between drops, radius / dmg = blast
## (damage as a share of yours), cluster = bomblets per blast. 3 = carpet runs, 4 = mines,
## 5 = MEGA bomb every 4th drop (BomberDrone).
const BOMBER_LV := [
	{"cd": 2.4, "radius": 26.0, "dmg": 1.8, "cluster": 0},
	{"cd": 2.3, "radius": 26.0, "dmg": 1.8, "cluster": 3},
	{"cd": 2.1, "radius": 28.0, "dmg": 2.0, "cluster": 3},
	{"cd": 1.9, "radius": 32.0, "dmg": 2.2, "cluster": 4},
	{"cd": 1.7, "radius": 34.0, "dmg": 2.4, "cluster": 4},
]
## Coin Magnet level 5: VACUUM PULSE every MAGNET_PULSE_EVERY s pulls the XP gems and
## coins within MAGNET_PULSE_R (Player._magnet_pulse).
const MAGNET_PULSE_EVERY := 10.0
const MAGNET_PULSE_R := 260.0
const SHIELD_COLORS := [Color("41a6f6"), Color("38e070"), Color("b35cff"), Color("ff9a2e"), Color("ff3344")]

const UPGRADES := {
	"blaster": {"name": "Blaster Upgrade", "desc": "Evolves your shots: bigger, stronger, piercing.", "icon": "GUN", "color": Color("41a6f6"), "max": 4, "weight": 3.0},
	"double_shot": {"name": "Double Shot", "desc": "Odd levels: an extra parallel bubble. Even levels: +15% damage.", "icon": "x2", "color": Color("ff5566"), "max": 5},
	"spread_shot": {"name": "Triple Spray", "desc": "Odd levels: two more diagonal bubbles. Even levels: +15% damage.", "icon": "<|>", "color": Color("38b764"), "max": 5},
	"ricochet": {"name": "Ricochet", "desc": "Bubbles bounce off walls: 2 bounces, +1 per level.", "icon": "/\\", "color": Color("c75bd6"), "max": 5},
	"piercing": {"name": "Piercing Suds", "desc": "Bubbles pass through one more alien.", "icon": "->", "color": Color("ffcd75"), "max": 5},
	"freeze": {"name": "Freeze Cleaner", "desc": "+12% chance to freeze aliens solid.", "icon": "*", "color": Color("73eff7"), "max": 5},
	"electric": {"name": "Electric Mop", "desc": "Hits chain lightning to nearby aliens (+1 jump per level).", "icon": "Z", "color": Color("41a6f6"), "max": 5},
	"rapid": {"name": "Rapid Fire", "desc": "Your weapon fires faster with every level.", "icon": ">>", "color": Color("41c8ff"), "max": 5, "kit": true,
		"levels": ["Fire rate +15%.", "Fire rate +32%.", "Fire rate +59%.", "Fire rate +90%.", "Fire rate +138%: a comet storm!"]},
	"power": {"name": "Power Suds", "desc": "+30% cleaning damage.", "icon": "!", "color": Color("c75bd6"), "max": 5},
	"crit": {"name": "Critical Clean", "desc": "+12% chance for 2.5x hits.", "icon": "!!", "color": Color("ef7d57"), "max": 5},
	"speed": {"name": "Jet Boots", "desc": "+10% movement speed.", "icon": "~", "color": Color("38b764"), "max": 5},
	"vitality": {"name": "Tough Suit", "desc": "+30 max health and heal 30.", "icon": "+", "color": Color("ffcd75"), "max": 5},
	"orbiters": {"name": "Scrub-Bots", "desc": "A cleaning drone hovers at your side and fires its plasma pods.", "icon": "o", "color": Color("ff9a2e"), "max": 5, "kit": true, "art": "scrub",
		"levels": ["Drone fires a plasma pod at the nearest alien.", "Two pods, two different aliens.", "Three pods; orbs pop in small blasts.", "SPIN SCRUB: spins, spraying a spiral of orbs.", "Four pods, double spiral that shoves aliens back."]},
	"slime_explode": {"name": "Volatile Slime", "desc": "Cleaned aliens burst in toxic slime and hurt the aliens around them.", "icon": "@", "color": Color("7dff3a"), "max": 5, "kit": true,
		"levels": ["Cleaned aliens burst, hurting aliens nearby.", "Bigger bursts: +33% damage.", "Bursts knock aliens back.", "Huge bursts: +25% damage.", "Every 4th burst is a MEGA burst."]},
	"air_cannon": {"name": "Air Cannon Mod", "desc": "More knockback; BLAST recharges 15% faster.", "icon": ")))", "color": Color("38b764"), "max": 5},
	"shield": {"name": "Ion Shield", "desc": "A dome that blocks hits, grows and recharges. Red is the strongest.", "icon": "( )", "color": Color("41a6f6"), "max": 5, "kit": true,
		"levels": ["Blue dome: blocks 1 hit.", "Green dome: bigger, blocks 2 hits.", "Purple dome: 3 hits, shoves aliens away.", "Orange dome: 4 hits, recharges faster.", "RED dome, the strongest: 5 hits and burns aliens."]},
	"overdrive": {"name": "Overdrive", "desc": "Supercharges the weapon in your hands, whichever it is.", "icon": ">>", "color": Color("41a6f6"), "max": 5, "kit": true, "weight": 1.3,
		"levels": ["Overcharged: +25% damage, +15% fire rate.", "Twin barrels: fires 2 shots side by side.", "Triple fan: 3 shots in a spread.", "Drill tips: shots pierce 2 more aliens, +15% damage.", "ROCKET NOVA: every 3s, 5 homing rockets burst out!"]},
	"martian": {"name": "Martian UFO", "desc": "A tiny ally that orbits you and attacks with you.", "icon": "o", "color": Color("5ef07a"), "max": 5, "kit": true,
		"levels": ["Zaps the nearest alien with plasma.", "Fires twin plasma shots.", "Shots chain to 2 more aliens.", "Triple burst, fires faster.", "Fires a fan of 5 plasma shots."]},
	"hunter": {"name": "Hunter Drone", "desc": "Throws boomerang blades that cut aliens out and back.", "icon": "x", "color": Color("ff3344"), "max": 5, "kit": true,
		"levels": ["A boomerang blade cuts on the way out and back.", "Twin blades in mirrored loops.", "Three bigger blades in a fan.", "PINWHEEL: 4 blades buzz around you, then fly out.", "WHIRLWIND: the drone throws itself; slash waves!"]},
	"bomber": {"name": "Bomber Drone", "desc": "A bomber that circles you and bombs the biggest crowd.", "icon": "B", "color": Color("ffb000"), "max": 5, "kit": true,
		"levels": ["Drops a bomb on the biggest crowd.", "CLUSTER: blasts scatter bomblets.", "CARPET RUN: flies over a crowd dropping a line of bombs.", "Bigger blasts; misses stay as MINES.", "MEGA BOMB: every 4th drop is a nuke!"]},
	"magnet": {"name": "Coin Magnet", "desc": "A gravity vortex that pulls coins and XP gems to you.", "icon": "$", "color": Color("41c8ff"), "max": 5, "kit": true,
		"levels": ["Pulls coins and gems from further away.", "Wider pull.", "Even wider pull.", "+1 coin for every alien cleaned.", "VACUUM PULSE: every 10s sucks in all loot nearby."]},
	"snack": {"name": "Space Snack", "desc": "Heal 50% of your health.", "icon": "<3", "color": Color("41a6f6"), "max": 99},
}


static func is_kit(id: String) -> bool:
	return bool(UPGRADES[id].get("kit", false))


## File name of its art (Scrub-Bots keeps its old id "orbiters" but its kit art is "scrub").
static func art_name(id: String) -> String:
	return str(UPGRADES[id].get("art", id))


static func icon(id: String) -> Texture2D:
	return load((KIT if is_kit(id) else ART) + art_name(id) + ".png")


static func level_tex(id: String, lv: int) -> Texture2D:
	return load((KIT if is_kit(id) else ART) + "%s_%d.png" % [art_name(id), clampi(lv, 1, LEVELS)])


## Big picture of the level-up card: the shield shows its dome in that level's colour.
static func portrait(id: String, lv: int) -> Texture2D:
	if id == "shield":
		return shield_dome(lv)
	return icon(id)


static func shield_dome(hits: int) -> Texture2D:
	return load(KIT + "shield_dome_%d.png" % clampi(hits, 1, LEVELS))


## The dome drawn around the astronaut: hollowed out so the astronaut shows through.
static func shield_bubble(hits: int) -> Texture2D:
	return load(KIT + "shield_bubble_%d.png" % clampi(hits, 1, LEVELS))


## Card text; OVERDRIVE names the weapon it will supercharge.
static func description(id: String) -> String:
	if id == "overdrive" and not Game.stats.is_empty():
		return "Supercharges your %s: more shots, more power." % GunData.gun(str(Game.stats.get("gun", "pulse"))).name
	return str(UPGRADES[id].desc)


## What level lv adds ("" when the upgrade has no per-level text).
static func level_text(id: String, lv: int) -> String:
	var lines: Array = UPGRADES[id].get("levels", [])
	return str(lines[lv - 1]) if lv >= 1 and lv <= lines.size() else ""


## Shield level in play: the upgrade, or 1 from a gear perk (Crystal suit).
static func shield_level(s: Dictionary) -> int:
	return maxi(int(s.get("shield_lvl", 0)), 1 if bool(s.get("shield", false)) else 0)


## Level the upgrade is at now (0 = not taken). The blaster shows its tier (1-5).
static func current_level(id: String) -> int:
	if id == "blaster":
		return int(Game.stats.weapon)
	return int(Game.upgrades.get(id, 0))


static func roll(count: int, levels: Dictionary, hp_ratio: float) -> Array[String]:
	var pool: Array[String] = []
	for id: String in ACTIVE:
		var def: Dictionary = UPGRADES[id]
		if id == "snack" and hp_ratio > 0.65:
			continue
		if id == "blaster" and int(Game.stats.weapon) >= WeaponData.max_level():
			continue
		if int(levels.get(id, 0)) >= int(def.max):
			continue
		pool.append(id)
	# weighted pick without replacement
	var out: Array[String] = []
	while out.size() < count and not pool.is_empty():
		var total := 0.0
		for id in pool:
			total += float(UPGRADES[id].get("weight", 1.0))
		var r := randf() * total
		for i in pool.size():
			r -= float(UPGRADES[pool[i]].get("weight", 1.0))
			if r <= 0.0 or i == pool.size() - 1:
				out.append(pool[i])
				pool.remove_at(i)
				break
	return out


## Apply level `lv` (1-based, already counted in Game.upgrades) of upgrade `id`.
static func apply(id: String, s: Dictionary, lv := 1) -> void:
	match id:
		"blaster":
			s.weapon = mini(int(s.weapon) + 1, WeaponData.max_level())
		"double_shot":
			if lv % 2 == 1:
				s.shots = int(s.shots) + 1
			else:
				s.damage = float(s.damage) * 1.15
		"spread_shot":
			if lv % 2 == 1:
				s.spread = int(s.spread) + 1
			else:
				s.damage = float(s.damage) * 1.15
		"ricochet":
			s.ricochet = int(s.ricochet) + (2 if lv == 1 else 1)
		"piercing":
			s.pierce = int(s.pierce) + 1
		"freeze":
			s.freeze = float(s.freeze) + 0.12
		"electric":
			s.chain = int(s.chain) + (2 if int(s.chain) == 0 else 1)
		"rapid":
			s.fire_interval = float(s.fire_interval) / float(RAPID_STEP[clampi(lv, 1, LEVELS) - 1])
		"power":
			s.damage = float(s.damage) * 1.3
		"crit":
			s.crit = float(s.crit) + 0.12
			s.crit_mult = 2.5
		"speed":
			s.move_speed = float(s.move_speed) * 1.1
		"vitality":
			s.max_hp = float(s.max_hp) + 30.0
			s.hp = minf(float(s.hp) + 30.0, float(s.max_hp))
		"orbiters":
			s.orbiters = int(s.orbiters) + 1
		"slime_explode":
			s.death_explode = true
			s.explode_lvl = lv
		"air_cannon":
			s.knockback = float(s.knockback) * 1.25
			s.blast_cooldown = float(s.blast_cooldown) * 0.85
		"shield":
			s.shield_lvl = lv
		"martian":
			s.martian = lv
		"hunter":
			s.hunter = lv
		"bomber":
			s.bomber = lv
		"overdrive":  # boosts the equipped ARMORY weapon (GunFire copies / pierce / nova)
			s.overdrive = lv
			match lv:
				1:
					s.damage = float(s.damage) * 1.25
					s.fire_interval = float(s.fire_interval) / 1.15
				2:
					s.shots = int(s.shots) + 1
				3:
					s.shots = int(s.shots) - 1
					s.spread = int(s.spread) + 1
				4:
					s.pierce = int(s.pierce) + 2
					s.damage = float(s.damage) * 1.15
		"magnet":
			s.magnet = lv >= 4  # +1 coin per alien from level 4 (the "+1" in its art)
			s.magnet_lvl = lv
		"snack":
			s.hp = minf(float(s.hp) + float(s.max_hp) * 0.5, float(s.max_hp))
