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

var current_question: QuestionData
var _buttons: Array[Button] = []
var _locked: bool = false


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


func show_question(question: QuestionData) -> void:
	current_question = question
	$Panel/Layout/QuestionLabel.text = question.question_text
	$Panel/Layout/ExplanationLabel.visible = false

	for i in _buttons.size():
		var b := _buttons[i]
		b.modulate = Color.WHITE
		if i < question.options.size():
			b.visible = true
			b.text = question.options[i]
		else:
			b.visible = false

	unlock()
	visible = true


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


func hide_panel() -> void:
	visible = false


func _on_option_pressed(index: int) -> void:
	if _locked:
		return
	lock()
	var is_correct := index == current_question.correct_option_index
	answer_selected.emit(index, is_correct)
