extends Enemy
## BIO DROID (world 8 BIODOME): the dome's gardening droid gone rogue, a SABOTEUR. It
## heads for the nearest seed tank still standing (it is always lured to it, whoever is
## around) and gnaws at it; when the astronaut comes near it turns, winds up its eye and
## flings a fan of LEAF DARTS that curve in after you, then goes back to the tank. With no
## tank left it just hounds you with leaves. Hunt them down before they reach the tanks.
## Breaks apart into leaves and scrap (the set's "death").

const SEEK_R := 600.0  # looks for seed tanks within this
const NEAR := 95.0  # the astronaut this close: it fights back
const WIND := 0.55
const LEAVES := 3
const LEAF_SPEED := 85.0
const COOLDOWN := 2.4

var _cd := 1.0
var _tank: SeedTank


func _init_ai() -> void:
	state = "seek"
	_pick_tank()


func _pick_tank() -> void:
	_tank = null
	var best := SEEK_R
	for n in get_tree().get_nodes_in_group("seed_tanks"):
		var t2 := n as SeedTank
		if t2 != null and not t2.lost and t2.global_position.distance_to(global_position) < best:
			best = t2.global_position.distance_to(global_position)
			_tank = t2


func _ai(delta: float) -> Vector2:
	state_t -= delta
	_cd -= delta
	air = 6.0 + sin(t * 4.0 + phase) * 2.0
	var to_p := player().global_position - global_position
	match state:
		"seek":
			if _cd <= 0.0 and to_p.length() < NEAR:
				state = "wind"
				state_t = WIND
				alert.visible = true
				Sfx.play("charge", 0.3, -10.0)
				return Vector2.ZERO
			if _tank == null or _tank.lost:
				if int(t * 2.0) % 3 == 0:
					_pick_tank()
				if _tank == null or _tank.lost:
					lure = null
					return to_p.normalized() * speed  # nothing left to wreck: you
			lure = _tank  # Enemy._to_player now leads to the tank
			var to_t := _tank.global_position - global_position
			if to_t.length() < SeedTank.DANGER_R * 0.8:
				return Vector2.ZERO  # gnawing
			return to_t.normalized() * speed
		"wind":
			face = signf(to_p.x) if to_p.x != 0.0 else face
			if state_t <= 0.0:
				_fling(to_p)
				alert.visible = false
				state = "seek"
				_cd = COOLDOWN
			return Vector2.ZERO
	return Vector2.ZERO


## A fan of leaf darts that curve in after the astronaut.
func _fling(to_p: Vector2) -> void:
	var base := (to_p + Vector2(0, Player.BODY_Y)).angle()
	for i in LEAVES:
		var d := Vector2.from_angle(base + (i - (LEAVES - 1) * 0.5) * 0.35)
		var s := Game.world.spawn_enemy_shot(hit_center() + d * 10.0, d * LEAF_SPEED, contact_damage * 0.6, "bio_leaf")
		s.life = 2.6
	squash = Vector2(1.15, 0.9)
	Sfx.play("slash", 0.4, -8.0)


func _anim_name() -> String:
	return "attack" if state == "wind" else "walk"


func _on_death() -> void:
	var w := Game.world
	var fx := AnimFx.spawn(w.effects, "bio_droid", "death", global_position + Vector2(0, -air), base_scale)
	fx.flip_h = face < 0.0
	w.burst(hit_center(), Color("8cff5a"), 12, 80.0, 0.5, 2.0, 60.0)
	Sfx.play("explode", 0.3, -10.0)
