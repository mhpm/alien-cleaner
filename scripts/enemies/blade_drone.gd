extends Enemy
## CYCLONE BLADE DRONE (world 4): a round drone with two curved blades spinning round it.
## It circles you tight; every few seconds it winds up ("attack") and flings two fiery
## crescents off its blades that curve in after you (EnemyShot style "crescent", "home"),
## then lunges through where you stand. Its blades cut on contact.
## Blows apart into blades and scrap (the set's "death").

const ORBIT := 50.0
const WIND_TIME := 0.5
const CRESCENT_SPEED := 100.0
const LUNGE_SPEED := 190.0
const LUNGE_TIME := 0.35

var _turn := 1.0


func _init_ai() -> void:
	state = "spin"
	state_t = randf_range(1.6, 2.6)
	_turn = 1.0 if randf() < 0.5 else -1.0


func _ai(delta: float) -> Vector2:
	state_t -= delta
	air = 7.0 + sin(t * 5.0 + phase) * 2.0
	var to_p := _to_player()
	match state:
		"spin":
			if state_t <= 0.0:
				state = "wind"
				state_t = WIND_TIME
				alert.visible = true
				Sfx.play("charge", 0.2, -12.0)
				return Vector2.ZERO
			var v := to_p.normalized().orthogonal() * _turn * 1.2
			v += to_p.normalized() * clampf((to_p.length() - ORBIT) / 20.0, -1.0, 1.0)
			return v.normalized() * speed
		"wind":
			face = signf(to_p.x) if to_p.x != 0.0 else face
			if state_t <= 0.0:
				alert.visible = false
				_fling(to_p)
				aim = to_p.normalized()
				state = "lunge"
				state_t = LUNGE_TIME
				Sfx.play("slash", 0.15, -6.0)
			return -to_p.normalized() * 10.0
		"lunge":
			if state_t <= 0.0 or hit_wall:
				state = "spin"
				state_t = randf_range(1.8, 2.6)
				if randf() < 0.4:
					_turn = -_turn
			return aim * LUNGE_SPEED
	return Vector2.ZERO


## A crescent off each blade, thrown out to the sides; they curve in after you.
func _fling(to_p: Vector2) -> void:
	var d := to_p.normalized()
	for s: float in [-1.0, 1.0]:
		var dir := d.rotated(s * 0.9)
		var sh := Game.world.spawn_enemy_shot(hit_center() + dir * 12.0, dir * CRESCENT_SPEED, contact_damage * 0.7, "crescent")
		sh.life = 3.0
	Game.world.burst(hit_center(), Color("ffb030"), 8, 60.0, 0.25, 2.0)


func _anim_name() -> String:
	return "attack" if state in ["wind", "lunge"] else "walk"


func _on_death() -> void:
	var w := Game.world
	var fx := AnimFx.spawn(w.effects, "blade_drone", "death", global_position + Vector2(0, -air), base_scale)
	fx.flip_h = face < 0.0
	w.burst(hit_center(), Color("ffb030"), 12, 90.0, 0.4, 2.5)
	Sfx.play("explode", 0.2, -10.0)
