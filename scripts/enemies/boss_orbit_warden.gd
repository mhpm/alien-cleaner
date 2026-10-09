extends OrbitRaider
## Boss-only toughness. Horde enemies retain ordinary HP and uncapped damage.

## As a mini boss (an event of a stage whose final boss is someone else) the fight is shorter.
const MINI_SECS := 45.0


func _init_ai() -> void:
	var s := Game.world.survival if Game.world != null else null
	var mini := s != null and str(s.def.get("boss", "")) != type_id
	max_hp = maxf(max_hp, BossBase._player_dps() * BossBase.DPS_REALISM * (MINI_SECS if mini else BossBase.TARGET_SECS))
	var ex: Explore = Game.world.explore if Game.world != null else null
	if ex != null and ex.forge_cooled():  # world 5: the forge cooled, bosses weaker
		max_hp *= Explore.COOLED_HP
	hp = max_hp
	super._init_ai()


func take_damage(amount: float, dir := Vector2.ZERO, crit := false) -> void:
	super.take_damage(minf(amount, max_hp * BossBase.HIT_CAP), dir, crit)
