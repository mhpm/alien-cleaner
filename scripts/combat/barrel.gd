class_name Barrel
extends StaticBody2D
## Explosive container (red hazard drum, PropData.BARREL_TEX). Two hits (or a nearby
## blast) and it goes boom, hurting everyone around.

var hp := 2
var exploded := false
var sprite: Sprite2D
var mat: ShaderMaterial
var flash_t := 0.0


func _ready() -> void:
	add_to_group("barrels")
	collision_layer = 1
	collision_mask = 0
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(10, 8)
	cs.shape = r
	cs.position = Vector2(0, -4)
	add_child(cs)
	var sh := Sprite2D.new()
	sh.texture = Art.tex("shadow")
	add_child(sh)
	sprite = Sprite2D.new()
	var theme: String = Game.world.room.theme if Game.world != null else "ship"
	sprite.texture = PropData.pick(PropData.themed("barrel", PropData.BARREL_TEX, theme), Vector2i(position / 16.0))
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.centered = false
	sprite.offset = Vector2(-sprite.texture.get_width() * 0.5, -sprite.texture.get_height())
	sprite.scale = Vector2.ONE * (11.0 / sprite.texture.get_width())
	mat = Art.flash_material()
	sprite.material = mat
	add_child(sprite)


func _process(delta: float) -> void:
	flash_t = maxf(0.0, flash_t - delta)
	mat.set_shader_parameter("flash", clampf(flash_t / 0.1, 0.0, 1.0))
	if hp == 1 and not exploded:
		sprite.position.x = sin(Time.get_ticks_msec() * 0.06) * 0.6
		sprite.modulate = Color(1.3, 0.8, 0.8) if fmod(Time.get_ticks_msec() * 0.004, 1.0) < 0.5 else Color.WHITE


func bullet_hit(_dmg: float) -> void:
	if exploded:
		return
	hp -= 1
	flash_t = 0.1
	Sfx.play("hit", 0.1, -6.0)
	if hp <= 0:
		trigger(0.0)


func trigger(delay: float) -> void:
	if exploded:
		return
	exploded = true
	flash_t = 1.0
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	if Game.world != null:
		Game.world.explosion(global_position + Vector2(0, -6), 36.0, 60.0, 18.0)
	queue_free()
