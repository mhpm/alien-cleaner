extends Node
## Loads every screen, world, enemy, boss and data texture so a build exported with
## the Android exclude_filter can be checked for missing files: run it from the
## exported pack and look for "not found" / "Failed loading" errors in the log.
## godot --headless --main-pack build.pck res://tests/asset_check.tscn
var missing: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _tex(path: String) -> void:
	if not ResourceLoader.exists(path) or load(path) == null:
		missing.append(path)
		push_error("ASSET_CHECK missing: " + path)


## Every "a:NNN"-style prop reference found anywhere inside `v`.
func _props(v: Variant) -> void:
	if v is Dictionary:
		for k: Variant in v:
			_props(v[k])
	elif v is Array:
		for x: Variant in v:
			_props(x)
	elif v is String and PropData.DIRS.has(str(v).get_slice(":", 0)) and ":" in str(v):
		_tex(PropData.path(str(v)))


func _wait(secs: float) -> void:
	await get_tree().create_timer(secs).timeout


func _run() -> void:
	var had_save := FileAccess.file_exists(Game.SAVE_PATH)
	var saved := FileAccess.get_file_as_bytes(Game.SAVE_PATH) if had_save else PackedByteArray()
	# Data tables
	_props([PropData.PROPS, PropData.THEME_TEX, PropData.BARREL_TEX, PropData.GRIME_TEX, PropData.PAD_TEX])
	for kind: String in CollectibleData.ITEMS:
		CollectibleData.tex(kind)
	for id: String in UpgradeData.UPGRADES:
		UpgradeData.icon(id)
		for lv in range(1, UpgradeData.LEVELS + 1):
			UpgradeData.level_tex(id, lv)
	for hits in range(1, UpgradeData.LEVELS + 1):
		UpgradeData.shield_dome(hits)
		UpgradeData.shield_bubble(hits)
	for id: String in GunData.ids():
		GunData.icon(id)
	for lv in range(1, MutationData.MAX + 1):
		MutationData.gun_tex(lv)
		MutationData.shot_tex(lv)
		MutationData.tentacles(lv)
	# Menus
	for scene: String in ["res://scenes/main_menu.tscn", "res://scenes/world_select.tscn",
			"res://scenes/lab.tscn", "res://scenes/armory.tscn"]:
		var s := (load(scene) as PackedScene).instantiate()
		add_child(s)
		await _wait(0.6)
		s.queue_free()
		await get_tree().process_frame
	# Every world, then every enemy and boss inside it
	var ids: Array = EnemyData.TYPES.keys()
	for wi in WorldData.WORLDS.size():
		Game.new_run(wi)
		var w := (load("res://scenes/game.tscn") as PackedScene).instantiate() as GameWorld
		add_child(w)
		await _wait(1.0)
		var batch := 6
		for i in range(0, ids.size(), batch):
			var spawned: Array[Enemy] = []
			for id: String in ids.slice(i, i + batch):
				if is_instance_valid(w.player):
					w.player.invuln = 99.0
					var pos := w.player.global_position + Vector2.from_angle(randf() * TAU) * 70.0
					spawned.append(w.spawn_enemy(id, pos))
			await _wait(1.5)
			for e in spawned:
				if is_instance_valid(e) and not e.dead:
					e.die()
			await _wait(1.0)
			if wi > 0:
				break  # all enemy art is checked in the first world
		w.queue_free()
		await _wait(0.2)
	if had_save:
		var f := FileAccess.open(Game.SAVE_PATH, FileAccess.WRITE)
		f.store_buffer(saved)
	elif FileAccess.file_exists(Game.SAVE_PATH):
		DirAccess.remove_absolute(Game.SAVE_PATH)
	print("ASSET_CHECK: %s (%d missing)" % ["PASS" if missing.is_empty() else "FAIL", missing.size()])
	get_tree().quit(0 if missing.is_empty() else 1)
