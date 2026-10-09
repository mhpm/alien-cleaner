extends BossBase
## THE MOTHERSHIP, world 6 (GENE VAULT) final boss: the giant UFO that seeded the cloning
## vats, hovering over the fight (flies high: touching it does not hurt). It drifts round
## the top of the BossFence and takes turns at:
##  - volley: laser fans aimed at the astronaut (an alert "!" first)
##  - spiral: rotating arms of lasers (walk round with them)
##  - beams: abduction circles marked under / around you, then columns of light
##  - summon: portals drop specimens from the vats (capped, MAX_MINIONS of its own)
##  - tractor: a lane locks onto you and the tractor beam PULLS you towards the ship
##    (slower than you walk: run against it), then the ship lets out a ring of lasers
## Under 50% (FURY_ARMOR): a roar wipes the shots, everything faster, triple beams, four
## spiral arms. Under 20%: five arms, two summons in a row, shorter pauses.
## Health sized to the astronaut like every final boss (BossBase).

const PATTERN := ["drift", "volley", "drift", "beam", "summon", "drift", "tractor", "spiral", "volley", "beam", "drift", "spiral"]
const LASER_SPEED := 120.0
const BEAM_R := 22.0
const ORBIT_R := 120.0  # drift round the fence centre at this distance, on its top half
const MAX_MINIONS := 6
const SUMMON_IDS := ["jelly_pod", "tentacle_pod", "octo_wizard", "mini_slime", "mini_slime"]
const PULL := 52.0  # tractor beam pull (the astronaut walks at ~80)
const TRACTOR_LOCK := 0.8
const TRACTOR_TIME := 1.6
const FURY_ARMOR := 0.75

var pattern_i := 0
var shots_left := 0
var fire_t := 0.0
var spin := 0.0
var orbit_a := -PI * 0.5
var furious := false
var desperate := false
var minions: Array[Enemy] = []


func _init_ai() -> void:
	_size_to_player()
	state = "intro"
	state_t = 1.2


func _tempo() -> float:
	return 0.6 if desperate else (0.75 if furious else 1.0)


func _centre() -> Vector2:
	var f := _fence()
	return f.global_position if f != null else player().global_position


func _ai(delta: float) -> Vector2:
	state_t -= delta
	air = 18.0 + sin(t * 1.8) * 3.0
	if not furious and hp < max_hp * 0.5:
		_enrage()
	elif furious and not desperate and hp < max_hp * 0.2:
		desperate = true
		Game.world.hud.banner("MOTHERSHIP CRITICAL!", Color("ff4fd8"), 24, 1.0)
		Sfx.play("alert", 0.0, 0.0)
	var to_p := _to_player()
	face = signf(to_p.x) if absf(to_p.x) > 2.0 else face
	match state:
		"intro", "rest", "roar":
			if state_t <= 0.0:
				_next()
			return _hover(delta, 0.6)
		"drift":
			if state_t <= 0.0:
				_next()
			return _hover(delta, 1.6)
		"attack":
			fire_t -= delta
			if fire_t <= 0.0 and shots_left > 0:
				shots_left -= 1
				fire_t = 0.38 * _tempo()
				var n := 7 if furious else 5
				var base := (player().global_position + Vector2(0, -6) - hit_center()).angle()
				for i in n:
					_laser(Vector2.from_angle(base + (i - (n - 1) * 0.5) * 0.2))
				squash = Vector2(1.15, 0.9)
				Sfx.play("zap", 0.15, -4.0)
			if shots_left <= 0 and fire_t <= 0.0:
				_rest(0.5)
			return _hover(delta, 0.3)
		"spiral":
			fire_t -= delta
			spin += delta * (2.2 if furious else 1.6)
			if fire_t <= 0.0:
				fire_t = 0.14
				var arms := 5 if desperate else (4 if furious else 3)
				for i in arms:
					_laser(Vector2.from_angle(spin + TAU * i / arms))
				Sfx.play("zap", 0.2, -14.0)
			if state_t <= 0.0:
				_rest(0.6)
			return Vector2.ZERO
		"tractor_lock":
			if state_t <= 0.0:
				state = "tractor"
				state_t = TRACTOR_TIME
				Sfx.play("charge", 0.0, 0.0)
			return Vector2.ZERO
		"tractor":
			var p := player()
			var d := hit_center() - p.global_position
			if not p.dead and d.length() > 26.0:
				p.knock = d.normalized() * PULL
			if randf() < delta * 30.0:
				var k := randf()
				Game.world.burst(p.global_position.lerp(hit_center(), k), Color("a7f070"), 1, 20.0, 0.4, 2.0)
			if state_t <= 0.0:
				_ring(12 if furious else 9, randf() * TAU, LASER_SPEED, 0.6, "ufo")
				Game.world.ring(hit_center(), 40.0, Color("a7f070"), 0.4, 3.0)
				_rest(0.7)
			return Vector2.ZERO
	return Vector2.ZERO


## Drift round the top half of the fence (or of the astronaut without one).
func _hover(delta: float, pace: float) -> Vector2:
	orbit_a += delta * 0.45 * pace / _tempo()
	var a := -PI * 0.5 + sin(orbit_a) * 1.1  # swings between upper left and upper right
	var target := _in_fence(_centre() + Vector2.from_angle(a) * ORBIT_R, 40.0)
	return (target - global_position).limit_length(speed * 1.4 * pace)


func _rest(secs: float) -> void:
	state = "rest"
	state_t = secs * _tempo()


func _next() -> void:
	var step: String = PATTERN[pattern_i % PATTERN.size()]
	pattern_i += 1
	match step:
		"drift":
			state = "drift"
			state_t = 1.5 * _tempo()
		"volley":
			state = "attack"
			shots_left = 4 if furious else 3
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
			_rest(1.2)
		"summon":
			_summon()
			if desperate:
				get_tree().create_timer(1.2).timeout.connect(func() -> void:
					if not dead:
						_summon())
			_rest(0.9)
		"tractor":
			state = "tractor_lock"
			state_t = TRACTOR_LOCK
			var to := player().global_position - hit_center()
			Game.world.telegraph_line(hit_center(), to.normalized(), to.length(), 30.0, TRACTOR_LOCK)
			Sfx.play("alert", 0.1, -4.0)


## Abduction beams: warning circles under the astronaut (and around when furious), then
## a column of light that hurts anyone still inside.
func _beams() -> void:
	var w := Game.world
	var spots: Array[Vector2] = [player().global_position]
	if furious:
		for i in 2:
			spots.append(w.room.open_near(_in_fence(player().global_position + Vector2.from_angle(randf() * TAU) * randf_range(30.0, 50.0), 16.0)))
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


## Portals drop specimens from the vats, never more than MAX_MINIONS of its own alive.
func _summon() -> void:
	minions.assign(minions.filter(func(e: Variant) -> bool: return is_instance_valid(e) and not (e as Enemy).dead))
	var room_left := MAX_MINIONS - minions.size()
	if room_left <= 0:
		return
	var w := Game.world
	var m := _minion_mults()
	var n := mini(room_left, 4 if furious else 3)
	for i in n:
		var id: String = SUMMON_IDS[randi() % SUMMON_IDS.size()]
		var at := w.room.open_near(_in_fence(player().global_position + Vector2.from_angle(TAU * i / n + randf()) * randf_range(70.0, 110.0), 20.0))
		w.telegraph_circle(at, 14.0, 0.6)
		get_tree().create_timer(0.6).timeout.connect(func() -> void:
			if dead or w != Game.world or w.player.dead:
				return
			w.burst(at, Color("a7f070"), 12, 60.0, 0.4, 2.0)
			var e := w.spawn_enemy(id, at, m.x, 1.0, false, true, m.y)
			if e != null:
				minions.append(e))
	Sfx.play("spawn", 0.1, -4.0)


func _enrage() -> void:
	furious = true
	armor = FURY_ARMOR
	tint = Color(1.25, 0.85, 1.1)
	state = "roar"
	state_t = 1.1
	var w := Game.world
	Sfx.play("roar", 0.0, 3.0)
	w.shake(0.9)
	w.hud.banner("THE MOTHERSHIP IS FURIOUS!", Color("ff4fd8"), 22, 1.0)
	w.hud.tint_flash(Color("ff1fd0"), 0.3, 0.6)
	w.ring(hit_center(), 70.0, Color("a7f070"), 0.5, 4.0)
	for n in get_tree().get_nodes_in_group("enemy_shots"):
		(n as EnemyShot).pop()


func _laser(dir: Vector2) -> void:
	Game.world.spawn_enemy_shot(hit_center() + dir * 10.0, dir * LASER_SPEED, contact_damage * 0.6, "ufo")


func _on_death() -> void:
	# the ship breaks apart in a chain of blasts
	var w := Game.world
	var c := hit_center()
	for i in 8:
		get_tree().create_timer(0.1 * i).timeout.connect(func() -> void:
			if w == Game.world:
				var p := c + Vector2(randf_range(-26, 26), randf_range(-16, 16))
				w.burst(p, Color("ffcd75"), 18, 120.0, 0.5, 3.0)
				w.burst(p, Color("ff4fd8"), 10, 80.0, 0.6, 3.0)
				Sfx.play("explode", 0.2, -4.0)
				w.shake(0.6))
