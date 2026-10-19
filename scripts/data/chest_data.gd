class_name ChestData
extends RefCounted
## Exploration chests (Explore maps, arena ArenaChest): standing next to one for OPEN_TIME
## opens it and grants its perk for the rest of the run. Art: assets/sprites/chests/
## chest_<n>.png (closed) and chest_<n>_open.png (open) from tools/make_chests.py
## (tools/chests2_ref.webp; n = index + 1, same order as CHESTS). Each perk matches its
## chest's picture. One-off parts happen in `apply`; the ones that keep working (regen,
## cupid hearts, rocket pod, toxic aura, vortex) are levels in the player's ChestPerks node.
## `weight` = how often that chest shows up (rarer chests carry stronger perks).

const OPEN_TIME := 5.0  # seconds standing next to a chest to open it
const OPEN_R := 40.0  # how close the astronaut must stand (world units) = its ring
const DIR := "res://assets/sprites/chests/"
const MAX_UPGRADE := 5  # UpgradeData levels; past it the chest gives its fallback

const CHESTS := [
	{"id": "medkit", "name": "FIELD MEDKIT", "desc": "Full heal, then +1% health every 2 s", "color": Color("ff4a5a"), "weight": 2.5},
	{"id": "shield", "name": "ION BUBBLE", "desc": "+1 Ion Shield level: hits pop a bubble", "color": Color("41a6f6"), "weight": 2.0},
	{"id": "ammo", "name": "HEAVY ROUNDS", "desc": "+20% damage, shots pierce +1 alien", "color": Color("ffcd3a"), "weight": 2.5},
	{"id": "xp", "name": "XP SURGE", "desc": "Instant LEVEL UP and a burst of gems", "color": Color("c95cff"), "weight": 2.0},
	{"id": "speed", "name": "SPRINT CORE", "desc": "+15% speed, BLAST recharges 25% faster", "color": Color("7dff3a"), "weight": 2.5},
	{"id": "coins", "name": "JACKPOT", "desc": "Coin shower, +1 coin from every alien", "color": Color("ffb020"), "weight": 2.0},
	{"id": "heart", "name": "CUPID CORE", "desc": "+20 max HP; a heart charms an alien every 9 s", "color": Color("ff6ab4"), "weight": 1.5},
	{"id": "drone", "name": "DRONE BAY", "desc": "+1 Scrub-Bot level: a drone fights by you", "color": Color("5fd4ff"), "weight": 1.5},
	{"id": "rocket", "name": "ROCKET POD", "desc": "5 homing rockets burst out every 5 s", "color": Color("ff5a3a"), "weight": 1.2},
	{"id": "magnet", "name": "MEGA MAGNET", "desc": "+1 Coin Magnet level, pulls in everything now", "color": Color("a7f070"), "weight": 2.0},
	{"id": "hazmat", "name": "HAZMAT CORE", "desc": "Toxic aura burns close aliens; hazards hurt half", "color": Color("d4ff3a"), "weight": 1.5},
	{"id": "vortex", "name": "VOID VORTEX", "desc": "Every 8 s a vortex sucks in a pack and implodes", "color": Color("b05cff"), "weight": 1.0},
]


static func tex(i: int) -> Texture2D:
	return load(DIR + "chest_%d.png" % (i + 1))


static func open_tex(i: int) -> Texture2D:
	var p := DIR + "chest_%d_open.png" % (i + 1)
	return load(p) if ResourceLoader.exists(p) else tex(i)


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
	var id := str(CHESTS[i].id)
	match id:
		"medkit":
			s.hp = s.max_hp
		"shield":
			if not _upgrade("shield"):
				_more_hp(25.0)
		"ammo":
			s.damage = float(s.damage) * 1.2
			s.pierce = int(s.pierce) + 1
		"xp":
			for k in 6:
				_drop_xp(w, at)
			if w.survival != null:
				w.survival.collect("golden_carrot", 0, at)
		"speed":
			s.move_speed = float(s.move_speed) * 1.15
			s.blast_cooldown = float(s.blast_cooldown) * 0.75
		"coins":
			w.drop_pickups(at, 22, 0.0)
			s.coin_bonus = int(s.get("coin_bonus", 0)) + 1
		"heart":
			_more_hp(20.0)
		"drone":
			if not _upgrade("orbiters") and not _upgrade("hunter"):
				s.damage = float(s.damage) * 1.15
		"magnet":
			_upgrade("magnet")
			if w.survival != null:
				w.survival.collect("magnet", 0, at)
		"hazmat":
			s.hazard_mult = float(s.get("hazard_mult", 1.0)) * 0.5
	if ChestPerks.KINDS.has(id) and w.player != null:
		ChestPerks.of(w.player).add(id)
	if w.player != null:
		w.player.refresh_upgrades()
	Game.hp_changed.emit()


## One more level of an upgrade (false when it is already at the top).
static func _upgrade(id: String) -> bool:
	if int(Game.upgrades.get(id, 0)) >= MAX_UPGRADE:
		return false
	Game.take_upgrade(id)
	return true


static func _more_hp(v: float) -> void:
	var s := Game.stats
	s.max_hp = float(s.max_hp) + v
	s.hp = minf(float(s.hp) + v, float(s.max_hp))


static func _drop_xp(w: GameWorld, at: Vector2) -> void:
	if w.survival != null:
		w.survival._drop("xp", at + Vector2(randf_range(-14, 14), randf_range(-8, 8)), 8)
