extends Control
## Shows one question and reports which option was picked.
##
## Knows nothing about combat. It reports the choice; BattleController decides
## what a choice costs.

## Carries the index as well as correctness, so the panel can highlight what
## was picked and the controller can record what the player got wrong.
signal answer_selected(index: int, is_correct: bool)

const COLOUR_CORRECT := Color(0.25, 0.73, 0.31)
const COLOUR_WRONG := Color(0.97, 0.32, 0.29)
## Extra time on screen when there is an explanation to read. The explanation
## is the teaching moment, so it gets longer than the colour flash.
const EXPLANATION_HOLD := 2.2

## Asymmetric on purpose. Out accelerates away and reads as dismissed; in
## arrives and settles with a slight overshoot and reads as presented. The same
## curve both ways feels mechanical, and that difference is most of what
## separates "polished" from merely "animated".
const SLIDE_OUT_TIME := 0.28
const SLIDE_IN_TIME := 0.34

## How far the battlefield dims while a question is up. Enough to pull the eye
## to the scroll, not enough to hide the fight behind it.
const DIM_ALPHA := 0.45

var current_question: QuestionData
var _buttons: Array[Button] = []
var _locked: bool = false

## The explanation plate: a bordered box in the correctness colour, built here
## rather than placed in the scene because it wraps a label that already exists
## there and the wrapping is the whole change.
var _explain_box: PanelContainer
var _explain_head: Label
var _explain_body: Label

@onready var _box: PanelContainer = $Panel
var _dim: ColorRect
## Where the panel rests. Captured rather than hardcoded, so moving the panel
## in the scene never silently breaks the animation.
var _home_y: float = 0.0
var _away_y: float = 0.0


func _ready() -> void:
	_buttons = [
		$Panel/Layout/OptionButton1,
		$Panel/Layout/OptionButton2,
		$Panel/Layout/OptionButton3,
		$Panel/Layout/OptionButton4,
	]
	# Connected once, here — never in a setup() that might be called twice.
	for i in _buttons.size():
		_buttons[i].pressed.connect(_on_option_pressed.bind(i))

	_build_explanation()
	_build_dim()
	_home_y = _box.position.y
	# Far enough below the viewport that the panel is fully gone whatever its
	# height, with margin for the shadow a styled panel will cast later.
	_away_y = get_viewport_rect().size.y + 40.0
	_box.position.y = _away_y
	# Start off-stage and hidden. The first question slides it in like any
	# other, so there is no special case for the opening beat.
	visible = false


## Fill the panel and slide it up into place. Awaitable, and it does not accept
## input until it has arrived — answering a question that is still moving would
## mean answering one you have not finished reading.
func show_question(question: QuestionData) -> void:
	current_question = question
	$Panel/Layout/QuestionBox/QuestionLabel.text = question.question_text
	_explain_box.visible = false

	for i in _buttons.size():
		var b := _buttons[i]
		b.modulate = Color.WHITE
		if i < question.options.size():
			b.visible = true
			# Numbered, because the keys only exist for a player who can see
			# that they do. Same lesson as the Pause button (ADR-034).
			b.text = "%d.   %s" % [i + 1, question.options[i]]
		else:
			b.visible = false

	lock()
	visible = true
	_box.position.y = _away_y
	AudioManager.play(&"panel_in", 0.03)

	var t := create_tween().set_parallel()
	t.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(_box, "position:y", _home_y, SLIDE_IN_TIME)
	# The dim leads slightly: the room darkens, then the scroll arrives in it.
	t.tween_property(_dim, "modulate:a", DIM_ALPHA, SLIDE_IN_TIME * 0.8)
	await t.finished

	unlock()


## Wraps the scene's ExplanationLabel in a bordered plate with a verdict header.
##
## The label was a bare line of grey text under the options — the question got a
## box when it was asked for one, and the answer never did.
func _build_explanation() -> void:
	var layout: VBoxContainer = $Panel/Layout
	_explain_body = $Panel/Layout/ExplanationLabel

	_explain_box = PanelContainer.new()
	_explain_box.name = "ExplanationBox"
	_explain_box.theme_type_variation = &"ScrollHeader"
	_explain_box.visible = false
	layout.add_child(_explain_box)

	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 4)
	_explain_box.add_child(col)

	_explain_head = Label.new()
	_explain_head.name = "Verdict"
	_explain_head.add_theme_font_size_override(&"font_size", 13)
	col.add_child(_explain_head)

	# Reparented rather than rebuilt, so whatever the scene set on it survives.
	layout.remove_child(_explain_body)
	col.add_child(_explain_body)
	_explain_body.theme_type_variation = &""
	_explain_body.add_theme_font_size_override(&"font_size", 15)
	_explain_body.visible = true

	# The plate is the last thing in the column.
	layout.move_child(_explain_box, layout.get_child_count() - 1)

	# Tighter than the theme's 14px: measured, the scroll has 304px of inner
	# height and a two-option feedback state needs 297 of it.
	var sb: StyleBoxFlat = _explain_box.get_theme_stylebox(&"panel", &"ScrollHeader").duplicate()
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 10.0
	_explain_box.add_theme_stylebox_override(&"panel", sb)


## The battlefield dimmer. Built here rather than placed in the scene so it is
## always the first child — it has to draw under the scroll and over the fight,
## and tree order is what decides that.
func _build_dim() -> void:
	_dim = ColorRect.new()
	_dim.name = "Dim"
	_dim.color = Color.BLACK
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.modulate.a = 0.0
	add_child(_dim)
	move_child(_dim, 0)


## Stop accepting input. Called the instant an option is pressed, so a fast
## double-click cannot fire two answers.
func lock() -> void:
	_locked = true
	for b in _buttons:
		b.disabled = true


func unlock() -> void:
	_locked = false
	for b in _buttons:
		b.disabled = false


## Colour the chosen button, reveal the right one, and clear the rest away to
## make room for the explanation.
##
## The wrong options are hidden, not just dimmed, and that is a space fix as
## much as a teaching one. Measured: the scroll has 304px of inner height, and
## the question box, four options and their separations already use 297 of it —
## the explanation has been overflowing the parchment this whole time. Removing
## the options that are now irrelevant frees 126px and the plate fits.
##
## What stays is what the player needs: the question, the right answer, their
## own answer if it differed, and why.
func show_feedback(index: int, is_correct: bool, hold: float = 0.45) -> void:
	var right := current_question.correct_option_index

	if index >= 0 and index < _buttons.size():
		_buttons[index].modulate = COLOUR_CORRECT if is_correct else COLOUR_WRONG
	if not is_correct and right >= 0 and right < _buttons.size():
		_buttons[right].modulate = COLOUR_CORRECT

	var fade := create_tween().set_parallel()
	for i in _buttons.size():
		if i == index or i == right or not _buttons[i].visible:
			continue
		fade.tween_property(_buttons[i], "modulate:a", 0.0, 0.16)
	await fade.finished
	for i in _buttons.size():
		if i != index and i != right:
			_buttons[i].visible = false

	if current_question.explanation.is_empty():
		await get_tree().create_timer(hold, false).timeout
		return

	var accent := COLOUR_CORRECT if is_correct else COLOUR_WRONG
	_explain_head.text = "CORRECT" if is_correct else "NOT QUITE"
	_explain_head.add_theme_color_override(&"font_color", accent)
	_explain_body.text = current_question.explanation
	_explain_body.add_theme_color_override(&"font_color",
			Color(0.89, 0.92, 0.96))

	# The plate's border carries the verdict; the text stays readable rather
	# than being tinted green or red, because it is the part meant to be read.
	var sb: StyleBoxFlat = _explain_box.get_theme_stylebox(&"panel").duplicate()
	sb.border_color = accent
	_explain_box.add_theme_stylebox_override(&"panel", sb)

	_explain_box.visible = true
	_explain_box.modulate.a = 0.0
	var t := create_tween()
	t.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	t.tween_property(_explain_box, "modulate:a", 1.0, 0.2)

	await get_tree().create_timer(hold + EXPLANATION_HOLD, false).timeout


## Slide the panel out and return only once it has gone, so the battle can
## await it and start the attack on a clear stage.
func hide_panel() -> void:
	if not visible:
		return
	lock()
	AudioManager.play(&"panel_out", 0.03)
	var t := create_tween().set_parallel()
	t.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	t.tween_property(_box, "position:y", _away_y, SLIDE_OUT_TIME)
	# The light comes back up as the scroll leaves, so the attack lands on a
	# fully lit stage rather than a half-dark one.
	t.tween_property(_dim, "modulate:a", 0.0, SLIDE_OUT_TIME)
	await t.finished
	visible = false


## True only while the panel is up and taking answers. The battle's countdown
## reads this, so no time is charged while the panel is in motion.
func is_accepting() -> bool:
	return visible and not _locked


## Number keys pick an option. A campaign is eight worlds of ten questions in
## two fights each — a hundred and sixty answers, every one of them a mouse
## journey across the scroll. The keys cost fifteen lines.
##
## Guarded by `is_accepting()`, which is already the one place that knows
## whether the panel is up, arrived, and unanswered — so a key cannot do
## anything a click could not.
func _unhandled_input(event: InputEvent) -> void:
	if not is_accepting():
		return
	var index := _option_for(event)
	if index < 0 or index >= _buttons.size() or not _buttons[index].visible:
		return
	get_viewport().set_input_as_handled()
	_on_option_pressed(index)


func _option_for(event: InputEvent) -> int:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return -1
	match event.keycode:
		KEY_1, KEY_KP_1: return 0
		KEY_2, KEY_KP_2: return 1
		KEY_3, KEY_KP_3: return 2
		KEY_4, KEY_KP_4: return 3
	return -1


func _on_option_pressed(index: int) -> void:
	if _locked:
		return
	lock()
	var is_correct := index == current_question.correct_option_index
	answer_selected.emit(index, is_correct)
