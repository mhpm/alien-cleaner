class_name EggCluster
extends Enemy
## World 6 (GENE VAULT): a cluster of alien eggs in goo, laid around the map by Explore
## ("eggs": n). It sleeps until the astronaut comes within WAKE: then the big egg
## splits (CRACK_TIME, it shivers and an alert shows), the OCTOLINGS climb out and the
## empty nest stays on the floor. Shoot it before it hatches and nothing comes out (it
## pops into the empty nest, XP as usual). Never moves (`anchored`).
## Art: tools/egg_cluster_ref.webp -> python tools/make_gene_vault_assets.py.

const WAKE := 125.0
const CRACK_TIME := 1.1
const HATCH_TIME := 0.6  # the 3 "hatch" frames
const OCTOLINGS := 2
## its shadow: small, dark and tucked under the goo (the round one of the aliens, as wide
## as the nest and centred on its bottom edge, made it look like it was floating)
const SHADOW_SCALE := Vector2(2.3, 1.1)
const SHADOW_Y := -5.0
const SHADOW_COL := Color(0.05, 0.0, 0.08, 0.95)


func _init_ai() -> void:
	anchored = true
	state = "idle"
	knock = Vector2.ZERO


func _ai(delta: float) -> Vector2:
	_sep = Vector2.ZERO
	knock = Vector2.ZERO
	state_t -= delta
	match state:
		"idle":
			if player().global_position.distance_to(global_position) < WAKE:
				state = "crack"
				state_t = CRACK_TIME
				alert.visible = true
				Sfx.play("alert", 0.15, -8.0)
		"crack":
			squash = Vector2(1.0 + sin(t * 40.0) * 0.04, 1.0)
			if state_t <= 0.0:
				state = "hatch"
				state_t = HATCH_TIME
				alert.visible = false
				Sfx.play("pop", 0.2, -4.0)
		"hatch":
			if state_t <= 0.0:
				_hatch()
	return Vector2.ZERO


func _anim_name() -> String:
	return "walk" if state == "idle" else state


func _animate(delta: float) -> void:
	super._animate(delta)
	sprite.scale = Vector2(base_scale, base_scale) * squash  # eggs do not wobble
	if shadow.position.y != SHADOW_Y:
		shadow.position.y = SHADOW_Y
		shadow.scale = SHADOW_SCALE
		shadow.modulate = SHADOW_COL
		_shadow_air = air  # Enemy leaves the scale alone while it stays on the floor


## The octolings jump out; the empty nest stays as a floor decal (no reward: it hatched).
func _hatch() -> void:
	var w := Game.world
	var s := w.survival
	var m := Vector2(s._hp_mult(), s._dmg_mult()) if s != null else Vector2.ONE
	var c := hit_center()
	w.burst(c, Color("c75bd6"), 14, 70.0, 0.45, 2.0)
	for i in OCTOLINGS:
		w.spawn_enemy("octoling", w.room.open_near(global_position + Vector2.from_angle(PI + PI * (i + 0.5) / OCTOLINGS) * 14.0), m.x, 1.0, false, true, m.y)
	w.add_splat(global_position, art, base_scale, face < 0.0, tint)
	dead = true
	targetable = false
	remove_from_group("enemies")
	queue_free()


func _on_death() -> void:
	Game.world.burst(hit_center(), Color("e86bff"), 16, 80.0, 0.5, 2.0)
