@tool
extends "resource_list_page.gd"
## WAVES: ArenaData.waves in play order, with a timeline strip on top (one block per
## wave: its aliens, elites, boss and how it ends) and, per row, which spawners belong
## to it. "+ Spawner" arms the palette with an EnemySpawner already set to the selected
## wave, so laying out a wave is: add wave -> + Spawner -> click the map.

signal spawner_for_wave(wave_id: String)

const Timeline := preload("wave_timeline.gd")

var _timeline: Control


func _property() -> String:
	return "waves"


func _hint() -> String:
	return "Spawners join the waves whose id they carry."


func _build_header() -> void:
	_timeline = Timeline.new()
	_timeline.custom_minimum_size = Vector2(0, 54 * EditorInterface.get_editor_scale())
	add_child(_timeline)
	var row := HBoxContainer.new()
	add_child(row)
	var add := Button.new()
	add.text = "Add Wave"
	add.icon = EditorInterface.get_editor_theme().get_icon("Add", "EditorIcons")
	add.pressed.connect(_add)
	row.add_child(add)
	var sp := Button.new()
	sp.text = "+ Spawner"
	sp.tooltip_text = "Place an EnemySpawner that belongs to the selected wave"
	sp.icon = EditorInterface.get_editor_theme().get_icon("GPUParticles2D", "EditorIcons")
	sp.pressed.connect(func() -> void:
		var w := _selected() as WaveData
		if w == null and not _items().is_empty():
			w = _items().back()
		if w != null:
			spawner_for_wave.emit(w.wave_id))
	row.add_child(sp)


func _add() -> void:
	if arena == null or arena.data == null:
		return
	var w := WaveData.new()
	var n := _items().size() + 1
	w.wave_id = "w%d" % n
	if n >= 3:
		w.elite_count = 1
	add_item(w)


func _rename_copy(copy: Resource) -> void:
	(copy as WaveData).wave_id += "b"


func _row_text(res: Resource, i: int) -> String:
	var w := res as WaveData
	if w == null:
		return "<empty>"
	var spawners := _spawners(w.wave_id)
	return "%d. %s   %s   · %d spawner%s" % [i + 1, w.display_title(i), w.describe(), spawners.size(), "" if spawners.size() == 1 else "s"]


func _row_icon(res: Resource) -> Texture2D:
	var w := res as WaveData
	var t := EditorInterface.get_editor_theme()
	return t.get_icon("Skull" if w != null and not w.boss_id.is_empty() else "AnimationPlayer", "EditorIcons")


func _spawners(wave_id: String) -> Array[ArenaObject]:
	if arena == null:
		return []
	return arena.objects("EnemySpawner").filter(func(o: ArenaObject) -> bool: return (o as EnemySpawner).wave_id == wave_id)


## Aliens a wave sends: its enemy_count, or the sum of its spawners' counts (-1 = endless).
func wave_size(w: WaveData) -> int:
	if w.enemy_count > 0:
		return w.enemy_count
	var n := 0
	for o in _spawners(w.wave_id):
		var c := (o as EnemySpawner).spawn_count
		if c == 0:
			return -1
		n += c
	return n


func _after_refresh() -> void:
	if _timeline != null:
		_timeline.set("page", self)
		_timeline.queue_redraw()
