class_name HeartShotAbility
extends CharacterAbility
## The girl's HEART SHOT: every EVERY shots of any weapon she also throws a pink heart at
## her target. The alien it hits is charmed (Charm) for CHARM_TIME seconds and fights for
## the crew; bosses are only slowed.

const EVERY := 7  # shots between hearts
const CHARM_TIME := 5.0
const SPEED := 190.0
const DAMAGE := 0.5  # x the crew's base damage (the heart itself barely hurts)
const ART := "res://assets/guns/shot_heart.png"

var shots := 0

static var _tex: Texture2D


static func heart_tex() -> Texture2D:
	if _tex == null:
		_tex = load(ART)
	return _tex


func on_fire(origin: Vector2, dir: Vector2, target: Enemy) -> void:
	shots += 1
	if shots % EVERY != 0:
		return
	var d := dir
	if target != null and is_instance_valid(target):
		d = (target.hit_center() - origin).normalized()
	var h := HeartShot.new()
	h.dir = d
	h.speed = SPEED
	h.damage = float(Game.stats.damage) * DAMAGE
	h.charm_time = CHARM_TIME
	Game.world.effects.add_child(h)
	h.global_position = origin
	Sfx.play("select", 0.1, -4.0)
