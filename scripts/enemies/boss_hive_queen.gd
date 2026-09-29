extends BossBase
## World 2 final boss HIVE QUEEN (hive_queen set), fought inside the BossFence.
## Calm (above half health):
##   scuttle  skitters around the astronaut, spitting little acid balls
##   spit     a fan of acid balls aimed where the astronaut is heading
##   eggs     drools goo eggs (HiveEgg) that hatch greenies unless broken in time
##   rain     lobs acid globs onto red circles: burning green puddles
## FURIOUS (under half health): a roar, crystals sprout on her back and she raises
## GUARDS (HiveGuard, again under GUARDS_AGAIN): while any guard stands a crystal
## shield takes SHIELD_ARMOR off every hit, so the guards have to go first. New attacks:
##   lances        three crystal lances in a row, each with its own warning line
##   crystal_ring  two rings of crystal shards
##   crystal_rain  crystals fall out of the sky (FallingCrystal) and shatter
## and the calm attacks grow (wider fans, more eggs and globs).
## Dies stunned and dizzy, melting into a pile of goo and crystals.

const CALM := ["scuttle", "spit", "eggs", "scuttle", "rain", "spit", "eggs", "scuttle"]
const FURY := ["lances", "crystal_ring", "scuttle", "eggs", "crystal_rain", "spit", "lances", "crystal_ring", "rain", "scuttle"]
const ACID_SPEED := 90.0
const LANCE_SPEED := 185.0
const FURY_ARMOR := 0.8  # furious without guards: 20% less damage
const SHIELD_ARMOR := 0.25  # guards standing: 75% less damage
const GUARDS := 3
const GUARDS_AGAIN := 0.2  # a second set of guards under this share of health
const MAX_EGGS := 5

var pattern_i := 0
var furious := false
var second_guards := false
var shielded := false
var shot_t := 0.0
var fire_t := 0.0  # > 0: show the spitting pose
var lances := 0
var strafe := 1.0
var shield: Sprite2D


func _init_ai() -> void:
	_size_to_player()
	state = "intro"
	state_t = 1.4
	Sfx.play("roar", 0.0)
	shield = Sprite2D.new()
	shield.texture = UpgradeData.shield_bubble(3)  # the purple crystal bubble
	shield.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	shield.material = add
	shield.position = Vector2(0, -tex_h * base_scale * 0.5)
	shield.scale = Vector2.ONE * (radius * 3.0 / shield.texture.get_width())
	shield.visible = false
	add_child(shield)


func _ai(delta: float) -> Vector2:
	state_t -= delta
	fire_t -= delta
	var to_p := _to_player()
	if not furious and hp < max_hp * 0.5 and state != "intro":
		_enrage()
	elif furious and not second_guards and hp < max_hp * GUARDS_AGAIN:
		second_guards = true
		_raise_guards()
	_update_shield()
	match state:
		"intro", "roar":
			squash = Vector2(1.0 + sin(t * 40.0) * 0.05, 1.0)
			if state_t <= 0.0:
				_next()
			return Vector2.ZERO
		"recover":
			if state_t <= 0.0:
				_next()
			return Vector2.ZERO
		"scuttle":
			# circle round the astronaut at mid range, spitting little acid balls
			shot_t -= delta
			if shot_t <= 0.0:
				shot_t = 0.45 if furious else 0.6
				var d := to_p.normalized()
				Game.world.spawn_enemy_shot(hit_center() + d * 12.0, d * ACID_SPEED, contact_damage * 0.5, "hive_acid")
				fire_t = 0.2
			if state_t <= 0.0:
				_next()
			var dist := to_p.length()
			var toward := to_p.normalized() * (0.6 if dist > 90.0 else (-0.5 if dist < 55.0 else 0.0))
			var side := to_p.normalized().orthogonal() * strafe
			if to_p.x != 0.0:
				face = signf(to_p.x)
			return (side + toward).normalized() * speed * (1.9 if furious else 1.6)
		"spit_aim":
			if state_t <= 0.0:
				_spit_fan()
				_after(0.6)
			return Vector2.ZERO
		"drool":
			if state_t <= 0.0:
				_lay_eggs()
				_after(0.6)
			return Vector2.ZERO
		"rain_aim":
			if state_t <= 0.0:
				_acid_rain()
				_after(0.7)
			return Vector2.ZERO
		"lance_aim":
			sprite.position.x = sin(t * 60.0) * 0.6
			if state_t <= 0.0:
				sprite.position.x = 0.0
				Game.world.spawn_enemy_shot(hit_center() + aim * 14.0, aim * LANCE_SPEED, contact_damage * 0.9, "hive_crystal")
				fire_t = 0.25
				Sfx.play("freeze", 0.1, -2.0)
				lances -= 1
				if lances > 0:
					_aim_lance(0.35)
				else:
					_after(0.6)
			return Vector2.ZERO
		"ring_aim":
			if state_t <= 0.0:
				_ring(14, randf() * TAU, 85.0, 0.5, "hive_shard")
				var off := randf() * TAU
				get_tree().create_timer(0.35, false).timeout.connect(func() -> void:
					if not dead:
						_ring(14, off + PI / 14.0, 70.0, 0.5, "hive_shard"))
				fire_t = 0.3
				_after(0.8)
			return Vector2.ZERO
		"sky_aim":
			if state_t <= 0.0:
				_crystal_rain()
				_after(0.9)
			return Vector2.ZERO
	return Vector2.ZERO


func _next() -> void:
	var list: Array = FURY if furious else CALM
	var step: String = list[pattern_i % list.size()]
	pattern_i += 1
	match step:
		"scuttle":
			state = "scuttle"
			state_t = 1.4 if furious else 1.8
			shot_t = 0.3
			strafe = -strafe
		"spit":
			state = "spit_aim"
			state_t = 0.45
			face = signf(_to_player().x) if _to_player().x != 0.0 else face
			Sfx.play("charge", 0.0, -6.0)
		"eggs":
			if get_tree().get_nodes_in_group("enemies").filter(func(n: Node) -> bool: return (n as Enemy).type_id == "hive_egg").size() >= MAX_EGGS:
				_next()  # enough eggs around: do something else
				return
			state = "drool"
			state_t = 0.8
			Sfx.play("roar", 0.2, -8.0)
		"rain":
			state = "rain_aim"
			state_t = 0.5
			Sfx.play("charge", 0.0, -6.0)
		"lances":
			lances = 3
			_aim_lance(0.55)
		"crystal_ring":
			state = "ring_aim"
			state_t = 0.7
			Sfx.play("charge", 0.0, -4.0)
		"crystal_rain":
			state = "sky_aim"
			state_t = 0.6
			Sfx.play("roar", 0.1, -6.0)


func _after(rest: float) -> void:
	state = "recover"
	state_t = rest * (0.75 if furious else 1.0)


## Half health: a roar, crystals sprout, and the guards rise.
func _enrage() -> void:
	furious = true
	pattern_i = 0
	state = "roar"
	state_t = 1.3
	speed *= 1.15
	armor = FURY_ARMOR
	var w := Game.world
	Sfx.play("roar", 0.0, 3.0)
	w.shake(1.0)
	w.hud.banner("THE QUEEN CALLS HER GUARDS!", Color("b35cff"), 22, 1.2)
	w.hud.tint_flash(Color("b35cff"), 0.3, 0.6)
	w.ring(hit_center(), 70.0, Color("b35cff"), 0.5, 4.0)
	w.burst(hit_center(), Color("c8ff3a"), 30, 140.0, 0.6, 2.5)
	for n in get_tree().get_nodes_in_group("enemy_shots"):
		(n as EnemyShot).pop()
	var p := player()
	var d := p.global_position - global_position
	if d.length() < 90.0:
		p.knock = d.normalized() * 240.0
	_raise_guards()


## GUARDS crystal guards around the fight: they shield the queen while they stand.
func _raise_guards() -> void:
	var w := Game.world
	var f := _fence()
	var c := f.global_position if f != null else global_position
	var r := (f.radius if f != null else 130.0) * 0.6
	var off := randf() * TAU
	var m := _minion_mults()
	for i in GUARDS:
		var pos := c + Vector2.from_angle(off + TAU * i / GUARDS) * r
		var g := EnemyData.create("hive_guard")
		g.position = pos
		g.toughen(m.x, 1.0, m.y)
		g.set("queen", self)
		w.entities.add_child(g)
		w.ring(pos, 20.0, Color("b35cff"), 0.4, 3.0)
		w.burst(pos, Color("b35cff"), 12, 70.0, 0.4, 2.0, -40.0)
	Sfx.play("freeze", 0.0, 2.0)


## Crystal shield: up while any guard stands (75% less damage), shatters when the last falls.
func _update_shield() -> void:
	var up := get_tree().get_nodes_in_group("hive_guards").size() > 0
	if up != shielded:
		shielded = up
		if up:
			armor = SHIELD_ARMOR
		else:
			armor = FURY_ARMOR if furious else 1.0
			Game.world.burst(hit_center(), Color("b35cff"), 24, 110.0, 0.5, 2.0)
			Game.world.hud.banner("SHIELD DOWN!", Color("c8ff3a"), 26, 0.7)
			Sfx.play("freeze", 0.0, 3.0)
	shield.visible = shielded
	if shielded:
		shield.modulate = Color(1, 1, 1, 0.75 + sin(t * 6.0) * 0.2)


## A fan of acid balls at where the astronaut is heading.
func _spit_fan() -> void:
	var p := player()
	var target := p.global_position + Vector2(0, Player.BODY_Y) + p.velocity * 0.35
	var d := (target - hit_center()).normalized()
	face = signf(d.x) if d.x != 0.0 else face
	var n := 5 if furious else 3
	for i in n:
		var a := (i - (n - 1) * 0.5) * 0.22
		Game.world.spawn_enemy_shot(hit_center() + d * 14.0, d.rotated(a) * ACID_SPEED * 1.1, contact_damage * 0.8, "hive_acid")
	fire_t = 0.35
	Sfx.play("spit", 0.0, 2.0)


## Goo eggs lobbed around the astronaut: they hatch greenies unless broken in time.
func _lay_eggs() -> void:
	var n := 3 if furious else 2
	var p := player().global_position
	var m := _minion_mults()
	for i in n:
		var to := _in_fence(p + Vector2.from_angle(randf() * TAU) * randf_range(40.0, 80.0), 14.0)
		var g := GooGlob.new()
		g.style = "hive"
		g.from = hit_center()
		g.to = to
		g.height = 70.0
		g.dur = 0.8 + i * 0.1
		g.size = 1.4
		g.on_land = func(at: Vector2) -> void:
			Game.world.spawn_enemy("hive_egg", at, m.x, 1.0, false, true, m.y)
		Game.world.effects.add_child(g)
	fire_t = 0.3


## Acid globs onto red circles around the astronaut: burning green puddles.
func _acid_rain() -> void:
	var p := player().global_position
	var n := 7 if furious else 5
	for i in n:
		var to := _in_fence(p if i == 0 else p + Vector2.from_angle(randf() * TAU) * randf_range(20.0, 75.0), 10.0)
		var g := GooGlob.new()
		g.style = "hive"
		g.from = hit_center()
		g.to = to
		g.height = randf_range(60.0, 90.0)
		g.dur = 1.0 + i * 0.07
		g.acid = true
		g.damage = contact_damage * 0.8
		g.puddle_r = 13.0
		g.puddle_life = 4.5 if furious else 3.5
		Game.world.effects.add_child(g)
		Game.world.telegraph_circle(to, 13.0, g.dur)
	fire_t = 0.3


func _aim_lance(windup: float) -> void:
	state = "lance_aim"
	state_t = windup
	aim = (player().global_position + Vector2(0, Player.BODY_Y) - hit_center()).normalized()
	face = signf(aim.x) if aim.x != 0.0 else face
	Game.world.telegraph_line(hit_center(), aim, 260.0, 10.0, state_t)
	Sfx.play("charge", 0.0, -6.0)


## Crystals falling out of the sky around (and onto) the astronaut.
func _crystal_rain() -> void:
	var p := player().global_position
	for i in 6:
		var at := _in_fence(p if i == 0 else p + Vector2.from_angle(TAU * i / 5.0 + randf()) * randf_range(30.0, 70.0), 12.0)
		var fc := FallingCrystal.new()
		fc.position = at
		fc.damage = contact_damage * 0.9
		var delay := i * 0.12
		get_tree().create_timer(delay, false).timeout.connect(func() -> void:
			if is_instance_valid(Game.world):
				Game.world.effects.add_child(fc))


func _anim_name() -> String:
	if fire_t > 0.0:
		return "crystal_spit" if furious else "spit"
	match state:
		"intro", "roar", "sky_aim":
			return "roar"
		"spit_aim":
			return "spit"
		"drool", "rain_aim":
			return "drool"
		"lance_aim", "ring_aim":
			return "crystal"
	return "crystal" if furious else "walk"


func _on_death() -> void:
	var w := Game.world
	# stunned, dizzy, and it melts into a pile of goo and crystals...
	var fx := AnimFx.spawn(w.decals, "hive_queen", "death", global_position, base_scale)
	fx.flip_h = face < 0.0
	var pos := global_position
	get_tree().create_timer(1.0, false).timeout.connect(func() -> void:
		var pd := GooPuddle.new()
		pd.style = "hive"
		pd.big = true
		pd.radius = 40.0
		pd.life = 14.0
		pd.position = pos
		w.decals.add_child(pd))
	# ...splashing goo all around, crystals flying
	for i in 16:
		var g := GooGlob.new()
		g.style = "hive"
		g.from = hit_center()
		g.to = pos + Vector2.from_angle(TAU * i / 16.0 + randf_range(-0.2, 0.2)) * randf_range(35.0, 95.0)
		g.height = randf_range(30.0, 70.0)
		g.dur = randf_range(0.5, 0.9)
		g.size = randf_range(0.9, 1.4)
		g.puddle_r = randf_range(8.0, 14.0)
		g.puddle_life = 10.0
		w.effects.add_child(g)
	w.burst(hit_center(), Color("b35cff"), 30, 150.0, 0.7, 2.5, 120.0)
	Sfx.play("explode", 0.0, 2.0)
	Sfx.play("freeze", 0.1)
