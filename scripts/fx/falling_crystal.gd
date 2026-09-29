class_name FallingCrystal
extends Node2D
## A crystal dropping out of the sky onto a red warning circle (HIVE QUEEN's crystal
## rain): hurts the astronaut standing there and shatters into a ring of shards.

const FALL := 0.9
const HEIGHT := 110.0
const RADIUS := 15.0

var damage := 10.0
var t := 0.0
var spr: AnimatedSprite2D
var shadow: Sprite2D


func _ready() -> void:
	shadow = Sprite2D.new()
	shadow.texture = Art.tex("shadow")
	shadow.modulate.a = 0.0
	add_child(shadow)
	spr = Art.make_anim("hive_crystal", 0.34)
	spr.play("fly")
	spr.position = Vector2(0, -HEIGHT)
	spr.modulate.a = 0.0
	add_child(spr)
	Game.world.telegraph_circle(global_position, RADIUS, FALL)


func _physics_process(delta: float) -> void:
	t += delta
	var k := minf(t / FALL, 1.0)
	spr.position.y = -HEIGHT * (1.0 - k * k)
	spr.modulate.a = minf(1.0, k * 4.0)
	shadow.modulate.a = 0.5 * k
	shadow.scale = Vector2.ONE * (0.4 + 0.8 * k)
	if k >= 1.0:
		_shatter()


func _shatter() -> void:
	var w := Game.world
	var c := global_position + Vector2(0, -4)
	var p := w.player
	if not p.dead and p.global_position.distance_to(global_position) < RADIUS + 3.0:
		p.take_damage(damage, global_position)
	var off := randf() * TAU
	for i in 6:
		var d := Vector2.from_angle(off + TAU * i / 6.0)
		w.spawn_enemy_shot(c + d * 5.0, d * 75.0, damage * 0.5, "hive_shard")
	var fx := AnimFx.spawn(w.effects, "hive_burst", "pop", c, 0.18)
	fx.create_tween().tween_property(fx, "modulate:a", 0.0, 0.3)
	w.burst(c, Color("b35cff"), 12, 80.0, 0.35, 2.0)
	w.shake(0.25)
	Sfx.play("freeze", 0.1, -2.0)
	queue_free()
