class_name MutationData
extends RefCounted
## The 5 mutation guns bought in the MUTATION LAB (Game.perm.infected = gun owned, 0-5).
## Gun 1 unlocks Infected Mode (scripts/infected.gd): the astronaut mutates, keeping its
## own sprite with the mutated helmet of its phase (set "mutant<n>", sprite_set), carries
## the best gun bought and fires it on its own; tentacles of the phase (TENTACLES) burst
## under nearby aliens as a helper attack. Each gun hits harder and faster than the last and has its own
## projectile. Art: assets/sprites/mutations_player/mutation_guns/guns_elements/
## gun_<n>.png + shoot_<n>.png; grip / muzzle / shot head in guns.json
## (tools/make_mutation_guns.py). Lab cards: assets/ui/lab/look_<n>.png.

const MAX := 5
const PHASE_DIR := "res://assets/sprites/mutations_player/fase %d/fase%d_elements/"
## Helper-attack tentacles per phase (files in PHASE_DIR); later phases without their
## own use the previous ones.
const TENTACLES := {1: ["fase1_019.png", "fase1_022.png", "fase1_038.png"]}
const GUN_DIR := "res://assets/sprites/mutations_player/mutation_guns/"
const GUN_LEN := 16.0  # world units from grip to muzzle in the mutant's hands
## dmg = x the run's damage per shot, rate = seconds between shots, speed = shot speed,
## pierce = extra aliens it goes through, shot = projectile length (world units),
## hit = hit radius, color = its flash / sparks.
const LEVELS := [
	{},  # 0 = not mutated
	{"cost": 50, "name": "MUTA BLASTER", "desc": "Unlocks Infected Mode. The mutant fires a plasma blaster.",
		"dmg": 1.6, "rate": 0.3, "speed": 290.0, "pierce": 0, "shot": 16.0, "hit": 4.0, "color": "4fc3ff"},
	{"cost": 250, "name": "GOO BLASTER", "desc": "Infected tubing: harder, faster pink bolts.",
		"dmg": 2.1, "rate": 0.26, "speed": 300.0, "pierce": 1, "shot": 18.0, "hit": 4.5, "color": "ff3df0"},
	{"cost": 550, "name": "EYE CANNON", "desc": "An eye aims for it: ringed shots pierce 2 aliens.",
		"dmg": 2.8, "rate": 0.23, "speed": 310.0, "pierce": 2, "shot": 22.0, "hit": 5.5, "color": "ff3df0"},
	{"cost": 1000, "name": "BROOD CANNON", "desc": "Tentacles feed it: heavy bolts at a fast pace.",
		"dmg": 3.5, "rate": 0.2, "speed": 320.0, "pierce": 3, "shot": 23.0, "hit": 6.0, "color": "ff3df0"},
	{"cost": 1800, "name": "APEX MAW", "desc": "The living cannon: huge bolts that tear through lines.",
		"dmg": 4.5, "rate": 0.17, "speed": 330.0, "pierce": 5, "shot": 28.0, "hit": 7.5, "color": "ff7cf6"},
]

static var _points: Dictionary = {}


## The mutant's sprite set at gun level `lv`: "mutant<lv>", or the last phase that has one.
static func sprite_set(lv: int) -> String:
	for n in range(clampi(lv, 1, MAX), 0, -1):
		if Art.has_set("mutant%d" % n):
			return "mutant%d" % n
	return "mutant1"


## Tentacle textures of the helper attack at gun level `lv`.
static func tentacles(lv: int) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	for n in range(clampi(lv, 1, MAX), 0, -1):
		if TENTACLES.has(n):
			for f: String in TENTACLES[n]:
				out.append(load(PHASE_DIR % [n, n] + f))
			break
	return out


static func level() -> int:
	return int(Game.perm.get("infected", 0))


static func cost(lv: int) -> int:
	return int(LEVELS[clampi(lv, 1, MAX)].cost)


static func gun(lv: int) -> Dictionary:
	return LEVELS[clampi(lv, 1, MAX)]


static func gun_tex(lv: int) -> Texture2D:
	return load(GUN_DIR + "guns_elements/gun_%d.png" % clampi(lv, 1, MAX))


static func shot_tex(lv: int) -> Texture2D:
	return load(GUN_DIR + "guns_elements/shoot_%d.png" % clampi(lv, 1, MAX))


## Grip / muzzle (gun) and head (shot) in image px, from guns.json.
static func points() -> Dictionary:
	if _points.is_empty():
		_points = JSON.parse_string(FileAccess.get_file_as_string(GUN_DIR + "guns.json"))
	return _points


## Saves from the 10-level lab: level 1..10 -> gun 1..5.
static func from_old_level(old: int) -> int:
	return 0 if old <= 0 else clampi(ceili(old / 2.0), 1, MAX)


## Seconds a mutation lasts.
static func duration(lv: int) -> float:
	return 8.0 + 1.5 * maxi(lv - 1, 0)


static func can_buy() -> bool:
	var lv := level()
	return lv < MAX and Game.bank >= cost(lv + 1)


## Buy the next gun. True when it was bought.
static func buy() -> bool:
	var lv := level()
	if lv >= MAX or Game.bank < cost(lv + 1):
		return false
	Game.bank -= cost(lv + 1)
	Game.perm.infected = lv + 1
	Game.save()
	return true
