extends Node
## Owns every scene change in the game.
##
## Replaces SceneManager. Two things it adds:
##   1. A fade to black and back, so scene changes are not hard cuts.
##   2. A `setup` callable that runs on the new scene BEFORE it enters the
##      tree — so a scene receives its data before its own _ready() needs it.
##
## Usage:
##   SceneRouter.goto_scene("res://scenes/space_map/SpaceMap.tscn")
##
##   SceneRouter.goto_scene("res://scenes/travel/RocketTravel.tscn",
##       func(scene): scene.setup(world_data))

signal scene_changed(new_scene: Node)

## Seconds for one half of the transition. Set to 0.0 to disable fading.
@export var fade_duration: float = 0.25

var current_scene: Node = null

var _fade: ColorRect
var _busy: bool = false


func _ready() -> void:
	# Keep working even if the tree is paused (hitstop, pause menu).
	process_mode = Node.PROCESS_MODE_ALWAYS

	var layer := CanvasLayer.new()
	layer.layer = 128                      # above all gameplay and UI
	layer.name = "TransitionLayer"
	add_child(layer)

	_fade = ColorRect.new()
	_fade.name = "Fade"
	_fade.color = Color.BLACK
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.modulate.a = 0.0
	_fade.visible = false
	layer.add_child(_fade)


## Change to the scene at `path`.
## `setup` is optional; if given, it is called with the new scene instance
## after instantiation but before it is added to the tree.
func goto_scene(path: String, setup: Callable = Callable()) -> void:
	if _busy:
		push_warning("SceneRouter: transition already in progress, ignoring '%s'" % path)
		return
	_busy = true

	await _fade_to(1.0)

	var old: Node = current_scene if current_scene else get_tree().current_scene
	if is_instance_valid(old):
		old.queue_free()

	var packed := load(path) as PackedScene
	if packed == null:
		push_error("SceneRouter: could not load scene at '%s'" % path)
		_busy = false
		await _fade_to(0.0)
		return

	var next := packed.instantiate()
	if setup.is_valid():
		setup.call(next)

	get_tree().root.add_child(next)
	get_tree().current_scene = next
	current_scene = next
	scene_changed.emit(next)

	await _fade_to(0.0)
	_busy = false


func _fade_to(target_alpha: float) -> void:
	if fade_duration <= 0.0:
		_fade.modulate.a = target_alpha
		_fade.visible = target_alpha > 0.0
		return

	_fade.visible = true
	var tween := create_tween()
	tween.tween_property(_fade, "modulate:a", target_alpha, fade_duration)
	await tween.finished
	_fade.visible = target_alpha > 0.0
