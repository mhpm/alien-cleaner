extends Node
## RESCUE OPS: a stealth rescue mission on a COPY of the pixel 2.5D prototype arena
## (scenes/arenas/arena_proto_pixel25d.tscn, the user's hand-edited map; it is only read).
## The copy keeps the map, walls, cameras, hazards and the vault chest, drops the test
## objects (alien packs, spawners, nest, pickups but the heals) and adds:
##   * PlayerRules: no weapon, ability button = DASH, no upgrades, no mutation; no waves
##   * 5 crew to rescue: PILOT and MEDIC in the left lab, CHEF and NURSE in the maze, the
##     CHIEF SCIENTIST in the vault, who has to be escorted to the extraction pad
##   * aliens placed by hand (AlienPack + AlienMind): patrols, guards, sleepers, wanderers
##   * the cameras' endless alarm squads are replaced by two ALARM packs that hunt, lose
##     the crew member, search and go home (no weapon: the alarm must be survivable)
##   * entering the vault springs an ambush (trigger -> runners that come hunting)
##   * missions: RESCUE 5 (8 min), ESCORT the scientist, bonus: loot the vault chest
## Never overwrites: refuses if the copy exists (the user may have retouched it), unless
## run with -- --force.
##   godot --headless --path . res://tools/build_proto_rescue.tscn

const SOURCE := "res://scenes/arenas/arena_proto_pixel25d.tscn"
const TARGET := "res://scenes/arenas/arena_proto_rescue.tscn"
const KEEP_PICKUPS := ["Health", "Medkit"]
const EXTRACTION := "extraction"
const SCIENTIST := "chief_scientist"
const AMBUSH := "vault_ambush"


func _ready() -> void:
	if ResourceLoader.exists(TARGET) and not OS.get_cmdline_user_args().has("--force"):
		push_error("%s already exists (it may have been retouched by hand): not rebuilt. Use -- --force." % TARGET)
		get_tree().quit(1)
		return
	var arena := (load(SOURCE) as PackedScene).instantiate() as Arena
	_strip(arena)
	_cameras(arena)
	_data(arena)
	_survivors(arena)
	_aliens(arena)
	_triggers(arena)
	var packed := PackedScene.new()
	var err := packed.pack(arena)
	if err == OK:
		err = ResourceSaver.save(packed, TARGET)
	print("RESCUE OPS: %s -> %s (%s)" % [SOURCE, TARGET, error_string(err)])
	arena.free()
	get_tree().quit(0 if err == OK else 1)


## The prototype's test objects go; the map, cameras, hazards, chest and heals stay.
func _strip(arena: Arena) -> void:
	var gone: Array[Node] = []
	for n in arena.find_children("*", "", true, false):
		if n is AlienPack or n is EnemySpawner or n is AlienNest or n is ArenaSurvivor or n is ArenaTrigger:
			gone.append(n)
		elif n is ArenaPickup and not KEEP_PICKUPS.has(str(n.name)):
			gone.append(n)
	for n in gone:
		n.get_parent().remove_child(n)
		n.free()


## No endless squads (nothing can kill them); the ALARM packs answer instead.
func _cameras(arena: Arena) -> void:
	for n in arena.find_children("*", "SecurityCamera", true, false):
		var cam := n as SecurityCamera
		cam.alarm_squad = [] as Array[SpawnEntry]
		cam.alarm_cooldown = 10.0


func _data(arena: Arena) -> void:
	var d := arena.data.duplicate(true) as ArenaData
	d.arena_id = "proto_rescue"
	d.display_name = "RESCUE OPS"
	d.environment = "Alien Laboratory"
	d.description = "Unarmed. Five crew are trapped in the infested lab: sneak past the aliens, " \
		+ "stay out of the camera beams, DASH through danger and bring the Chief Scientist home."
	d.waves_enabled = false
	d.level_ups = false
	d.roaming = [] as Array[SpawnEntry]
	d.roaming_alive = 0
	d.start_delay = 1.0
	d.minimap = true
	var r := PlayerRules.new()
	r.weapon = false
	r.ability_button = PlayerRules.AbilityButton.DASH
	r.dash_cooldown = 1.8
	r.mutation = false
	r.upgrades = false
	d.player_rules = r
	var rescue := _objective("rescue", ObjectiveData.Type.RESCUE, "Rescue the 5 crew", 5)
	rescue.description = "Stand next to each survivor until they are safe."
	rescue.time_limit = 480.0
	var escort := _objective("escort", ObjectiveData.Type.ESCORT, "Bring the Chief Scientist home", 1)
	escort.description = "She follows you: keep the aliens off her until the extraction pad."
	escort.required_object_ids = PackedStringArray([SCIENTIST])
	var loot := _objective("loot", ObjectiveData.Type.COLLECT, "Loot the vault", 1)
	loot.filter = "chest"
	loot.optional = true
	d.objectives = [rescue, escort, loot] as Array[ObjectiveData]
	arena.data = d


func _objective(id: String, type: ObjectiveData.Type, title: String, count: int) -> ObjectiveData:
	var o := ObjectiveData.new()
	o.objective_id = id
	o.type = type
	o.title = title
	o.target_count = count
	return o


func _survivors(arena: Arena) -> void:
	# crew index (SurvivorData.CREW), where, what they shout, thanks
	_survivor(arena, "PilotSurvivor", 0, Vector2(560, 150), "pilot",
		["Psst! Over here!", "Mind the camera!", "Wait for the beam to turn!"],
		"Thanks! Moving faster already!")
	_survivor(arena, "MedicSurvivor", 3, Vector2(112, 720), "medic",
		["Quiet... the big one is sleeping!", "Help me, please!"],
		"Let me patch you up first.")
	_survivor(arena, "ChefSurvivor", 10, Vector2(1620, 100), "chef",
		["I'm stuck behind the goo!", "Anyone out there?"],
		"I owe you a hot meal!")
	_survivor(arena, "NurseSurvivor", 12, Vector2(1620, 840), "nurse",
		["Don't wake them...", "They're right next to me!"],
		"You walked right past them!")
	var sci := _survivor(arena, "ChiefScientist", 1, Vector2(2768, 120), SCIENTIST,
		["The vault! They locked me in the vault!", "I know how to stop them!"],
		"They heard the vault open! Get me to the extraction pad!")
	sci.character_name = "CHIEF SCIENTIST"
	sci.escort_to = EXTRACTION


func _survivor(arena: Arena, node_name: String, crew: int, at: Vector2, id: String,
		cries: Array, thanks: String) -> ArenaSurvivor:
	var s := ArenaSurvivor.new()
	s.name = node_name
	s.crew = crew
	s.position = at
	s.object_id = id
	s.dialogue = PackedStringArray(cries)
	s.thanks_line = thanks
	s.rescue_time = 5.0
	_add(arena, s)
	return s


func _aliens(arena: Arena) -> void:
	var W := AlienMind.Kind.WANDER
	var G := AlienMind.Kind.GUARD
	var P := AlienMind.Kind.PATROL
	var S := AlienMind.Kind.SLEEP
	# left lab
	_pack(arena, "LabPatrol", "slime", 2, Vector2(320, 330), P, {"patrol": [Vector2(-230, 0), Vector2(230, 0)]})
	_pack(arena, "LabWanderers", "runner", 2, Vector2(330, 590), W, {"radius": 110.0})
	_pack(arena, "SleepingBrute", "big_red", 1, Vector2(220, 780), S, {"facing": 180.0})
	# maze
	_pack(arena, "HallPatrol", "slime", 2, Vector2(1370, 450), P, {"patrol": [Vector2(-250, 0), Vector2(250, 0)]})
	_pack(arena, "ChefGuard", "big_red", 1, Vector2(1600, 300), G, {"facing": 90.0, "sight": 130.0})
	_pack(arena, "NurseSleepers", "slime", 3, Vector2(1500, 770), S, {"facing": 0.0})
	_pack(arena, "MazeWanderers", "runner", 2, Vector2(2050, 520), W, {"radius": 100.0})
	_pack(arena, "ShaftPatrol", "big_red", 1, Vector2(2384, 620), P, {"patrol": [Vector2(0, -180), Vector2(0, 180)]})
	_pack(arena, "VaultGuards", "alien_trooper", 2, Vector2(2600, 430), G, {"facing": 180.0, "fov": 90.0})
	# the base answers an alarm (any camera), then calms down again
	for spec: Array in [["LabAlarm", Vector2(320, 450)], ["MazeAlarm", Vector2(1900, 450)]]:
		var a := _pack(arena, spec[0], "runner", 3, spec[1], W, {"radius": 120.0})
		a.appear = AlienPack.Appear.ALARM
		a.entrance = AlienPack.Entrance.MARKER
		a.arrive_alert = true
	# the vault ambush: they come hunting the scientist's rescuer
	var amb := _pack(arena, "VaultAmbush", "runner", 3, Vector2(2200, 450), W, {"radius": 120.0})
	amb.object_id = AMBUSH
	amb.appear = AlienPack.Appear.TRIGGER
	amb.entrance = AlienPack.Entrance.MARKER
	amb.arrive_alert = true
	amb.give_up = 600.0


func _pack(arena: Arena, node_name: String, enemy: String, count: int, at: Vector2,
		routine: AlienMind.Kind, opt: Dictionary) -> AlienPack:
	var p := AlienPack.new()
	p.name = node_name
	p.enemy_id = enemy
	p.count = count
	p.position = at
	p.routine = routine
	p.hearing = 35.0
	p.facing_deg = float(opt.get("facing", 90.0))
	p.sight = float(opt.get("sight", 150.0))
	p.fov_deg = float(opt.get("fov", 110.0))
	if opt.has("radius"):
		p.wander_radius = float(opt.radius)
	if opt.has("patrol"):
		p.patrol_points = PackedVector2Array(opt.patrol)
	_add(arena, p)
	return p


func _triggers(arena: Arena) -> void:
	var pad := ArenaTrigger.new()
	pad.name = "ExtractionPad"
	pad.object_id = EXTRACTION
	pad.action = ArenaTrigger.Action.REACH_LOCATION
	pad.position = Vector2(912, 190)
	pad.size = Vector2(96, 64)
	pad.once = false
	_add(arena, pad)
	var brief := ArenaTrigger.new()
	brief.name = "Briefing"
	brief.action = ArenaTrigger.Action.MESSAGE
	brief.position = Vector2(928, 110)
	brief.size = Vector2(96, 96)
	brief.show_in_game = false
	brief.dialogue = _briefing()
	_add(arena, brief)
	var vault := ArenaTrigger.new()
	vault.name = "VaultAlarm"
	vault.action = ArenaTrigger.Action.START_SPAWNERS
	vault.targets = PackedStringArray([AMBUSH])
	vault.position = Vector2(2720, 150)
	vault.size = Vector2(160, 110)
	vault.show_in_game = false
	_add(arena, vault)


func _briefing() -> DialogueData:
	var d := DialogueData.new()
	var mc := DialogueSpeaker.new()
	d.cast = [mc] as Array[DialogueSpeaker]
	var lines: Array[DialogueLine] = []
	for t: String in [
			"No weapon on this one, cadet. Five crew are trapped in the lab.",
			"Sneak past the aliens and stay out of the camera beams: an alarm wakes the base.",
			"Your button is a DASH. Use it to slip through fire and away from trouble.",
			"The Chief Scientist is locked in the vault. Bring her back to this pad alive."]:
		var l := DialogueLine.new()
		l.text = t
		lines.append(l)
	d.lines = lines
	return d


func _add(arena: Arena, o: ArenaObject) -> void:
	var parent := arena.get_layer(o.arena_layer())
	if parent == null:
		parent = arena
	parent.add_child(o, true)
	o.owner = arena
