class_name DecoyAbility
extends CharacterAbility
## The kid's HOLO DECOY: every BLAST also leaves a hologram of him where he stands
## (HoloDecoy). Nearby aliens go for it instead of him, and it blows up when it fades.
## Only one at a time: a new BLAST replaces the old decoy (it goes off right away).

var decoy: HoloDecoy


## The kid himself in hologram cyan (the decoy BLAST leaves).
func icon() -> Texture2D:
	return player.body.character.portrait()


func icon_tint() -> Color:
	return HoloDecoy.HOLO


func on_blast() -> void:
	if decoy != null and is_instance_valid(decoy) and not decoy.is_resolved():
		decoy.detonate()
	decoy = HoloDecoy.new()
	decoy.copy_look(player.body)
	Game.world.entities.add_child(decoy)
	decoy.global_position = player.global_position
