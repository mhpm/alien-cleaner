class_name Bullet
extends Node2D
## Player suds bubble. Raycasts against the world (bounces / hits barrels)
## and checks aliens by distance.

const WORLD_MASK := 1

var dir := Vector2.UP
var speed := 220.0
var damage := 10.0
var pierce := 0
var bounces := 0
var life := 1.6
var t := 0.0
var hit_list: Array[int] = []
var tier: Dictionary = WeaponData.tier(1)
var style: Dictionary = WeaponData.style("standard")  # equipped blaster's look
var hit_r := 3.0
var exclude: Array[RID] = []  # colliders the shot ignores (the turret that fired it)
var base_scale := 0.2
var sprite: AnimatedSprite2D
var pop_art := "impact"  # one-shot fx set played where the shot ends
var pop_color := Color("73eff7")


func _ready() -> void:
	hit_r = float(tier.hit_r) * float(style.size)
	base_scale = float(tier.scale) * float(style.size)
	sprite = Art.make_anim(str(tier.art), base_scale)
	if style.color != null:
		sprite.material = Art.shot_material(Color(str(style.color)))
	sprite.play("fly")
	sprite.rotation = dir.angle()
	add_child(sprite)


func _physics_process(delta: float) -> void:
	t += delta
	life -= delta
	if life <= 0.0:
		_pop()
		return
	var motion := dir * speed * delta
	var q := PhysicsRayQueryParameters2D.create(global_position, global_position + motion, WORLD_MASK)
	q.exclude = exclude
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		var col: Object = hit.collider
		if col != null and col.has_method("bullet_hit"):
			col.call("bullet_hit", damage)
			_pop()
			return
		var n: Vector2 = hit.normal
		global_position = (hit.position as Vector2) + n * 1.0
		if bounces > 0:
			bounces -= 1
			dir = dir.bounce(n).normalized()
			sprite.rotation = dir.angle()
			hit_list.clear()
			Sfx.play("bounce", 0.2, -8.0)
			return
		_pop()
		return
	global_position += motion
	var grow := 1.0 + minf(t, 0.4) * 0.6 if tier.art == "shot5" else 1.0
	var s := base_scale * grow * (1.0 + sin(t * 30.0) * 0.08)
	sprite.scale = Vector2(s, s)

	# only the aliens in the grid cells around the shot (GameWorld.enemies_near)
	for e in Game.world.enemies_near(global_position, hit_r + 8.0):
		if not e.targetable:
			continue
		var id := e.get_instance_id()
		if hit_list.has(id):
			continue
		if global_position.distance_to(e.hit_center()) <= e.radius + hit_r:
			hit_list.append(id)
			_hit_enemy(e)
			if pierce <= 0:
				_pop()
				return
			pierce -= 1


func _hit_enemy(e: Enemy) -> void:
	var s := Game.stats
	var dmg := damage
	var crit := randf() < float(s.crit)
	if crit:
		dmg *= float(s.crit_mult)
	e.take_damage(dmg, dir, crit)
	if float(s.freeze) > 0.0 and randf() < float(s.freeze):
		e.freeze(1.6)
	if int(s.chain) > 0:
		Game.world.chain_lightning(e, dmg * 0.5, int(s.chain))
	Sfx.play("hit", 0.15, -4.0)


func _pop() -> void:
	if Game.world != null:
		var fx := AnimFx.spawn(Game.world.effects, pop_art, "pop", global_position, 0.1 + hit_r * 0.012, randf() * TAU)
		if pop_art != "impact":
			# single-frame bursts: grow and fade instead of holding the frame
			fx.scale *= 0.6
			var tw := fx.create_tween()
			tw.tween_property(fx, "scale", fx.scale * 1.4, 0.15)
			tw.parallel().tween_property(fx, "modulate:a", 0.0, 0.15)
			tw.tween_callback(fx.queue_free)
		Game.world.burst(global_position, pop_color, 4, 40.0, 0.25, 1.5)
	queue_free()
