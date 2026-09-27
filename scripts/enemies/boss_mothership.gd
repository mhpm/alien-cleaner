extends Enemy
## World 2 final boss THE MOTHERSHIP (room 30): a giant UFO hovering over the arena.
## Laser fans, rotating laser spirals, abduction beams (warning circles on the floor)
## and portals that drop Greenies and Droids. Flies high: touching it does not hurt.
## Enraged under 50% HP: faster, wider fans, triple beams, four-arm spirals.

const PATTERN := ["drift", "volley", "drift", "beam", "summon", "drift", "spiral", "volley", "beam", "drift", "spiral"]
const LASER_SPEED := 120.0
const BEAM_R := 22.0

var pattern_i := 0
var shots_left := 0
var fire_t := 0.0
var spin := 0.0
var drift_dir := 1.0


func _init_ai() -> void:
	state = "intro"
	state_t = 1.0


func _enraged() -> bool:
	return hp < max_hp * 0.5


func _tempo() -> float:
	return 0.72 if _enraged() else 1.0


func _ai(delta: float) -> Vector2:
	state_t -= delta
	air = 18.0 + sin(t * 1.8) * 3.0
	var to_p := _to_player()
	match state:
		"intro", "rest":
			if state_t <= 0.0:
				_next()
			return Vector2.ZERO
		"drift":
			if state_t <= 0.0:
				_next()
			# sweep side to side over the top half of the arena
			if global_position.x < 30.0:
				drift_dir = 1.0
			elif global_position.x > 130.0:
				drift_dir = -1.0
			var target_y := 60.0 + sin(t * 1.3) * 14.0
			return Vector2(drift_dir * speed * 1.4, (target_y - global_position.y) * 2.0) / _tempo()
		"attack":
			# laser fans aimed at the player, several salvos
			face = signf(to_p.x) if to_p.x != 0.0 else face
			fire_t -= delta
			if fire_t <= 0.0 and shots_left > 0:
				shots_left -= 1
				fire_t = 0.38 * _tempo()
				var n := 7 if _enraged() else 5
				var base := (player().global_position + Vector2(0, -6) - hit_center()).angle()
				for i in n:
					_laser(Vector2.from_angle(base + (i - (n - 1) * 0.5) * 0.2))
				squash = Vector2(1.15, 0.9)
				Sfx.play("zap", 0.15, -4.0)
			if shots_left <= 0 and fire_t <= 0.0:
				state = "rest"
				state_t = 0.5 * _tempo()
			return Vector2.ZERO
		"spiral":
			fire_t -= delta
			spin += delta * (2.2 if _enraged() else 1.6)
			if fire_t <= 0.0:
				fire_t = 0.14
				var arms := 4 if _enraged() else 3
				for i in arms:
					_laser(Vector2.from_angle(spin + TAU * i / arms))
				Sfx.play("zap", 0.2, -14.0)
			if state_t <= 0.0:
				state = "rest"
				state_t = 0.6 * _tempo()
			return Vector2.ZERO
	return Vector2.ZERO


func _next() -> void:
	var step: String = PATTERN[pattern_i % PATTERN.size()]
	pattern_i += 1
	match step:
		"drift":
			state = "drift"
			state_t = 1.5 * _tempo()
		"volley":
			state = "attack"
			shots_left = 4 if _enraged() else 3
			fire_t = 0.4
			alert.visible = true
			get_tree().create_timer(0.4).timeout.connect(func() -> void: alert.visible = false)
			Sfx.play("alert", 0.1, -6.0)
		"spiral":
			state = "spiral"
			state_t = 2.6
			spin = randf() * TAU
			Sfx.play("charge", 0.0, -4.0)
		"beam":
			_beams()
			state = "rest"
			state_t = 1.2 * _tempo()
		"summon":
			_summon()
			state = "rest"
			state_t = 0.9


## Abduction beams: warning circles under the player (and around them when enraged),
## then a column of light that hurts anyone still inside.
func _beams() -> void:
	var w := Game.world
	var spots: Array[Vector2] = [player().global_position]
	if _enraged():
		for i in 2:
			spots.append((player().global_position + Vector2.from_angle(randf() * TAU) * randf_range(30.0, 50.0))
					.clamp(Game.world.room.bounds().position + Vector2(14, 14), Game.world.room.bounds().end - Vector2(14, 14)))
	var dmg := contact_damage * 1.1
	for p: Vector2 in spots:
		w.telegraph_circle(p, BEAM_R, 0.95)
		get_tree().create_timer(0.95).timeout.connect(func() -> void:
			if dead or w != Game.world:
				return
			w.ring(p, BEAM_R, Color("a7f070"), 0.35, 3.0, true)
			w.burst(p, Color("a7f070"), 16, 70.0, 0.5, 2.5, -40.0)
			w.burst(p + Vector2(0, -20), Color(1, 1, 1, 0.8), 8, 30.0, 0.4, 2.0, 60.0)
			Sfx.play("zap", 0.1)
			w.shake(0.3)
			if not w.player.dead and w.player.global_position.distance_to(p) < BEAM_R:
				w.player.take_damage(dmg, p))
	Sfx.play("charge", 0.0, -2.0)


## Portals drop reinforcements: Greenies and a Droid (capped).
func _summon() -> void:
	var alive := get_tree().get_nodes_in_group("enemies").size() - 1
	if alive >= 6:
		return
	var ids := ["ufo_alien", "droid", "ufo_alien"]
	if _enraged():
		ids.append("ufo_alien")
	for i in mini(ids.size(), 6 - alive):
		var at := Vector2(30.0 + i * 100.0 / maxf(ids.size() - 1, 1), randf_range(90.0, 130.0))
		_ufo_portal(ids[i], at)
	Sfx.play("roar", 0.1, -6.0)


func _laser(dir: Vector2) -> void:
	Game.world.spawn_enemy_shot(hit_center() + dir * 10.0, dir * LASER_SPEED, contact_damage * 0.6, "ufo")


func _on_death() -> void:
	# the ship breaks apart in a chain of blasts
	var w := Game.world
	var c := hit_center()
	for i in 6:
		get_tree().create_timer(0.1 * i).timeout.connect(func() -> void:
			if w == Game.world:
				var p := c + Vector2(randf_range(-22, 22), randf_range(-14, 14))
				w.burst(p, Color("ffcd75"), 18, 120.0, 0.5, 3.0)
				w.burst(p, Color("ef7d57"), 10, 80.0, 0.6, 3.0)
				Sfx.play("explode", 0.2, -4.0)
				w.shake(0.6))
