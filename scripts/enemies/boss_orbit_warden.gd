extends OrbitRaider
## Boss-only toughness. Horde enemies retain ordinary HP and uncapped damage.



func _init_ai() -> void:
	# sized like every boss (BossBase.fight_hp): a short fight as a wave event's mini boss
	max_hp = BossBase.fight_hp(max_hp, BossBase._player_dps(), BossBase.is_mini(type_id))
	var ex: Explore = Game.world.explore if Game.world != null else null
	if ex != null and ex.forge_cooled():  # world 5: the forge cooled, bosses weaker
		max_hp *= Explore.COOLED_HP
	hp = max_hp
	super._init_ai()


func take_damage(amount: float, dir := Vector2.ZERO, crit := false) -> void:
	super.take_damage(minf(amount, max_hp * BossBase.HIT_CAP), dir, crit)
