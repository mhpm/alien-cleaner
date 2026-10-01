extends OrbitRaider
## Boss-only toughness. Horde enemies retain ordinary HP and uncapped damage.

func _init_ai() -> void:
	max_hp = maxf(max_hp, BossBase._player_dps() * BossBase.DPS_REALISM * BossBase.TARGET_SECS)
	hp = max_hp
	super._init_ai()


func take_damage(amount: float, dir := Vector2.ZERO, crit := false) -> void:
	super.take_damage(minf(amount, max_hp * BossBase.HIT_CAP), dir, crit)
