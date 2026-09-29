class_name MartianShot
extends Node2D
## The Martian UFO's green plasma ball (kit martian_shot.png, head pointing right).
## Flies over walls (the UFO shoots from the air), hits one alien and, with `chain` left,
## bends toward the next nearby alien it has not hit yet.

const TEX := preload("res://assets/ui/upgrades/kit/martian_shot.png")
const HEAD := Vector2(96, 39)  # centre of the plasma ball in the texture
const LEN := 13.0  # world units, tail included
const CHAIN_RANGE := 75.0

var dir := Vector2.RIGHT
var speed := 250.0
var damage := 8.0
var chain := 0
var life := 1.0
var hit_r := 3.5
var martian: MartianAlly
var hit_list: Array[int] = []
var sprite: Sprite2D
var t := 0.0


func _ready() -> void:
	sprite = Sprite2D.new()
	sprite.texture = TEX
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.centered = false
	sprite.offset = -HEAD
	sprite.scale = Vector2.ONE * (LEN / TEX.get_width())
	sprite.rotation = dir.angle()
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	sprite.material = m
	add_child(sprite)


func _physics_process(delta: float) -> void:
	t += delta
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	global_position += dir * speed * delta
	var k := LEN / TEX.get_width()
	sprite.scale = Vector2(k * (1.0 + sin(t * 45.0) * 0.08), k)
	for node in Game.world.enemy_cache:
		if not is_instance_valid(node):
			continue
		var e := node as Enemy
		if e == null or not e.targetable or hit_list.has(e.get_instance_id()):
			continue
		if global_position.distance_to(e.hit_center()) <= e.radius + hit_r:
			_hit(e)
			return


func _hit(e: Enemy) -> void:
	hit_list.append(e.get_instance_id())
	var s := Game.stats
	var crit := randf() < float(s.crit)
	e.take_damage(damage * (float(s.crit_mult) if crit else 1.0), dir * 0.5, crit)
	Game.world.burst(e.hit_center(), Color("7dff8a"), 5, 60.0, 0.25, 1.5, 0.0, dir, 0.6)
	Sfx.play("hit", 0.2, -9.0)
	if e.dead and martian != null and is_instance_valid(martian):
		martian.on_kill()
	if chain > 0:
		var next := _next_target(e.hit_center())
		if next != null:
			chain -= 1
			var from := global_position
			dir = (next.hit_center() - from).normalized()
			sprite.rotation = dir.angle()
			life = 0.6
			Game.world.burst(from, Color("b6ffb0"), 3, 30.0, 0.2, 1.0)
			return
	queue_free()


func _next_target(from: Vector2) -> Enemy:
	var best: Enemy = null
	var best_d := CHAIN_RANGE
	for node in Game.world.enemy_cache:
		if not is_instance_valid(node):
			continue
		var e := node as Enemy
		if e == null or not e.targetable or hit_list.has(e.get_instance_id()):
			continue
		var d := from.distance_to(e.hit_center())
		if d < best_d:
			best_d = d
			best = e
	return best
