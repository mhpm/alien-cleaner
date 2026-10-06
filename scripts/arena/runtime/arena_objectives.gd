class_name ArenaObjectives
extends Node
## Tracks ArenaData.objectives while the arena plays. Each objective listens to arena
## events through its own ObjectiveData.progress_for (so new objective types need no
## change here); time-based ones tick. Shows them in an ObjectivePanel, gives rewards,
## reports "objective_completed" and tells the director when every MAIN one is done,
## or fails the arena when a MAIN one fails.

class State:
	var data: ObjectiveData
	var target := 1
	var progress := 0.0
	var done := false
	var failed := false
	var time_left := 0.0

	func ratio() -> float:
		return clampf(progress / maxf(1.0, float(target)), 0.0, 1.0)

var director: ArenaDirector
var states: Array[State] = []
var panel: ObjectivePanel
var _main_done := false


func setup(d: ArenaDirector) -> ArenaObjectives:
	director = d
	name = "Objectives"
	return self


func start() -> void:
	for od in director.data.objectives:
		if od == null:
			continue
		var s := State.new()
		s.data = od
		s.target = maxi(1, od.target_count if od.target_count > 0 else _count_for(od))
		s.time_left = od.time_limit
		states.append(s)
	panel = ObjectivePanel.new()
	panel.position = Vector2(6, 73)
	director.world.hud.safe.add_child(panel)
	panel.setup(states)
	# keep the boss bar clear of the panel
	var hud := director.world.hud
	hud.boss_box.offset_top = panel.position.y + panel.size.y + 6.0
	hud.boss_box.offset_bottom = hud.boss_box.offset_top + 34.0
	director.waves.all_cleared.connect(func() -> void: on_event("all_waves_cleared", "", PackedStringArray()))
	if states.is_empty():
		_check_main()


## How many objects / events an objective without a target count waits for.
func _count_for(od: ObjectiveData) -> int:
	if not od.required_object_ids.is_empty():
		return od.required_object_ids.size()
	match od.type:
		ObjectiveData.Type.SURVIVE, ObjectiveData.Type.DEFEND:
			return 60
		ObjectiveData.Type.KILL:
			return 50
		ObjectiveData.Type.CLEAR_WAVES:
			return maxi(1, director.waves.total())
		ObjectiveData.Type.BOSS:
			var n := director.objects_of("BossTrigger").size()
			for w in director.data.waves:
				n += 1 if w != null and not w.boss_id.is_empty() else 0
			return maxi(1, n)
		ObjectiveData.Type.COLLECT:
			if od.filter == "android":
				return director.objects_of("AndroidPart").size()
			if od.filter == "chest":
				return director.objects_of("ArenaChest").size()
			return director.objects_of("AndroidPart").size() + director.objects_of("ArenaChest").size()
		ObjectiveData.Type.REACH_LOCATION, ObjectiveData.Type.ACTIVATE:
			var want := ArenaTrigger.Action.ACTIVATE if od.type == ObjectiveData.Type.ACTIVATE else ArenaTrigger.Action.REACH_LOCATION
			return director.objects_of("ArenaTrigger").filter(func(o: ArenaObject) -> bool: return (o as ArenaTrigger).action == want).size()
		ObjectiveData.Type.ESCORT:
			return director.objects_of("ArenaSurvivor").filter(func(o: ArenaObject) -> bool: return not (o as ArenaSurvivor).escort_to.is_empty()).size()
	var cls: String = ObjectiveData.OBJECT_CLASSES.get(od.type, "")
	return director.objects_of(cls).size() if not cls.is_empty() else 1


func on_event(kind: String, subject: String, tags: PackedStringArray) -> void:
	for s in states:
		if s.done or s.failed:
			continue
		if s.data.fails_on(kind, subject):
			_fail(s, "%s failed" % s.data.label(s.target))
			continue
		var add := s.data.progress_for(kind, subject, tags)
		if add > 0:
			s.progress += add
			panel.bump(s)
			if s.progress >= s.target:
				_complete(s)


func _physics_process(delta: float) -> void:
	if director.finished or director.world.state != "survive":
		return
	for s in states:
		if s.done or s.failed:
			continue
		var add := s.data.tick(delta)
		if add > 0.0:
			s.progress += add
			if s.progress >= s.target:
				_complete(s)
		if s.data.time_limit > 0.0:
			s.time_left -= delta
			if s.time_left <= 0.0:
				_fail(s, "Out of time: " + s.data.label(s.target))
	panel.refresh()


func _complete(s: State) -> void:
	s.done = true
	s.progress = s.target
	var w := director.world
	var col := Color("ffcd75") if s.data.optional else Color("a7f070")
	w.hud.banner(("BONUS: " if s.data.optional else "") + s.data.label(s.target).to_upper(), col, 22, 1.1)
	Sfx.play("upgrade" if s.data.optional else "victory", 0.0, -6.0)
	director.give(s.data.reward, w.player.global_position)
	panel.complete(s)
	director.fire("objective_completed", s.data.objective_id)
	_check_main()


func _fail(s: State, reason: String) -> void:
	s.failed = true
	panel.complete(s)
	director.world.hud.banner(("BONUS LOST" if s.data.optional else "MISSION FAILED"), Color("ff5566"), 26, 1.2)
	if not s.data.optional:
		director.finish(false, reason)


func main_done() -> bool:
	return _main_done


func _check_main() -> void:
	if _main_done:
		return
	for s in states:
		if not s.data.optional and not s.done:
			return
	_main_done = true
	director.main_objectives_done()


## Objects the unfinished objectives are about (guide arrow): MAIN ones first.
func pointed_objects() -> Array[ArenaObject]:
	for pass_optional: bool in [false, true]:
		var out: Array[ArenaObject] = []
		for s in states:
			if s.done or s.failed or s.data.optional != pass_optional:
				continue
			if not s.data.required_object_ids.is_empty():
				for id in s.data.required_object_ids:
					var o := director.find(id)
					if o != null:
						out.append(o)
				continue
			var cls: String = ObjectiveData.OBJECT_CLASSES.get(s.data.type, "")
			if s.data.type == ObjectiveData.Type.COLLECT:
				out.append_array(director.objects_of("AndroidPart") + director.objects_of("ArenaChest"))
			elif cls == "ArenaTrigger":
				var want := ArenaTrigger.Action.ACTIVATE if s.data.type == ObjectiveData.Type.ACTIVATE else ArenaTrigger.Action.REACH_LOCATION
				out.append_array(director.objects_of(cls).filter(func(o: ArenaObject) -> bool: return (o as ArenaTrigger).action == want))
			elif not cls.is_empty():
				out.append_array(director.objects_of(cls))
		if not out.is_empty():
			return out
	return []


## Results screen rows: [label, done, failed, optional, reward text].
func summary() -> Array:
	var out := []
	for s in states:
		out.append([s.data.label(s.target), s.done, s.failed, s.data.optional, s.data.reward.describe() if s.data.reward != null else ""])
	return out
