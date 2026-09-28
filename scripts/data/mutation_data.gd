class_name MutationData
extends RefCounted
## The 5 mutation phases bought in the MUTATION LAB (Game.perm.infected = phase owned).
## Phase 1 unlocks Infected Mode (scripts/infected.gd); every phase after raises its
## stats, adds powers and swaps in a bigger mutant sprite set. The phases also give
## permanent run bonuses (ATK, speed). Art: assets/ui/lab/look_<n>.png
## (tools/mutation_looks/phase_<n>.png).

const MAX := 5
## Mutant sprite set per phase (tools/slice_sprites.py): [first level, set].
## Phases still without their sprite set fall back to the previous one.
const PHASES := [[1, "mutant1"], [2, "mutant2"], [3, "mutant3"], [4, "mutant4"], [5, "mutant5"]]
## Phase that unlocks each power (Infected.has).
const ERUPTION := 2
const HUNGRY := 2
const MISSILES := 3
const AURA := 3
const BROOD := 4
const REGEN := 4
const SHOCK_ROLL := 5
const FRENZY := 5
const APEX := 5
const LEVELS := [
	{},  # 0 = not mutated
	{"cost": 50, "power": "MUTATION", "desc": "Unlocks Infected Mode: tentacle strikes, heavy combo blows, rolling dash."},
	{"cost": 250, "power": "SPIKE ERUPTION", "desc": "Spikes burst under aliens; the meter fills 30% faster."},
	{"cost": 550, "power": "EYE MISSILES", "desc": "Homing eye missiles and a toxic spore cloud."},
	{"cost": 1000, "power": "BROOD BURST", "desc": "Eye brood rams aliens; double missiles; heal 3% HP/s."},
	{"cost": 1800, "power": "APEX FORM", "desc": "Golden apex: triple missiles, spike rolls, kills extend it."},
]


static func level() -> int:
	return int(Game.perm.get("infected", 0))


static func cost(lv: int) -> int:
	return int(LEVELS[clampi(lv, 1, MAX)].cost)


static func has(power_lv: int, lv := -1) -> bool:
	return (level() if lv < 0 else lv) >= power_lv


## Saves from the 10-level lab: level 1..10 -> phase 1..5.
static func from_old_level(old: int) -> int:
	return 0 if old <= 0 else clampi(ceili(old / 2.0), 1, MAX)


## Permanent run bonuses (applied in Game.new_run): +5% ATK and +1.6% speed per phase.
static func atk_bonus(lv: int) -> float:
	return 0.05 * lv


static func speed_bonus(lv: int) -> float:
	return 0.016 * lv


## Mutant damage multiplier (Infected.power()).
static func power(lv: int) -> float:
	return 1.6 + 0.27 * maxi(lv - 1, 0)


## Seconds a mutation lasts.
static func duration(lv: int) -> float:
	return 8.0 + 1.8 * maxi(lv - 1, 0)


## Aura size: grows every phase, a lot at APEX FORM.
static func look_scale(lv: int) -> float:
	return 1.0 + 0.045 * maxi(lv - 1, 0) + (0.08 if lv >= APEX else 0.0)


## The in-game mutant's sprite set at mutation level `lv`.
static func sprite_set(lv: int) -> String:
	var best := "mutant1"
	for ph: Array in PHASES:
		if lv >= int(ph[0]) and Art.has_set(str(ph[1])):
			best = str(ph[1])
	return best


static func can_buy() -> bool:
	var lv := level()
	return lv < MAX and Game.bank >= cost(lv + 1)


## Buy the next phase. True when it was bought.
static func buy() -> bool:
	var lv := level()
	if lv >= MAX or Game.bank < cost(lv + 1):
		return false
	Game.bank -= cost(lv + 1)
	Game.perm.infected = lv + 1
	Game.save()
	return true
