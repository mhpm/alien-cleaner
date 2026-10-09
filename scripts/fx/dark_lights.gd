class_name DarkLights
extends Node2D
## Failing power (EXPLORE map, world 1): the whole stage is darkened with a CanvasModulate
## and lit only by a few lights: the astronaut's suit lamp, the ceiling lamps of each room
## (some dead, some flickering, an emergency red one now and then), the doorway lights
## and the red pulse of the ZONE ZERO reactor. What must stay readable ignores the dark:
## the Effects layer (shots, bullets, sparks, explosions) moves to its own CanvasLayer and
## warnings / spawn markers / the boss fence are drawn unshaded (DarkLights.glow()).
## Lights are PointLight2D with one shared radial texture.

const AMBIENT := Color(0.13, 0.14, 0.21)  # what the dark lets through
const PLAYER_R := 150.0  # suit lamp radius (world units)

static var active := false
static var _tex: Texture2D
static var _unshaded: CanvasItemMaterial

var world: GameWorld
var player_light: PointLight2D
var flicker: Array = []  # [light, base energy, mode, timer]
var t := 0.0


## A CanvasItem that must stay readable in the dark (warnings, markers): unshaded.
static func glow(c: CanvasItem) -> void:
	if not active or c.material != null:
		return
	if _unshaded == null:
		_unshaded = CanvasItemMaterial.new()
		_unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	c.material = _unshaded


static func light_tex() -> Texture2D:
	if _tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.45, Color(1, 1, 1, 0.55))
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(1.0, 0.5)
		gt.width = 256
		gt.height = 256
		_tex = gt
	return _tex


func setup(w: GameWorld, ex: Explore) -> DarkLights:
	world = w
	active = true
	var cm := CanvasModulate.new()
	cm.color = AMBIENT
	add_child(cm)
	# shots, bullets and bursts glow over the dark: their own layer between world and HUD
	var layer := CanvasLayer.new()
	layer.name = "LitEffects"
	layer.layer = 1
	layer.follow_viewport_enabled = true
	w.add_child(layer)
	w.effects.reparent(layer, false)
	w.hud.layer = 5
	# the astronaut's suit lamp
	player_light = _light(w.player, Vector2(0, -8), PLAYER_R, Color(0.95, 0.92, 0.8), 0.8)
	player_light.shadow_enabled = false
	_light(w.player, Vector2(0, -8), 34.0, Color(0.7, 0.85, 1.0), 0.35)  # soft core
	_room_lights(ex)
	return self


## World 2: no darkness, only 1-2 slow red alarm lights per room, kept faint.
func alarms_only(ex: Explore) -> DarkLights:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for rm: Array in ex.rooms:
		var r: Rect2 = rm[0]
		var spots := [Vector2(0.18, 0.22), Vector2(0.82, 0.22), Vector2(0.18, 0.8), Vector2(0.82, 0.8)]
		spots.shuffle()
		# many small areas (world 5 ForgeMap): one light each, so they stay few
		for i in rng.randi_range(1, 2 if ex.rooms.size() <= 12 else 1):
			var l := _light(self, r.position + r.size * (spots[i] as Vector2), rng.randf_range(80.0, 110.0),
					Color(1.0, 0.12, 0.1), 0.45)
			flicker.append([l, 0.45, "alarm_slow", rng.randf() * TAU])
	return self


func _exit_tree() -> void:
	active = false


func _light(parent: Node, at: Vector2, radius: float, col: Color, energy: float) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = light_tex()
	l.texture_scale = radius * 2.0 / 256.0
	l.color = col
	l.energy = energy
	l.position = at
	parent.add_child(l)
	return l


## Per room: 2-3 ceiling lamps (dead, steady, flickering or red emergency), a light at
## every doorway and the reactor of ZONE ZERO.
func _room_lights(ex: Explore) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for rm: Array in ex.rooms:
		var r: Rect2 = rm[0]
		var zero: bool = rm[2] == ex.zero_cell
		if zero:
			var reactor := _light(self, r.get_center() + Vector2(0, 10), 190.0, Color(1.0, 0.22, 0.35), 0.95)
			flicker.append([reactor, 0.95, "pulse", 0.0])
		var spots := [Vector2(0.22, 0.3), Vector2(0.78, 0.3), Vector2(0.22, 0.75), Vector2(0.78, 0.75), Vector2(0.5, 0.5)]
		spots.shuffle()
		for i in rng.randi_range(2, 3):
			var p: Vector2 = r.position + r.size * (spots[i] as Vector2)
			var roll := rng.randf()
			if roll < 0.2:
				continue  # dead lamp
			var mode := "steady"
			var col := Color(0.75, 0.85, 1.0)
			var e := 0.6
			if roll < 0.55:
				mode = "flicker"
			elif roll < 0.68:
				mode = "alarm"
				col = Color(1.0, 0.2, 0.15)
				e = 0.9
			var l := _light(self, p, rng.randf_range(90.0, 130.0), col, e)
			flicker.append([l, e, mode, rng.randf() * 3.0])
		# doorway lights (the blue lamps of the door frames)
		for d: Vector2 in [Vector2(0.5, 0.02), Vector2(0.5, 0.98), Vector2(0.02, 0.5), Vector2(0.98, 0.5)]:
			_light(self, r.position + r.size * d, 34.0, Color(0.5, 0.8, 1.0), 0.5)


func _process(delta: float) -> void:
	t += delta
	for f: Array in flicker:
		var l: PointLight2D = f[0]
		var base: float = f[1]
		match str(f[2]):
			"pulse":
				l.energy = base * (0.7 + 0.3 * sin(t * 2.2))
			"alarm_slow":
				l.energy = base * (0.1 + 0.9 * maxf(0.0, sin(t * 1.8 + float(f[3]))))
			"alarm":
				l.energy = base * (0.15 + 0.85 * maxf(0.0, sin(t * 4.0 + float(f[3]))))
			"flicker":
				# mostly on, dropping out in short stuttering bursts
				f[3] = float(f[3]) - delta
				if float(f[3]) <= 0.0:
					f[3] = randf_range(1.5, 5.0)
					l.set_meta("burst", randf_range(0.25, 0.9))
				var burst := float(l.get_meta("burst", 0.0))
				if burst > 0.0:
					l.set_meta("burst", burst - delta)
					l.energy = base * (0.05 if randf() < 0.55 else randf_range(0.4, 1.0))
				else:
					l.energy = base * (0.92 + randf() * 0.08)
