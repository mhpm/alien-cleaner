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
