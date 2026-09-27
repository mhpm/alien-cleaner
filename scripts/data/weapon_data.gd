class_name WeaponData
extends RefCounted
## Blaster power tiers. Each tier uses a projectile from the reference sheet
## (assets/sprites/shot1..shot5). `dmg` multiplies the run's base damage.

const TIERS := [
	{"name": "Suds Pellet", "art": "shot1", "scale": 0.2, "dmg": 1.0, "hit_r": 3.0, "speed": 220.0, "pierce": 0},
	{"name": "Plasma Comet", "art": "shot2", "scale": 0.22, "dmg": 1.3, "hit_r": 4.0, "speed": 245.0, "pierce": 0},
	{"name": "Plasma Orb", "art": "shot3", "scale": 0.17, "dmg": 1.65, "hit_r": 5.5, "speed": 215.0, "pierce": 1},
	{"name": "Arrow Burst", "art": "shot4", "scale": 0.2, "dmg": 2.0, "hit_r": 6.0, "speed": 255.0, "pierce": 1},
	{"name": "Sonic Ring", "art": "shot5", "scale": 0.2, "dmg": 2.5, "hit_r": 8.0, "speed": 205.0, "pierce": 3},
]


static func max_level() -> int:
	return TIERS.size()


static func tier(level: int) -> Dictionary:
	return TIERS[clampi(level - 1, 0, TIERS.size() - 1)]
