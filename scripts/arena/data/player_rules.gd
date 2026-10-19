@tool
class_name PlayerRules
extends Resource
## What the crew member may do in one arena (ArenaData.player_rules). The defaults are
## the normal game; change them for missions that are not about fighting:
##   escape   weapon off + ability DASH: run, dodge, reach the exit
##   stealth  weapon off + alien_senses low + hits_to_die: sneak past placed aliens
##   bare     upgrades off + mutation off: only what the arena gives you
## The Player asks these (Player.rules) instead of each mission special-casing it.

## The ability button: the character's own (BLAST + its ability), the plain BLAST, an
## evasive DASH (quick burst, briefly untouchable, no damage) or nothing (hidden).
enum AbilityButton { CHARACTER, BLAST_ONLY, DASH, NONE }

@export_group("Combat")
## Off: no shooting at all and no weapon in the hand (escape / stealth missions).
@export var weapon := true:
	set(value):
		weapon = value
		emit_changed()
@export var ability_button := AbilityButton.CHARACTER:
	set(value):
		ability_button = value
		emit_changed()
## DASH: seconds between two dashes.
@export_range(0.5, 10.0, 0.1) var dash_cooldown := 2.5:
	set(value):
		dash_cooldown = value
		emit_changed()
## Infected mode (the MUTATE button), when the crew has it.
@export var mutation := true:
	set(value):
		mutation = value
		emit_changed()

@export_group("Progress")
## Off: XP gems still drop but no LEVEL UP choices (no upgrades, no drones).
@export var upgrades := true:
	set(value):
		upgrades = value
		emit_changed()

@export_group("Body")
## Walking speed (x the crew member's own).
@export_range(0.3, 2.5, 0.05) var speed_mult := 1.0:
	set(value):
		speed_mult = value
		emit_changed()
## 0 = normal health. N = any hit takes 1/N of the health: dies after N hits.
@export_range(0, 20) var hits_to_die := 0:
	set(value):
		hits_to_die = value
		emit_changed()

@export_group("Stealth")
## How far placed aliens (AlienPack) see and hear the crew member (x their own senses).
@export_range(0.1, 2.0, 0.05) var alien_senses := 1.0:
	set(value):
		alien_senses = value
		emit_changed()


## Everything as in the normal game?
func is_default() -> bool:
	return weapon and ability_button == AbilityButton.CHARACTER and mutation and upgrades \
		and is_equal_approx(speed_mult, 1.0) and hits_to_die == 0 and is_equal_approx(alien_senses, 1.0)


## One line for the editor and the arena's intro ("NO WEAPON · DASH · 3 HITS").
func summary() -> String:
	var bits: Array[String] = []
	if not weapon:
		bits.append("NO WEAPON")
	match ability_button:
		AbilityButton.BLAST_ONLY:
			bits.append("BLAST ONLY")
		AbilityButton.DASH:
			bits.append("DASH")
		AbilityButton.NONE:
			bits.append("NO ABILITY")
	if not mutation:
		bits.append("NO MUTATION")
	if not upgrades:
		bits.append("NO UPGRADES")
	if not is_equal_approx(speed_mult, 1.0):
		bits.append("SPEED x%.2f" % speed_mult)
	if hits_to_die > 0:
		bits.append("%d HIT%s" % [hits_to_die, "S" if hits_to_die != 1 else ""])
	if alien_senses < 0.99:
		bits.append("STEALTH")
	elif alien_senses > 1.01:
		bits.append("ALIENS ALERT")
	return " · ".join(bits)
