class_name BossBase
extends Enemy
## What every final boss shares (BIG RED, HIVE QUEEN): tough whatever the build, held
## in the BossFence, and a few helpers for their attacks.
##  - health sized to the astronaut's damage per second when it arrives (about
##    TARGET_SECS of steady hits, never below its own base health)
##  - no single hit takes more than HIT_CAP of it (nukes, crits, the mutant)
##  - `armor` (1 = none) scales every hit: furious phases, crystal shields...

const TARGET_SECS := 85.0  # seconds of the astronaut's steady damage its health lasts
const DPS_REALISM := 0.7  # shots missed, moving (slower fire), dodging
const HIT_CAP := 0.025  # the most a single hit can take (share of max health)

var armor := 1.0


## Call first thing in _init_ai.
func _size_to_player(secs := TARGET_SECS) -> void:
	var need := _player_dps() * DPS_REALISM * secs
	if need > max_hp:
		max_hp = need
		hp = max_hp


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
