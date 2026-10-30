extends RefCounted
class_name LessonBank
## Loads a world's lesson from data/lessons/<world_id>.json
##
## JSON rather than CSV or .tres: lesson prose is multi-line, variable-length
## and nested, which is exactly what CSV is worst at and what the Inspector is
## tedious for. JSON diffs as text in git and can be written by someone who
## never opens Godot.
##
## Beats stay as Dictionaries. A LessonBeat resource class would add a layer
## that only renames the same fields — the renderers read them once each.

const DIR := "res://data/lessons/"

static var _cache: Dictionary = {}


## { "title": String, "beats": Array } — empty if the world has no lesson yet.
static func for_world(world_id: String) -> Dictionary:
	if _cache.has(world_id):
		return _cache[world_id]

	var path := DIR + world_id + ".json"
	if not FileAccess.file_exists(path):
		_cache[world_id] = {}
		return {}

	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("LessonBank: cannot open %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()

	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("beats"):
		push_error("LessonBank: %s is not a lesson document" % path)
		_cache[world_id] = {}
		return {}

	_cache[world_id] = parsed
	return parsed


static func has_lesson(world_id: String) -> bool:
	return not for_world(world_id).is_empty()


## Forces a re-read. Useful while writing lesson content with the game running.
static func reload() -> void:
	_cache.clear()
