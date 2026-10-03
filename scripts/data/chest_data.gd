class_name ChestData
extends RefCounted
## Exploration chests (Explore, world 1 prototype): standing next to one for OPEN_TIME
## opens it and grants its perk for the rest of the run. Art: assets/sprites/chests/
## chest_<n>.png from tools/make_chests.py (n = index + 1, same order as CHESTS).
## `weight` = how often that chest shows up (rarer chests carry stronger perks).

const OPEN_TIME := 5.0  # seconds standing next to a chest to open it
const OPEN_R := 30.0  # how close the astronaut must stand (world units)
const DIR := "res://assets/sprites/chests/"

const CHESTS := [
	{"id": "power", "name": "POWER CELL", "desc": "+20% damage", "color": Color("5ee84c"), "weight": 3.0},
	{"id": "rapid", "name": "RAPID CORE", "desc": "+18% fire rate", "color": Color("41a6f6"), "weight": 3.0},
	{"id": "crit", "name": "LUCKY GEM", "desc": "+10% critical chance", "color": Color("c95cff"), "weight": 2.5},
	{"id": "volatile", "name": "VOLATILE GOO", "desc": "Cleaned aliens burst", "color": Color("7dff3a"), "weight": 2.0},
	{"id": "pierce", "name": "PIERCER", "desc": "Shots pierce +1 alien", "color": Color("ff5a3a"), "weight": 2.0},
	{"id": "treasure", "name": "TREASURE", "desc": "Coins and XP rain", "color": Color("ffcd3a"), "weight": 1.5},
	{"id": "frost", "name": "FROST CORE", "desc": "+12% freeze chance", "color": Color("8fe8ff"), "weight": 2.0},
	{"id": "berserk", "name": "BERSERK", "desc": "+35% damage, harder crits", "color": Color("ff3344"), "weight": 1.0},
	{"id": "wings", "name": "JET WINGS", "desc": "+15% move speed", "color": Color("5fd4ff"), "weight": 2.5},
	{"id": "vault", "name": "ARMOR VAULT", "desc": "+30 max HP, full heal", "color": Color("ffb020"), "weight": 2.0},
	{"id": "storm", "name": "STORM CELL", "desc": "Hits chain to 2 aliens", "color": Color("6fd8ff"), "weight": 1.5},
	{"id": "nano", "name": "NANO MEDS", "desc": "+15 max HP, heal 50%", "color": Color("a7f070"), "weight": 2.5},
]


static func tex(i: int) -> Texture2D:
	return load(DIR + "chest_%d.png" % (i + 1))


## `n` different chest indices, weighted by rarity.
static func pick(n: int, rng: RandomNumberGenerator) -> Array[int]:
	var pool: Array[int] = []
	for i in CHESTS.size():
		pool.append(i)
	var out: Array[int] = []
	while out.size() < n and not pool.is_empty():
		var total := 0.0
		for i in pool:
			total += float(CHESTS[i].weight)
		var r := rng.randf() * total
		for k in pool.size():
			r -= float(CHESTS[pool[k]].weight)
			if r <= 0.0 or k == pool.size() - 1:
				out.append(pool[k])
				pool.remove_at(k)
				break
	return out


## Applies chest `i`'s perk to the run (stats are read live by Player / GunFire / hits).
static func apply(i: int, w: GameWorld, at: Vector2) -> void:
	var s := Game.stats
	match str(CHESTS[i].id):
		"power":
			s.damage = float(s.damage) * 1.2
		"rapid":
			s.fire_interval = float(s.fire_interval) / 1.18
		"crit":
			s.crit = float(s.crit) + 0.1
		"volatile":
			s.death_explode = true
			s.explode_lvl = maxi(int(s.get("explode_lvl", 0)), 2)
		"pierce":
			s.pierce = int(s.pierce) + 1
		"treasure":
			w.drop_pickups(at, 18, 0.0)
			if w.survival != null:
				for k in 8:
					w.survival._drop("xp", at, 8)
		"frost":
			s.freeze = float(s.freeze) + 0.12
		"berserk":
			s.damage = float(s.damage) * 1.35
			s.crit_mult = float(s.crit_mult) + 0.5
		"wings":
			s.move_speed = float(s.move_speed) * 1.15
		"vault":
			s.max_hp = float(s.max_hp) + 30.0
			s.hp = s.max_hp
		"storm":
			s.chain = int(s.chain) + 2
		"nano":
			s.max_hp = float(s.max_hp) + 15.0
			s.hp = minf(float(s.hp) + float(s.max_hp) * 0.5, float(s.max_hp))
	Game.hp_changed.emit()
