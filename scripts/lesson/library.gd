extends Control
## The Bugfall Archive: every world's teaching phase, replayable on its own.
##
## Strictly a reading room. Choosing a topic plays that lesson in library mode
## and comes back here. Nothing in this scene marks progress, changes combat
## state, or starts a fight — except the one button that says it does.

const ROW_HEIGHT := 46.0
const ROW_GAP := 8.0

var _worlds: Array[WorldData] = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	AudioManager.play_music(&"lesson")
	_worlds = WorldDatabase.load_default().in_order()

	_build_backdrop()
	_build_header()
	_build_topics()
	_build_footer()


func _build_backdrop() -> void:
	var path := "res://assets/arenas/bug_lord_arena.png"
	if ResourceLoader.exists(path):
		var bg := TextureRect.new()
		bg.texture = load(path)
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bg)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.06, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)


func _build_header() -> void:
	var title := Label.new()
	title.theme_type_variation = &"Title"
	title.text = "The Bugfall Archive"
	title.position = Vector2(64, 28)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)

	var sub := Label.new()
	sub.theme_type_variation = &"Subtle"
	sub.text = "Every lesson, kept. Read any of them again — nothing here is a fight."
	sub.position = Vector2(68, 94)
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sub)

	# A shelf should say how much of it you have read.
	var studied := 0
	for w in _worlds:
		if GameState.has_seen_lesson(w.world_id):
			studied += 1
	var count := Label.new()
	count.theme_type_variation = &"Subtle"
	count.text = "%d of %d studied" % [studied, _worlds.size()]
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.position = Vector2(get_viewport_rect().size.x - 364, 94)
	count.size.x = 300
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(count)


## One row per world, in campaign order. A world with no lesson file is listed
## and disabled rather than hidden — a gap in the shelf is information.
func _build_topics() -> void:
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", int(ROW_GAP))
	list.position = Vector2(64, 138)
	list.size = Vector2(740, _worlds.size() * (ROW_HEIGHT + ROW_GAP))
	add_child(list)

	for w in _worlds:
		# A row is a marker plus a button rather than one button with the tick
		# baked into its text: the font is proportional, so spacing a column
		# with spaces would make the titles disagree row by row.
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 10)
		row.custom_minimum_size = Vector2(740, ROW_HEIGHT)

		var seen := GameState.has_seen_lesson(w.world_id)
		var mark := Label.new()
		mark.custom_minimum_size = Vector2(26, ROW_HEIGHT)
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		mark.text = "\u2713" if seen else "\u00b7"
		mark.add_theme_color_override(&"font_color",
				Color(0.83, 0.69, 0.22) if seen else Color(0.45, 0.49, 0.60))
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(mark)

		var b := Button.new()
		b.theme_type_variation = &"ScrollOption"
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(700, ROW_HEIGHT)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.text = "%d.  %s  —  %s" % [w.order_index + 1, w.display_name, w.sdlc_phase]

		if LessonBank.has_lesson(w.world_id):
			b.pressed.connect(func() -> void: WorldFlow.study(self, w))
		else:
			b.disabled = true
			b.text += "   (no lesson yet)"
		# Unread rows stay fully readable and fully clickable — the Archive is
		# open by design, and dimming what you have not done yet reads as locked.
		row.add_child(b)
		list.add_child(row)


func _build_footer() -> void:
	var vp := get_viewport_rect().size

	var fight := Button.new()
	fight.theme_type_variation = &"ScrollOption"
	fight.text = "Face the Bug Lord"
	fight.custom_minimum_size = Vector2(260, 52)
	fight.position = Vector2(vp.x - 312, vp.y - 116)
	fight.pressed.connect(func() -> void: WorldFlow.face_bug_lord(self))
	add_child(fight)

	var back := Button.new()
	back.theme_type_variation = &"ScrollOption"
	back.text = "Back to the Space Map"
	back.custom_minimum_size = Vector2(260, 44)
	back.position = Vector2(vp.x - 312, vp.y - 56)
	back.pressed.connect(_leave)
	add_child(back)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_leave()


func _leave() -> void:
	SceneRouter.goto_scene(WorldFlow.SPACE_MAP_SCENE)
