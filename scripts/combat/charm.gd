class_name Charm
extends RefCounted
## Charmed status of an alien (the girl's Heart Shot, HeartShotAbility): for a few
## seconds it fights for the crew. While charmed (Enemy.charm) its own AI, its touch and
## the crew's weapons leave it alone (targetable off); it hunts the nearest hostile alien
## and bites it, or trails the astronaut when none is near. Bosses and anchored
## objectives cannot be charmed: bosses are slowed instead.

const MAX_ACTIVE := 3  # charmed aliens at once (the oldest ones keep theirs)
const SEEK_R := 170.0  # hunts hostile aliens this close to it
const RETARGET := 0.4  # seconds between looking for a new victim
const CHASE := 1.35  # its speed while hunting (x its own)
const BITE_EVERY := 0.45
const BITE_DMG := 1.6  # x the crew's base damage per bite
const FOLLOW_GAP := 34.0  # no victim: stays this close to the astronaut
const BOSS_SLOW := 2.0  # seconds a boss is slowed by a heart
const COLOR := Color("ff6bc7")
const TINT := Color(1.5, 0.75, 1.35)
const GROUP := "charmed"

var enemy: Enemy
var time_left := 0.0
var target: Enemy
var _look_t := 0.0
var _bite_t := 0.0
var _tint := Color.WHITE  # the alien's own tint, given back at the end
var _glow: HeartSparkles  # tiny hearts rising off it while charmed


## Charms `e` for `secs` (refreshes an alien already charmed). False when it cannot be
## charmed (bosses get slowed, objectives nothing, or too many charmed already).
static func apply(e: Enemy, secs: float) -> bool:
	if e == null or e.dead:
		return false
	if e.charm != null:
		e.charm.time_left = maxf(e.charm.time_left, secs)
		return true
	if e.is_boss:
		e.slow_t = maxf(e.slow_t, BOSS_SLOW)
		Game.world.burst(e.hit_center(), COLOR, 10, 60.0, 0.4, 2.0)
		return false
	if e.anchored or not e.targetable:
		return false
	if e.get_tree().get_nodes_in_group(GROUP).size() >= MAX_ACTIVE:
		return false
	var c := Charm.new()
	c.enemy = e
	c.time_left = secs
	c._start()
	e.charm = c
	return true


func _start() -> void:
	enemy.targetable = false
	enemy.lure = null
	enemy.add_to_group(GROUP)
	_tint = enemy.tint
	enemy.tint = TINT
	_glow = HeartSparkles.aura(enemy, Vector2(0, -enemy.tex_h * enemy.base_scale * 0.5), enemy.radius + 2.0)
	var w := Game.world
	w.ring(enemy.hit_center(), 14.0, COLOR, 0.35, 2.5)
	w.burst(enemy.hit_center(), COLOR, 14, 70.0, 0.45, 2.0)
	HeartSparkles.burst(enemy, Vector2(0, -enemy.tex_h * enemy.base_scale * 0.5), 0.35, 14, 12.0)
	Sfx.play("upgrade", 0.1, -6.0)


## This frame's velocity (Enemy._physics_process asks it instead of its AI).
func steer(delta: float) -> Vector2:
	time_left -= delta
	if time_left <= 0.0:
		end()
		return Vector2.ZERO
	_look_t -= delta
	_bite_t -= delta
	if not is_instance_valid(target):
		target = null  # its victim died (freed): never hand a freed node to a typed call
	if _look_t <= 0.0 or not _hostile(target):
		_look_t = RETARGET
		target = _nearest_hostile()
	if target == null:
		var to_p := enemy.player().global_position - enemy.global_position
		return Vector2.ZERO if to_p.length() < FOLLOW_GAP else to_p.normalized() * enemy.speed
	var to_t := target.global_position - enemy.global_position
	if to_t.length() <= enemy.radius + target.radius + 3.0:
		if _bite_t <= 0.0:
			_bite(target, to_t)
		return Vector2.ZERO
	return to_t.normalized() * enemy.speed * CHASE


func _bite(victim: Enemy, dir: Vector2) -> void:
	_bite_t = BITE_EVERY
	enemy.squash = Vector2(1.25, 0.8)
	victim.take_damage(float(Game.stats.damage) * BITE_DMG, dir.normalized())
	Game.world.burst(victim.hit_center(), COLOR, 5, 45.0, 0.25, 1.5)


## `e` must be null or a live node (the caller drops freed ones first).
func _hostile(e: Enemy) -> bool:
	return e != null and not e.dead and e.targetable and e.charm == null


func _nearest_hostile() -> Enemy:
	var best: Enemy = null
	var best_d := SEEK_R
	for e in Game.world.enemies_near(enemy.global_position, SEEK_R):
		if e == enemy or not _hostile(e):
			continue
		var d := e.global_position.distance_to(enemy.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best


## The charm wears off: the alien is hostile (and a target) again.
func end() -> void:
	if enemy.charm != self:
		return
	enemy.charm = null
	enemy.remove_from_group(GROUP)
	enemy.tint = _tint
	enemy.targetable = not enemy.dead
	if is_instance_valid(_glow):
		_glow.stop()
	Game.world.burst(enemy.hit_center(), COLOR, 8, 50.0, 0.35, 1.5)
