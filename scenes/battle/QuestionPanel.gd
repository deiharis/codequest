extends Control

signal answer_selected(is_correct: bool)

var current_question: QuestionData
var option_buttons: Array[Button] = []

func _ready():
	option_buttons = [
		$Panel/Layout/OptionButton1,
		$Panel/Layout/OptionButton2,
		$Panel/Layout/OptionButton3,
		$Panel/Layout/OptionButton4
	]
	for i in range(option_buttons.size()):
		option_buttons[i].pressed.connect(_on_option_pressed.bind(i))

func show_question(question: QuestionData):
	current_question = question
	$Panel/Layout/QuestionLabel.text = question.question_text

	for i in range(option_buttons.size()):
		if i < question.options.size():
			option_buttons[i].visible = true
			option_buttons[i].text = question.options[i]
		else:
			option_buttons[i].visible = false

func _on_option_pressed(index: int):
	var is_correct = (index == current_question.correct_option_index)
	answer_selected.emit(is_correct)
