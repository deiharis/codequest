extends Node2D
## Runs one battle. Built from a BattleRequest and nothing else — no enemy is
## ever named in this file.
##
## The whole point of this script is ORDERING. A question must not appear until
## the attack and damage it caused have finished playing. Three things enforce
## that, and all three are deliberate:
##
##   1. A state gate   — answers are only accepted in State.QUESTION
##   2. A UI lock      — the panel disables itself the instant a button is hit
##   3. One await chain — _resolve_answer() does not return until the last
##                        animation has played, and nothing after it runs early

enum State { INTRO, QUESTION, RESOLVING, ENDING, FINISHED }
enum Outcome { VICTORY, HERO_DEFEATED, TIMER_EXPIRED }

signal battle_finished(outcome: Outcome, request: BattleRequest)

@export_group("Layout")
## Where each fighter stands. Tuned here rather than in the scene so both
## battle modes can share one Battle.tscn.
@export var hero_pos_general: Vector2 = Vector2(260, 430)
@export var enemy_pos_general: Vector2 = Vector2(880, 230)
@export var hero_pos_boss: Vector2 = Vector2(576, 500)
@export var enemy_pos_boss: Vector2 = Vector2(576, 200)
## Multiplied by each character's display_scale. Art frames are ~443px tall, so
## this is what brings them down to a sensible size on a 1152x648 canvas.
@export var base_scale: float = 0.55

@export_group("Pacing")
@export var feedback_hold: float = 0.45
@export var impact_pause: float = 0.08
@export var hp_bar_time: float = 0.3

var request: BattleRequest
var state: State = State.INTRO

var hero: Combatant
var enemy: Combatant

var _pool: Array[QuestionData] = []
var _used: Array[QuestionData] = []
var _outcome: Outcome = Outcome.VICTORY

@onready var _panel: Control = $QuestionPanel
@onready var _hero_fill: ColorRect = $HeroHPBarBg/HeroHPBarFill
@onready var _enemy_fill: ColorRect = $EnemyHPBarBg/EnemyHPBarFill

const HP_BAR_WIDTH := 200.0


func _ready() -> void:
	# Running Battle.tscn on its own (F6) still gives a playable fight.
	if request == null:
		request = BattleRequest.debug_default()
	_build_combatants()
	_panel.answer_selected.connect(_on_answer_selected)
	await _start()


## Called by whoever routes into this scene, before it enters the tree.
func setup(r: BattleRequest) -> void:
	request = r


# --------------------------------------------------------------------------
# Setup
# --------------------------------------------------------------------------

func _build_combatants() -> void:
	var boss := request.mode == BattleRequest.Mode.BUG_LORD

	# The scene's placeholder Hero rect and Enemy sprite are replaced by real
	# Combatants. Doing it here keeps Battle.tscn free of per-mode layout.
	for placeholder_name in ["Hero", "Enemy"]:
		var n := get_node_or_null(placeholder_name)
		if n:
			n.queue_free()

	hero = Combatant.new()
	hero.name = "HeroCombatant"
	hero.position = hero_pos_boss if boss else hero_pos_general
	hero.lunge_offset = Vector2(0, -110) if boss else Vector2(150, -95)
	add_child(hero)

	var hd := request.hero
	var hero_frames := {
		&"idle": hd.boss_idle_frames if boss else hd.idle_frames,
		&"attack": hd.boss_attack_frames if boss else hd.attack_frames,
		&"damage": hd.boss_damage_frames if boss else hd.damage_frames,
		&"defeat": hd.boss_defeat_frames if boss else hd.defeat_frames,
		&"ultimate": hd.ultimate_frames,
	}
	var start_hp := request.hero_start_hp if request.hero_start_hp > 0 else hd.max_hp
	hero.configure(hero_frames, start_hp, base_scale * hd.display_scale,
			hd.ground_offset, hd.attack_scale)
	hero.hp_changed.connect(_on_hero_hp_changed)

	enemy = Combatant.new()
	enemy.name = "EnemyCombatant"
	enemy.position = enemy_pos_boss if boss else enemy_pos_general
	enemy.lunge_offset = Vector2(0, 110) if boss else Vector2(-150, 95)
	add_child(enemy)

	var ed := request.enemy
	enemy.configure({
		&"idle": ed.idle_frames,
		&"attack": ed.attack_frames,
		&"damage": ed.damage_frames,
		&"defeat": ed.defeat_frames,
	}, ed.max_hp, base_scale * ed.display_scale, ed.ground_offset, ed.attack_scale)
	enemy.hp_changed.connect(_on_enemy_hp_changed)

	_pool = request.questions.duplicate()
	_pool.shuffle()


# --------------------------------------------------------------------------
# Flow
# --------------------------------------------------------------------------

func _start() -> void:
	state = State.INTRO
	_panel.hide_panel()
	await get_tree().create_timer(0.4).timeout
	state = State.QUESTION
	_next_question()


func _next_question() -> void:
	var q := _take_question()
	if q == null:
		push_warning("BattleController: no questions available")
		return
	_panel.show_question(q)


## Never run out mid-fight: battle length is governed by HP, not by content.
func _take_question() -> QuestionData:
	if _pool.is_empty():
		if _used.is_empty():
			return null
		_pool = _used.duplicate()
		_pool.shuffle()
		_used.clear()
	var q: QuestionData = _pool.pop_back()
	_used.append(q)
	return q


func _on_answer_selected(index: int, is_correct: bool) -> void:
	if state != State.QUESTION:        # guard 1 — the state gate
		return
	state = State.RESOLVING

	await _resolve_answer(index, is_correct)   # guard 3 — one awaited chain

	# The timer (Bug Lord mode) can fire while we were awaiting above.
	if state == State.ENDING or state == State.FINISHED:
		return

	if _check_end_conditions():
		await _finish()
		return

	state = State.QUESTION
	_next_question()


## Reads in the same order as the design: answer, feedback, attack, damage,
## HP, return. Each step returns only when its animation is done.
func _resolve_answer(index: int, is_correct: bool) -> void:
	await _panel.show_feedback(index, is_correct, feedback_hold)
	_panel.hide_panel()

	if is_correct:
		await _exchange_blow(hero, enemy, request.hero.attack_damage)
	else:
		await _exchange_blow(enemy, hero, request.enemy.attack_damage)


func _exchange_blow(attacker: Combatant, defender: Combatant, amount: int) -> void:
	await attacker.play_attack()
	await get_tree().create_timer(impact_pause).timeout
	defender.apply_damage(amount)
	await defender.play_damage()
	await attacker.return_home()


func _check_end_conditions() -> bool:
	return enemy.current_hp == 0 or hero.current_hp == 0


func _finish() -> void:
	state = State.ENDING
	_panel.hide_panel()

	if enemy.current_hp == 0:
		_outcome = Outcome.VICTORY
		await enemy.play_defeat()
	else:
		_outcome = Outcome.HERO_DEFEATED
		await hero.play_defeat()

	state = State.FINISHED
	battle_finished.emit(_outcome, request)
	print("Battle finished: ", Outcome.keys()[_outcome])


# --------------------------------------------------------------------------
# HP bars
# --------------------------------------------------------------------------

func _on_hero_hp_changed(current: int, maximum: int) -> void:
	_tween_bar(_hero_fill, current, maximum)


func _on_enemy_hp_changed(current: int, maximum: int) -> void:
	_tween_bar(_enemy_fill, current, maximum)


func _tween_bar(bar: ColorRect, current: int, maximum: int) -> void:
	if bar == null:
		return
	var target := HP_BAR_WIDTH * (float(current) / float(maxi(1, maximum)))
	var t := create_tween()
	t.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	t.tween_property(bar, "size:x", target, hp_bar_time)
