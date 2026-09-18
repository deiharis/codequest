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
	$Panel/Layout/ExplanationLabel.visible = false

	for i in _buttons.size():
		var b := _buttons[i]
		b.modulate = Color.WHITE
		if i < question.options.size():
			b.visible = true
			b.text = question.options[i]
		else:
			b.visible = false

	lock()
	visible = true
	_box.position.y = _away_y

	var t := create_tween().set_parallel()
	t.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(_box, "position:y", _home_y, SLIDE_IN_TIME)
	# The dim leads slightly: the room darkens, then the scroll arrives in it.
	t.tween_property(_dim, "modulate:a", DIM_ALPHA, SLIDE_IN_TIME * 0.8)
	await t.finished

	unlock()


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


## Colour the chosen button, and reveal the right one if it was wrong.
## Awaitable so the battle can pause on it.
func show_feedback(index: int, is_correct: bool, hold: float = 0.45) -> void:
	if index >= 0 and index < _buttons.size():
		_buttons[index].modulate = COLOUR_CORRECT if is_correct else COLOUR_WRONG
	if not is_correct:
		var right := current_question.correct_option_index
		if right >= 0 and right < _buttons.size():
			_buttons[right].modulate = COLOUR_CORRECT

	var label: Label = $Panel/Layout/ExplanationLabel
	if current_question.explanation.is_empty():
		await get_tree().create_timer(hold).timeout
		return
	label.text = current_question.explanation
	label.modulate = COLOUR_CORRECT if is_correct else COLOUR_WRONG
	label.visible = true
	await get_tree().create_timer(hold + EXPLANATION_HOLD).timeout


## Slide the panel out and return only once it has gone, so the battle can
## await it and start the attack on a clear stage.
func hide_panel() -> void:
	if not visible:
		return
	lock()
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


func _on_option_pressed(index: int) -> void:
	if _locked:
		return
	lock()
	var is_correct := index == current_question.correct_option_index
	answer_selected.emit(index, is_correct)
