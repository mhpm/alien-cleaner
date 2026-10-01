extends Enemy
## MARTIAN SCOUT SAUCER (world 4): a little green martian in a saucer that FLIES IN
## FORMATION. All the martian scouts near each other share out the circle round you
## (each takes its own slot, evenly spaced, and the ring slowly turns), so a squad
## surrounds you; and they FIRE TOGETHER on a shared clock: a volley from every side at
## once ("attack", EnemyShot style "martian"). Alone it just circles and shoots. Break
## the formation by killing one: the others re-spread.
## Its saucer cracks and blows up in a pink flash (the set's "death", played once).

const SQUAD_R := 220.0  # scouts this close count as one squad
const RING := 95.0
const TURN := 0.35  # how fast the formation turns (rad/s)
const VOLLEY_EVERY := 3.0
const WARN := 0.5
const ORB_SPEED := 105.0

var _slot := 0
var _size := 1
var _fired_at := -1


func _init_ai() -> void:
	state = "fly"


func _ai(delta: float) -> Vector2:
	air = 9.0 + sin(t * 3.0 + phase) * 2.0
	var to_p := _to_player()
	if Engine.get_physics_frames() % 20 == get_instance_id() % 20:
		_find_squad()
	# the shared clock: every scout sees the same cycle
	var clock := Engine.get_physics_frames() / float(Engine.physics_ticks_per_second)
	var cyc := fmod(clock, VOLLEY_EVERY)
	var round_n := int(clock / VOLLEY_EVERY)
	var warn := cyc > VOLLEY_EVERY - WARN
	alert.visible = warn
	state = "attack" if warn else "fly"
	if warn:
		face = signf(to_p.x) if to_p.x != 0.0 else face
	if round_n != _fired_at and cyc < WARN * 0.5 and to_p.length() < 200.0:
		_fired_at = round_n
		var d := (to_p + Vector2(0, Player.BODY_Y)).normalized()
		Game.world.spawn_enemy_shot(hit_center() + d * 10.0, d * ORB_SPEED, contact_damage * 0.6, "martian")
		Sfx.play("zap", 0.3, -12.0)
		squash = Vector2(1.15, 0.9)
	# fly to this scout's slot of the ring round the astronaut
	var ang := clock * TURN + TAU * _slot / float(_size)
	var want := player().global_position + Vector2.from_angle(ang) * RING
	var v := want - global_position
	return v.normalized() * minf(speed * 1.4, v.length() * 3.0)


## The scouts around: this one's slot is its place in the squad sorted by id.
func _find_squad() -> void:
	var ids: Array[int] = []
	for n in Game.world.enemy_cache:
		var e := n as Enemy
		if is_instance_valid(e) and not e.dead and e.type_id == "martian_scout" and e.global_position.distance_to(global_position) < SQUAD_R:
			ids.append(e.get_instance_id())
	ids.sort()
	_size = maxi(ids.size(), 1)
	_slot = maxi(ids.find(get_instance_id()), 0)


func _anim_name() -> String:
	return "attack" if state == "attack" else "walk"


func _on_death() -> void:
	var w := Game.world
	var fx := AnimFx.spawn(w.effects, "martian_scout", "death", global_position + Vector2(0, -air), base_scale)
	fx.flip_h = face < 0.0
	w.burst(hit_center(), Color("ff4fb8"), 12, 80.0, 0.4, 2.5)
	Sfx.play("explode", 0.2, -10.0)
