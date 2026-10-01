extends Node
## Reuses the shipped arena scene without changing it or writing a second copy.

func _ready() -> void:
	if not PlaygroundSession.valid():
		get_tree().call_deferred("change_scene_to_file", PlaygroundSession.PICKER)
		return
	var game := (load("res://scenes/game.tscn") as PackedScene).instantiate()
	game.set_script(load("res://scripts/playground/playground_world.gd"))
	game.get_node("HUD").set_script(load("res://scripts/playground/playground_hud.gd"))
	add_child(game)
