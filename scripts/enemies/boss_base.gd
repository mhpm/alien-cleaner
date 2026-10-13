class_name BossBase
extends Enemy
## What every boss shares (final bosses and the mini bosses of wave events): tough
## whatever the build, held in the BossFence, and a few helpers for their attacks.
##  - health sized to the astronaut's damage per second when it arrives (fight_hp):
##    a FINAL boss (the stage's own "boss") lasts about TARGET_SECS of steady hits and
##    never less than its base health; a MINI boss lasts about MINI_SECS whatever its
##    base health (only MINI_FLOOR of it as a floor), so an early mini boss is never as
##    tough as the final one
##  - no single hit takes more than HIT_CAP of it (nukes, crits, the mutant)
##  - `armor` (1 = none) scales every hit: furious phases, crystal shields...

const TARGET_SECS := 85.0  # final boss: seconds of the astronaut's steady damage its health lasts
const MINI_SECS := 45.0  # mini boss: a shorter fight
const MINI_FLOOR := 0.2  # mini boss: never below this share of its base health (a safety net)
## Mini bosses take less damage in their late phases (fury, desperate): on average about
## this much of every hit, so their health is trimmed to keep the fight at MINI_SECS.
const MINI_PHASE_ARMOR := 0.9
const DPS_REALISM := 0.7  # shots missed, moving (slower fire), dodging
const HIT_CAP := 0.025  # the most a single hit can take (share of max health)

var armor := 1.0


## The health a boss gets: `base_hp` (its data x world x clock) against `dps` of the
## astronaut. Pure: tests size every boss of every world with it.
static func fight_hp(base_hp: float, dps: float, mini: bool) -> float:
	if mini:
		return maxf(dps * DPS_REALISM * MINI_SECS * MINI_PHASE_ARMOR, base_hp * MINI_FLOOR)
	return maxf(dps * DPS_REALISM * TARGET_SECS, base_hp)


## True when boss `id` is not the final boss of the running stage (a wave event).
static func is_mini(id: String) -> bool:
	var s := Game.world.survival if Game.world != null else null
	return s != null and str(s.def.get("boss", "")) != id


## Call first thing in _init_ai: sizes its health to the astronaut (fight_hp), then the
## world objectives that weaken bosses.
func _size_to_player() -> void:
	max_hp = fight_hp(max_hp, _player_dps(), is_mini(type_id))
	hp = max_hp
	# world 5: every overheating reactor vented = the forge cooled, bosses arrive weaker
	var ex: Explore = Game.world.explore if Game.world != null else null
	if ex != null and ex.gate_charged():  # world 7: every warp cell taken
		max_hp *= Explore.GATE_HP
		hp = max_hp
		Game.world.popup_text(global_position + Vector2(0, -40), "GATE CHARGED: -%d%% HP" % roundi((1.0 - Explore.GATE_HP) * 100.0), WarpCell.COL, 11)
	if ex != null and ex.forge_cooled():
		max_hp *= Explore.COOLED_HP
		hp = max_hp
		Game.world.popup_text(global_position + Vector2(0, -40), "FORGE COOLED: -%d%% HP" % roundi((1.0 - Explore.COOLED_HP) * 100.0), ReactorCore.COOL, 11)


## The astronaut's damage per second right now: the ARMORY weapon (its level, blaster
## tier, extra shots, crits) plus the Martian UFO's plasma.
static func _player_dps() -> float:
	var s := Game.stats
	var tier := WeaponData.tier(int(s.weapon))
	var shots := int(s.shots) + int(s.spread)  # side shots of the spread rarely all hit
	var crit := 1.0 + float(s.crit) * (float(s.crit_mult) - 1.0)
	var gun_dps := GunData.dps(str(s.get("gun", "pulse")), int(s.get("gun_lv", 1)))
	var dps := float(s.damage) * float(tier.dmg) * gun_dps * shots * (GunFire.BASE_INTERVAL / float(s.fire_interval)) * crit
	var ml := int(s.get("martian", 0))
	if ml > 0:
		var d: Dictionary = UpgradeData.MARTIAN_LV[mini(ml, UpgradeData.MARTIAN_LV.size()) - 1]
		dps += float(s.damage) * 0.75 * int(d.shots) / float(d.rate)
	return dps


func take_damage(amount: float, dir := Vector2.ZERO, crit := false) -> void:
	super.take_damage(minf(amount, max_hp * HIT_CAP) * armor, dir, crit)


func _fence() -> BossFence:
	var s := Game.world.survival
	return s.fence if s != null and is_instance_valid(s.fence) else null


## `p` pulled inside the fence, `margin` clear of it (unchanged without a fence).
func _in_fence(p: Vector2, margin := 10.0) -> Vector2:
	var f := _fence()
	if f == null or f.holds(p, margin):
		return p
	return f.global_position + (p - f.global_position).limit_length(f.radius - margin)


## `n` shots of style `tex` fanning out all round from the boss.
func _ring(n: int, off: float, spd: float, dmg_k := 0.45, tex := "red_blob") -> void:
	var c := hit_center()
	for i in n:
		var d := Vector2.from_angle(off + TAU * i / n)
		Game.world.spawn_enemy_shot(c + d * 12.0, d * spd, contact_damage * dmg_k, tex)
	Sfx.play("spit", 0.05)


## Toughness of the horde right now (minions the boss calls are as strong as it).
func _minion_mults() -> Vector2:
	var s := Game.world.survival
	return Vector2(s._hp_mult(), s._dmg_mult()) if s != null else Vector2.ONE
