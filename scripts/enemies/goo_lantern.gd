extends Enemy
## GOO LANTERN ORBITER (world 4): a glowing little flame in a purple saucer, the horde's
## HEALER. It hangs back behind the other aliens and, every HEAL_EVERY seconds, sends
## pink beams to up to HEAL_MAX wounded aliens near it, healing each HEAL_SHARE of its
## health (it can't heal bosses or itself). When nobody needs healing it puffs a
## bubble at you (EnemyShot style "lantern"). Kill it first, or the fight drags on.
## Its dome cracks and the flame drips away into a puddle (the set's "splat").

const HEAL_EVERY := 2.4
const HEAL_R := 120.0
const HEAL_MAX := 3
const HEAL_SHARE := 0.3
const KEEP := 130.0
const BUBBLE_SPEED := 90.0

var _beams: Array = []  # [target position, life] drawn as pink beams


func _init_ai() -> void:
	state = "hide"
	state_t = randf_range(1.0, HEAL_EVERY)


func _ai(delta: float) -> Vector2:
	state_t -= delta
	air = 9.0 + sin(t * 2.0 + phase) * 3.0
	var to_p := _to_player()
	for b: Array in _beams:
		b[1] = float(b[1]) - delta
	_beams = _beams.filter(func(b: Array) -> bool: return float(b[1]) > 0.0)
	queue_redraw()
	if state_t <= 0.0:
		state_t = HEAL_EVERY
		if not _heal():
			var d := (to_p + Vector2(0, Player.BODY_Y)).normalized()
			Game.world.spawn_enemy_shot(hit_center() + d * 10.0, d * BUBBLE_SPEED, contact_damage * 0.7, "lantern")
			Sfx.play("pop", 0.2, -8.0)
		squash = Vector2(0.85, 1.15)
	return _hide(to_p) * speed


## Heals the most wounded aliens around. False if nobody needed it.
func _heal() -> bool:
	var hurt: Array[Enemy] = []
	for n in Game.world.enemy_cache:
		var e := n as Enemy
		if e == self or not is_instance_valid(e) or e.dead or e.is_boss or e.hp >= e.max_hp * 0.95:
			continue
		if e.global_position.distance_to(global_position) < HEAL_R:
			hurt.append(e)
	if hurt.is_empty():
		return false
	hurt.sort_custom(func(a: Enemy, b: Enemy) -> bool: return a.hp / a.max_hp < b.hp / b.max_hp)
	for i in mini(HEAL_MAX, hurt.size()):
		var e := hurt[i]
		e.hp = minf(e.max_hp, e.hp + e.max_hp * HEAL_SHARE)
		_beams.append([e, 0.35])
		Game.world.burst(e.hit_center(), Color("ff6fe0"), 6, 40.0, 0.4, 2.0, -30.0)
		Game.world.popup_text(e.hit_center() + Vector2(0, -12), "+", Color("ff6fe0"), 12)
	Sfx.play("heal", 0.1, -8.0)
	return true


## Floats to the far side of the nearest alien, keeping it between itself and you.
func _hide(to_p: Vector2) -> Vector2:
	var p := player().global_position
	var best: Enemy = null
	var bd := 140.0
	for n in Game.world.enemy_cache:
		var e := n as Enemy
		if e == self or not is_instance_valid(e) or e.dead or e.type_id == "goo_lantern":
			continue
		var d := e.global_position.distance_to(global_position)
		if d < bd:
			bd = d
			best = e
	var want := p - to_p.normalized() * KEEP
	if best != null:
		want = best.global_position + (best.global_position - p).normalized() * 34.0
	var v := want - global_position
	return v.normalized() if v.length() > 6.0 else Vector2.ZERO


func _draw() -> void:
	var c := hit_center() - global_position
	for b: Array in _beams:
		var e: Enemy = b[0]
		if not is_instance_valid(e):
			continue
		var a := clampf(float(b[1]) / 0.35, 0.0, 1.0)
		var to := e.hit_center() - global_position
		draw_line(c, to, Color(1.0, 0.45, 0.9, 0.7 * a), 3.0)
		draw_line(c, to, Color(1.0, 0.9, 1.0, 0.9 * a), 1.0)


func _anim_name() -> String:
	return "attack" if not _beams.is_empty() else "walk"


func _on_death() -> void:
	Game.world.burst(hit_center(), Color("c060ff"), 12, 70.0, 0.45, 2.5, 40.0)
	Sfx.play("pop", 0.15, -4.0)
