extends Node
## Everything that survives between scenes, and everything that is saved.
##
## Two rules keep this file honest:
##
##   1. **One source of truth per fact.** Progress is the list of generals
##      beaten; the current world is derived from its length rather than stored
##      alongside it. Two fields that can disagree eventually will.
##   2. **Encounter state does not live here.** The 500 HP a Bug Lord encounter
##      starts with is on his EnemyData. The 8000 that persists across the
##      campaign is `bug_lord_hp` below. Different numbers, different objects,
##      so they cannot be confused. (ADR-004)

const SAVE_PATH := "user://savegame.json"
const SAVE_VERSION := 1

## ADR-003: the Bug Lord's health is the campaign's progress bar. Each world
## cleared takes 1000 off it, so eight worlds bring him to zero.
const BUG_LORD_MAX_HP := 8000
const BUG_LORD_DAMAGE_PER_WORLD := 1000

signal progress_changed

## world_id of every world whose General has been beaten, in the order beaten.
var defeated_generals: Array[String] = []
var bug_lord_hp: int = BUG_LORD_MAX_HP

## world_id of every world whose lesson has been played to the end or skipped.
## Separate from defeated_generals because losing a fight should not make you
## sit through the lesson again, and clearing a world is not what marks it read.
var lessons_seen: Array[String] = []


func _ready() -> void:
	load_game()


# --------------------------------------------------------------------------
# Progress
# --------------------------------------------------------------------------

## How many worlds are cleared. Derived, never stored.
var current_world_index: int:
	get: return defeated_generals.size()


func is_world_unlocked(order_index: int) -> bool:
	return order_index <= current_world_index


func is_general_defeated(world_id: String) -> bool:
	return defeated_generals.has(world_id)


func has_seen_lesson(world_id: String) -> bool:
	return lessons_seen.has(world_id)


func mark_lesson_seen(world_id: String) -> void:
	if lessons_seen.has(world_id):
		return
	lessons_seen.append(world_id)
	save_game()


## Clearing a world happens when the Bug Lord encounter is passed, not when the
## General falls — the General is the gate to the encounter, not the encounter.
##
## Idempotent: replaying a world you have already cleared costs the Bug Lord
## nothing, so the first world cannot be farmed to finish the game.
## Returns true if this actually changed anything.
func clear_world(world_id: String) -> bool:
	if defeated_generals.has(world_id):
		return false
	defeated_generals.append(world_id)
	bug_lord_hp = maxi(0, bug_lord_hp - BUG_LORD_DAMAGE_PER_WORLD)
	progress_changed.emit()
	save_game()
	return true


## True once every world has been cleared and he has nothing left.
func is_campaign_won() -> bool:
	return bug_lord_hp == 0


func reset() -> void:
	defeated_generals.clear()
	lessons_seen.clear()
	bug_lord_hp = BUG_LORD_MAX_HP
	progress_changed.emit()
	save_game()


# --------------------------------------------------------------------------
# Save / load
# --------------------------------------------------------------------------
# JSON in user://, with a version field. Plain text so a broken save can be
# read and fixed by hand, and so a marking tutor can see what is stored.
# ADR-013.

func save_game() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("GameState: cannot write %s" % SAVE_PATH)
		return
	f.store_string(JSON.stringify({
		"version": SAVE_VERSION,
		"defeated_generals": defeated_generals,
		"lessons_seen": lessons_seen,
		"bug_lord_hp": bug_lord_hp,
	}, "\t"))
	f.close()


## A missing save is a new game, not an error. A corrupt or future-version save
## is refused rather than half-applied — a partly loaded save is worse than none.
func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false

	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		push_error("GameState: cannot read %s" % SAVE_PATH)
		return false
	var text := f.get_as_text()
	f.close()

	var data: Variant = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		push_error("GameState: save file is not valid JSON, ignoring it")
		return false
	if int(data.get("version", 0)) != SAVE_VERSION:
		push_warning("GameState: save version %s is not %d, starting fresh"
				% [data.get("version", "missing"), SAVE_VERSION])
		return false

	defeated_generals.clear()
	for id in data.get("defeated_generals", []):
		defeated_generals.append(str(id))
	# Absent in a version-1 save written before lessons existed: an empty list
	# is the right answer there, so it needs no version bump.
	lessons_seen.clear()
	for id in data.get("lessons_seen", []):
		lessons_seen.append(str(id))
	bug_lord_hp = clampi(int(data.get("bug_lord_hp", BUG_LORD_MAX_HP)),
			0, BUG_LORD_MAX_HP)

	progress_changed.emit()
	return true


func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
