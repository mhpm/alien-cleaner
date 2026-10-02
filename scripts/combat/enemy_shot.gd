class_name EnemyShot
extends Node2D
## Projectile fired by aliens: slime glob, or a sprite-set shot from STYLES (droid
## plasma, UFO laser, octopus orb). Destroyed by walls or the player's air blast.

## tex_id -> fly art, scale, pop art, pop scale, pop tint, burst colour
const STYLES := {
	"orbit_plasma": {"art": "orbit_plasma", "scale": 0.18, "pop": "orbit_burst", "pop_s": 0.12, "tint": Color.WHITE, "color": Color("c8ff3a"), "hit": 6.0},
	"droid": {"art": "droid_shot", "scale": 0.1, "pop": "droid_pop", "pop_s": 0.12, "tint": Color.WHITE, "color": Color("73eff7")},
	"ufo": {"art": "ufo_shot", "scale": 0.16, "pop": "droid_pop", "pop_s": 0.12, "tint": Color(0.55, 1.6, 0.45), "color": Color("a7f070")},
	"octopus": {"art": "octopus_shot", "scale": 0.12, "pop": "octopus_pop", "pop_s": 0.11, "tint": Color.WHITE, "color": Color("41a6f6")},
	"eyeclops": {"art": "eyeclops_orb", "scale": 0.3, "pop": "glob_pop", "pop_s": 0.11, "tint": Color(1.5, 0.5, 1.7), "color": Color("d43cff"), "hit": 7.0},
	"plant": {"art": "plant_glob", "scale": 0.14, "pop": "glob_pop", "pop_s": 0.12, "tint": Color(1.6, 0.5, 0.8), "color": Color("ff3c6e"), "hit": 7.0},
	# Octo-Wizard: slow orb that curves towards you ("home" = turn rate, rad/s)
	"wizard": {"art": "wizard_orb", "scale": 0.11, "pop": "glob_pop", "pop_s": 0.14, "tint": Color(1.6, 0.6, 1.8), "color": Color("d43cff"), "hit": 7.0, "home": 1.7},
	# VOID ARCHMAGE: homing orb, plain orb, crescent blade (art points +x)
	"arch_orb": {"art": "arch_orb", "scale": 0.17, "pop": "glob_pop", "pop_s": 0.14, "tint": Color(1.6, 0.6, 1.8), "color": Color("d43cff"), "hit": 7.5, "home": 1.3},
	"arch_star": {"art": "arch_orb", "scale": 0.15, "pop": "glob_pop", "pop_s": 0.12, "tint": Color(1.6, 0.6, 1.8), "color": Color("d43cff"), "hit": 7.0},
	"arch_blade": {"art": "arch_blade", "scale": 0.15, "pop": "glob_pop", "pop_s": 0.1, "tint": Color(1.5, 0.6, 1.8), "color": Color("ff4fd8"), "hit": 8.0},
	# Big Red: fireball, acid blob, and the giant fireball that bursts into "split" blobs
	"big_red": {"art": "big_red_ball", "scale": 0.1, "pop": "glob_pop", "pop_s": 0.2, "tint": Color(1.5, 0.7, 1.1), "color": Color("ff4f9a"), "hit": 8.5},
	"red_blob": {"art": "big_red_blob", "scale": 0.24, "pop": "glob_pop", "pop_s": 0.1, "tint": Color(1.5, 0.7, 1.1), "color": Color("ff4f9a"), "hit": 6.0},
	# HIVE QUEEN: acid ball, crystal lance, crystal shard ("rot": the art points up)
	"hive_acid": {"art": "hive_acid", "scale": 0.13, "pop": "glob_pop", "pop_s": 0.18, "tint": Color(0.9, 1.5, 0.6), "color": Color("c8ff3a"), "hit": 8.0},
	"hive_crystal": {"art": "hive_crystal", "scale": 0.26, "pop": "hive_burst", "pop_s": 0.12, "tint": Color.WHITE, "color": Color("b35cff"), "hit": 7.0, "rot": PI * 0.5},
	"hive_shard": {"art": "hive_shard", "scale": 0.22, "pop": "hive_burst", "pop_s": 0.06, "tint": Color.WHITE, "color": Color("b35cff"), "hit": 5.5, "rot": PI * 0.5},
	# world 4 UFOs: the gunship's plasma ball, the scout's small comets and big comet (art points +x)
	"gunship": {"art": "gunship_shot", "scale": 0.16, "pop": "glob_pop", "pop_s": 0.12, "tint": Color(1.6, 0.6, 1.8), "color": Color("ff4fd8"), "hit": 7.0},
	"scout": {"art": "scout_shot", "scale": 0.14, "pop": "droid_pop", "pop_s": 0.1, "tint": Color(1.6, 0.6, 1.2), "color": Color("ff5fa8"), "hit": 5.5},
	"scout_comet": {"art": "scout_comet", "scale": 0.16, "pop": "droid_pop", "pop_s": 0.16, "tint": Color(1.6, 0.6, 1.2), "color": Color("ff5fa8"), "hit": 7.0},
	# Jelly Pod: a spore that slows down and hangs in the air like a mine ("drag" = slowdown/s, "min" = cruise speed)
	"jelly": {"art": "jelly_spore", "scale": 0.16, "pop": "glob_pop", "pop_s": 0.14, "tint": Color(1.6, 0.5, 1.8), "color": Color("ff3cf0"), "hit": 7.0, "drag": 2.2, "min": 4.0},
	# Spike Mine: a little fireball (art points +x)
	"mine": {"art": "mine_shot", "scale": 0.16, "pop": "glob_pop", "pop_s": 0.12, "tint": Color(1.6, 0.8, 0.4), "color": Color("ff7a2a"), "hit": 6.5},
	# COMMANDER ZORP: plasma orb, big orb that bursts into bolts ("split_tex"), bolt, crescent blade
	"zorp_orb": {"art": "zorp_orb", "scale": 0.2, "pop": "droid_pop", "pop_s": 0.12, "tint": Color(0.6, 1.4, 1.6), "color": Color("5fe6ff"), "hit": 6.5},
	"zorp_big": {"art": "zorp_big", "scale": 0.26, "pop": "droid_pop", "pop_s": 0.3, "tint": Color(0.6, 1.4, 1.6), "color": Color("5fe6ff"), "hit": 12.0, "split": 10, "split_tex": "zorp_bolt"},
	"zorp_bolt": {"art": "zorp_bolt", "scale": 0.4, "pop": "droid_pop", "pop_s": 0.08, "tint": Color(0.6, 1.4, 1.6), "color": Color("5fe6ff"), "hit": 5.0},
	"zorp_blade": {"art": "zorp_blade", "scale": 0.3, "pop": "droid_pop", "pop_s": 0.1, "tint": Color(0.8, 1.6, 0.8), "color": Color("c8ff3a"), "hit": 6.0},
	# world 4 sheet enemies: Comet Hopper's comet, Ring Bug's boomerang ring (RingShot),
	# Drill Orbiter's drill blast, Nova Puffer's star bubble (art points +x)
	"hopper": {"art": "hopper_comet", "scale": 0.2, "pop": "glob_pop", "pop_s": 0.14, "tint": Color(1.6, 0.9, 0.4), "color": Color("ff8a2a"), "hit": 7.0},
	"ring": {"art": "ring_bug_ring", "scale": 0.24, "pop": "droid_pop", "pop_s": 0.14, "tint": Color(1.6, 1.1, 0.5), "color": Color("ffb030"), "hit": 10.0},
	"drill": {"art": "drill_cone", "scale": 0.22, "pop": "droid_pop", "pop_s": 0.14, "tint": Color(0.6, 1.2, 1.7), "color": Color("5fb8ff"), "hit": 8.0},
	"nova": {"art": "nova_bubble", "scale": 0.12, "pop": "glob_pop", "pop_s": 0.12, "tint": Color(1.6, 0.6, 1.6), "color": Color("ff4fd8"), "hit": 6.5},
	# world 4 drones: curving crescent, tesla orb, homing rocket (art points +x)
	"crescent": {"art": "blade_crescent", "scale": 0.2, "pop": "glob_pop", "pop_s": 0.12, "tint": Color(1.6, 0.9, 0.4), "color": Color("ffb030"), "hit": 7.0, "home": 1.1},
	"tesla": {"art": "tesla_orb", "scale": 0.22, "pop": "droid_pop", "pop_s": 0.12, "tint": Color(0.6, 1.2, 1.7), "color": Color("5fb8ff"), "hit": 6.0},
	"rocket": {"art": "crab_rocket", "scale": 0.3, "pop": "glob_pop", "pop_s": 0.2, "tint": Color(1.6, 0.8, 0.4), "color": Color("ff7a2a"), "hit": 7.0, "home": 1.6},
	# world 4, second sheet: Meteor Peeper's meteor (bursts into rocks), Bubble Brain's
	# homing bubble, Tentacle Bell's bubble chain
	"peeper": {"art": "peeper_meteor", "scale": 0.24, "pop": "glob_pop", "pop_s": 0.2, "tint": Color(1.6, 0.8, 0.4), "color": Color("ff8a2a"), "hit": 7.5, "split": 5, "split_tex": "peeper_rock"},
	"peeper_rock": {"art": "peeper_rock", "scale": 0.16, "pop": "glob_pop", "pop_s": 0.1, "tint": Color(1.4, 0.9, 0.6), "color": Color("c07040"), "hit": 5.5},
	"brain": {"art": "brain_bubble", "scale": 0.16, "pop": "glob_pop", "pop_s": 0.16, "tint": Color(0.6, 1.3, 1.8), "color": Color("5fd0ff"), "hit": 7.0, "home": 2.0},
	"bell": {"art": "bell_bubble", "scale": 0.13, "pop": "glob_pop", "pop_s": 0.12, "tint": Color(1.6, 0.6, 1.6), "color": Color("ff5fe0"), "hit": 6.0},
	# world 4, third sheet: Nebula Pod's orb, Ring-Eye's sniper orb, Puddle Radar's bubble, Comet Baby's glob (art points +x)
	"nebula": {"art": "nebula_orb", "scale": 0.16, "pop": "glob_pop", "pop_s": 0.12, "tint": Color(1.6, 0.6, 1.6), "color": Color("ff4fd8"), "hit": 6.0},
	"ring_eye": {"art": "ring_eye_orb", "scale": 0.2, "pop": "droid_pop", "pop_s": 0.14, "tint": Color(0.6, 1.3, 1.8), "color": Color("5fd0ff"), "hit": 7.0},
	"radar": {"art": "radar_bubble", "scale": 0.16, "pop": "glob_pop", "pop_s": 0.14, "tint": Color(1.6, 0.6, 1.6), "color": Color("ff5fe0"), "hit": 6.5},
	"baby": {"art": "baby_glob", "scale": 0.16, "pop": "glob_pop", "pop_s": 0.12, "tint": Color(0.9, 1.6, 0.6), "color": Color("a7f070"), "hit": 6.0},
	# world 4, fourth sheet: Tadpole's orbiting bubble, Pupil's plasma, Tentacle Pod's big
	# bubble (slow, homing, bursts into "pod_bit" bubbles) and its bits, Pearl Flyer's pearl
	"tadpole": {"art": "tadpole_bubble", "scale": 0.14, "pop": "glob_pop", "pop_s": 0.12, "tint": Color(0.6, 1.4, 1.8), "color": Color("5fe6ff"), "hit": 6.5},
	"pupil": {"art": "pupil_plasma", "scale": 0.15, "pop": "glob_pop", "pop_s": 0.14, "tint": Color(1.6, 0.6, 1.6), "color": Color("ff4fd8"), "hit": 7.0},
	"pod_big": {"art": "pod_bubble", "scale": 0.3, "pop": "glob_pop", "pop_s": 0.3, "tint": Color(0.7, 1.2, 1.8), "color": Color("7fc8ff"), "hit": 11.0, "home": 0.9, "split": 8, "split_tex": "pod_bit"},
	"pod_bit": {"art": "pod_bubble", "scale": 0.11, "pop": "glob_pop", "pop_s": 0.1, "tint": Color(0.7, 1.2, 1.8), "color": Color("7fc8ff"), "hit": 5.0},
	"pearl": {"art": "slime_pearl", "scale": 0.16, "pop": "glob_pop", "pop_s": 0.14, "tint": Color(0.9, 1.6, 0.6), "color": Color("c8ff3a"), "hit": 6.5},
	# world 4, fifth sheet: Martian Scout's orb, Cyclops Pod's tethered orb, Tentacle Orbiter's
	# gravity orb (stops, then bursts into "orbiter_bit"), Slime Comet's glob
	"martian": {"art": "martian_orb", "scale": 0.16, "pop": "glob_pop", "pop_s": 0.12, "tint": Color(1.6, 0.6, 1.4), "color": Color("ff4fb8"), "hit": 6.5},
	"cyclops": {"art": "cyclops_orb", "scale": 0.2, "pop": "droid_pop", "pop_s": 0.16, "tint": Color(0.6, 1.3, 1.8), "color": Color("5fd8ff"), "hit": 8.0},
	"orbiter": {"art": "orbiter_orb", "scale": 0.3, "pop": "glob_pop", "pop_s": 0.3, "tint": Color(1.5, 0.6, 1.8), "color": Color("c060ff"), "hit": 9.0, "drag": 2.0, "min": 0.0, "split": 8, "split_tex": "orbiter_bit"},
	"orbiter_bit": {"art": "orbiter_orb", "scale": 0.1, "pop": "glob_pop", "pop_s": 0.1, "tint": Color(1.5, 0.6, 1.8), "color": Color("c060ff"), "hit": 5.0},
	"comet_slime": {"art": "comet_slime", "scale": 0.16, "pop": "glob_pop", "pop_s": 0.14, "tint": Color(0.9, 1.6, 0.6), "color": Color("a7f070"), "hit": 6.5},
	# world 4, sixth sheet: Blink Saucer's bubble, Nugget Ship's heavy ray-orb, Goo Lantern's bubble
	"blink": {"art": "blink_bubble", "scale": 0.15, "pop": "glob_pop", "pop_s": 0.12, "tint": Color(1.6, 0.6, 1.4), "color": Color("ff6fc8"), "hit": 6.0},
	"nugget": {"art": "nugget_orb", "scale": 0.22, "pop": "droid_pop", "pop_s": 0.18, "tint": Color(0.6, 1.3, 1.8), "color": Color("5fd0ff"), "hit": 8.5},
	"lantern": {"art": "lantern_bubble", "scale": 0.15, "pop": "glob_pop", "pop_s": 0.12, "tint": Color(1.5, 0.6, 1.8), "color": Color("c060ff"), "hit": 6.0},
	# MAGMA DRAKE: fireball, crescent wave, and the meteor that bursts into fireballs (art points +x)
	"magma": {"art": "magma_fire", "scale": 0.15, "pop": "glob_pop", "pop_s": 0.14, "tint": Color(1.6, 0.8, 0.4), "color": Color("ff8a2a"), "hit": 6.5},
	"magma_crescent": {"art": "magma_crescent", "scale": 0.22, "pop": "glob_pop", "pop_s": 0.16, "tint": Color(1.6, 0.8, 0.4), "color": Color("ff8a2a"), "hit": 9.0},
	"magma_meteor": {"art": "magma_meteor", "scale": 0.24, "pop": "glob_pop", "pop_s": 0.4, "tint": Color(1.6, 0.8, 0.4), "color": Color("ff8a2a"), "hit": 12.0, "split": 10, "split_tex": "magma"},
	# TOXIC ANGLER: a bubble that swells ("grow" = its frames play over its life) and bursts
	# into droplets, the droplets, and the spine-storm droplet (art is centred, round)
	"angler": {"art": "angler_bubble", "scale": 0.2, "pop": "angler_pop", "pop_s": 0.17, "tint": Color.WHITE, "color": Color("a7f070"), "hit": 8.5, "grow": true, "split": 6, "split_tex": "angler_drop"},
	"angler_drop": {"art": "angler_drop", "scale": 0.15, "pop": "angler_pop", "pop_s": 0.07, "tint": Color.WHITE, "color": Color("a7f070"), "hit": 5.5},
	# DRILLBACK: a chunk of rock (rubble, debris of the bursts)
	"drill_chunk": {"art": "drill_rock", "scale": 0.13, "pop": "drill_boom", "pop_s": 0.08, "tint": Color(1.1, 0.95, 0.8), "color": Color("b9803f"), "hit": 5.0},
	# BLOBULUS: a droplet of slime
	"blob_drop": {"art": "blob_drop", "scale": 0.1, "pop": "blob_pop", "pop_s": 0.07, "tint": Color.WHITE, "color": Color("5fd0ff"), "hit": 5.5},
	"big_red_mega": {"art": "big_red_ball", "scale": 0.19, "pop": "glob_pop", "pop_s": 0.45, "tint": Color(1.6, 0.8, 1.2), "color": Color("ff4f9a"), "hit": 13.0, "split": 12},
}

const WORLD_MASK := 1

var vel := Vector2.ZERO
var damage := 10.0
var life := 4.0
var tex_id := "glob"
var no_split := false
var span := 0.0  # total life when first stepped (the "grow" frames spread over it)
var t := 0.0
var sprite: AnimatedSprite2D


func _ready() -> void:
	add_to_group("enemy_shots")
	sprite = Art.make_anim(_art(), _scale())
	sprite.rotation = vel.angle() + (float(STYLES[tex_id].get("rot", 0.0)) if STYLES.has(tex_id) else 0.0)
	if tex_id == "glob_green":
		sprite.self_modulate = Color(0.55, 1.5, 0.5)
	add_child(sprite)


func _physics_process(delta: float) -> void:
	t += delta
	life -= delta
	if life <= 0.0:
		pop()
		return
	if STYLES.has(tex_id) and STYLES[tex_id].has("home"):
		var target := Game.world.player
		if not target.dead:
			var want := (target.global_position + Vector2(0, Player.BODY_Y) - global_position).angle()
			var turn := float(STYLES[tex_id].home) * delta
			vel = vel.rotated(clampf(angle_difference(vel.angle(), want), -turn, turn))
	if STYLES.has(tex_id) and STYLES[tex_id].has("grow"):
		if span == 0.0:
			span = life + delta
		var n := sprite.sprite_frames.get_frame_count(sprite.animation)
		sprite.frame = mini(n - 1, int(t / span * n))
	if STYLES.has(tex_id) and STYLES[tex_id].has("drag"):
		var st: Dictionary = STYLES[tex_id]
		vel = vel.move_toward(vel.normalized() * float(st.get("min", 0.0)), vel.length() * float(st.drag) * delta)
	var motion := vel * delta
	var q := PhysicsRayQueryParameters2D.create(global_position, global_position + motion, WORLD_MASK)
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		var col: Object = hit.collider
		if col != null and col.has_method("bullet_hit"):
			col.call("bullet_hit", damage)
		global_position = hit.position
		pop()
		return
	global_position += motion
	sprite.scale = Vector2.ONE * _scale() * (1.0 + sin(t * 20.0) * 0.08)
	var p := Game.world.player
	var hit_r := float(STYLES[tex_id].get("hit", 7.5)) if STYLES.has(tex_id) else 7.5
	if not p.dead and global_position.distance_to(p.global_position + Vector2(0, Player.BODY_Y)) < hit_r:
		p.take_damage(damage, global_position)
		if STYLES.has(tex_id) and STYLES[tex_id].has("split_tex"):
			no_split = true  # it already hit: no burst of bits on top of the astronaut
		pop()


func _art() -> String:
	return str(STYLES[tex_id].art) if STYLES.has(tex_id) else "glob"


func _scale() -> float:
	return float(STYLES[tex_id].scale) if STYLES.has(tex_id) else 0.17


func pop() -> void:
	if STYLES.has(tex_id):
		var st: Dictionary = STYLES[tex_id]
		var f := AnimFx.spawn(Game.world.effects, str(st.pop), "pop", global_position, float(st.pop_s))
		f.self_modulate = st.tint
		f.create_tween().tween_property(f, "modulate:a", 0.0, 0.15)
		Game.world.burst(global_position, st.color, 5, 40.0, 0.3, 2.0)
		var n := 0 if no_split else int(st.get("split", 0))
		if n > 0:  # the giant fireball bursts into a ring of acid blobs
			Sfx.play("explode", 0.1, -4.0)
			Game.world.shake(0.4)
			Game.world.ring(global_position, 24.0, st.color, 0.3, 3.0)
			var off := randf() * TAU
			for i in n:
				Game.world.spawn_enemy_shot(global_position, Vector2.from_angle(off + TAU * i / n) * 80.0, damage * 0.5, str(st.get("split_tex", "red_blob")))
		queue_free()
		return
	var c := Color("a7f070") if tex_id == "glob_green" else Color("ff4fd8")
	var fx := AnimFx.spawn(Game.world.effects, "glob_pop", "pop", global_position, 0.14)
	if tex_id == "glob_green":
		fx.self_modulate = Color(0.55, 1.5, 0.5)
	Game.world.burst(global_position, c, 5, 40.0, 0.3, 2.0)
	queue_free()
