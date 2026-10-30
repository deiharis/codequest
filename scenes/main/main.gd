extends Control
## The title screen, and the game's boot scene.
##
## Reads GameState rather than the save file directly — the autoload has
## already loaded it by the time this runs, and one thing should own that file.

## Starfield, drawn by this node itself. Background sits at z_index -10 so it
## renders behind that drawing — a child ColorRect would otherwise paint over
## its own parent's _draw and hide every star.
##
## Seeded so it is the same sky every launch: a field that reshuffles
## on each boot reads as noise rather than as a place.
@export var star_seed: int = 4
@export var star_count: int = 220
@export var background_texture: Texture2D
@export var title_texture: Texture2D
@export var title_area: Rect2 = Rect2(176, 52, 800, 222)

@onready var _continue: Button = $Menu/Continue
@onready var _new_game: Button = $Menu/NewGame
@onready var _quit: Button = $Menu/Quit
var _sound: Button
@onready var _progress: Label = $Progress

## New Game is destructive once there is progress, so the first press asks and
## the second confirms. A dialog would be heavier than the decision deserves.
var _confirming: bool = false


func _ready() -> void:
	_build_backdrop()
	_build_title()
	AudioManager.play_music(&"title")
	_build_sound_button()
	_continue.pressed.connect(_on_continue)
	_new_game.pressed.connect(_on_new_game)
	_quit.pressed.connect(_on_quit)
	_refresh()


## The pause menu owns the sound toggle everywhere else, but it is deliberately
## hidden on this screen (ADR-034) — which left the game's first screen with no
## way to turn the sound off at all.
##
## Built here rather than placed in the scene so it sits between New Game and
## Quit without the .tscn and this script having to agree on an index.
func _build_sound_button() -> void:
	_sound = Button.new()
	_sound.name = "Sound"
	_sound.custom_minimum_size = Vector2(0, 46)
	_sound.pressed.connect(_on_sound)
	$Menu.add_child(_sound)
	$Menu.move_child(_sound, _quit.get_index())

	# A fourth row makes the block 60px taller (46 + the VBox's 14 separation),
	# and the menu is centre-anchored with the progress line pinned 78px off the
	# bottom — so without this the two would overlap by 20px. Lifting by half
	# the added height keeps the block centred on the same point it was.
	const ADDED := 46.0 + 14.0
	$Menu.offset_top -= ADDED * 0.5
	$Menu.offset_bottom -= ADDED * 0.5

	_refresh_sound()


func _refresh_sound() -> void:
	_sound.text = "Sound:  Off" if AudioManager.muted else "Sound:  On"


func _on_sound() -> void:
	AudioManager.muted = not AudioManager.muted
	_refresh_sound()


func _refresh() -> void:
	var cleared := GameState.defeated_generals.size()
	var started := cleared > 0

	_continue.visible = started
	_new_game.text = "New Game"
	_confirming = false

	if GameState.is_campaign_won():
		_progress.text = "Campaign complete — the Bug Lord is gone"
	elif started:
		_progress.text = "%d of 8 worlds cleared   ·   Bug Lord %d HP" \
				% [cleared, GameState.bug_lord_hp]
	else:
		_progress.text = "Eight worlds. Seven Generals. One Bug Lord."


func _on_continue() -> void:
	SceneRouter.goto_scene("res://scenes/space_map/SpaceMap.tscn")


func _on_new_game() -> void:
	if GameState.defeated_generals.is_empty():
		SceneRouter.goto_scene("res://scenes/space_map/SpaceMap.tscn")
		return

	if not _confirming:
		_confirming = true
		_new_game.text = "Erase progress?"
		_progress.text = "This deletes your save. Press again to confirm."
		return

	GameState.reset()
	SceneRouter.goto_scene("res://scenes/space_map/SpaceMap.tscn")


func _on_quit() -> void:
	get_tree().quit()


# --------------------------------------------------------------------------
# Presentation
# --------------------------------------------------------------------------

## Same three-layer ordering as the Space Map: flat rect at -10, nebula at -9,
## this node's own stars on top of both.
func _build_backdrop() -> void:
	if background_texture == null:
		return
	var art := TextureRect.new()
	art.name = "Nebula"
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.custom_minimum_size = Vector2.ZERO
	art.texture = background_texture
	art.position = Vector2.ZERO
	art.size = get_viewport_rect().size
	art.z_index = -9
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(art)


func _build_title() -> void:
	if title_texture == null:
		return
	var art := TextureRect.new()
	# Expand first: until then a TextureRect's minimum size is the texture's
	# full size, and any size set before that is clamped back up to it.
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.custom_minimum_size = Vector2.ZERO
	art.texture = title_texture
	art.position = title_area.position
	art.size = title_area.size
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(art)


func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = star_seed
	var view := get_viewport_rect().size
	for i in star_count:
		var p := Vector2(rng.randf() * view.x, rng.randf() * view.y)
		var r := rng.randf_range(0.6, 1.8)
		# Most stars are faint; a few are bright. An evenly lit field looks
		# printed on rather than deep.
		var a := rng.randf_range(0.10, 0.85)
		draw_circle(p, r, Color(1, 1, 1, a * a))
