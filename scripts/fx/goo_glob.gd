class_name GooGlob
extends Node2D
## A drop of a boss's goo flying in an arc (style "red" = big_red_drop, "hive" =
## hive_drop), its shadow sliding along the floor. On landing it splashes and leaves a
## GooPuddle: an acid one that burns (the mortars: `acid` also hurts the astronaut it
## lands on) or plain residue (death splashes). `on_land` (optional) is called with the
## landing point instead of leaving a puddle (the HIVE QUEEN's eggs).

const DROP := {"red": "big_red_drop", "hive": "hive_drop"}
const TINT := {"red": Color(1.5, 0.7, 1.1), "hive": Color(0.9, 1.5, 0.6)}

var style := "red"
var from := Vector2.ZERO
var to := Vector2.ZERO
var height := 40.0
var dur := 1.0
var acid := false
var damage := 10.0
var puddle_r := 12.0
var puddle_life := 5.0
var size := 1.0
var on_land := Callable()
var t := 0.0
var drop: AnimatedSprite2D
var shadow: Sprite2D


func _ready() -> void:
	global_position = from
	shadow = Sprite2D.new()
	shadow.texture = Art.tex("shadow")
	shadow.modulate.a = 0.5
	add_child(shadow)
	drop = Art.make_anim(str(DROP[style]), 0.2 * size)
	drop.play("fly")
	add_child(drop)


func _physics_process(delta: float) -> void:
	t += delta
	var k := minf(t / dur, 1.0)
	global_position = from.lerp(to, k)
	var up := sin(k * PI) * height
	drop.position = Vector2(0, -up)
	# the drop points along its path (the art falls downwards)
	var vel := (to - from) / dur + Vector2(0, -cos(k * PI) * PI * height / dur)
	drop.rotation = vel.angle() - PI * 0.5
	shadow.scale = Vector2.ONE * (0.5 + 0.5 * k) * size
	if k >= 1.0:
		_land()


func _land() -> void:
	var w := Game.world
	var col: Color = GooPuddle.STYLES[style].color
	w.burst(global_position, col, 6 if acid else 4, 50.0, 0.35, 2.0, 60.0)
	var fx := AnimFx.spawn(w.effects, "glob_pop", "pop", global_position + Vector2(0, -2), 0.12 * size)
	fx.self_modulate = TINT[style]
	if on_land.is_valid():
		on_land.call(global_position)
		queue_free()
		return
	var pd := GooPuddle.new()
	pd.style = style
	pd.acid = acid
	pd.radius = puddle_r
	pd.life = puddle_life
	pd.damage = damage * 0.35
	pd.position = global_position
	w.decals.add_child(pd)
	if acid:
		Sfx.play("spit", 0.15, -6.0)
		var p := w.player
		if not p.dead and p.global_position.distance_to(global_position) < puddle_r + 4.0:
			p.take_damage(damage, global_position)
	queue_free()
