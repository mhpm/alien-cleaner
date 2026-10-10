extends Node
## Global run state (stats, upgrades, coins) and the persistent save.

signal hp_changed
signal coins_changed

const SAVE_PATH := "user://save.cfg"
const BASE_HP := 70.0
## ARMORY crew levels: LIFE (perm.health) and ATTACK (perm.power). A level costs
## cost + step * current level coins (step defaults to cost).
const LIFE_STEP := 0.2  # +20% max health per LIFE level
const ATTACK_STEP := 0.1  # +10% damage (every weapon) per ATTACK level
const PERM := {
	"health": {"name": "Life", "desc": "+20% max health", "max": 20, "cost": 50, "step": 100},
	"power": {"name": "Attack", "desc": "+10% damage, every weapon", "max": 20, "cost": 100, "step": 100},
	"speed": {"name": "Jet Boots", "desc": "+6% move speed", "max": 5, "cost": 20},
}

# persistent
var bank := 0
var perm := {"health": 0, "power": 0, "speed": 0, "infected": 0}
var best_room := 0
var runs := 0
## world select: worlds beaten (world i is playable once i worlds are), longest time
## survived per world (seconds), world chests already opened, lifetime XP gems (crew level)
var worlds_cleared := 0
var best_time: Dictionary = {}
var chests: Array = []
## BOSS CHALLENGE (world select, once a world is cleared): fastest time beating each
## world's final boss straight away (seconds, by world index)
var boss_best: Dictionary = {}
## worlds whose BOSS CHALLENGE chest (unlocked by winning the challenge once) was opened
var boss_chests: Array = []
var total_xp := 0
## Android pieces found in arenas (AndroidPart part_id -> true), kept across runs.
var android_parts: Dictionary = {}
var menu_scene := "res://scenes/world_select.tscn"  # where the game / armory return
## ARMORY: weapons owned ({GunData id: level 1-3}) and the one carried into runs
var guns: Dictionary = {"pulse": 1}
var gun := "pulse"
## coins given back for the retired gear system (shown once by the armory screen)
var gear_refund := 0

# current run
var stats: Dictionary = {}
var upgrades: Dictionary = {}
var world_index := 0
var room_index := 0
var run_coins := 0
var boss_rush := false  # this run is a BOSS CHALLENGE: straight to the final boss
var world: GameWorld = null
var playground_active := false  # test runs never write persistent progression


func _ready() -> void:
	load_save()


func new_run(world_i := -1, rush := false) -> void:
	boss_rush = rush
	upgrades = {}
	if world_i >= 0:
		world_index = world_i
	room_index = 0
	run_coins = 0
	stats = base_stats()


## Run stats before any upgrade (ARMORY levels and the equipped weapon included).
func base_stats() -> Dictionary:
	# a fresh crew member is fragile: the ARMORY's LIFE levels are what keep you alive
	# (aliens hit relative to base_hp, so every LIFE level is real extra survival)
	var mhp := roundf(BASE_HP * (1.0 + LIFE_STEP * int(perm.health)))
	return {
		"max_hp": mhp, "hp": mhp, "base_hp": BASE_HP,
		"damage": 10.0 * (1.0 + ATTACK_STEP * int(perm.power)),
		"fire_interval": 0.42, "bullet_speed": 220.0,
		"move_speed": 80.0 * (1.0 + 0.06 * int(perm.speed)),
		"shots": 1, "spread": 0, "ricochet": 0, "pierce": 0,
		"freeze": 0.0, "chain": 0, "crit": 0.05, "crit_mult": 2.0,
		"orbiters": 0, "death_explode": false, "magnet": false,
		"knockback": 60.0, "blast_cooldown": 6.0, "shield": false, "shield_lvl": 0, "martian": 0, "overdrive": 0, "hunter": 0, "bomber": 0,
		"weapon": 1, "gun": gun, "gun_lv": gun_level(gun),
		"hazard_mult": 1.0, "coin_bonus": 0, "room_heal": 0,
		"infected": int(perm.infected),
	}


## Testing (playground): put an upgrade at any level, up or down. Rebuilds the run stats
## from scratch and re-applies every upgrade level by level (life keeps its share).
## Chest perks and crew gifts taken this run are not re-applied.
func set_upgrade_level(id: String, lv: int) -> void:
	var ratio := float(stats.hp) / maxf(float(stats.max_hp), 1.0) if not stats.is_empty() else 1.0
	var keep_weapon := int(stats.get("weapon", 1))
	if lv <= 0:
		upgrades.erase(id)
	else:
		upgrades[id] = lv
	stats = base_stats()
	for u: String in upgrades:
		for k in range(1, int(upgrades[u]) + 1):
			UpgradeData.apply(u, stats, k)
	if not upgrades.has("blaster"):
		stats.weapon = keep_weapon
	stats.hp = float(stats.max_hp) * ratio
	hp_changed.emit()


# ---------------------------------------------------------------- armory

func gun_level(id: String) -> int:
	return int(guns.get(id, 0))


func owns_gun(id: String) -> bool:
	return guns.has(id)


func buy_gun(id: String) -> bool:
	if owns_gun(id) or bank < GunData.price(id):
		return false
	bank -= GunData.price(id)
	guns[id] = 1
	gun = id
	save()
	return true


func upgrade_gun(id: String) -> bool:
	var lv := gun_level(id)
	if lv < 1 or lv >= GunData.MAX_LEVEL or bank < GunData.upgrade_cost(id, lv):
		return false
	bank -= GunData.upgrade_cost(id, lv)
	guns[id] = lv + 1
	save()
	return true


func equip_gun(id: String) -> void:
	if owns_gun(id):
		gun = id
		save()


## Crew POWER (world select / armory): the equipped weapon plus ATTACK and LIFE levels.
func crew_power() -> int:
	return GunData.power(gun, gun_level(gun)) + 12 * int(perm.power) + 8 * int(perm.health)


## True when some weapon, weapon level, ATTACK or LIFE level can be bought right now.
func armory_affordable() -> bool:
	for id: String in GunData.ids():
		if not owns_gun(id):
			if bank >= GunData.price(id):
				return true
		elif gun_level(id) < GunData.MAX_LEVEL and bank >= GunData.upgrade_cost(id, gun_level(id)):
			return true
	for id: String in ["power", "health"]:
		if int(perm[id]) < int(PERM[id].max) and bank >= perm_cost(id):
			return true
	return false


## Coins spent in the retired gear system (CHARACTER screen: 6 slots x 8 variants,
## buy price by variant and upgrades of price * 0.5 * (level + 1); standard items were
## free at level 0 and upgraded from there).
static func _gear_spent(owned: Dictionary) -> int:
	var variants := ["standard", "recon", "heavy", "stealth", "hazard", "exploration", "titan", "final"]
	var prices := [0, 120, 250, 250, 400, 400, 600, 900]
	var total := 0
	for id: String in owned:
		var v := variants.find(id.get_slice("_", 1))
		if v < 0:
			continue
		var lvl := int(owned[id])
		var price: int = prices[v]
		var from := 1
		if price == 0:
			from = 0
		total += price
		for l in range(from, lvl):
			total += int((price if price > 0 else 60) * 0.5 * (l + 1))
	return total


## Enemy HP/damage scale with how deep the player is in the current world
## (WorldData "difficulty" = [start, per room]).
func difficulty() -> float:
	var d: Array = WorldData.world(world_index).get("difficulty", [1.0, 0.08])
	return float(d[0]) + room_index * float(d[1])


## Extra multiplier on every alien's HP and damage in the current world (world 2: 1.2).
func enemy_mult() -> float:
	return float(WorldData.world(world_index).get("enemy_mult", 1.0))


## Room number across worlds (1..30).
func global_room() -> int:
	return WorldData.global_room(world_index, room_index)


func hp_ratio() -> float:
	return float(stats.hp) / float(stats.max_hp)


func add_coins(n: int) -> void:
	run_coins += n
	coins_changed.emit()


func heal(n: float) -> void:
	stats.hp = minf(float(stats.hp) + n, float(stats.max_hp))
	hp_changed.emit()


func take_upgrade(id: String) -> void:
	upgrades[id] = int(upgrades.get(id, 0)) + 1
	UpgradeData.apply(id, stats, int(upgrades[id]))
	hp_changed.emit()


## Power Core pickup / boss reward: raise the blaster one tier (coins if maxed).
func weapon_up() -> bool:
	if int(stats.weapon) >= WeaponData.max_level():
		add_coins(15)
		return false
	take_upgrade("blaster")
	return true


func perm_cost(id: String) -> int:
	var def: Dictionary = PERM[id]
	return int(def.cost) + int(def.get("step", def.cost)) * int(perm[id])


func buy_perm(id: String) -> bool:
	var def: Dictionary = PERM[id]
	if int(perm[id]) >= int(def.max) or bank < perm_cost(id):
		return false
	bank -= perm_cost(id)
	perm[id] = int(perm[id]) + 1
	save()
	return true


## Record how long this world was survived (seconds) and whether it was beaten.
func record_world(secs: float, cleared: bool) -> void:
	var k := str(world_index)
	best_time[k] = maxf(float(best_time.get(k, 0.0)), secs)
	if cleared:
		worlds_cleared = maxi(worlds_cleared, world_index + 1)


## A BOSS CHALLENGE won in `secs`: true when it beats the world's record (saved).
func record_boss(secs: float) -> bool:
	var k := str(world_index)
	var old := float(boss_best.get(k, 0.0))
	var better := old <= 0.0 or secs < old
	if better:
		boss_best[k] = secs
	return better


## Coins for a won BOSS CHALLENGE (twice as many for a new record).
func boss_bonus(record: bool) -> int:
	var n := 75 * (world_index + 1) * (2 if record else 1)
	bank += n
	save()
	return n


## Coins inside the BOSS CHALLENGE chest of world `i`.
func boss_chest_coins(i: int) -> int:
	return 250 * (i + 1)


## Coins for beating the current world: the full bonus the first time, a third after.
func clear_bonus(first: bool) -> int:
	var n := 150 * (world_index + 1)
	if not first:
		n = roundi(n / 3.0)
	bank += n
	save()
	return n


## Debug builds (editor / dev runs): every world in WorldData is open, the new ones too.
## Turn it off with the project setting debug/worlds/unlock_all = false; Release builds
## always use the normal unlocking (clear a world to open the next).
const UNLOCK_ALL := "debug/worlds/unlock_all"


func world_unlocked(i: int) -> bool:
	if _unlock_all():
		return true
	return i <= worlds_cleared


## BOSS CHALLENGE of world i open: after clearing it, or always in debug builds (same
## setting debug/worlds/unlock_all as world_unlocked).
func boss_challenge_unlocked(i: int) -> bool:
	return _unlock_all() or worlds_cleared > i


func _unlock_all() -> bool:
	return OS.is_debug_build() and bool(ProjectSettings.get_setting(UNLOCK_ALL, true))


## Crew level from lifetime XP gems: [level, progress 0..1 to the next one].
func crew_level() -> Array:
	var lv := 1
	var need := 60
	var xp := total_xp
	while xp >= need:
		xp -= need
		lv += 1
		need = 60 + (lv - 1) * 40
	return [lv, float(xp) / float(need)]


func end_run() -> void:
	if playground_active:
		return
	bank += run_coins
	best_room = maxi(best_room, global_room())
	runs += 1
	save()


func save() -> void:
	if playground_active:
		return
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "bank", bank)
	cfg.set_value("meta", "perm", perm)
	cfg.set_value("meta", "mutation_phases", 1)
	cfg.set_value("meta", "best_room", best_room)
	cfg.set_value("meta", "runs", runs)
	cfg.set_value("worlds", "cleared", worlds_cleared)
	cfg.set_value("worlds", "best_time", best_time)
	cfg.set_value("worlds", "chests", chests)
	cfg.set_value("worlds", "boss_best", boss_best)
	cfg.set_value("worlds", "boss_chests", boss_chests)
	cfg.set_value("meta", "total_xp", total_xp)
	cfg.set_value("android", "parts", android_parts)
	cfg.set_value("armory", "guns", guns)
	cfg.set_value("armory", "gun", gun)
	cfg.set_value("settings", "music", Sfx.music_enabled)
	cfg.set_value("settings", "sfx", Sfx.sfx_enabled)
	cfg.save(SAVE_PATH)


func load_save() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	bank = int(cfg.get_value("meta", "bank", 0))
	var p: Dictionary = cfg.get_value("meta", "perm", {})
	for k: String in perm:
		perm[k] = int(p.get(k, 0))
	# the lab went from 10 mutation levels to 5 phases
	if int(cfg.get_value("meta", "mutation_phases", 0)) == 0:
		perm.infected = MutationData.from_old_level(int(perm.infected))
	best_room = int(cfg.get_value("meta", "best_room", 0))
	runs = int(cfg.get_value("meta", "runs", 0))
	worlds_cleared = int(cfg.get_value("worlds", "cleared", 0))
	best_time = cfg.get_value("worlds", "best_time", {})
	chests = cfg.get_value("worlds", "chests", [])
	boss_best = cfg.get_value("worlds", "boss_best", {})
	boss_chests = cfg.get_value("worlds", "boss_chests", [])
	total_xp = int(cfg.get_value("meta", "total_xp", 0))
	android_parts = cfg.get_value("android", "parts", {})
	var owned: Dictionary = cfg.get_value("armory", "guns", {})
	for k: String in owned:
		if GunData.ids().has(k):
			guns[k] = clampi(int(owned[k]), 1, GunData.MAX_LEVEL)
	var g := str(cfg.get_value("armory", "gun", "pulse"))
	gun = g if guns.has(g) else "pulse"
	Sfx.music_enabled = bool(cfg.get_value("settings", "music", true))
	Sfx.sfx_enabled = bool(cfg.get_value("settings", "sfx", true))
	if not cfg.has_section("armory"):
		# the CHARACTER gear screen became the ARMORY: its coins come back once
		gear_refund = _gear_spent(cfg.get_value("gear", "owned", {}))
		bank += gear_refund
		save()
