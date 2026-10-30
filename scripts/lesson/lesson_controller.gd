extends Control
## Plays a world's lesson, one beat at a time, and then opens the fight.
##
## The teaching phase exists because a battle here asks multiple-choice
## questions about software engineering. Asking before teaching is an exam, not
## a game. LEARN -> UNDERSTAND -> APPLY -> TEST.
##
## The card is rebuilt per beat in code rather than kept as one hidden layout
## per beat type in the scene. Layouts that must be shown and hidden in the
## right combination are more state to get wrong than one that is thrown away.
##
## Two modes. In campaign mode the lesson leads to the world's fight and marks
## itself seen. In library mode — the Bugfall Archive — it leads back to the
## Archive, marks nothing, and drops the encounter beat, because a replay is
## revision and must not touch progress or start a battle.

const SIFU := "Sifu, The Wise"

## Seconds per character. Fast enough not to be a wait, slow enough that the
## text reads as spoken rather than pasted.
const TYPE_SPEED := 0.018

## Sifu stands in the left column, so the card is not centred — it sits in the
## space he leaves. Sized against the 1152x648 design resolution (ADR-015).
const CARD_SIZE := Vector2(790, 436)
const CARD_POS := Vector2(344, 110)
const PORTRAIT_HEIGHT := 500.0

var world: WorldData
## Set by the Bugfall Archive. Changes where the lesson leads and nothing else.
var library_mode: bool = false
## Where a replayed lesson goes when it ends. The Archive is one caller; a
## planet on the Space Map is another, and a lesson opened from a planet has to
## come back to the map rather than teleporting the player to Bugfall.
var return_scene: String = ""
var _lesson: Dictionary = {}
var _beats: Array = []
var _index: int = 0

var _card: PanelContainer
var _body_box: VBoxContainer
var _title: Label
var _progress: Label
var _next: Button
var _typing: Tween
var _typed: Label            ## the label currently being typed, if any
var _portrait: TextureRect
## A `steps` beat reveals one line per press. Counts how many are still hidden.
var _steps_left: int = 0
var _step_rows: Array[Control] = []
## Ticks while text is typing. A timer rather than a per-character callback:
## the typewriter is a tween on visible_ratio, which has no per-character hook,
## and one tick per character would be too many anyway.
var _tick: Timer
var _back: Button
## The current `check` beat's options, so the number keys can reach them. Empty
## on every other beat type, which is also how the key handler knows to ignore
## them.
var _check_buttons: Array[Button] = []


## Called by SceneRouter before the scene enters the tree.
func setup(world_data: WorldData, library: bool = false,
		back_to: String = "") -> void:
	world = world_data
	library_mode = library
	return_scene = back_to


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# PASS, not the Control default STOP: a root that swallows clicks would
	# never let _unhandled_input see them, and click-to-finish-the-line is the
	# main way this scene is driven.
	mouse_filter = Control.MOUSE_FILTER_PASS
	if world == null:
		push_error("Lesson: no world was set")
		SceneRouter.goto_scene("res://scenes/space_map/SpaceMap.tscn")
		return

	_lesson = LessonBank.for_world(world.world_id)
	_beats = _lesson.get("beats", [])
	if library_mode:
		# The encounter beat is the General stepping forward. In the Archive
		# there is no fight to step into, so it is not shown at all.
		_beats = _beats.filter(func(b): return str(b.get("type", "")) != "encounter")
	if _beats.is_empty():
		# No lesson written for this world yet: move on rather than showing an
		# empty room.
		_finish()
		return

	AudioManager.play_music(&"lesson")
	_build_tick_timer()
	_build_backdrop()
	_build_header()
	_build_card()
	_build_footer()
	_show_beat(0)


# --------------------------------------------------------------------------
# Static furniture
# --------------------------------------------------------------------------

## The arena the fight happens in, dimmed. The lesson is the same place a
## moment earlier, which is cheaper and more coherent than a backdrop of its own.
func _build_tick_timer() -> void:
	_tick = Timer.new()
	_tick.wait_time = 0.045
	_tick.timeout.connect(func() -> void:
		# Heavy jitter, well below the master: a run of identical ticks reads as
		# a machine gun, and this fires about twenty times a second.
		AudioManager.play(&"type_tick", 0.2, -9.0))
	add_child(_tick)


func _build_backdrop() -> void:
	var tex: Texture2D = null
	if world.general != null:
		var path := "res://assets/arenas/%s_arena.png" % world.general.enemy_id
		if ResourceLoader.exists(path):
			tex = load(path)

	if tex:
		var bg := TextureRect.new()
		bg.texture = tex
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bg)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.06, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	_build_portrait()


## Sifu. Added before the card so the card draws over him where they overlap,
## and positioned to run off the bottom edge — a figure that stops in mid-air
## reads as a sticker, one that leaves the frame reads as standing there.
##
## expand_mode first, then size. A TextureRect ignores `size` until told not to
## use the texture's own dimensions as its minimum, which has cost this project
## three separate layout bugs.
func _build_portrait() -> void:
	const PATH := "res://assets/characters/sifu.png"
	if not ResourceLoader.exists(PATH):
		return
	var tex: Texture2D = load(PATH)

	_portrait = TextureRect.new()
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.custom_minimum_size = Vector2.ZERO
	_portrait.texture = tex
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var w := PORTRAIT_HEIGHT * tex.get_width() / tex.get_height()
	_portrait.size = Vector2(w, PORTRAIT_HEIGHT)
	_portrait.position = Vector2(-26, get_viewport_rect().size.y - PORTRAIT_HEIGHT + 40)
	add_child(_portrait)


func _build_header() -> void:
	var vp := get_viewport_rect().size

	_title = Label.new()
	_title.theme_type_variation = &"Heading"
	_title.text = str(_lesson.get("title", world.display_name))
	_title.position = Vector2(CARD_POS.x + 4, 26)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title)

	var phase := Label.new()
	phase.theme_type_variation = &"Subtle"
	phase.text = "%s  ·  %s" % [world.display_name, _lesson.get("phase", world.sdlc_phase)]
	phase.position = Vector2(CARD_POS.x + 6, 70)
	phase.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(phase)

	_progress = Label.new()
	_progress.theme_type_variation = &"Subtle"
	_progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_progress.position = Vector2(vp.x - 248, 40)
	_progress.size.x = 200
	_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_progress)


func _build_card() -> void:
	_card = PanelContainer.new()
	_card.theme_type_variation = &"Scroll"
	_card.custom_minimum_size = CARD_SIZE
	_card.size = CARD_SIZE
	_card.position = CARD_POS
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_card)

	_body_box = VBoxContainer.new()
	_body_box.add_theme_constant_override("separation", 14)
	_card.add_child(_body_box)


func _build_footer() -> void:
	var vp := get_viewport_rect().size

	_next = Button.new()
	_next.theme_type_variation = &"ScrollOption"
	_next.custom_minimum_size = Vector2(240, 46)
	_next.position = Vector2(vp.x - 288, vp.y - 82)
	_next.pressed.connect(_on_next)
	add_child(_next)

	# Going back a beat. A lesson that can only move forward punishes one
	# impatient click with a paragraph the player cannot get to again — which is
	# the opposite of what a teaching phase is for.
	_back = Button.new()
	_back.theme_type_variation = &"ScrollOption"
	_back.text = "Back"
	_back.custom_minimum_size = Vector2(140, 40)
	_back.position = Vector2(vp.x - 672, vp.y - 79)
	_back.modulate.a = 0.75
	_back.pressed.connect(_on_back)
	add_child(_back)

	var skip := Button.new()
	skip.theme_type_variation = &"ScrollOption"
	if library_mode:
		skip.text = "Back to the Archive"
	elif world.world_id == WorldFlow.LIBRARY_WORLD:
		skip.text = "Skip to the Archive"
	else:
		skip.text = "Skip to the fight"
	skip.custom_minimum_size = Vector2(200, 40)
	# Bottom-right beside Continue, not bottom-left: Sifu is standing there.
	skip.position = Vector2(vp.x - 512, vp.y - 79)
	skip.modulate.a = 0.75
	skip.pressed.connect(_finish)
	add_child(skip)


# --------------------------------------------------------------------------
# Beats
# --------------------------------------------------------------------------

func _show_beat(i: int) -> void:
	_index = i
	var beat: Dictionary = _beats[i]
	_progress.text = "%d / %d" % [i + 1, _beats.size()]

	AudioManager.play(&"page_turn", 0.06, -3.0)
	_tick.stop()

	for child in _body_box.get_children():
		child.queue_free()
	_typed = null
	_check_buttons.clear()
	_steps_left = 0
	_step_rows.clear()
	_next.disabled = false

	match str(beat.get("type", "")):
		"dialogue": _render_dialogue(beat)
		"concept": _render_concept(beat)
		"compare": _render_compare(beat)
		"example": _render_example(beat)
		"steps": _render_steps(beat)
		"check": _render_check(beat)
		"encounter": _render_encounter(beat)
		_:
			push_warning("Lesson: unknown beat type '%s'" % beat.get("type"))
			_render_concept(beat)

	# He teaches every beat but the last. The encounter beat is the General
	# speaking, and Sifu has said his piece by then.
	if _portrait:
		_portrait.visible = str(beat.get("type", "")) != "encounter"

	if _back:
		_back.disabled = i == 0

	var last := i == _beats.size() - 1
	if not last:
		_next.text = "Continue"
	elif library_mode:
		_next.text = "Back to the Archive"
	elif world.world_id == WorldFlow.LIBRARY_WORLD:
		# Bugfall's lesson opens the Archive, not a fight. The button has to say
		# where it goes, or it lies.
		_next.text = "Open the Archive"
	else:
		_next.text = "Enter the fight"

	# Fade the card contents in, so a new beat reads as a new page rather than
	# text that changed underneath you.
	_body_box.modulate.a = 0.0
	create_tween().tween_property(_body_box, "modulate:a", 1.0, 0.18)

	if _typed:
		_start_typing(_typed)


func _render_dialogue(beat: Dictionary) -> void:
	var speaker := Label.new()
	speaker.theme_type_variation = &"Accent"
	speaker.text = str(beat.get("speaker", SIFU))
	_body_box.add_child(speaker)

	# Portrait slot. Sifu has no art yet; the layout is built to take one so
	# adding it later is a texture, not a rewrite.

	_body_box.add_child(_rule())

	var text := Label.new()
	text.text = str(beat.get("text", ""))
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_theme_font_size_override("font_size", 21)
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body_box.add_child(text)
	_typed = text


func _render_concept(beat: Dictionary) -> void:
	var head := _header_box(str(beat.get("title", "")))
	_body_box.add_child(head)

	var body := Label.new()
	body.text = str(beat.get("body", ""))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body_box.add_child(body)
	_typed = body

	var terms: Variant = beat.get("terms", [])
	if terms is Array and not terms.is_empty():
		var t := Label.new()
		t.theme_type_variation = &"Subtle"
		t.text = "Key terms:  " + "   ·   ".join(PackedStringArray(terms))
		_body_box.add_child(t)


func _render_compare(beat: Dictionary) -> void:
	_body_box.add_child(_header_box(str(beat.get("title", ""))))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(_column(str(beat.get("left_label", "")), str(beat.get("left_body", ""))))
	row.add_child(_column(str(beat.get("right_label", "")), str(beat.get("right_body", ""))))
	_body_box.add_child(row)


func _render_example(beat: Dictionary) -> void:
	_body_box.add_child(_header_box(str(beat.get("title", ""))))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(_column(str(beat.get("bad_label", "Before")), str(beat.get("bad", "")),
			Color(0.97, 0.32, 0.29)))
	row.add_child(_column(str(beat.get("good_label", "After")), str(beat.get("good", "")),
			Color(0.25, 0.73, 0.31)))
	_body_box.add_child(row)

	var verdict := Label.new()
	verdict.theme_type_variation = &"Subtle"
	verdict.text = str(beat.get("verdict", ""))
	verdict.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_box.add_child(verdict)


func _render_encounter(beat: Dictionary) -> void:
	var who := Label.new()
	who.theme_type_variation = &"Accent"
	who.text = world.general_name if world.general_name else "The holder of this world"
	who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body_box.add_child(who)

	_body_box.add_child(_rule())

	var taunt := Label.new()
	taunt.text = "“%s”" % str(beat.get("taunt", ""))
	taunt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	taunt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	taunt.add_theme_font_size_override("font_size", 24)
	taunt.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body_box.add_child(taunt)
	_typed = taunt

	var closing := Label.new()
	closing.theme_type_variation = &"Subtle"
	closing.text = str(beat.get("text", ""))
	closing.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body_box.add_child(closing)


## An ordered process, revealed one line per press rather than dumped at once.
## Reading a five-step pipeline as five arrivals is the difference between
## watching something happen and being handed a list.
func _render_steps(beat: Dictionary) -> void:
	_body_box.add_child(_header_box(str(beat.get("title", ""))))

	var steps: Array = beat.get("steps", [])
	for i in steps.size():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)

		var num := Label.new()
		num.text = "%d" % (i + 1)
		num.custom_minimum_size = Vector2(34, 0)
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		num.add_theme_color_override("font_color", Color(0.83, 0.69, 0.22))
		num.add_theme_font_size_override("font_size", 20)
		row.add_child(num)

		var text := Label.new()
		text.text = str(steps[i])
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text)

		row.modulate.a = 0.0
		_body_box.add_child(row)
		_step_rows.append(row)

	_steps_left = _step_rows.size()
	if _steps_left > 0:
		_reveal_step()


## One step fades in. Called by Continue and by a click, so revealing and
## advancing are the same gesture.
##
## Fade only, no slide: these rows live in a VBoxContainer, which rewrites its
## children's positions every layout pass and would fight the tween.
func _reveal_step() -> void:
	if _steps_left <= 0:
		return
	var row := _step_rows[_step_rows.size() - _steps_left]
	_steps_left -= 1
	var t := create_tween()
	t.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(row, "modulate:a", 1.0, 0.22)


## One question, answered here, with no cost. The General battle is the test;
## this is the rehearsal, and getting it wrong in the lesson is how you find
## out you had not understood before it matters.
func _render_check(beat: Dictionary) -> void:
	_body_box.add_child(_header_box(str(beat.get("question", ""))))

	var options: Array = beat.get("options", [])
	var answer := int(beat.get("answer", 0))
	var explain := Label.new()
	var buttons: Array[Button] = []

	for i in options.size():
		var b := Button.new()
		b.theme_type_variation = &"ScrollOption"
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		# Numbered like the battle's options, and answerable by the same keys —
		# the rehearsal should not be operated differently from the test.
		b.text = "%d.   %s" % [i + 1, str(options[i])]
		_body_box.add_child(b)
		buttons.append(b)
	_check_buttons = buttons

	explain.theme_type_variation = &"Subtle"
	explain.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	explain.visible = false
	_body_box.add_child(explain)

	for i in buttons.size():
		buttons[i].pressed.connect(func() -> void:
			for b in buttons:
				b.disabled = true
			buttons[i].modulate = Color(0.25, 0.73, 0.31) if i == answer \
					else Color(0.97, 0.32, 0.29)
			if i != answer and answer < buttons.size():
				buttons[answer].modulate = Color(0.25, 0.73, 0.31)
			explain.text = str(beat.get("explanation", ""))
			explain.visible = true
			_next.disabled = false)

	# Continue is closed until the question is answered. Skipping past a check
	# would make it decoration.
	_next.disabled = true


# --------------------------------------------------------------------------
# Small builders
# --------------------------------------------------------------------------

func _header_box(text: String) -> PanelContainer:
	var box := PanelContainer.new()
	box.theme_type_variation = &"ScrollHeader"
	var label := Label.new()
	label.theme_type_variation = &"ScrollQuestion"
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(label)
	return box


func _column(heading: String, body: String, tint: Color = Color(0.83, 0.69, 0.22)) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 8)

	var h := Label.new()
	h.text = heading
	h.add_theme_color_override("font_color", tint)
	h.add_theme_font_size_override("font_size", 20)
	col.add_child(h)

	var b := Label.new()
	b.text = body
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(b)
	return col


func _rule() -> ColorRect:
	var line := ColorRect.new()
	line.color = Color(0.58, 0.48, 0.16, 0.55)
	line.custom_minimum_size = Vector2(0, 2)
	return line


# --------------------------------------------------------------------------
# Typing
# --------------------------------------------------------------------------

func _start_typing(label: Label) -> void:
	if _typing and _typing.is_valid():
		_typing.kill()          # killing a tween does not emit `finished`
	_tick.stop()

	label.visible_ratio = 0.0
	_typing = create_tween()
	_typing.tween_property(label, "visible_ratio", 1.0,
			maxf(0.2, label.text.length() * TYPE_SPEED))
	# Fires whether the line finished on its own or the player clicked through
	# it, so the ticking always stops with the text.
	_typing.finished.connect(_tick.stop)
	_tick.start()


func _is_typing() -> bool:
	return _typing != null and _typing.is_valid() and _typing.is_running()


## Click or space finishes the line rather than skipping the beat. Skipping on
## the same input would punish an impatient reader by hiding what they were
## waiting for.
func _unhandled_input(event: InputEvent) -> void:
	# A check beat's options answer to the number keys, exactly as the battle's
	# do. Handled before everything else, so 1-4 never doubles as "advance".
	if not _check_buttons.is_empty() and event is InputEventKey \
			and event.pressed and not event.echo:
		var pick := -1
		match event.keycode:
			KEY_1, KEY_KP_1: pick = 0
			KEY_2, KEY_KP_2: pick = 1
			KEY_3, KEY_KP_3: pick = 2
			KEY_4, KEY_KP_4: pick = 3
		if pick >= 0 and pick < _check_buttons.size() \
				and not _check_buttons[pick].disabled:
			get_viewport().set_input_as_handled()
			_check_buttons[pick].pressed.emit()
			return

	# Left arrow goes back a beat. Cheap to add, and the only way to re-read
	# without taking a hand off the keyboard.
	if event.is_action_pressed("ui_left"):
		get_viewport().set_input_as_handled()
		_on_back()
		return

	var pressed: bool = (event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT) \
			or event.is_action_pressed("ui_accept") \
			or event.is_action_pressed("ui_right")
	if not pressed:
		return
	get_viewport().set_input_as_handled()
	if _is_typing():
		_typing.custom_step(999.0)
	elif not _next.disabled:
		_on_next()


# --------------------------------------------------------------------------
# Flow
# --------------------------------------------------------------------------

## One beat back, re-read from the start of its text. A `steps` beat replays its
## reveals and a `check` beat asks again, which is what re-reading means.
func _on_back() -> void:
	if _index <= 0:
		return
	if _is_typing():
		_typing.custom_step(999.0)
	_show_beat(_index - 1)


func _on_next() -> void:
	if _is_typing():
		_typing.custom_step(999.0)
		return
	if _steps_left > 0:
		_reveal_step()
		return
	if _index + 1 < _beats.size():
		_show_beat(_index + 1)
	else:
		_finish()


## Where the lesson leads. In the Archive it leads back to the Archive and
## touches nothing else — no progress, no battle, no saved state.
func _finish() -> void:
	if library_mode:
		SceneRouter.goto_scene(return_scene if not return_scene.is_empty()
				else WorldFlow.LIBRARY_SCENE)
		return

	# Marked seen whether the lesson was read or skipped: a replay should not
	# force the lesson on someone who has already chosen to pass it.
	GameState.mark_lesson_seen(world.world_id)
	WorldFlow.after_lesson(self, world)
