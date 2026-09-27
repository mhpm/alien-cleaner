class_name WeaponData
extends RefCounted
## Blaster power tiers. Each tier uses a projectile from the reference sheet
## (assets/sprites/shot1..shot5). `dmg` multiplies the run's base damage.
## The equipped blaster (gear "weapon" slot) gives the shots their own look/feel:
## STYLES recolors them (null = original colours) and scales size, speed, pierce.

const TIERS := [
	{"name": "Suds Pellet", "art": "shot1", "scale": 0.2, "dmg": 1.0, "hit_r": 3.0, "speed": 220.0, "pierce": 0},
	{"name": "Plasma Comet", "art": "shot2", "scale": 0.22, "dmg": 1.3, "hit_r": 4.0, "speed": 245.0, "pierce": 0},
	{"name": "Plasma Orb", "art": "shot3", "scale": 0.17, "dmg": 1.65, "hit_r": 5.5, "speed": 215.0, "pierce": 1},
	{"name": "Arrow Burst", "art": "shot4", "scale": 0.2, "dmg": 2.0, "hit_r": 6.0, "speed": 255.0, "pierce": 1},
	{"name": "Sonic Ring", "art": "shot5", "scale": 0.2, "dmg": 2.5, "hit_r": 8.0, "speed": 205.0, "pierce": 3},
]


const STYLES := {
	"standard": {"color": null, "flash": "9fe8ff", "size": 1.0, "speed": 1.0, "pierce": 0},
	"recon": {"color": "4f8cff", "flash": "9fc4ff", "size": 0.8, "speed": 1.3, "pierce": 0},
	"heavy": {"color": "ff6a2a", "flash": "ffb070", "size": 1.35, "speed": 0.8, "pierce": 1},
	"stealth": {"color": "ff2448", "flash": "ff8090", "size": 0.85, "speed": 1.4, "pierce": 0},
	"hazard": {"color": "ffc21a", "flash": "ffe27a", "size": 1.1, "speed": 1.0, "pierce": 0},
	"exploration": {"color": "3cff6a", "flash": "a0ffb4", "size": 1.0, "speed": 1.05, "pierce": 0},
	"titan": {"color": "8ff0ff", "flash": "e0fcff", "size": 1.2, "speed": 0.95, "pierce": 1},
	"final": {"color": "ffcf3a", "flash": "fff0a0", "size": 1.25, "speed": 1.1, "pierce": 1},
}


static func style(variant: String) -> Dictionary:
	return STYLES.get(variant, STYLES.standard)


static func max_level() -> int:
	return TIERS.size()


static func tier(level: int) -> Dictionary:
	return TIERS[clampi(level - 1, 0, TIERS.size() - 1)]
