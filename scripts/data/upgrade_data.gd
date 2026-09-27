class_name UpgradeData
extends RefCounted
## Run upgrades. `roll` picks random offers, `apply` mutates the run stats.

const UPGRADES := {
	"blaster": {"name": "Blaster Upgrade", "desc": "Evolves your shots: bigger, stronger, piercing.", "icon": "GUN", "color": Color("41a6f6"), "max": 4, "weight": 3.0},
	"double_shot": {"name": "Double Shot", "desc": "Fire an extra parallel suds bubble.", "icon": "x2", "color": Color("41a6f6"), "max": 2},
	"spread_shot": {"name": "Triple Spray", "desc": "Adds two diagonal bubbles.", "icon": "<|>", "color": Color("73eff7"), "max": 2},
	"ricochet": {"name": "Ricochet", "desc": "Bubbles bounce off walls twice.", "icon": "/\\", "color": Color("6b8cff"), "max": 2},
	"piercing": {"name": "Piercing Suds", "desc": "Bubbles pass through one more alien.", "icon": "->", "color": Color("94b0c2"), "max": 2},
	"freeze": {"name": "Freeze Cleaner", "desc": "20% chance to freeze aliens solid.", "icon": "*", "color": Color("a6e3ff"), "max": 3},
	"electric": {"name": "Electric Mop", "desc": "Hits zap nearby aliens in a chain.", "icon": "Z", "color": Color("ffcd75"), "max": 3},
	"rapid": {"name": "Faster Cleaning", "desc": "+25% fire rate.", "icon": ">>", "color": Color("ef7d57"), "max": 3},
	"power": {"name": "Power Suds", "desc": "+30% cleaning damage.", "icon": "!", "color": Color("b13e53"), "max": 3},
	"crit": {"name": "Critical Clean", "desc": "+20% chance for 2.5x hits.", "icon": "!!", "color": Color("f5a3e0"), "max": 2},
	"speed": {"name": "Jet Boots", "desc": "+18% movement speed.", "icon": "~", "color": Color("38b764"), "max": 2},
	"vitality": {"name": "Tough Suit", "desc": "+30 max health and heal 30.", "icon": "+", "color": Color("b13e53"), "max": 3},
	"orbiters": {"name": "Scrub-Bots", "desc": "A little bot orbits you, scrubbing aliens.", "icon": "o", "color": Color("73eff7"), "max": 3},
	"slime_explode": {"name": "Volatile Slime", "desc": "Cleaned aliens burst and hurt others.", "icon": "@", "color": Color("a7f070"), "max": 1},
	"air_cannon": {"name": "Air Cannon Mod", "desc": "Huge knockback. Blast recharges 30% faster.", "icon": ")))", "color": Color("f4f4f4"), "max": 2},
	"shield": {"name": "Bubble Shield", "desc": "Blocks one hit. Recharges every 8s.", "icon": "( )", "color": Color("73eff7"), "max": 1},
	"magnet": {"name": "Coin Magnet", "desc": "Pull coins from afar. +1 coin per alien.", "icon": "$", "color": Color("ffcd75"), "max": 1},
	"snack": {"name": "Space Snack", "desc": "Heal 50% of your health.", "icon": "<3", "color": Color("ef7d57"), "max": 99},
}


static func roll(count: int, levels: Dictionary, hp_ratio: float) -> Array[String]:
	var pool: Array[String] = []
	for id: String in UPGRADES:
		var def: Dictionary = UPGRADES[id]
		if id == "snack" and hp_ratio > 0.65:
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


static func apply(id: String, s: Dictionary) -> void:
	match id:
		"blaster":
			s.weapon = mini(int(s.weapon) + 1, WeaponData.max_level())
		"double_shot":
			s.shots = int(s.shots) + 1
		"spread_shot":
			s.spread = int(s.spread) + 1
		"ricochet":
			s.ricochet = int(s.ricochet) + 2
		"piercing":
			s.pierce = int(s.pierce) + 1
		"freeze":
			s.freeze = float(s.freeze) + 0.2
		"electric":
			s.chain = int(s.chain) + (2 if int(s.chain) == 0 else 1)
		"rapid":
			s.fire_interval = float(s.fire_interval) / 1.25
		"power":
			s.damage = float(s.damage) * 1.3
		"crit":
			s.crit = float(s.crit) + 0.2
			s.crit_mult = 2.5
		"speed":
			s.move_speed = float(s.move_speed) * 1.18
		"vitality":
			s.max_hp = float(s.max_hp) + 30.0
			s.hp = minf(float(s.hp) + 30.0, float(s.max_hp))
		"orbiters":
			s.orbiters = int(s.orbiters) + 1
		"slime_explode":
			s.death_explode = true
		"air_cannon":
			s.knockback = float(s.knockback) * 1.6
			s.blast_cooldown = float(s.blast_cooldown) * 0.7
		"shield":
			s.shield = true
		"magnet":
			s.magnet = true
		"snack":
			s.hp = minf(float(s.hp) + float(s.max_hp) * 0.5, float(s.max_hp))
