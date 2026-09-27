class_name Pickup
extends Node2D
## Coin or heart that pops out of a cleaned alien and flies to the player.

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


func _ready() -> void:
	add_to_group("pickups")
	shadow = Sprite2D.new()
	shadow.texture = Art.tex("shadow")
	shadow.scale = Vector2(0.55, 0.6)
	add_child(shadow)
	sprite = Sprite2D.new()
	if kind == "power":
		sprite.texture = Art.frame_tex("shot3", "fly", 0)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		sprite.scale = Vector2.ONE * 0.2
		shadow.scale = Vector2(0.9, 0.8)
	else:
		sprite.texture = Art.tex("coin" if kind == "coin" else "heart")
	add_child(sprite)
	vz = randf_range(55.0, 95.0)
	vel = Vector2.from_angle(randf() * TAU) * randf_range(10.0, 45.0)


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
	position = position.clamp(Vector2(4, 4), Vector2(Room.W - 4.0, Room.H - 4.0))
	var d := p.global_position + Vector2(0, -4) - global_position
	var mr := 60.0 if bool(Game.stats.magnet) else 16.0
	if not p.dead and t > 0.35 and (magnet or d.length() < mr):
		speed = minf(speed + 700.0 * delta, 320.0)
		global_position += d.normalized() * minf(speed * delta, d.length())
		z = move_toward(z, 0.0, delta * 60.0)
		if d.length() < 5.0:
			_collect()
			return
	sprite.position.y = -z - 3.0 + (sin(t * 5.0) * 0.6 if z == 0.0 else 0.0)
	if kind == "coin":
		sprite.scale.x = maxf(0.25, absf(cos(t * 5.0)))
	elif kind == "power":
		sprite.scale = Vector2.ONE * 0.2 * (1.0 + sin(t * 8.0) * 0.12)
		sprite.position.y -= 4.0
		if randf() < 0.3:
			Game.world.burst(global_position + Vector2(0, -7), Color("73eff7"), 1, 20.0, 0.4, 1.5, -30.0)


func _collect() -> void:
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
