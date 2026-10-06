class_name ArenaReport
extends RefCounted
## Result of validating an Arena: a flat list of issues the editor dock lists and tests
## can assert on. Components add their own issues from `validate_arena(report, arena)`,
## so new component types extend validation without touching ArenaValidator.

enum Severity { INFO, WARNING, ERROR }

## Each issue: {"severity": Severity, "message": String, "path": NodePath (from the arena root, may be empty)}
var issues: Array[Dictionary] = []
var _arena: Node


func _init(arena: Node = null) -> void:
	_arena = arena


func error(message: String, node: Node = null) -> void:
	_add(Severity.ERROR, message, node)


func warning(message: String, node: Node = null) -> void:
	_add(Severity.WARNING, message, node)


func info(message: String, node: Node = null) -> void:
	_add(Severity.INFO, message, node)


func count(severity: Severity) -> int:
	var n := 0
	for issue in issues:
		if int(issue.severity) == severity:
			n += 1
	return n


func has_errors() -> bool:
	return count(Severity.ERROR) > 0


func summary() -> String:
	return "%d errors, %d warnings, %d info" % [count(Severity.ERROR), count(Severity.WARNING), count(Severity.INFO)]


func _add(severity: Severity, message: String, node: Node) -> void:
	var path := NodePath()
	if node != null and _arena != null and (node == _arena or _arena.is_ancestor_of(node)):
		path = _arena.get_path_to(node)
	issues.append({"severity": severity, "message": message, "path": path})
