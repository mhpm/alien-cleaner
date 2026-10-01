class_name GunDemo
extends Control
## ARMORY "holo range": the weapon on show fires its real projectile art (assets/guns)
## at a bobbing target alien, so every weapon's shot type and special can be seen before
## buying it. Coordinates are the control's own (stage px); children are clipped.

var gun_id := "pulse"
var owned := true
var gun_icon: TextureRect
var target: Sprite2D
var muzzle := Vector2.ZERO
var target_pos := Vector2.ZERO
var t := 0.0
var next_t := 0.4
var arcs: Array = []  # [from, to, time left] jagged Tesla arcs drawn in _draw
var hurt_t := 0.0
var _seq := 0


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	gun_icon = TextureRect.new()
	gun_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gun_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	gun_icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	gun_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(gun_icon)
	target = Sprite2D.new()
	target.texture = load(GunData.DIR + "germ.png")
	target.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(target)
	resized.connect(_layout)
	_layout()


func show_gun(id: String, is_owned: bool) -> void:
	gun_id = id
	owned = is_owned
	gun_icon.texture = GunData.icon(id)
	gun_icon.modulate = Color.WHITE if owned else Color(0.75, 0.78, 0.9)
	for c in get_children():
		if c != gun_icon and c != target:
			c.queue_free()
	arcs.clear()
	next_t = 0.35
	_layout()
	# a little "loaded" kick
	gun_icon.pivot_offset = gun_icon.size * 0.5
	gun_icon.scale = Vector2(0.8, 0.8)
	gun_icon.create_tween().tween_property(gun_icon, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _layout() -> void:
	if gun_icon == null:
		return
	var h := size.y
	var gw := minf(size.x * 0.4, 150.0)
	gun_icon.position = Vector2(14, h * 0.5 - gw * 0.32)
	gun_icon.size = Vector2(gw, gw * 0.64)
	var tex := gun_icon.texture
	if tex != null:
		# muzzle = right end of the drawn art, at the tip's height
		var data: Dictionary = Astronaut.guns_data().guns[GunData.index(gun_id)]
		var ts := tex.get_size()
		var k := minf(gun_icon.size.x / ts.x, gun_icon.size.y / ts.y)
		var off := (gun_icon.size - ts * k) * 0.5
		muzzle = gun_icon.position + off + Vector2(float(data.tip[0]), float(data.tip[1])) * k
	target_pos = Vector2(size.x - 46, h * 0.5)
	target.scale = Vector2.ONE * (58.0 / target.texture.get_width())


func _process(delta: float) -> void:
	t += delta
	hurt_t = maxf(0.0, hurt_t - delta)
	target.position = target_pos + Vector2(sin(t * 1.7) * 4.0, sin(t * 2.9) * 6.0)
	var sq := 1.0 + sin(t * 6.0) * 0.04
	var k := 58.0 / target.texture.get_width()
	target.scale = Vector2(k * sq * (1.25 if hurt_t > 0.1 else 1.0), k / sq * (0.8 if hurt_t > 0.1 else 1.0))
	target.modulate = Color(3, 3, 3) if hurt_t > 0.12 else Color.WHITE
	next_t -= delta
	if next_t <= 0.0:
		next_t = clampf(float(GunData.gun(gun_id).rate) * 2.2, 0.6, 1.5)
		_fire()
	for a: Array in arcs:
		a[2] = float(a[2]) - delta
	arcs = arcs.filter(func(a: Array) -> bool: return float(a[2]) > 0.0)
	queue_redraw()


func _draw() -> void:
	for a: Array in arcs:
		var p0: Vector2 = a[0]
		var p1: Vector2 = a[1]
		var pts := PackedVector2Array()
		var n := maxi(4, int(p0.distance_to(p1) / 14.0))
		var perp := (p1 - p0).orthogonal().normalized()
		for i in n + 1:
			var off := 0.0 if i == 0 or i == n else randf_range(-12.0, 12.0)
			pts.append(p0.lerp(p1, float(i) / n) + perp * off)
		var al := clampf(float(a[2]) / 0.15, 0.0, 1.0)
		draw_polyline(pts, Color(0.45, 0.85, 1.0, 0.35 * al), 10.0)
		draw_polyline(pts, Color(0.55, 0.9, 1.0, al), 4.0)
		draw_polyline(pts, Color(1, 1, 1, al), 2.0)


# ---------------------------------------------------------------- shots

func _sprite(art: String, length: float, pos: Vector2, rot := 0.0) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(GunData.DIR + art + ".png")
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	s.scale = Vector2.ONE * (length / s.texture.get_width())
	s.position = pos
	s.rotation = rot
	add_child(s)
	return s


## Art that pops at `pos`, grows and fades.
func _pop(art: String, length: float, pos: Vector2, dur := 0.25, rot := 0.0) -> void:
	var s := _sprite(art, length, pos, rot)
	var tw := s.create_tween().set_parallel()
	tw.tween_property(s, "scale", s.scale * 1.35, dur)
	tw.tween_property(s, "modulate:a", 0.0, dur).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(s.queue_free)


## Moves `s` along a quadratic curve through `mid` and runs `done` at the end.
func _fly(s: Sprite2D, to: Vector2, dur: float, mid: Vector2, face: bool, done: Callable) -> void:
	var from := s.position
	var m := (from + to) * 0.5 if mid == Vector2.INF else mid
	var step := func(k: float) -> void:
		if not is_instance_valid(s):
			return
		var p := from.lerp(m, k).lerp(m.lerp(to, k), k)
		if face and p != s.position:
			s.rotation = (p - s.position).angle()
		s.position = p
	var tw := s.create_tween()
	tw.tween_method(step, 0.0, 1.0, dur)
	tw.tween_callback(func() -> void:
		s.queue_free()
		done.call())


func _hit(dmg_text := "") -> void:
	hurt_t = 0.18
	if dmg_text == "":
		dmg_text = str(roundi(_dmg()))
	var l := Label.new()
	l.text = dmg_text
	l.add_theme_font_size_override("font_size", 26)
	l.add_theme_color_override("font_color", Color("ffe08a"))
	l.add_theme_constant_override("outline_size", 8)
	l.position = target.position + Vector2(-20, -50)
	add_child(l)
	var tw := l.create_tween().set_parallel()
	tw.tween_property(l, "position:y", l.position.y - 30.0, 0.5)
	tw.tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.2)
	tw.chain().tween_callback(l.queue_free)


func _dmg() -> float:
	var lv := maxi(1, Game.gun_level(gun_id))
	return 10.0 * (1.0 + Game.ATTACK_STEP * int(Game.perm.power)) * float(GunData.gun(gun_id).dmg) * GunData.level_mult(lv)


func _kick() -> void:
	gun_icon.pivot_offset = Vector2(gun_icon.size.x * 0.3, gun_icon.size.y * 0.6)
	var tw := gun_icon.create_tween()
	tw.tween_property(gun_icon, "position:x", 8.0, 0.05)
	tw.tween_property(gun_icon, "position:x", 14.0, 0.12)
	var c := GunData.color(gun_id)
	var f := _sprite("hit_pulse", 22.0, muzzle)
	f.modulate = c.lightened(0.3)
	var tw2 := f.create_tween()
	tw2.tween_property(f, "modulate:a", 0.0, 0.12)
	tw2.tween_callback(f.queue_free)


func _fire() -> void:
	_seq += 1
	var to := target.position
	match str(GunData.gun(gun_id).kind):
		"pulse":
			_kick()
			var crit := _seq % 4 == 0
			var s := _sprite("shot_pulse", 46.0 if crit else 36.0, muzzle)
			if crit:
				s.modulate = Color(1.4, 1.25, 0.8)
			_fly(s, to, 0.28, Vector2.INF, true, func() -> void:
				_pop("hit_pulse", 48.0, to)
				_hit(("%d!" % roundi(_dmg() * 2.0)) if crit else ""))
		"nova":
			_kick()
			for k in 5:
				var a := (k / 4.0 - 0.5) * 0.5
				var s := _sprite("shot_nova", 24.0, muzzle, a)
				var end := muzzle + Vector2.from_angle(a) * (to.x - muzzle.x)
				var last := k == 2
				_fly(s, end, 0.22, Vector2.INF, true, func() -> void:
					_pop("hit_pulse", 22.0, end, 0.15)
					if last:
						_hit()
						target.position.x += 10.0)
		"drill":
			_kick()
			var s := _sprite("bolt_drill", 90.0, muzzle)
			_fly(s, Vector2(size.x + 60.0, muzzle.y), 0.32, Vector2.INF, true, func() -> void: pass)
			get_tree().create_timer(0.2).timeout.connect(func() -> void:
				if is_inside_tree():
					_pop("hit_drill", 50.0, to)
					_hit())
		"spark":
			_kick()
			var s := _sprite("shot_spark", 22.0, muzzle)
			var top := Vector2(lerpf(muzzle.x, to.x, 0.5), 18.0)
			_fly(s, top, 0.18, Vector2.INF, true, func() -> void:
				_pop("hit_spark", 26.0, top, 0.15)
				var s2 := _sprite("shot_spark", 22.0, top)
				_fly(s2, to, 0.18, Vector2.INF, true, func() -> void:
					_pop("hit_spark", 40.0, to)
					_hit()))
		"cryo":
			for k in 7:
				get_tree().create_timer(k * 0.05).timeout.connect(func() -> void:
					if not is_inside_tree():
						return
					var s := _sprite("flake", randf_range(12.0, 20.0), muzzle)
					var end := to + Vector2(randf_range(-14, 14), randf_range(-18, 18))
					var tw := s.create_tween()
					tw.tween_property(s, "rotation", randf_range(-6.0, 6.0), 0.35)
					_fly(s, end, 0.35, Vector2.INF, false, func() -> void:
						if k == 6:
							_pop("crystal", 70.0, to + Vector2(0, 6), 0.6)
							_hit()))
		"goo":
			_kick()
			var s := _sprite("glob", 26.0, muzzle)
			_fly(s, to + Vector2(0, 14), 0.42, Vector2(lerpf(muzzle.x, to.x, 0.5), -40.0), false, func() -> void:
				_pop("splash", 100.0, to + Vector2(0, 8), 0.4)
				_hit())
		"graviton":
			_kick()
			var s := _sprite("shot_grav", 40.0, muzzle)
			var tw := s.create_tween().set_loops(4)
			tw.tween_property(s, "rotation", TAU, 0.2).from(0.0)
			_fly(s, to, 0.75, Vector2.INF, false, func() -> void:
				_pop("hole", 120.0, to, 0.45)
				target.position.x -= 8.0
				_hit())
		"tesla":
			_kick()
			arcs.append([muzzle, to, 0.18])
			arcs.append([to, Vector2(size.x + 20.0, 20.0), 0.14])
			_pop("spark_tesla", 56.0, to, 0.22)
			_hit()
		"rockets":
			_kick()
			for k in 3:
				var s := _sprite("rocket", 30.0, muzzle)
				var ys: Array[float] = [12.0, size.y * 0.5, size.y - 12.0]
				var mid := Vector2(lerpf(muzzle.x, to.x, 0.4), ys[k])
				var end := to + Vector2(randf_range(-10, 10), randf_range(-12, 12))
				var tw_t := 0.38 + k * 0.06
				_fly(s, end, tw_t, mid, true, func() -> void:
					_pop("boom", 52.0, end, 0.3)
					if k == 1:
						_hit())
		"solar":
			var orb := _sprite("orb_solar", 4.0, muzzle)
			var tw := orb.create_tween()
			tw.tween_property(orb, "scale", Vector2.ONE * (40.0 / orb.texture.get_width()), 0.32)
			tw.tween_callback(func() -> void:
				orb.queue_free()
				_kick()
				var beam := _sprite("beam_solar", 10.0, muzzle)
				beam.centered = false
				beam.offset = Vector2(0, -beam.texture.get_height() * 0.5)
				beam.scale = Vector2((size.x - muzzle.x + 20.0) / beam.texture.get_width(), 26.0 / beam.texture.get_height())
				var tw2 := beam.create_tween()
				tw2.tween_property(beam, "modulate:a", 0.0, 0.35).set_delay(0.1)
				tw2.tween_callback(beam.queue_free)
				_pop("hit_solar", 90.0, to, 0.35)
				_hit())
