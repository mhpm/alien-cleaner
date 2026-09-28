extends Node
## Global run state (stats, upgrades, coins) and the persistent save.

signal hp_changed
signal coins_changed

const SAVE_PATH := "user://save.cfg"
const BASE_HP := 70.0
const PERM := {
	"health": {"name": "Suit Plating", "desc": "+20 max health", "max": 5, "cost": 20},
	"power": {"name": "Suds Pressure", "desc": "+12% cleaning power", "max": 5, "cost": 25},
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
var total_xp := 0
var menu_scene := "res://scenes/world_select.tscn"  # where the game / gear screen return
## equipment: owned item levels ({id: level}) and the item worn in each slot
var gear_owned: Dictionary = {}
var gear_equipped: Dictionary = {}

# current run
var stats: Dictionary = {}
var upgrades: Dictionary = {}
var world_index := 0
var room_index := 0
var run_coins := 0
var world: GameWorld = null


func _ready() -> void:
	_default_gear()
	load_save()


func _default_gear() -> void:
	for slot: String in GearData.SLOTS:
		var id := GearData.item_id(slot, "standard")
		if not gear_owned.has(id):
			gear_owned[id] = 0
		if not gear_equipped.has(slot):
			gear_equipped[slot] = id


func new_run(world_i := -1) -> void:
	upgrades = {}
	if world_i >= 0:
		world_index = world_i
	room_index = 0
	run_coins = 0
	# a fresh crew member is fragile: the shop's Suit Plating is what keeps you alive
	var mhp := BASE_HP + 20.0 * int(perm.health)
	stats = {
		"max_hp": mhp, "hp": mhp,
		"damage": 10.0 * (1.0 + 0.12 * int(perm.power)),
		"fire_interval": 0.42, "bullet_speed": 220.0,
		"move_speed": 80.0 * (1.0 + 0.06 * int(perm.speed)),
		"shots": 1, "spread": 0, "ricochet": 0, "pierce": 0,
		"freeze": 0.0, "chain": 0, "crit": 0.05, "crit_mult": 2.0,
		"orbiters": 0, "death_explode": false, "magnet": false,
		"knockback": 60.0, "blast_cooldown": 6.0, "shield": false,
		"weapon": 1,
		"hazard_mult": 1.0, "coin_bonus": 0, "surge": false, "room_heal": 0,
		"infected": int(perm.infected),
	}
	# mutation levels (MUTATION LAB) also make the crew permanently stronger
	var mut := int(perm.infected)
	stats.damage = float(stats.damage) * (1.0 + MutationData.atk_bonus(mut))
	stats.move_speed = float(stats.move_speed) * (1.0 + MutationData.speed_bonus(mut))
	_apply_gear(stats)


# ---------------------------------------------------------------- equipment

func gear_level(id: String) -> int:
	return int(gear_owned.get(id, -1))


func is_owned(id: String) -> bool:
	return gear_owned.has(id)


func equipped_level(slot: String) -> int:
	return gear_level(str(gear_equipped[slot]))


## Totals of every equipped item: {"hp", "spd", "dmg"}.
func gear_totals() -> Dictionary:
	var t := {"hp": 0, "spd": 0.0, "dmg": 0}
	for slot: String in GearData.SLOTS:
		var id := str(gear_equipped[slot])
		var st := GearData.stats(id, gear_level(id))
		t.hp = int(t.hp) + int(st.hp)
		t.spd = float(t.spd) + float(st.spd)
		t.dmg = int(t.dmg) + int(st.dmg)
	return t


func parts_equipped() -> int:
	var n := 0
	for slot: String in GearData.SLOTS:
		if equipped_level(slot) >= 1:
			n += 1
	return n


## Most common non-standard variant worn and how many slots use it.
func set_progress() -> Array:
	var counts := {}
	for slot: String in GearData.SLOTS:
		var v := GearData.variant_of(str(gear_equipped[slot]))
		if v != "standard":
			counts[v] = int(counts.get(v, 0)) + 1
	var best := ""
	var best_n := 0
	for v: String in counts:
		if int(counts[v]) > best_n:
			best_n = int(counts[v])
			best = v
	return [best, best_n]


func gear_power() -> int:
	var p := 0
	for slot: String in GearData.SLOTS:
		var id := str(gear_equipped[slot])
		var lvl := gear_level(id)
		if lvl > 0:
			p += lvl * 10 + GearData.VARIANTS.find(GearData.variant_of(id)) * 5
	return p


func buy_gear(id: String) -> bool:
	if is_owned(id) or bank < GearData.price(id):
		return false
	bank -= GearData.price(id)
	gear_owned[id] = 1
	gear_equipped[GearData.slot_of(id)] = id
	save()
	return true


func upgrade_gear(id: String) -> bool:
	var lvl := gear_level(id)
	if lvl < 0 or lvl >= GearData.MAX_LEVEL or bank < GearData.upgrade_cost(id, lvl):
		return false
	bank -= GearData.upgrade_cost(id, lvl)
	gear_owned[id] = lvl + 1
	save()
	return true


func equip_gear(id: String) -> void:
	if is_owned(id):
		gear_equipped[GearData.slot_of(id)] = id
		save()


func _apply_gear(s: Dictionary) -> void:
	var t := gear_totals()
	s.max_hp = float(s.max_hp) + int(t.hp)
	s.damage = float(s.damage) + int(t.dmg)
	s.move_speed = float(s.move_speed) * (1.0 + float(t.spd))
	for slot: String in GearData.SLOTS:
		var id := str(gear_equipped[slot])
		if gear_level(id) < 1:
			continue
		s.weapon = mini(int(s.weapon) + GearData.weapon_bonus(id), WeaponData.max_level())
		var perk: Dictionary = GearData.PROFILE[GearData.variant_of(id)].perk
		for k: String in perk:
			if perk[k] is bool:
				s[k] = true
			elif k == "hazard_mult":
				s[k] = maxf(0.2, float(s[k]) + float(perk[k]))
			else:
				s[k] = s[k] + perk[k]
	var parts := parts_equipped()
	if parts >= 2:
		s.max_hp = float(s.max_hp) * 1.1
	if parts >= 4:
		s.damage = float(s.damage) * 1.1
	if parts >= 6:
		s.move_speed = float(s.move_speed) * 1.1
	var sp := set_progress()
	if int(sp[1]) >= 6:
		s.surge = true
		s.blast_cooldown = float(s.blast_cooldown) * 0.6
	s.max_hp = roundf(float(s.max_hp))
	s.hp = s.max_hp


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
	return int(def.cost) * (int(perm[id]) + 1)


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


## Coins for beating the current world: the full bonus the first time, a third after.
func clear_bonus(first: bool) -> int:
	var n := 150 * (world_index + 1)
	if not first:
		n = roundi(n / 3.0)
	bank += n
	save()
	return n


func world_unlocked(i: int) -> bool:
	return i <= worlds_cleared


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
	bank += run_coins
	best_room = maxi(best_room, global_room())
	runs += 1
	save()


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "bank", bank)
	cfg.set_value("meta", "perm", perm)
	cfg.set_value("meta", "mutation_phases", 1)
	cfg.set_value("meta", "best_room", best_room)
	cfg.set_value("meta", "runs", runs)
	cfg.set_value("worlds", "cleared", worlds_cleared)
	cfg.set_value("worlds", "best_time", best_time)
	cfg.set_value("worlds", "chests", chests)
	cfg.set_value("meta", "total_xp", total_xp)
	cfg.set_value("gear", "owned", gear_owned)
	cfg.set_value("gear", "equipped", gear_equipped)
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
	total_xp = int(cfg.get_value("meta", "total_xp", 0))
	var owned: Dictionary = cfg.get_value("gear", "owned", {})
	var equipped: Dictionary = cfg.get_value("gear", "equipped", {})
	for k: String in owned:
		gear_owned[k] = int(owned[k])
	for k: String in equipped:
		if gear_owned.has(str(equipped[k])):
			gear_equipped[k] = str(equipped[k])
	Sfx.music_enabled = bool(cfg.get_value("settings", "music", true))
	Sfx.sfx_enabled = bool(cfg.get_value("settings", "sfx", true))
