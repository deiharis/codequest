extends Node2D

var enemy_data: EnemyData
var enemy_current_hp: int
var enemy_max_hp: int

var hero_max_hp: int = 100
var hero_current_hp: int = 100

var question_list: Array[QuestionData] = []
var current_question_index: int = 0

func _ready():
	var test_enemy = load("res://resources/enemies/placeholder_general.tres")
	var q1 = load("res://resources/questions/test_question_1.tres")
	var q2 = load("res://resources/questions/test_question_2.tres")
	setup(test_enemy, [q1, q2])

func setup(data: EnemyData, questions: Array[QuestionData]):
	enemy_data = data
	enemy_max_hp = data.max_hp
	enemy_current_hp = data.max_hp
	question_list = questions
	current_question_index = 0

	_apply_enemy_visuals()
	_update_enemy_hp_bar()
	_update_hero_hp_bar()

	$QuestionPanel.answer_selected.connect(_on_answer_selected)
	_show_next_question()

func _apply_enemy_visuals():
	if enemy_data.idle_frames:
		$Enemy.sprite_frames = enemy_data.idle_frames
		$Enemy.play("idle")

func _update_enemy_hp_bar():
	var full_width = 200.0
	var ratio = float(enemy_current_hp) / float(enemy_max_hp)
	$EnemyHPBarBg/EnemyHPBarFill.size.x = full_width * ratio

func _update_hero_hp_bar():
	var full_width = 200.0
	var ratio = float(hero_current_hp) / float(hero_max_hp)
	$HeroHPBarBg/HeroHPBarFill.size.x = full_width * ratio

func _show_next_question():
	if current_question_index >= question_list.size():
		print("No more questions — battle would end here (Step 6e)")
		return
	$QuestionPanel.show_question(question_list[current_question_index])

func _on_answer_selected(is_correct: bool):
	current_question_index += 1
	if is_correct:
		print("Correct! Hero attacks. Enemy takes damage.")
		enemy_current_hp = max(0, enemy_current_hp - 25)
		_update_enemy_hp_bar()
	else:
		print("Wrong! Enemy attacks. Hero takes damage.")
		hero_current_hp = max(0, hero_current_hp - 15)
		_update_hero_hp_bar()

	_show_next_question()
