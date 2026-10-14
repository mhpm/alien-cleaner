class_name ShotgunAbility
extends CharacterAbility
## ZED's ability: BLAST draws his personal SHOTGUN (assets/guns/zed_shotgun.png) for
## DURATION seconds and he fires it instead of his equipped weapon: a fan of PELLETS
## short-range pellets that shove the aliens back hard (PUSH). Then he puts it away and
## the button recharges for COOLDOWN seconds from THAT moment (holds_cooldown: frozen
## while it is out; cooldown(): longer than a plain blast; perks that shorten the blast
## shorten it too). About twice his weapon's damage up close: 5 s out, then 10 s without.
## While mutated the mutant fires its own gun (the shotgun waits until it reverts).

const DURATION := 5.0
const COOLDOWN := 10.0  # without it after putting it away, at the base blast cooldown
const PELLETS := 7
const ARC := 0.7  # radians the fan spreads over
const PELLET_DMG := 0.6  # x the crew's base hit, each pellet
const PUSH := 140.0  # knockback per pellet
const SPEED := 270.0
const RANGE_LIFE := 0.4  # seconds a pellet flies (short range)
const RATE := 0.55  # seconds between blasts at the base fire rate (Rapid Fire speeds it up)
const RECOIL := 5.0
const ART := "zed_shotgun"  # assets/guns/<ART>.png
const GRIP := Vector2(17, 40)  # in the art's px
const TIP := Vector2(95, 18)
const COLOR := Color("ff5a3c")

var time_left := 0.0


## The gun art, with mipmaps (GunFire.tex): the button icon and the weapon in hand.
static func gun_tex() -> Texture2D:
	return GunFire.tex(ART)


func cooldown() -> float:
	return COOLDOWN * float(Game.stats.blast_cooldown) / Game.BLAST_COOLDOWN


func holds_cooldown() -> bool:
	return time_left > 0.0


func icon() -> Texture2D:
	return gun_tex()


## While the shotgun is out: the time it has left.
func meter() -> float:
	return time_left / DURATION if time_left > 0.0 else -1.0


func meter_color() -> Color:
	return COLOR


func on_blast() -> void:
	time_left = DURATION
	_show_gun()  # in his hand at once
	Sfx.play("shotgun", 0.05, -2.0)
	Game.world.burst(player.global_position + Vector2(0, Player.BODY_Y), COLOR, 10, 60.0, 0.3, 1.8)


func overrides_fire() -> bool:
	return time_left > 0.0 and not _mutated()


func fire_interval() -> float:
	return RATE * float(Game.stats.fire_interval) / GunFire.BASE_INTERVAL


func fire(origin: Vector2, dir: Vector2, _target: Enemy) -> float:
	var dmg := GunFire.unit(player) * PELLET_DMG
	for k in PELLETS:
		var a := (float(k) / (PELLETS - 1) - 0.5) * ARC + randf_range(-0.04, 0.04)
		var b := GunFire.shot("shot_nova", origin, dir.rotated(a), SPEED * randf_range(0.9, 1.1), dmg, 10.0, 3.0, RANGE_LIFE)
		b.push = PUSH
		b.modulate = Color(1.6, 0.7, 0.5)
	Sfx.play("shotgun", 0.1, -3.0)
	Game.world.burst(origin, COLOR, 6, 70.0, 0.2, 1.8, 0.0, dir, 0.4)
	return RECOIL


func _process(delta: float) -> void:
	if time_left > 0.0:
		time_left = maxf(0.0, time_left - delta)
	_show_gun()


## The shotgun in his hand while it is out; his equipped weapon back when it is put away
## (never touched while mutated: the mutant holds its own gun).
func _show_gun() -> void:
	if _mutated():
		return
	var body := player.body
	var out := time_left > 0.0
	if out and body.held != gun_tex():
		body.hold_gun(gun_tex(), GRIP, TIP)
	elif not out and body.held == gun_tex():
		body.refresh()


func _mutated() -> bool:
	var inf := player.infected
	return inf.active or inf.transforming or inf.reverting


## Swapped for another character mid-blast: the shotgun goes back in his pocket.
func _exit_tree() -> void:
	if player != null and is_instance_valid(player) and player.body.held == gun_tex():
		player.body.refresh()
