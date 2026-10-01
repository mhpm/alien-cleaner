extends Enemy
## COMET HOPPER (world 4): a little bunny riding a molten comet pod. It HOPS after you in
## arcs (its shadow shrinks while it is up, and it can't touch you in the air), landing
## with a puff of sparks that burns anyone right under it; every third landing it
## winds up ("attack") and flings a flaming comet at you (EnemyShot style "hopper").
## Blows up into rocks and fire (the set's "death", played once).

const HOP_TIME := 0.55
const HOP_REACH := 75.0
const HOP_HEIGHT := 26.0
const LAND_R := 18.0
const AIM_TIME := 0.45
const COMET_SPEED := 115.0

var _hops := 0
var _hop_v := Vector2.ZERO


func _init_ai() -> void:
	state = "rest"
	state_t = randf_range(0.3, 0.8)


func _ai(delta: float) -> Vector2:
	state_t -= delta
	var to_p := _to_player()
	match state:
		"rest":
			air = 0.0
			if state_t <= 0.0:
				_hop(to_p)
			return Vector2.ZERO
		"hop":
			var k := 1.0 - clampf(state_t / HOP_TIME, 0.0, 1.0)
			air = sin(k * PI) * HOP_HEIGHT
			if state_t <= 0.0:
				_land()
				return Vector2.ZERO
			return _hop_v
		"aim":
			air = 0.0
			face = signf(to_p.x) if to_p.x != 0.0 else face
			if state_t <= 0.0:
				_fling(to_p)
				state = "rest"
				state_t = randf_range(0.4, 0.7)
			return Vector2.ZERO
	return Vector2.ZERO


func _hop(to_p: Vector2) -> void:
	var target := (to_p + player().velocity * 0.35).limit_length(HOP_REACH)
	_hop_v = target / HOP_TIME
	state = "hop"
	state_t = HOP_TIME
	squash = Vector2(0.8, 1.25)
	Sfx.play("bounce", 0.2, -8.0)


func _land() -> void:
	air = 0.0
	squash = Vector2(1.3, 0.75)
	Game.world.burst(global_position, Color("ff8a2a"), 8, 60.0, 0.3, 2.0, 60.0, Vector2.UP, 1.2)
	var p := player()
	if not p.dead and p.global_position.distance_to(global_position) < LAND_R:
		p.take_damage(contact_damage, global_position)
	_hops += 1
	if _hops % 3 == 0:
		state = "aim"
		state_t = AIM_TIME
		alert.visible = true
		Sfx.play("alert", 0.1, -10.0)
	else:
		state = "rest"
		state_t = randf_range(0.25, 0.55)


func _fling(to_p: Vector2) -> void:
	alert.visible = false
	var from := hit_center()
	var d := (to_p + Vector2(0, Player.BODY_Y)).normalized()
	Game.world.spawn_enemy_shot(from + d * 8.0, d * COMET_SPEED, contact_damage * 0.9, "hopper")
	Game.world.burst(from, Color("ff8a2a"), 6, 50.0, 0.25, 2.0, 0.0, d, 0.5)
	Sfx.play("spit", 0.1, -6.0)
	squash = Vector2(1.15, 0.9)


func _anim_name() -> String:
	return "attack" if state == "aim" else "walk"


func _on_death() -> void:
	var w := Game.world
	var fx := AnimFx.spawn(w.effects, "comet_hopper", "death", global_position + Vector2(0, -air), base_scale)
	fx.flip_h = face < 0.0
	w.burst(hit_center(), Color("ff8a2a"), 12, 90.0, 0.4, 2.5)
	Sfx.play("explode", 0.2, -10.0)
