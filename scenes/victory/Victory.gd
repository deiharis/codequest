extends Control
## Shown once the Bug Lord's persistent HP reaches zero.
##
## It has one job the old version did not: show the player what they actually
## did. "8 worlds cleared" is a number; eight named worlds with their SDLC
## phases beside them is a record of a campaign, and this game is about those
## eight subjects more than it is about the fight.
##
## Built in code, like the lesson and the Archive, so the layout is one file
## rather than a scene tree plus a script that has to agree with it.

const ROW_HEIGHT := 34.0

@export var star_seed: int = 11
@export var star_count: int = 260
@export var background_texture: Texture2D

var _panel: PanelContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	AudioManager.play(&"victory", 0.0)
	# Back to the menu's theme: the campaign ends where it started.
	AudioManager.play_music(&"title")

	_build_backdrop()
	_build_title()
	_build_roll()
	_build_buttons()
	_play_entrance()


# --------------------------------------------------------------------------
# Presentation
# --------------------------------------------------------------------------

## Same three-layer ordering as the title screen and the Space Map: flat clear
## colour, nebula at z -9, and this node's own starfield drawn on top of both.
## A child ColorRect would paint over its own parent's `_draw` and hide the sky.
func _build_backdrop() -> void:
	var tex := background_texture
	if tex == null and ResourceLoader.exists("res://assets/ui/space_background.png"):
		tex = load("res://assets/ui/space_background.png")
	if tex == null:
		return

	var art := TextureRect.new()
	art.name = "Nebula"
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.custom_minimum_size = Vector2.ZERO
	art.texture = tex
	art.size = get_viewport_rect().size
	art.z_index = -9
	art.modulate = Color(1, 1, 1, 0.55)     # dimmer than the title screen's
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(art)


func _build_title() -> void:
	var vp := get_viewport_rect().size

	var title := Label.new()
	title.name = "Title"
	title.theme_type_variation = &"Title"
	title.text = "THE BUG LORD IS GONE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 54)
	title.size.x = vp.x
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)

	var sub := Label.new()
	sub.name = "Subtitle"
	sub.theme_type_variation = &"Subtle"
	sub.text = "Eight worlds. Seven Generals. One campaign."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.position = Vector2(0, 122)
	sub.size.x = vp.x
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sub)


## Every world, in order, with the subject it taught. The roll is the point of
## the screen — the player is being shown a syllabus they finished, not a score.
func _build_roll() -> void:
	var vp := get_viewport_rect().size
	var worlds := WorldDatabase.load_default().in_order()

	_panel = PanelContainer.new()
	_panel.name = "Roll"
	_panel.size = Vector2(660, worlds.size() * ROW_HEIGHT + 64)
	_panel.position = Vector2((vp.x - 660) * 0.5, 166)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 4)
	_panel.add_child(list)

	for w in worlds:
		var row := HBoxContainer.new()
		row.custom_minimum_size.y = ROW_HEIGHT
		row.add_theme_constant_override("separation", 14)

		var mark := Label.new()
		mark.text = "✓"
		mark.custom_minimum_size = Vector2(26, 0)
		mark.add_theme_color_override("font_color", Color(0.83, 0.69, 0.22))
		row.add_child(mark)

		var name_label := Label.new()
		name_label.text = w.display_name
		name_label.custom_minimum_size = Vector2(190, 0)
		row.add_child(name_label)

		var phase := Label.new()
		phase.theme_type_variation = &"Subtle"
		phase.text = w.sdlc_phase
		phase.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(phase)

		list.add_child(row)


func _build_buttons() -> void:
	var vp := get_viewport_rect().size
	var y := vp.y - 96.0

	var again := Button.new()
	again.name = "PlayAgain"
	again.theme_type_variation = &"ScrollOption"
	again.text = "New Campaign"
	again.custom_minimum_size = Vector2(230, 48)
	again.position = Vector2(vp.x * 0.5 - 246, y)
	again.pressed.connect(_on_play_again)
	add_child(again)

	var title_screen := Button.new()
	title_screen.name = "TitleScreen"
	title_screen.theme_type_variation = &"ScrollOption"
	title_screen.text = "Title Screen"
	title_screen.custom_minimum_size = Vector2(230, 48)
	title_screen.position = Vector2(vp.x * 0.5 + 16, y)
	title_screen.pressed.connect(_on_title_screen)
	add_child(title_screen)


## Title, then the roll, then the buttons — in that order and slightly apart, so
## the screen arrives rather than appearing. Everything starts transparent and
## a little low; nothing moves far.
func _play_entrance() -> void:
	var order: Array[Node] = []
	for n in ["Title", "Subtitle", "Roll", "PlayAgain", "TitleScreen"]:
		var node := get_node_or_null(NodePath(n))
		if node:
			order.append(node)

	for i in order.size():
		var c: Control = order[i]
		var home := c.position
		c.modulate.a = 0.0
		c.position = home + Vector2(0, 18)
		var t := create_tween().set_parallel()
		t.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		t.tween_property(c, "modulate:a", 1.0, 0.35).set_delay(i * 0.13)
		t.tween_property(c, "position", home, 0.4).set_delay(i * 0.13)


func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = star_seed
	var view := get_viewport_rect().size
	for i in star_count:
		var p := Vector2(rng.randf() * view.x, rng.randf() * view.y)
		var r := rng.randf_range(0.6, 1.8)
		# Most stars faint, a few bright. An evenly lit field looks printed on.
		var a := rng.randf_range(0.10, 0.85)
		draw_circle(p, r, Color(1, 1, 1, a * a))


# --------------------------------------------------------------------------
# Flow
# --------------------------------------------------------------------------

## A new campaign means a genuinely new campaign — the save is cleared, not
## edited, so there is no half-finished state left behind.
func _on_play_again() -> void:
	GameState.reset()
	SceneRouter.goto_scene("res://scenes/space_map/SpaceMap.tscn")


func _on_title_screen() -> void:
	SceneRouter.goto_scene("res://scenes/main/Main.tscn")
