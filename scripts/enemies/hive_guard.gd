extends Enemy
## Crystal guard the HIVE QUEEN raises when she turns furious (hive_guard set): it
## stands still, fires crystal shards at the astronaut and, while any guard stands, a
## crackling link keeps the queen's crystal shield up. Shatters into shards when broken.

const FIRE_EVERY := 2.6

var queen: Node2D
var fire_t := 1.5
var link_t := 0.0


func _init_ai() -> void:
	state = "guard"
	add_to_group("hive_guards")
	fire_t = randf_range(1.0, 2.0)


func _ai(delta: float) -> Vector2:
	fire_t -= delta
	link_t -= delta
	squash = Vector2(1.0, 1.0 + sin(t * 3.0) * 0.03)
	if link_t <= 0.0 and queen != null and is_instance_valid(queen):
		link_t = 0.1
		var l := Lightning.new()
		l.a = hit_center()
		l.b = (queen as Enemy).hit_center()
		l.color = Color("b35cff")
		l.dur = 0.14
		Game.world.effects.add_child(l)
	if fire_t <= 0.0:
		fire_t = FIRE_EVERY
		var d := _to_player().normalized()
		for a in [-0.2, 0.0, 0.2]:
			Game.world.spawn_enemy_shot(hit_center() + d * 8.0, d.rotated(a) * 105.0, contact_damage, "hive_shard")
		Sfx.play("freeze", 0.15, -8.0)
		squash = Vector2(0.85, 1.2)
	return Vector2.ZERO


func _on_death() -> void:
	var w := Game.world
	var c := hit_center()
	var off := randf() * TAU
	for i in 6:
		var d := Vector2.from_angle(off + TAU * i / 6.0)
		w.spawn_enemy_shot(c + d * 6.0, d * 70.0, contact_damage * 0.6, "hive_shard")
	var fx := AnimFx.spawn(w.effects, "hive_burst", "pop", c, 0.2)
	fx.create_tween().tween_property(fx, "modulate:a", 0.0, 0.35)
	w.burst(c, Color("b35cff"), 18, 90.0, 0.45, 2.0)
	Sfx.play("freeze", 0.0)
