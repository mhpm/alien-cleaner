class_name CharacterAbility
extends Node
## A playable character's unique ability (CharacterData.ability = a script extending
## this one). The Player owns one, rebuilt whenever its character changes, and calls the
## hooks below; it knows nothing about what each ability does (new characters only add
## a subclass). Abilities live under the Player node, so they can _process too.

var player: Player


func setup(p: Player) -> void:
	player = p


## A shot of the equipped weapon left `origin` along `dir` toward `target` (may be null).
func on_fire(_origin: Vector2, _dir: Vector2, _target: Enemy) -> void:
	pass


## The BLAST button fired its shockwave (not while mutated: that is the mutant's dash).
func on_blast() -> void:
	pass


## Seconds the BLAST button needs between uses with this ability (its own recharge when
## it is stronger than a plain blast); -1 = the normal blast cooldown.
func cooldown() -> float:
	return -1.0


## True while the ability fires instead of the equipped weapon (fire / fire_interval).
func overrides_fire() -> bool:
	return false


## Fires the ability's own weapon from `origin` along `dir` (when overrides_fire()).
## Returns the recoil, like GunFire.fire.
func fire(_origin: Vector2, _dir: Vector2, _target: Enemy) -> float:
	return 0.0


## Seconds between the ability weapon's shots (when overrides_fire()).
func fire_interval() -> float:
	return GunFire.interval(Game.stats)


## Picture on the ability button (null = the plain BLAST look).
func icon() -> Texture2D:
	return null


func icon_tint() -> Color:
	return Color.WHITE


## Progress 0..1 toward the ability's next trigger, drawn as an inner arc on the button;
## -1 = nothing to show (the button's own cooldown already says it all).
func meter() -> float:
	return -1.0


func meter_color() -> Color:
	return Color("73eff7")
