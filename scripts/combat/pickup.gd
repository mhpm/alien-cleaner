class_name Pickup
extends Node2D
## Something that pops out of a cleaned alien (or a supply crate) and flies to the
## player: coins, hearts, power cores, and in survival stages XP gems and power-ups.
## Art and names come from CollectibleData; survival effects live in Survival.collect().

var kind := "coin"
var value := 1
var vel := Vector2.ZERO
var z := 0.0
var vz := 0.0
var magnet := false
var t := 0.0
var speed := 0.0
var sprite: Sprite2D
var shadow: Sprite2D
var base := 1.0  # sprite scale
var glow: Sprite2D


func is_powerup() -> bool:
	return kind not in ["coin", "heart", "xp"]


func _ready() -> void:
	add_to_group("pickups")
	shadow = Sprite2D.new()
	shadow.texture = Art.tex("shadow")
	add_child(shadow)
	if is_powerup():
		add_to_group("powerups")
		# a soft coloured halo so power-ups read in a crowd
		glow = Sprite2D.new()
		glow.texture = Art.tex("glow")
		var col: Color = CollectibleData.ITEMS.get(kind, {}).get("color", Color("73eff7"))
		glow.modulate = Color(col, 0.55)
		glow.scale = Vector2(0.8, 0.8)
		glow.position = Vector2(0, -7)
		var add := CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		glow.material = add
		add_child(glow)
	sprite = Sprite2D.new()
	sprite.texture = CollectibleData.tex(kind, value)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.centered = true
	base = CollectibleData.scale_for(kind, value)
	sprite.scale = Vector2.ONE * base
	add_child(sprite)
	var sw := sprite.texture.get_width() * base
	shadow.scale = Vector2(sw / 11.0, 0.6)
	vz = randf_range(55.0, 95.0) * (0.5 if kind == "xp" else 1.0)
	vel = Vector2.from_angle(randf() * TAU) * randf_range(10.0, 45.0) * (0.6 if kind == "xp" else 1.0)


func _physics_process(delta: float) -> void:
	t += delta
	var p := Game.world.player
	if z > 0.0 or vz > 0.0:
		vz -= 320.0 * delta
		z += vz * delta
		position += vel * delta
		if z <= 0.0:
			z = 0.0
			vz = -vz * 0.45 if absf(vz) > 30.0 else 0.0
			vel *= 0.5
	var b := Game.world.room.bounds().grow(-4.0)
	position = position.clamp(b.position, b.end)
	var d := p.global_position + Vector2(0, -4) - global_position
	var mr := 16.0 + 22.0 * int(Game.stats.get("magnet_lvl", 0))
	if kind == "xp" and Game.world.survival != null:
		mr = Game.world.survival.pickup_range()
	if not p.dead and t > 0.35 and (magnet or d.length() < mr):
		speed = minf(speed + 700.0 * delta, 320.0)
		global_position += d.normalized() * minf(speed * delta, d.length())
		z = move_toward(z, 0.0, delta * 60.0)
		if d.length() < 5.0:
			_collect()
			return
	var h := sprite.texture.get_height() * base
	sprite.position.y = -z - h * 0.5 - 1.0 + (sin(t * 5.0) * 0.6 if z == 0.0 else 0.0)
	if kind == "coin":
		sprite.scale = Vector2(base * maxf(0.25, absf(cos(t * 5.0))), base)
	elif is_powerup():
		# power-ups bob, pulse and sparkle
		sprite.scale = Vector2.ONE * base * (1.0 + sin(t * 6.0) * 0.08)
		sprite.position.y -= 3.0
		glow.position.y = sprite.position.y
		glow.modulate.a = 0.45 + sin(t * 6.0) * 0.15
		if randf() < 0.2:
			var col: Color = glow.modulate
			Game.world.burst(global_position + Vector2(randf_range(-4, 4), -8), Color(col, 1.0), 1, 15.0, 0.4, 1.5, -25.0)


func _collect() -> void:
	if kind not in ["coin", "heart", "power"]:
		if Game.world.survival != null:
			Game.world.survival.collect(kind, value, global_position)
		queue_free()
		return
	if kind == "coin":
		Game.add_coins(value)
		Sfx.play("coin", 0.06, -6.0)
		Game.world.burst(global_position, Color("ffcd75"), 4, 30.0, 0.25, 1.5)
	elif kind == "power":
		var upgraded := Game.weapon_up()
		Sfx.play("upgrade", 0.0)
		var tier := WeaponData.tier(int(Game.stats.weapon))
		Game.world.hud.banner("BLASTER LV %d!" % int(Game.stats.weapon) if upgraded else "+15 COINS",
				Color("73eff7"), 30, 0.7)
		if upgraded:
			Game.world.popup_text(global_position + Vector2(0, -14), str(tier.name), Color("73eff7"), 16)
		Game.world.player.refresh_upgrades()
		Game.world.ring(global_position + Vector2(0, -8), 26.0, Color("73eff7"), 0.4, 3.0, true)
		Game.world.burst(global_position + Vector2(0, -8), Color("73eff7"), 20, 90.0, 0.5, 2.0)
	else:
		Game.heal(float(value))
		Sfx.play("heal")
		Game.world.popup_text(global_position + Vector2(0, -10), "+%d" % value, Color("a7f070"), 14)
		Game.world.burst(global_position, Color("b13e53"), 8, 40.0, 0.4, 2.0)
	queue_free()
