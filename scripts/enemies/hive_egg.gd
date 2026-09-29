extends Enemy
## Goo egg the HIVE QUEEN lobs (hive_egg set). It sits and pulses faster and faster;
## break it in time or after HATCH seconds it bursts into a few greenies that join the
## fight. A hatched egg gives no reward, a broken one drops its XP as usual.

const HATCH := 4.0
const BROOD := 3

var life_t := 0.0


func _init_ai() -> void:
	state = "wait"
	knock = Vector2.ZERO


func _ai(delta: float) -> Vector2:
	life_t += delta
	var k := life_t / HATCH
	sprite.speed_scale = 1.0 + k * 3.0
	squash = Vector2(1.0 + sin(t * (6.0 + k * 20.0)) * 0.06 * (1.0 + k), 1.0)
	if k > 0.7 and randf() < delta * 8.0:
		Game.world.burst(hit_center(), Color("c8ff3a"), 1, 20.0, 0.3, 1.5, -30.0)
	if life_t >= HATCH:
		_hatch()
	return Vector2.ZERO


func _contact() -> void:
	pass  # an egg does not hurt: it hatches


func _hatch() -> void:
	var w := Game.world
	var m := Vector2(w.survival._hp_mult(), w.survival._dmg_mult()) if w.survival != null else Vector2.ONE
	for i in BROOD:
		var pos := global_position + Vector2.from_angle(TAU * i / BROOD + randf()) * 8.0
		w.spawn_enemy("ufo_alien", pos, m.x, 1.0, false, true, m.y)
	w.burst(hit_center(), Color("c8ff3a"), 14, 70.0, 0.4, 2.0)
	w.add_splat(global_position, art, base_scale, false, tint)
	Sfx.play("pop", 0.1)
	dead = true  # hatched: no reward
	targetable = false
	remove_from_group("enemies")
	queue_free()
