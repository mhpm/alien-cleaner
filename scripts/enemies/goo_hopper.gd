extends Enemy
## GOO SEED HOPPER (world 4): a green seed pod with an orange eye inside. It HOPS after you
## (can't touch you in the air) and every other landing it opens up ("attack") and lobs
## a glob of goo at where you stand (GooGlob, style "hive"): it splashes into an acid
## puddle that burns for a few seconds. Splits open and oozes into a puddle (the set's
## "splat").

const HOP_TIME := 0.5
const HOP_REACH := 60.0
const HOP_HEIGHT := 20.0
const AIM_TIME := 0.5
const LOB_RANGE := 150.0

var _hops := 0
var _hop_v := Vector2.ZERO


func _init_ai() -> void:
	state = "rest"
	state_t = randf_range(0.4, 0.9)


func _ai(delta: float) -> Vector2:
	state_t -= delta
	var to_p := _to_player()
	match state:
		"rest":
			air = 0.0
			if state_t <= 0.0:
				_hop_v = (to_p + player().velocity * 0.3).limit_length(HOP_REACH) / HOP_TIME
				state = "hop"
				state_t = HOP_TIME
				squash = Vector2(0.8, 1.25)
				Sfx.play("bounce", 0.2, -10.0)
			return Vector2.ZERO
		"hop":
			var k := 1.0 - clampf(state_t / HOP_TIME, 0.0, 1.0)
			air = sin(k * PI) * HOP_HEIGHT
			if state_t <= 0.0:
				air = 0.0
				squash = Vector2(1.3, 0.75)
				Game.world.burst(global_position, Color("a7f070"), 6, 50.0, 0.3, 2.0, 60.0)
				_hops += 1
				if _hops % 2 == 0 and to_p.length() < LOB_RANGE:
					state = "aim"
					state_t = AIM_TIME
					alert.visible = true
				else:
					state = "rest"
					state_t = randf_range(0.3, 0.6)
				return Vector2.ZERO
			return _hop_v
		"aim":
			face = signf(to_p.x) if to_p.x != 0.0 else face
			if state_t <= 0.0:
				alert.visible = false
				_lob()
				state = "rest"
				state_t = randf_range(0.6, 0.9)
			return Vector2.ZERO
	return Vector2.ZERO


func _lob() -> void:
	var p := player()
	var to := p.global_position + p.velocity * 0.4
	var b := Game.world.room.bounds().grow(-6.0)
	to = to.clamp(b.position, b.end)
	var g := GooGlob.new()
	g.style = "hive"
	g.from = hit_center()
	g.to = to
	g.height = 55.0
	g.dur = 0.75
	g.acid = true
	g.damage = contact_damage * 0.7
	g.puddle_r = 13.0
	g.puddle_life = 4.0
	Game.world.effects.add_child(g)
	Game.world.telegraph_circle(to, 13.0, g.dur)
	Sfx.play("spit", 0.1, -6.0)
	squash = Vector2(1.15, 0.9)


func _anim_name() -> String:
	return "attack" if state == "aim" else "walk"


func _on_death() -> void:
	Game.world.burst(hit_center(), Color("a7f070"), 12, 70.0, 0.45, 2.5, 60.0)
	Sfx.play("pop", 0.15, -4.0)
