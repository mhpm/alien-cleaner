class_name SpecimenVat
extends Enemy
## World 6 (GENE VAULT) objective, placed by Explore ("vats": n): a CLONING VAT in the
## middle of a hall, with a specimen floating inside. While it stands and the astronaut is
## within REACH, every BIRTH_EVERY seconds (sooner as it cracks) it marks a circle on the
## floor and lets out a brood of SPECIMENS (never more than MAX_OWN of its own alive).
## Shoot it down: the glass cracks (and the specimen inside winces) under 60% health, then
## it bursts, breaks apart and leaves its remains on the floor (the set's "splat"; art
## tools/specimen_vat_ref.webp -> python tools/make_gene_vault_assets.py). Breaking every
## vat PURGES THE VAULT (Explore.vault_purged): the final boss gets no reinforcements.
## Never moves (no separation push, no knockback) and the horde leash / wipe leave it be
## (`anchored`).

const REACH := 300.0
const BIRTH_EVERY := 8.0
const WARN := 1.0
const MAX_OWN := 6
const SPECIMENS := ["mini_slime", "mini_slime", "splitlet", "splitlet", "jelly_pod", "tentacle_pod"]
const CRACK_AT := 0.6
const TOUGH_SECS := 7.0  # its health: about this many seconds of the astronaut's damage

var _birth_t := 0.0
var _warned := false
var _own: Array[Enemy] = []
var _at := Vector2.ZERO


func _init_ai() -> void:
	anchored = true
	state = "idle"
	knock = Vector2.ZERO
	_birth_t = randf_range(3.0, BIRTH_EVERY)
	var need := BossBase._player_dps() * BossBase.DPS_REALISM * TOUGH_SECS
	if need > max_hp:
		max_hp = need
		hp = max_hp


func _ai(delta: float) -> Vector2:
	_sep = Vector2.ZERO
	knock = Vector2.ZERO
	var hurt := 1.0 - hp / max_hp
	if randf() < delta * (1.5 + hurt * 5.0):
		Game.world.burst(hit_center() + Vector2(randf_range(-6, 6), randf_range(-10, 10)), Color("9ff6ff"), 1, 14.0, 0.6, 1.5, -40.0)
	if player().global_position.distance_to(global_position) > REACH:
		return Vector2.ZERO
	_birth_t -= delta * (1.0 + hurt * 0.8)
	if _birth_t <= WARN and not _warned:
		_warned = true
		_at = Game.world.room.open_near(global_position + Vector2.from_angle(randf_range(0.2, PI - 0.2)) * 34.0)
		Game.world.telegraph_circle(_at, 20.0, WARN)
		alert.visible = true
		Sfx.play("alert", 0.1, -8.0)
	if _birth_t <= 0.0:
		_birth_t = BIRTH_EVERY
		_warned = false
		alert.visible = false
		_brood()
	return Vector2.ZERO


func _brood() -> void:
	_own.assign(_own.filter(func(e: Variant) -> bool: return is_instance_valid(e) and not (e as Enemy).dead))
	var n := mini(MAX_OWN - _own.size(), 2 + int(hp < max_hp * 0.5))
	if n <= 0:
		return
	var w := Game.world
	var s := w.survival
	var m := Vector2(s._hp_mult(), s._dmg_mult()) if s != null else Vector2.ONE
	squash = Vector2(1.15, 0.9)
	w.burst(_at, Color("5fe8ff"), 14, 70.0, 0.5, 2.0)
	w.burst(_at, Color("ff4fd8"), 8, 50.0, 0.4, 2.0)
	Sfx.play("pop", 0.15, -4.0)
	for i in n:
		var id: String = SPECIMENS[randi() % SPECIMENS.size()]
		var e := w.spawn_enemy(id, w.room.open_near(_at + Vector2(randf_range(-12, 12), randf_range(-8, 8))), m.x, 1.0, false, true, m.y)
		if e != null:
			_own.append(e)


## Cracked glass under CRACK_AT of its health; no wobble: it is a capsule.
func _anim_name() -> String:
	return "crack" if hp < max_hp * CRACK_AT else "walk"


func _animate(delta: float) -> void:
	super._animate(delta)
	sprite.scale = Vector2(base_scale, base_scale) * squash


func _on_death() -> void:
	var w := Game.world
	w.burst(hit_center(), Color("5fe8ff"), 34, 140.0, 0.7, 2.6)
	w.burst(hit_center(), Color(1, 1, 1, 0.9), 14, 90.0, 0.4, 2.0)
	w.shake(0.5)
	Sfx.play("explode", 0.1, -2.0)
	if w.explore != null:
		w.explore.vat_broken(self)
