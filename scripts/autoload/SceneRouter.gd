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

## How a scene change looks. Two shapes, not six: a fade is right for almost
## everything, and an iris is right for the one moment the game narrows onto a
## single thing. Colour carries the rest of the meaning, which is far cheaper
## than a shape per mood and reads just as clearly at a quarter of a second.
enum Style {
	FADE,   ## the whole screen washes to `tint` and back
	IRIS,   ## a circle closes onto the centre, then opens again
}

## Seconds for one half of the transition. Set to 0.0 to disable it.
@export var fade_duration: float = 0.25

var _iris: Iris

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

	_iris = Iris.new()
	_iris.name = "Iris"
	_iris.set_anchors_preset(Control.PRESET_FULL_RECT)
	_iris.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_iris.visible = false
	layer.add_child(_iris)


## Change to the scene at `path`.
## `setup` is optional; if given, it is called with the new scene instance
## after instantiation but before it is added to the tree.
func goto_scene(path: String, setup: Callable = Callable(),
		style: Style = Style.FADE, tint: Color = Color.BLACK) -> void:
	if _busy:
		push_warning("SceneRouter: transition already in progress, ignoring '%s'" % path)
		return
	_busy = true

	await _cover(style, tint)

	var old: Node = current_scene if current_scene else get_tree().current_scene
	if is_instance_valid(old):
		old.queue_free()

	var packed := load(path) as PackedScene
	if packed == null:
		push_error("SceneRouter: could not load scene at '%s'" % path)
		_busy = false
		await _reveal(style)
		return

	var next := packed.instantiate()
	if setup.is_valid():
		setup.call(next)

	get_tree().root.add_child(next)
	get_tree().current_scene = next
	current_scene = next
	scene_changed.emit(next)

	await _reveal(style)
	_busy = false


## Hide the old scene. `tint` is ignored by the iris, which is always black —
## a coloured hole reads as a bug rather than as mood.
func _cover(style: Style, tint: Color) -> void:
	if style == Style.IRIS:
		_iris.color = Color.BLACK
		_iris.radius = _reach()
		_iris.visible = true
		_fade.visible = false
		await _tween_to(_iris, "radius", 0.0, Tween.EASE_IN, Tween.TRANS_CUBIC)
		return

	_iris.visible = false
	_fade.color = tint
	_fade.modulate.a = 0.0
	_fade.visible = true
	await _tween_to(_fade, "modulate:a", 1.0, Tween.EASE_IN, Tween.TRANS_QUAD)


## Show the new one, and leave nothing on screen either way.
func _reveal(style: Style) -> void:
	if style == Style.IRIS:
		await _tween_to(_iris, "radius", _reach(), Tween.EASE_OUT, Tween.TRANS_CUBIC)
		_iris.visible = false
		return

	await _tween_to(_fade, "modulate:a", 0.0, Tween.EASE_OUT, Tween.TRANS_QUAD)
	_fade.visible = false


func _tween_to(node: Node, property: String, value: Variant,
		ease_type: Tween.EaseType, trans: Tween.TransitionType) -> void:
	if fade_duration <= 0.0:
		node.set_indexed(property, value)
		return
	var tween := create_tween()
	tween.set_ease(ease_type).set_trans(trans)
	tween.tween_property(node, property, value, fade_duration)
	await tween.finished


## Half the viewport's diagonal: the radius at which the circle clears every
## corner, whatever the aspect ratio.
func _reach() -> float:
	return get_viewport().get_visible_rect().size.length() * 0.5


## The iris. Godot has no "fill everything except this circle", so it is drawn
## as one enormously thick ring: the arc's inner edge is the hole, and its
## width carries the black past every corner of the screen.
class Iris extends Control:
	var color: Color = Color.BLACK
	var radius: float = 0.0:
		set(value):
			radius = value
			queue_redraw()

	func _draw() -> void:
		var centre := size * 0.5
		var band := size.length() * 2.0
		draw_arc(centre, radius + band * 0.5, 0.0, TAU, 64, color, band)
