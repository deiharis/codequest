extends RefCounted
class_name WorldFlow
## Where a world goes next, decided in one place.
##
## I argued against an orchestrator when the sequence was Rocket -> Battle,
## because there was nothing to reorder. The Bugfall Archive changed that.
## Three callers now have to agree on what follows a world — the rocket
## arriving, a lesson ending, and the Archive being left — and three copies of
## that rule would drift apart the first time one of them changed.
##
## Static, and takes the calling node: a static function has no tree of its
## own, and `from` is how it reaches the autoloads.

const LESSON_SCENE := "res://scenes/lesson/Lesson.tscn"
const LIBRARY_SCENE := "res://scenes/lesson/Library.tscn"
const BATTLE_SCENE := "res://scenes/battle/Battle.tscn"
const SPACE_MAP_SCENE := "res://scenes/space_map/SpaceMap.tscn"

## SceneRouter.Style.IRIS. Spelled as a number here for the same reason the
## default argument below is: this file is static, and one named constant is
## clearer than an autoload lookup repeated at two call sites.
const IRIS := 1

## Bugfall holds the Archive. It is the last world and the only one with no
## General (ADR-002), so it is the one place a library of every topic belongs
## and the one arrival that must not drop straight into a fight.
const LIBRARY_WORLD := "bugfall"


## Arriving at a world. Its lesson first, unless there is none written or it
## has already been seen.
static func arrive(from: Node, world: WorldData) -> void:
	if world == null:
		push_error("WorldFlow: arrive() with no world")
		_goto(from, SPACE_MAP_SCENE)
		return

	var state: Node = from.get_node("/root/GameState")
	if LessonBank.has_lesson(world.world_id) \
			and not state.has_seen_lesson(world.world_id):
		_goto(from, LESSON_SCENE, func(scene): scene.setup(world))
		return

	after_lesson(from, world)


## What a finished lesson leads to: the world's fight, or — for Bugfall — its
## Archive, because the Bug Lord is not something you walk into by arriving.
static func after_lesson(from: Node, world: WorldData) -> void:
	if world.world_id == LIBRARY_WORLD:
		_goto(from, LIBRARY_SCENE)
		return

	if world.general == null:
		push_error("WorldFlow: world '%s' has no general assigned" % world.world_id)
		_goto(from, SPACE_MAP_SCENE)
		return

	# Arriving at a fight closes in on it. Every other move in the game fades.
	var request := BattleRequest.for_world(world)
	_goto(from, BATTLE_SCENE, func(scene): scene.setup(request), IRIS)


## Replaying one world's lesson. Marks nothing, starts nothing.
##
## `back_to` is where it returns: the Archive by default, or the Space Map when
## the player opened it from the planet itself.
static func study(from: Node, world: WorldData, back_to: String = "") -> void:
	_goto(from, LESSON_SCENE, func(scene): scene.setup(world, true, back_to))


## The final encounter, entered deliberately from the Archive rather than by
## arriving at the world.
static func face_bug_lord(from: Node) -> void:
	var db := WorldDatabase.load_default()
	var world := db.by_id(LIBRARY_WORLD)
	if world == null or world.general == null:
		push_error("WorldFlow: Bugfall is missing or has no enemy assigned")
		_goto(from, SPACE_MAP_SCENE)
		return
	_goto(from, BATTLE_SCENE, func(scene): scene.setup(BattleRequest.for_world(world)), IRIS)


## `style` defaults to -1 rather than to `SceneRouter.Style.FADE` because this
## is a static function: resolving an autoload in a default argument is the one
## place that lookup has no instance to hang off. Deferring it to the body costs
## a line and removes the question.
static func _goto(from: Node, path: String, setup: Callable = Callable(),
		style: int = -1) -> void:
	var router: Node = from.get_node("/root/SceneRouter")
	if style < 0:
		style = router.Style.FADE
	router.goto_scene(path, setup, style)
