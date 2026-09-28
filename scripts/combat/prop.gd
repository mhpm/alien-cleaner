class_name Prop
extends StaticBody2D
## A room prop from PropData standing on the floor (origin = feet). Blocks bodies and
## bullets. Optional soft glow; consoles spark when shot; tanks take a few hits and
## burst (toxic slime flood / freezing cloud); a med kit pops open for a heart.
## Tanks join "barrels" so explosions chain into them. Fences only block bodies.
## Alien eggs (hive) hatch Greenies when the player comes close during a fight.
## Supply crates burst into coins. Auto turrets wake up when the player stands next
## to them mid-fight and shoot the nearest alien, then cool down.

const EGG_RANGE := 34.0
const TURRET_WAKE := 26.0  # the player must stand this close to power it up
const TURRET_CHARGE := 0.8
const TURRET_ACTIVE := 9.0
const TURRET_COOL := 6.0
const TURRET_REACH := 140.0
const TURRET_RATE := 0.38

var id := ""
var def: Dictionary = {}
var cell := Vector2i.ZERO
var theme := "ship"
var hatching := -1.0  # egg: seconds left before it hatches (-1 = dormant)
var hp := 0
var exploded := false
var sprite: Sprite2D
var glow: Sprite2D
var mat: ShaderMaterial
var flash_t := 0.0
var t := 0.0
var turret := "idle"  # idle / charge / active / cool
var deploy_secs := 0.0  # turret dropped by a power-up: fires right away, then vanishes
var turret_t := 0.0
var fire_t := 0.0


func setup(prop_id: String, at_cell: Vector2i, foot: Vector2, room_theme := "ship") -> Prop:
	id = prop_id
	theme = room_theme
	def = PropData.PROPS[id]
	cell = at_cell
	position = foot
	hp = int(def.get("hp", 0))
	return self


func _ready() -> void:
	collision_layer = 1 if bool(def.get("bullets", true)) else PropData.LAYER_BODIES_ONLY
	collision_mask = 0
	t = randf() * TAU
	var box: Vector2 = def.box
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = box
	cs.shape = shape
	cs.position = Vector2(0, -box.y * 0.5)
	add_child(cs)
	var width := float(def.width)
	if def.has("glow"):
		glow = Sprite2D.new()
		glow.texture = Art.tex("glow")
		glow.modulate = def.glow
		glow.scale = Vector2(width / 14.0, width / 24.0)
		glow.position = Vector2(0, -2)
		var add := CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		glow.material = add
		add_child(glow)
	var shadow := Sprite2D.new()
	shadow.texture = Art.tex("shadow")
	shadow.scale = Vector2(width / 11.0, 1.2)
	shadow.position = Vector2(0, -1)
	add_child(shadow)
	sprite = Sprite2D.new()
	sprite.texture = PropData.texture_for(id, cell, theme)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var tw := float(sprite.texture.get_width())
	sprite.scale = Vector2.ONE * (width / tw)
	sprite.centered = false
	sprite.offset = Vector2(-tw * 0.5, -sprite.texture.get_height())
	mat = Art.flash_material()
	sprite.material = mat
	add_child(sprite)
	if def.get("kind", "") in ["toxic", "cryo", "egg", "loot"]:
		add_to_group("barrels")


func _process(delta: float) -> void:
	t += delta
	flash_t = maxf(0.0, flash_t - delta)
	mat.set_shader_parameter("flash", clampf(flash_t / 0.1, 0.0, 1.0))
	if glow != null:
		glow.modulate.a = float(def.glow.a) * (0.8 + sin(t * 2.5) * 0.2)
	if def.get("kind", "") == "egg":
		_egg(delta)
		return
	if def.get("kind", "") == "turret":
		_turret(delta)
		return
	# supply crates also smash open when the astronaut walks into them
	if def.get("kind", "") == "loot" and not exploded and Game.world != null \
			and not Game.world.player.dead and Game.world.player.global_position.distance_to(global_position) < 14.0:
		trigger(0.0)
		return
	# a damaged tank rattles and blinks before it bursts
	if hp == 1 and not exploded:
		sprite.position.x = sin(t * 60.0) * 0.5
		sprite.modulate = Color(1.4, 1.4, 1.4) if fmod(t * 4.0, 1.0) < 0.5 else Color.WHITE


func bullet_hit(_dmg: float) -> void:
	if exploded:
		return
	flash_t = 0.1
	var top := global_position + Vector2(0, -sprite.texture.get_height() * sprite.scale.y * 0.6)
	match str(def.get("kind", "")):
		"spark":
			Game.world.burst(top, Color("ffcd75"), 4, 60.0, 0.25, 1.5, 120.0)
			Game.world.burst(top, Color("73eff7"), 2, 40.0, 0.2, 1.5)
			Sfx.play("zap", 0.2, -14.0)
		"medkit":
			_open_medkit()
		"egg":
			hp -= 1
			Sfx.play("hit", 0.1, -6.0)
			Game.world.burst(top, Color("c75bd6"), 3, 40.0, 0.3, 1.5)
			if hp <= 0:
				trigger(0.0)
		"toxic", "cryo":
			hp -= 1
			Sfx.play("hit", 0.1, -6.0)
			if hp <= 0:
				trigger(0.0)
		"loot":
			hp -= 1
			Sfx.play("hit", 0.1, -6.0)
			Game.world.burst(top, Color("ffcd75"), 3, 40.0, 0.3, 1.5, 80.0)
			if hp <= 0:
				trigger(0.0)


## Burst the tank (also called by nearby explosions, like the barrels).
func trigger(delay: float) -> void:
	if exploded or not def.has("hp"):
		return
	exploded = true
	flash_t = 1.0
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	var w := Game.world
	if w == null:
		return
	var c := global_position + Vector2(0, -6)
	if def.kind == "egg":
		_egg_pop(w, c, false)
		return
	if def.kind == "loot":
		_burst_loot(w, c)
		return
	if def.kind == "toxic":
		_burst_toxic(w, c)
	else:
		_burst_cryo(w, c)
	queue_free()


## Egg: breathes while dormant; when the player comes close mid-fight it shakes,
## then bursts and releases two Greenies.
func _egg(delta: float) -> void:
	var w := Game.world
	if exploded or w == null:
		return
	if hatching < 0.0:
		var pulse := sin(t * 2.0) * 0.04
		sprite.scale = Vector2.ONE * (float(def.width) / sprite.texture.get_width()) * Vector2(1.0 + pulse, 1.0 - pulse)
		if w.state in ["fight", "gap"] and not w.player.dead 				and w.player.global_position.distance_to(global_position) < EGG_RANGE:
			hatching = 0.9
			Sfx.play("alert", 0.1, -6.0)
		return
	hatching -= delta
	sprite.position.x = sin(t * 55.0) * (1.0 - hatching) * 0.9
	sprite.modulate = Color(1.5, 1.1, 1.5) if fmod(t * 6.0, 1.0) < 0.5 else Color.WHITE
	if hatching <= 0.0:
		exploded = true
		_egg_pop(w, global_position + Vector2(0, -6), true)


func _egg_pop(w: GameWorld, c: Vector2, hatch: bool) -> void:
	w.burst(c, Color("c75bd6"), 16, 80.0, 0.45, 2.5, 30.0)
	w.burst(c, Color("a7f070"), 8, 50.0, 0.4, 2.0)
	w.add_stain(global_position, Color("7a2b8f"), 1.2)
	Sfx.play("pop", 0.15)
	if hatch:
		for i in 2:
			w.spawn_enemy("ufo_alien", global_position + Vector2(-5.0 + i * 10.0, 4.0))
	else:
		w.drop_pickups(global_position, 1, 0.0)
	queue_free()


## Shot open: the kit pops a heart and stays behind as an empty box.
func _open_medkit() -> void:
	if hp <= 0:
		return
	hp = 0
	var w := Game.world
	var h := Pickup.new()
	h.kind = "heart"
	h.value = 20
	h.position = global_position + Vector2(0, 8)
	w.entities.add_child(h)
	w.burst(global_position + Vector2(0, -8), Color("ff5566"), 10, 60.0, 0.4, 2.0, 60.0)
	w.popup_text(global_position + Vector2(0, -20), "+HP", Color("ff5566"), 12)
	Sfx.play("heal", 0.1)
	sprite.modulate = Color(0.55, 0.55, 0.6)
	if glow != null:
		glow.queue_free()
		glow = null


## Supply crate: splinters into a shower of coins (and sometimes a heart).
func _burst_loot(w: GameWorld, c: Vector2) -> void:
	Sfx.play("pop", 0.1)
	Sfx.play("coin", 0.1, -4.0)
	w.shake(0.25)
	w.burst(c, Color("ffcd75"), 18, 90.0, 0.5, 2.5, 120.0)
	w.burst(c, Color("8b9bb4"), 10, 60.0, 0.5, 2.5, 160.0)
	w.add_stain(global_position, Color(0.12, 0.1, 0.1), 1.0)
	if w.survival != null:
		w.survival.crate_loot(global_position)
	else:
		w.drop_pickups(global_position, 4 + randi() % 4, 0.3)
	w.popup_text(c + Vector2(0, -12), "LOOT!", Color("ffcd75"), 12)
	queue_free()


## Auto turret: idle until the player stands next to it during a fight, charges,
## then fires at the nearest alien in reach; afterwards it needs to cool down.
func _turret(delta: float) -> void:
	var w := Game.world
	if w == null:
		return
	var fighting: bool = w.state in ["fight", "gap", "survive"]
	var near := not w.player.dead and w.player.global_position.distance_to(global_position) < TURRET_WAKE
	if deploy_secs > 0.0 and turret == "idle":
		turret = "active"
		turret_t = deploy_secs
		fire_t = 0.3
	match turret:
		"idle":
			if fighting and near:
				turret = "charge"
				turret_t = 0.0
				Sfx.play("alert", 0.1, -6.0)
		"charge":
			turret_t += delta if near else -delta * 2.0
			if turret_t <= 0.0 or not fighting:
				turret = "idle"
			elif turret_t >= TURRET_CHARGE:
				turret = "active"
				turret_t = TURRET_ACTIVE
				fire_t = 0.1
				Sfx.play("shield", 0.1, -6.0)
				w.ring(global_position + Vector2(0, -4), 18.0, Color("73eff7"), 0.35, 2.0)
				w.popup_text(global_position + Vector2(0, -30), "TURRET ONLINE", Color("73eff7"), 10)
		"active":
			turret_t -= delta
			fire_t -= delta
			if fire_t <= 0.0:
				var e := _nearest_enemy(TURRET_REACH)
				if e != null:
					_turret_shoot(w, e)
					fire_t = TURRET_RATE
			if deploy_secs > 0.0 and (turret_t <= 0.0 or not fighting):
				# a dropped turret powers down and beams away
				exploded = true
				collision_layer = 0
				w.burst(global_position + Vector2(0, -10), Color("73eff7"), 12, 50.0, 0.4, 2.0, -30.0)
				var tw := create_tween()
				tw.tween_property(self, "modulate:a", 0.0, 0.4)
				tw.tween_callback(queue_free)
				set_process(false)
				return
			if turret_t <= 0.0 or not fighting:
				turret = "cool"
				turret_t = TURRET_COOL
				w.burst(global_position + Vector2(0, -16), Color(0.6, 0.6, 0.7, 0.8), 6, 20.0, 0.8, 2.0, -30.0)
		"cool":
			turret_t -= delta
			if turret_t <= 0.0:
				turret = "idle"
	var k := 1.0
	match turret:
		"active":
			k = 1.25 + sin(t * 18.0) * 0.1
		"cool":
			k = 0.6
	sprite.modulate = Color(k, k, k * (1.1 if turret == "active" else 1.0))
	if glow != null:
		glow.modulate.a = float(def.glow.a) * (2.0 if turret == "active" else (0.3 if turret == "cool" else 1.0))
	queue_redraw()


func _turret_shoot(w: GameWorld, e: Enemy) -> void:
	var h := sprite.texture.get_height() * sprite.scale.y
	var muzzle := global_position + Vector2(0, -h * 0.72)
	var dir := (e.hit_center() - muzzle).normalized()
	sprite.flip_h = dir.x < 0.0
	var b := Bullet.new()
	b.tier = WeaponData.tier(1)
	b.style = {"color": "73eff7", "flash": "9fe8ff", "size": 0.9, "speed": 1.0, "pierce": 0}
	b.dir = dir
	b.speed = 240.0
	b.damage = float(Game.stats.damage) * 0.6
	b.exclude = [get_rid()]
	w.effects.add_child(b)
	b.global_position = muzzle + dir * 4.0
	w.burst(muzzle + dir * 4.0, Color("73eff7"), 3, 40.0, 0.15, 1.5, 0.0, dir, 0.5)
	Sfx.play("shoot", 0.15, -12.0)


func _nearest_enemy(reach: float) -> Enemy:
	var best: Enemy = null
	var bd := reach
	for n in get_tree().get_nodes_in_group("enemies"):
		var e := n as Enemy
		if e == null or not e.targetable:
			continue
		var d := e.global_position.distance_to(global_position)
		if d < bd:
			bd = d
			best = e
	return best


## Turret: the activation circle on the floor (charge / time left as an arc).
func _draw() -> void:
	if def.get("kind", "") != "turret" or Game.world == null:
		return
	var c := Vector2(0, -1)
	draw_set_transform(c, 0.0, Vector2(1.0, 0.55))
	match turret:
		"idle":
			if Game.world.state in ["fight", "gap", "survive"]:
				var a := 0.35 + sin(t * 4.0) * 0.15
				draw_arc(Vector2.ZERO, TURRET_WAKE, 0.0, TAU, 32, Color(0.45, 0.94, 0.97, a), 1.0)
		"charge":
			draw_arc(Vector2.ZERO, TURRET_WAKE, -PI * 0.5, -PI * 0.5 + TAU * turret_t / TURRET_CHARGE, 32, Color("73eff7"), 2.0)
		"active":
			draw_arc(Vector2.ZERO, 12.0, -PI * 0.5, -PI * 0.5 + TAU * turret_t / TURRET_ACTIVE, 24, Color("73eff7"), 1.5)
		"cool":
			draw_arc(Vector2.ZERO, 12.0, -PI * 0.5, -PI * 0.5 + TAU * (1.0 - turret_t / TURRET_COOL), 24, Color(0.5, 0.5, 0.6, 0.6), 1.0)
	draw_set_transform(Vector2.ZERO)


func _burst_toxic(w: GameWorld, c: Vector2) -> void:
	Sfx.play("explode", 0.1, -4.0)
	w.shake(0.5)
	w.ring(c, 30.0, Color("a7f070"), 0.35, 3.0, true)
	w.burst(c, Color("a7f070"), 24, 110.0, 0.6, 3.0, 40.0)
	w.burst(c, Color("38b764"), 12, 60.0, 0.8, 3.0, -20.0)
	for e in _enemies_near(c, 30.0):
		e.take_damage(float(Game.stats.damage) * 1.5, (e.global_position - c).normalized() * 2.0)
	if w.player.global_position.distance_to(c) < 22.0:
		w.player.take_damage(10.0, c, true)
	# slime floods the tank's cell and the free cells around it for a while
	w.room.flood_toxic(cell, 10.0)


func _burst_cryo(w: GameWorld, c: Vector2) -> void:
	Sfx.play("freeze", 0.05)
	w.shake(0.4)
	w.ring(c, 44.0, Color("c0f4ff"), 0.4, 3.0, true)
	w.burst(c, Color("c0f4ff"), 26, 120.0, 0.7, 3.0, -10.0)
	w.burst(c, Color.WHITE, 10, 60.0, 0.5, 2.0)
	for e in _enemies_near(c, 44.0):
		e.freeze(3.0)
		e.take_damage(float(Game.stats.damage), Vector2.ZERO)


func _enemies_near(c: Vector2, r: float) -> Array[Enemy]:
	var out: Array[Enemy] = []
	for n in get_tree().get_nodes_in_group("enemies"):
		var e := n as Enemy
		if e != null and e.targetable and e.global_position.distance_to(c) < r + e.radius:
			out.append(e)
	return out
