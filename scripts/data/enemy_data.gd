class_name EnemyData
extends RefCounted
## Alien definitions. Add a new alien by adding an entry here (and an `ai` branch
## in enemy.gd, or a custom `script` for bosses).

const TYPES := {
	"slime": {
		"name": "Slime", "hp": 30.0, "speed": 22.0, "damage": 10.0, "coins": 2, "cost": 1,
		"radius": 8.0, "art": "green", "scale": 0.27, "ai": "chaser",
		"color": Color("a7f070"), "kb": 1.0,
	},
	"runner": {
		"name": "Runner", "hp": 22.0, "speed": 28.0, "damage": 12.0, "coins": 2, "cost": 2,
		"radius": 7.0, "art": "pink", "scale": 0.23, "ai": "runner",
		"color": Color("f0447a"), "kb": 1.2,
	},
	"spitter": {
		"name": "Spitter", "hp": 26.0, "speed": 20.0, "damage": 10.0, "coins": 3, "cost": 2,
		"radius": 7.0, "art": "blue", "scale": 0.26, "ai": "spitter",
		"color": Color("41a6f6"), "kb": 1.0,
	},
	"droid": {
		"name": "Droid", "hp": 28.0, "speed": 24.0, "damage": 10.0, "coins": 3, "cost": 2,
		"radius": 7.0, "art": "droid", "scale": 0.21, "ai": "droid",
		"color": Color("73eff7"), "kb": 1.0,
	},
	"ufo": {
		"name": "UFO", "hp": 45.0, "speed": 26.0, "damage": 9.0, "coins": 5, "cost": 3,
		"radius": 9.0, "art": "ufo", "scale": 0.22, "ai": "ufo",
		"color": Color("a7f070"), "kb": 0.7,
	},
	# dropped by the UFO through a portal (not in the random pools)
	"ufo_alien": {
		"name": "Greenie", "hp": 10.0, "speed": 38.0, "damage": 6.0, "coins": 1, "cost": 1,
		"radius": 5.0, "art": "ufo_alien", "scale": 0.17, "ai": "chaser",
		"color": Color("a7f070"), "kb": 1.4,
	},
	"octopus": {
		"name": "Octo", "hp": 34.0, "speed": 30.0, "damage": 9.0, "coins": 4, "cost": 3,
		"radius": 8.0, "art": "octopus", "scale": 0.23, "ai": "octopus",
		"color": Color("41a6f6"), "kb": 1.0,
	},
	"mini_slime": {
		"name": "Slimelet", "hp": 12.0, "speed": 34.0, "damage": 6.0, "coins": 1, "cost": 1,
		"radius": 5.0, "art": "green", "scale": 0.16, "ai": "chaser",
		"color": Color("a7f070"), "kb": 1.4,
	},
	"gloop_brute": {
		"name": "GLOOP BRUTE", "hp": 560.0, "speed": 34.0, "damage": 20.0, "coins": 25, "cost": 0,
		"radius": 17.0, "art": "pink", "scale": 0.58, "ai": "boss",
		"color": Color("c75bd6"), "kb": 0.12, "boss": true, "tint": Color(0.9, 0.62, 1.3), "power_core": true,
		"script": "res://scripts/enemies/boss_brute.gd",
	},
	"slime_king": {
		"name": "THE SLIME KING", "hp": 1000.0, "speed": 48.0, "damage": 22.0, "coins": 60, "cost": 0,
		"radius": 21.0, "art": "green", "scale": 0.72, "ai": "boss",
		"color": Color("a7f070"), "kb": 0.05, "boss": true,
		"script": "res://scripts/enemies/boss_king.gd",
	},
	# world 2 mini boss (room 20): giant hive octopus
	"brood_mother": {
		"name": "BROOD MOTHER", "hp": 1400.0, "speed": 30.0, "damage": 20.0, "coins": 40, "cost": 0,
		"radius": 17.0, "art": "octopus", "scale": 0.6, "ai": "boss",
		"color": Color("c75bd6"), "kb": 0.1, "boss": true, "tint": Color(1.25, 0.6, 1.25), "power_core": true,
		"script": "res://scripts/enemies/boss_brood.gd",
	},
	# world 2 final boss (room 30): the alien mothership
	"mothership": {
		"name": "THE MOTHERSHIP", "hp": 2400.0, "speed": 34.0, "damage": 22.0, "coins": 100, "cost": 0,
		"radius": 20.0, "art": "ufo", "scale": 0.62, "ai": "boss",
		"color": Color("a7f070"), "kb": 0.0, "boss": true, "tint": Color(1.15, 0.85, 0.85),
		"script": "res://scripts/enemies/boss_mothership.gd",
	},
}


static func create(id: String) -> Enemy:
	var def: Dictionary = TYPES[id]
	var e: Enemy
	if def.has("script"):
		var scr: GDScript = load(def.script)
		e = scr.new() as Enemy
	else:
		e = Enemy.new()
	e.setup(id)
	return e
