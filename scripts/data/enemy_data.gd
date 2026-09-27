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
	"mini_slime": {
		"name": "Slimelet", "hp": 12.0, "speed": 34.0, "damage": 6.0, "coins": 1, "cost": 1,
		"radius": 5.0, "art": "green", "scale": 0.16, "ai": "chaser",
		"color": Color("a7f070"), "kb": 1.4,
	},
	"gloop_brute": {
		"name": "GLOOP BRUTE", "hp": 380.0, "speed": 30.0, "damage": 15.0, "coins": 25, "cost": 0,
		"radius": 17.0, "art": "pink", "scale": 0.58, "ai": "boss",
		"color": Color("c75bd6"), "kb": 0.12, "boss": true, "tint": Color(0.9, 0.62, 1.3),
		"script": "res://scripts/enemies/boss_brute.gd",
	},
	"slime_king": {
		"name": "THE SLIME KING", "hp": 850.0, "speed": 45.0, "damage": 18.0, "coins": 60, "cost": 0,
		"radius": 21.0, "art": "green", "scale": 0.72, "ai": "boss",
		"color": Color("a7f070"), "kb": 0.05, "boss": true,
		"script": "res://scripts/enemies/boss_king.gd",
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
