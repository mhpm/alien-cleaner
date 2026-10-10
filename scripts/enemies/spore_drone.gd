class_name SporeDrone
extends Enemy
## SPORE DRONE (world 8 BIODOME): a floating dome full of glowing spores that DENIES
## GROUND. It drifts at mid range and every few seconds rains a SPORE CLOUD ahead of where
## you are walking (a circle marks it): green goo that slows you and stings while you stand
## in it. Between clouds it puffs 3 slow spores that drift after you. Popping it releases
## its spores in a ring. Cracks open and drops (the set's "death").

const RANGE := 110.0
const CHARGE := 0.7
const CLOUD_R := 26.0
const CLOUD_LIFE := 6.0
const LEAD := 0.9
const SPORE_SPEED := 55.0
const MAX_CLOUDS := 3  # of its own on the floor at once

var _turn := 1.0
var _clouds: Array[Node] = []
var _n := 0


func _init_ai() -> void:
	state = "float"
	state_t = randf_range(1.8, 2.8)
	_turn = 1.0 if randf() < 0.5 else -1.0


func _ai(delta: float) -> Vector2:
	state_t -= delta
	air = 12.0 + sin(t * 2.0 + phase) * 3.0
	var to_p := _to_player()
	match state:
		"float":
			if state_t <= 0.0 and to_p.length() < RANGE * 1.6:
				state = "charge"
				state_t = CHARGE
				alert.visible = true
				Sfx.play("charge", 0.5, -10.0)
				return Vector2.ZERO
			var v := to_p.normalized().orthogonal() * _turn * 0.7
			v += to_p.normalized() * clampf((to_p.length() - RANGE) / 30.0, -1.0, 1.0)
			return v.normalized() * speed
		"charge":
			if state_t <= 0.0:
				alert.visible = false
				_n += 1
				if _n % 2 == 1:
					_cloud()
				else:
					_puff(to_p)
				state = "float"
				state_t = randf_range(2.4, 3.2)
				if randf() < 0.4:
					_turn = -_turn
	return Vector2.ZERO


## A spore cloud rained ahead of where the astronaut is walking.
func _cloud() -> void:
	_clouds.assign(_clouds.filter(func(n: Variant) -> bool: return is_instance_valid(n)))
	if _clouds.size() >= MAX_CLOUDS:
		_puff(_to_player())
		return
	var w := Game.world
	var p := player()
	var at := w.room.open_near(p.global_position + p.velocity * LEAD)
	w.telegraph_circle(at, CLOUD_R, 0.8)
	var dmg := contact_damage * 0.3
	var me: WeakRef = weakref(self)  # it may be cleaned before the cloud lands
	get_tree().create_timer(0.8, false).timeout.connect(func() -> void:
		var g: Node = SporeDrone.cloud_at(at, dmg)
		var d: SporeDrone = me.get_ref()
		if g != null and d != null:
			d._clouds.append(g))
	Sfx.play("spit", 0.6, -8.0)


## The spore cloud: green goo that slows and stings (StickyGoo with damage).
static func cloud_at(at: Vector2, dmg: float) -> Node:
	var w := Game.world
	if w == null:
		return null
	var goo := StickyGoo.new()
	goo.position = at
	goo.life = CLOUD_LIFE
	goo.radius = CLOUD_R
	goo.damage = dmg
	goo.tag = "spores"
	goo.base = Color(0.55, 0.85, 0.2, 0.85)
	goo.light = Color(0.85, 1.0, 0.4)
	goo.rim = Color(0.2, 0.55, 0.45)
	goo.glint = Color(0.95, 1.0, 0.7)
	w.decals.add_child(goo)
	w.burst(at, Color("c8ff3a"), 12, 50.0, 0.6, 2.0, -30.0)
	return goo


func _puff(to_p: Vector2) -> void:
	var base := (to_p + Vector2(0, Player.BODY_Y)).angle()
	for i in 3:
		var d := Vector2.from_angle(base + (i - 1) * 0.5)
		Game.world.spawn_enemy_shot(hit_center() + d * 8.0, d * SPORE_SPEED, contact_damage * 0.5, "drone_spore").life = 3.5
	Sfx.play("pop", 0.5, -8.0)


func _anim_name() -> String:
	return "attack" if state == "charge" else "walk"


func _on_death() -> void:
	var w := Game.world
	var fx := AnimFx.spawn(w.effects, "spore_drone", "death", global_position + Vector2(0, -air), base_scale)
	fx.flip_h = face < 0.0
	var c := hit_center()
	for i in 6:
		var d := Vector2.from_angle(TAU * i / 6.0)
		w.spawn_enemy_shot(c + d * 6.0, d * SPORE_SPEED, contact_damage * 0.4, "drone_spore").life = 2.0
	w.burst(c, Color("c8ff3a"), 14, 80.0, 0.5, 2.0)
	Sfx.play("pop", 0.2, -6.0)
