class_name SlimeSplitter
extends Enemy
## SLIME SPLITTER: a lumbering mass of orange goo with many eyes. It plods after you and,
## when you are in range, pulls back ("wind") and stretches an arm ("fling") to throw a
## slimelet at you that lands and joins the chase (never more than MAX_LETS alive).
## Cleaning it makes it burst into BROOD slimelets (the set's "splat" = its puddle).

const BROOD := 3
const MAX_LETS := 10
const REACH := 110.0


func _init_ai() -> void:
	state = "chase"
	state_t = randf_range(1.5, 3.0)


func _ai(delta: float) -> Vector2:
	state_t -= delta
	var to_p := _to_player()
	match state:
		"chase":
			if to_p.x != 0.0:
				face = signf(to_p.x)
			if state_t <= 0.0:
				if to_p.length() < REACH and _lets_alive() < MAX_LETS:
					state = "wind"
					state_t = 0.6
					alert.visible = true
					Sfx.play("alert", 0.1, -8.0)
				else:
					state_t = 1.0
			return to_p.normalized() * speed * (0.8 + 0.25 * sin(t * 4.0 + phase))
		"wind":
			face = signf(to_p.x) if to_p.x != 0.0 else face
			sprite.position.x = sin(t * 50.0) * 0.6
			squash = Vector2(1.0 - (0.6 - state_t) * 0.25, 1.0 + (0.6 - state_t) * 0.25)
			if state_t <= 0.0:
				sprite.position.x = 0.0
				alert.visible = false
				_fling(player().global_position)
				state = "fling"
				state_t = 0.3
				squash = Vector2(1.25, 0.85)
			return Vector2.ZERO
		"fling":
			if state_t <= 0.0:
				state = "chase"
				state_t = randf_range(2.5, 3.5)
			return Vector2.ZERO
	return to_p.normalized() * speed


func _lets_alive() -> int:
	var n := 0
	for node in Game.world.enemy_cache:
		if is_instance_valid(node) and (node as Enemy).type_id == "splitlet":
			n += 1
	return n


## Lob a slimelet over to `target`; it hatches into a real one where it lands.
func _fling(target: Vector2) -> void:
	var g := GooGlob.new()
	g.flat_art = "splitlet"
	g.from = global_position + Vector2(face * 6.0, -8.0)
	g.to = target
	g.height = 26.0
	g.dur = clampf(g.from.distance_to(target) / 110.0, 0.4, 0.9)
	g.size = 0.9
	g.on_land = hatch
	Sfx.play("spit", 0.1, -4.0)
	Game.world.effects.add_child(g)


## A slimelet at `pos`, tougher and harder-hitting as the clock runs (like the rest of the horde).
static func hatch(pos: Vector2) -> void:
	var w := Game.world
	if w == null or w.player.dead:
		return
	if w.survival != null:
		w.survival._spawn_one("splitlet", pos)
	else:
		w.spawn_enemy("splitlet", pos, 1.0, 1.0, false, true)


func _on_death() -> void:
	for i in BROOD:
		var g := GooGlob.new()
		g.flat_art = "splitlet"
		g.from = global_position + Vector2(0, -6.0)
		g.to = global_position + Vector2.from_angle(TAU * i / BROOD + randf() * 1.2) * randf_range(14.0, 26.0)
		g.height = randf_range(10.0, 18.0)
		g.dur = randf_range(0.3, 0.45)
		g.size = 0.9
		g.on_land = hatch
		Game.world.effects.add_child(g)
