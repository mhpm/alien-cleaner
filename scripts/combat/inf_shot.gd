class_name InfShot
extends Node2D
## A mutation gun's shot (MutationData gun `lv`): its own painted bolt (shoot_<n>.png),
## flying straight along the barrel. Stops at walls, hurts every alien it touches up to
## its pierce count, and bursts in the gun's colour.

const WORLD_MASK := 1

var lv := 1
var dir := Vector2.RIGHT
var speed := 300.0
var damage := 20.0
var pierce := 0
var life := 1.3
var hit_r := 4.0
var color := Color("ff3df0")
var hit_list: Array[int] = []
var sprite: Sprite2D
var t := 0.0
var base_scale := 0.1


func _ready() -> void:
	var g := MutationData.gun(lv)
	var info: Dictionary = MutationData.points().shots[lv - 1]
	var size: Array = info.size
	var head: Array = info.head
	sprite = Sprite2D.new()
	sprite.texture = MutationData.shot_tex(lv)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.centered = false
	# the bolt's head sits on the node, its tail trails behind
	sprite.offset = -Vector2(float(head[0]), float(head[1]))
	base_scale = float(g.shot) / float(size[0])
	sprite.scale = Vector2.ONE * base_scale
	sprite.rotation = dir.angle()
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	sprite.material = m
	add_child(sprite)


func _physics_process(delta: float) -> void:
	t += delta
	life -= delta
	if life <= 0.0:
		_pop()
		return
	var motion := dir * speed * delta
	var q := PhysicsRayQueryParameters2D.create(global_position, global_position + motion, WORLD_MASK)
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		var col: Object = hit.collider
		if col != null and col.has_method("bullet_hit"):
			col.call("bullet_hit", damage)
		global_position = hit.position
		_pop()
		return
	global_position += motion
	# stretches a little as it leaves the barrel, then wobbles
	var k := minf(t / 0.08, 1.0)
	sprite.scale = Vector2(base_scale * (0.6 + 0.4 * k) * (1.0 + sin(t * 40.0) * 0.05), base_scale)
	for node in Game.world.enemy_cache:
		if not is_instance_valid(node):
			continue
		var e := node as Enemy
		if e == null or not e.targetable:
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
	Game.world.burst(e.hit_center(), color, 5, 70.0, 0.25, 2.0, 0.0, dir, 0.6)
	Sfx.play("hit", 0.15, -4.0)


func _pop() -> void:
	if Game.world != null:
		Game.world.burst(global_position, color, 6, 50.0, 0.25, 2.0)
		Game.world.ring(global_position, hit_r + 3.0, color, 0.15, 1.5)
	queue_free()
