class_name ScrubShot
extends Node2D
## The Scrub-Bot's orange plasma orb (kit scrub_orb.png, drawn additive). Flies over walls
## (the drone shoots from the air), hits one alien; with `blast_r` > 0 it pops in a small
## blast that hurts the aliens around (level 3+).

const TEX := preload("res://assets/ui/upgrades/kit/scrub_orb.png")
const SIZE := 9.5  # world units
const BLAST_K := 0.6  # blast damage, share of the orb's

var dir := Vector2.RIGHT
var speed := 230.0
var damage := 8.0
var blast_r := 0.0
var life := 0.85
var hit_r := 3.5
var sprite: Sprite2D
var t := 0.0


func _ready() -> void:
	sprite = Sprite2D.new()
	sprite.texture = TEX
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.scale = Vector2.ONE * (SIZE / TEX.get_width())
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
	var k := SIZE / TEX.get_width() * (1.0 + sin(t * 40.0) * 0.12)
	sprite.scale = Vector2(k * 1.25, k)
	sprite.rotation = dir.angle()
	for e in Game.world.enemies_near(global_position, hit_r + 8.0):
		if e.targetable and global_position.distance_to(e.hit_center()) <= e.radius + hit_r:
			_hit(e)
			return


func _hit(e: Enemy) -> void:
	var s := Game.stats
	var crit := randf() < float(s.crit)
	e.take_damage(damage * (float(s.crit_mult) if crit else 1.0), dir * 0.5, crit)
	Game.world.burst(e.hit_center(), Color("ffb347"), 5, 60.0, 0.25, 1.5, 0.0, dir, 0.6)
	Sfx.play("hit", 0.2, -10.0)
	if blast_r > 0.0:
		var at := e.hit_center()
		Game.world.ring(at, blast_r, Color("ffcd75"), 0.22, 2.0)
		Game.world.burst(at, Color("ff9a2e"), 6, 70.0, 0.25, 1.8)
		for o in Game.world.enemies_near(at, blast_r):
			if o != e and o.targetable and at.distance_to(o.hit_center()) <= blast_r + o.radius:
				o.take_damage(damage * BLAST_K, (o.global_position - at).normalized() * 0.4)
	queue_free()
