extends Node
## Every arena in scenes/arenas/ must pass ArenaValidator with no errors (structure,
## missions, reachability and the performance budget: missing files, aliens alive at
## once...). Prints each arena's issues and quits with the number of failing arenas.

const DIR := "res://scenes/arenas/"


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var failing := 0
	var files := DirAccess.get_files_at(DIR)
	for file in files:
		if not file.ends_with(".tscn"):
			continue
		var packed := load(DIR + file) as PackedScene
		var arena := packed.instantiate() as Arena if packed != null else null
		if arena == null:
			print("ARENAS_CHECK FAIL %s: does not load as an Arena" % file)
			failing += 1
			continue
		add_child(arena)
		var r := ArenaValidator.validate(arena)
		var peak := ArenaValidator.peak_alive(arena, arena.objects())
		var errors := r.count(ArenaReport.Severity.ERROR)
		print("ARENAS_CHECK %s %s: %d errors, %d warnings, peak %d aliens alive (%s)" % [
			"FAIL" if errors > 0 else "ok  ", file, errors, r.count(ArenaReport.Severity.WARNING), peak.total, peak.where])
		for issue in r.issues:
			if int(issue.severity) != ArenaReport.Severity.INFO:
				print("    %s %s" % ["ERROR  " if int(issue.severity) == ArenaReport.Severity.ERROR else "warning", issue.message])
		if errors > 0:
			failing += 1
		arena.queue_free()
	print("ARENAS_CHECK: %s" % ("PASS" if failing == 0 else "FAIL (%d arenas)" % failing))
	get_tree().quit(failing)
