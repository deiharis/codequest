extends Node
## Escape, anywhere it makes sense, and a way out.
##
## Before this existed the game had no pause at all — `get_tree().paused` was
## never set. Escape left the Space Map and the Archive; inside a battle or a
## lesson it did nothing, so once a fight started the only way out was to kill
## the window. That is a defect, not a missing nicety.
##
## An autoload rather than a node per scene: every scene needs it, and a rule
## that says "remember to add the pause menu" is a rule that holds until the day
## someone forgets. Same reasoning as AudioManager's button hook (ADR-029).

## Scenes that own Escape themselves, or where pausing means nothing.
##
## The Space Map and the Archive already consume the key before this node sees
## it, so listing them changes nothing about the keyboard — it is what keeps the
## on-screen Pause button off screens that have their own way out, and off the
## title screen, where pausing a menu is meaningless.
const IGNORED := [
	"res://scenes/main/Main.tscn",
	"res://scenes/space_map/SpaceMap.tscn",
	"res://scenes/lesson/Library.tscn",
]

var is_open: bool = false

var _layer: CanvasLayer
var _dim: ColorRect
var _panel: PanelContainer
var _sound_button: Button
var _open_button: Button


func _ready() -> void:
	# Has to keep running while the tree is paused, or it could not unpause it.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	# The button has to know when the scene changed, because whether it belongs
	# on screen depends on which scene is showing.
	SceneRouter.scene_changed.connect(func(_scene): _refresh_button())
	# Deferred as well as immediate: autoloads run before the main scene is
	# assigned, so `current_scene` is still null here. It also covers a scene
	# run directly with F6, which never emits `scene_changed` at all.
	_refresh_button.call_deferred()


## Scenes are later children of the root than autoloads, and `_unhandled_input`
## propagates from the bottom of the tree up — so any scene that consumes
## Escape (the Space Map, the Archive) is served before this ever runs.
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"ui_cancel"):
		return
	if not _allowed_here():
		return
	get_viewport().set_input_as_handled()
	toggle()


func _allowed_here() -> bool:
	var scene := get_tree().current_scene
	return scene != null and not (scene.scene_file_path in IGNORED)


## Shown wherever pausing is allowed, and hidden while the menu itself is up —
## the panel has its own Resume, and two ways to close it in the same corner is
## one too many.
func _refresh_button() -> void:
	if _open_button:
		_open_button.visible = _allowed_here() and not is_open


func toggle() -> void:
	if is_open:
		close()
	else:
		open()


func open() -> void:
	if is_open:
		return
	is_open = true
	_sound_button.text = "Sound:  Off" if AudioManager.muted else "Sound:  On"
	_dim.visible = true
	_panel.visible = true
	_refresh_button()
	get_tree().paused = true

	_dim.modulate.a = 0.0
	# Set here, not at build time: the panel has no size until it has been laid
	# out, and scaling around a pivot of (0,0) grows it out of the corner.
	_panel.pivot_offset = _panel.size * 0.5
	_panel.scale = Vector2(0.94, 0.94)
	var t := create_tween().set_parallel()
	t.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(_dim, "modulate:a", 1.0, 0.14)
	t.tween_property(_panel, "scale", Vector2.ONE, 0.18)


func close() -> void:
	if not is_open:
		return
	is_open = false
	get_tree().paused = false
	_dim.visible = false
	_panel.visible = false
	_refresh_button()


# --------------------------------------------------------------------------
# Construction
# --------------------------------------------------------------------------

func _build() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "PauseLayer"
	_layer.layer = 120          # over everything but SceneRouter's fade (128)
	add_child(_layer)

	# The affordance. Escape works, but nothing on screen said so, and a player
	# should not have to guess that a key exists.
	_open_button = Button.new()
	_open_button.theme_type_variation = &"ScrollOption"
	_open_button.text = "Pause"
	_open_button.custom_minimum_size = Vector2(96, 34)
	_open_button.position = Vector2(18, 16)
	_open_button.modulate.a = 0.8
	_open_button.pressed.connect(open)
	_layer.add_child(_open_button)

	_dim = ColorRect.new()
	_dim.color = Color(0.01, 0.02, 0.05, 0.72)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	# STOP, not IGNORE: the dimmer is what stops clicks reaching the paused
	# scene behind it. A paused battle would not act on them, but the Space Map
	# would, and the player would launch a rocket from inside a pause menu.
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.visible = false
	_layer.add_child(_dim)

	# A CenterContainer rather than anchor presets on the panel itself: a
	# PanelContainer has no size until its children are laid out, so centring it
	# by anchors at build time centres a zero-sized box.
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(centre)
	

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(340, 0)
	_panel.visible = false
	centre.add_child(_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	_panel.add_child(box)

	var title := Label.new()
	title.theme_type_variation = &"Heading"
	title.text = "Paused"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var rule := ColorRect.new()
	rule.color = Color(0.58, 0.48, 0.16, 0.55)
	rule.custom_minimum_size = Vector2(0, 2)
	box.add_child(rule)

	box.add_child(_button("Resume", close))
	_sound_button = _button("Sound:  On", _toggle_sound)
	box.add_child(_sound_button)
	box.add_child(_button("Quit to Title", _quit_to_title))


func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.theme_type_variation = &"ScrollOption"
	b.text = text
	b.custom_minimum_size = Vector2(300, 44)
	b.pressed.connect(action)
	return b


func _toggle_sound() -> void:
	AudioManager.muted = not AudioManager.muted
	_sound_button.text = "Sound:  Off" if AudioManager.muted else "Sound:  On"


func _quit_to_title() -> void:
	close()
	SceneRouter.goto_scene("res://scenes/main/Main.tscn")
