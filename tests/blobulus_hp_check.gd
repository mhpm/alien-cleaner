extends Node
## World 1: BLOBULUS spawned by its wave event gets the mini boss health (BossBase.fight_hp).

func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	Game.playground_active = true
	Game.new_run(0)
	var w := (load("res://scenes/game.tscn") as PackedScene).instantiate() as GameWorld
	add_child(w)
	for i in 20:
		await get_tree().physics_frame
	w.survival.set_physics_process(false)
	w.survival.t = 222.0  # when its wave event fires
	var b := w.spawn_enemy("blobulus", w.player.global_position + Vector2(0, -120), w.survival._boss_hp_mult())
	for i in 5:
		await get_tree().physics_frame
	var secs := b.max_hp / (BossBase._player_dps() * BossBase.DPS_REALISM)
	print("BLOBULUS hp %.0f = %.0f s of steady fire (mini: %s)" % [b.max_hp, secs, BossBase.is_mini("blobulus")])
	var ok := BossBase.is_mini("blobulus") and secs <= 60.0
	print("BLOBULUS HP CHECK " + ("OK" if ok else "FAILED"))
	Game.playground_active = false
	get_tree().quit(0 if ok else 1)
