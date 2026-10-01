class_name OrbitRaider
extends Enemy
## Shared saucer AI. The horde version cannot summon or enrage.
## Boss profile is supplied by boss_orbit_warden.gd / EnemyData's boss flag.

const GREEN := Color("c8ff3a")
const BOSS_PATTERN := ["volley", "beam", "volley", "summon", "beam"]
const MINION_CAP := 6

var attack_i := 0
var furious := false
var shots_left := 0
var shot_t := 0.0
var minions: Array[Enemy] = []
var owned_shots: Array[EnemyShot] = []
var strikes: Array[OrbitStrike] = []


func _init_ai() -> void:
	state = "move"
	state_t = 1.4 if is_boss else randf_range(2.0, 3.5)
	if is_boss:
		Sfx.play("roar", 0.0)


func _ai(delta: float) -> Vector2:
	state_t -= delta
	air = (10.0 if is_boss else 6.0) + sin(t * 2.5 + phase) * 2.0
	var to_p := _to_player()
	if state == "move" and to_p.x != 0.0:
		face = signf(to_p.x)
	if is_boss and not furious and hp <= max_hp * 0.5:
		furious = true
		state = "roar"
		state_t = 1.3
		alert.visible = false
		Game.world.hud.banner("ORBIT OVERLOAD!", GREEN, 32, 1.3)
		Game.world.ring(hit_center(), 42.0, GREEN, 0.6, 3.0)
		Sfx.play("roar", 0.0, 2.0)
	match state:
		"move":
			if state_t <= 0.0 and to_p.length() < 220.0:
				_begin_attack()
				return Vector2.ZERO
			return _hover(to_p)
		"charge":
			if state_t <= 0.0:
				state = "fire"
				shots_left = (3 if furious else 2) if is_boss else 1
				shot_t = 0.0
				alert.visible = false
		"fire":
			shot_t -= delta
			if shot_t <= 0.0:
				_fire_volley()
				shots_left -= 1
				shot_t = 0.32
				if shots_left <= 0:
					_rest()
		"beam", "roar":
			if state_t <= 0.0:
				_rest()
		"summon":
			if state_t <= 0.0:
				_summon()
				_rest()
	return Vector2.ZERO


func _hover(to_p: Vector2) -> Vector2:
	var dist := to_p.length()
	var toward := 1.0 if dist > 130.0 else (-1.0 if dist < 85.0 else 0.0)
	var dir := to_p.normalized()
	var v := (dir * toward + dir.orthogonal() * sin(t * 0.6 + phase)).normalized() * speed
	var fence := Game.world.survival.fence if Game.world.survival != null else null
	if is_instance_valid(fence) and not fence.holds(global_position + v * 0.3, radius):
		v = (fence.global_position - global_position).normalized() * speed
	return v


func _begin_attack() -> void:
	var next := "beam" if attack_i % 3 == 2 else "volley"
	if is_boss:
		next = str(BOSS_PATTERN[attack_i % BOSS_PATTERN.size()])
	attack_i += 1
	match next:
		"volley":
			state = "charge"
			state_t = 0.85 if is_boss else 1.0
			aim = (player().global_position + Vector2(0, Player.BODY_Y) - hit_center()).normalized()
			face = signf(aim.x) if aim.x != 0.0 else face
			alert.visible = true
			Game.world.telegraph_line(hit_center(), aim, 170.0, 12.0, state_t / aggro)
			Sfx.play("charge", 0.1, -6.0)
		"beam":
			state = "beam"
			state_t = 1.5
			var center := _safe_ground(player().global_position)
			_strike(center)
			if is_boss:
				var side := _to_player().normalized().orthogonal() * (60.0 if furious else 72.0)
				_strike(_safe_ground(center + side))
				if furious:
					_strike(_safe_ground(center - side))
		"summon":
			state = "summon"
			state_t = 0.9
			Sfx.play("spawn", 0.1, -3.0)


func _rest() -> void:
	state = "move"
	state_t = (0.85 if furious else 1.4) if is_boss else randf_range(2.8, 4.0)
	alert.visible = false


func _fire_volley() -> void:
	# Lock the direction during the warning: it never snaps to the player at firing.
	var n := (7 if furious else 5) if is_boss else 1
	# Prune in place: freed nodes cannot be passed to a typed filter callback.
	for i in range(owned_shots.size() - 1, -1, -1):
		if not is_instance_valid(owned_shots[i]):
			owned_shots.remove_at(i)
	for i in n:
		var dir := aim.rotated((i - (n - 1) * 0.5) * 0.2)
		var s := Game.world.spawn_enemy_shot(hit_center() + dir * 12.0,
			dir * (100.0 if is_boss else 75.0), contact_damage * 0.65, "orbit_plasma")
		s.life = 2.8
		owned_shots.append(s)
	Sfx.play("zap", 0.1, -6.0)
	squash = Vector2(1.12, 0.9)


func _safe_ground(at: Vector2) -> Vector2:
	var bounds := Game.world.room.bounds().grow(-28.0)
	var safe := at.clamp(bounds.position, bounds.end)
	var fence := Game.world.survival.fence if Game.world.survival != null else null
	if is_instance_valid(fence) and not fence.holds(safe, 28.0):
		safe = fence.global_position + (safe - fence.global_position).limit_length(maxf(0.0, fence.radius - 28.0))
	return safe


func _strike(at: Vector2) -> void:
	for i in range(strikes.size() - 1, -1, -1):
		if not is_instance_valid(strikes[i]):
			strikes.remove_at(i)
	var strike := OrbitStrike.new()
	strike.position = at
	strike.caster = self
	strike.radius = 28.0 if is_boss else 17.0
	strike.damage = contact_damage * (0.9 if is_boss else 0.55)
	# Absolute warning duration: world aggro never shortens the ground escape window.
	strike.warning_time = 1.1 if is_boss else 1.35
	Game.world.effects.add_child(strike)
	strikes.append(strike)


func _summon() -> void:
	if not is_boss:
		return
	for i in range(minions.size() - 1, -1, -1):
		if not is_instance_valid(minions[i]) or minions[i].dead:
			minions.remove_at(i)
	var count := mini((4 if furious else 3), MINION_CAP - minions.size())
	var survival := Game.world.survival
	var hp_k := survival._hp_mult() if survival != null else 1.0
	var dmg_k := survival._dmg_mult() if survival != null else 1.0
	for i in count:
		var at := _safe_ground(global_position + Vector2.from_angle(TAU * i / maxf(count, 1)) * 55.0)
		var child := Game.world.spawn_enemy("orbit_spawn", at, hp_k, 1.0, false, false, dmg_k)
		minions.append(child)
	Game.world.ring(global_position, 55.0, GREEN, 0.5, 2.0)


func _anim_name() -> String:
	if hurt_t > 0.0:
		return "hurt"
	match state:
		"charge": return "charge"
		"fire": return "fire"
		"beam", "summon": return "summon"
	return "fury" if furious else "walk"


func _on_death() -> void:
	# Only this creature's effects are removed; other bosses' attacks stay intact.
	for strike in strikes:
		if is_instance_valid(strike):
			strike.queue_free()
	for shot in owned_shots:
		if is_instance_valid(shot):
			shot.queue_free()
	for child in minions:
		if is_instance_valid(child) and not child.dead:
			child.queue_free()
	Game.world.ring(hit_center(), 30.0 if is_boss else 15.0, GREEN, 0.4, 2.0)
