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
## Deliberately low. The Bug Lord is taller than the screen, so something must
## crop — this puts the crop at his feet, behind the question panel, rather
## than through his head.
@export var enemy_pos_boss: Vector2 = Vector2(576, 340)
## Multiplied by each character's display_scale. Art frames are ~443px tall, so
## this is what brings them down to a sensible size on a 1152x648 canvas.
@export var base_scale: float = 0.55

@export_group("Boss HP bars")
## The Bug Lord's bar spans the top of the screen. He is the only enemy that
## gets one this size — the scale of the bar is part of the scale of the fight.
@export var boss_bar_rect: Rect2 = Rect2(76, 22, 1000, 34)
## The hero's bar sits along the bottom, under the question panel.
@export var hero_bar_rect_boss: Rect2 = Rect2(376, 614, 400, 22)

@export_group("Timer")
## Where the countdown sits. Directly under the boss's HP bar.
@export var timer_rect: Rect2 = Rect2(476, 62, 200, 40)
## Below this many seconds the countdown turns red.
@export var timer_warning_at: float = 10.0

@export_group("Boss entrance")
## How long the Bug Lord takes to rise into frame and the world to change.
@export var boss_arrival_time: float = 1.6

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

var _time_left: float = 0.0
var _timer_label: Label

@onready var _panel: Control = $QuestionPanel
@onready var _background: ColorRect = $Background
@onready var _hero_fill: ColorRect = $HeroHPBarBg/HeroHPBarFill
@onready var _enemy_fill: ColorRect = $EnemyHPBarBg/EnemyHPBarFill


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
	# The Bug Lord already fills the screen — lunging him forward reads as the
	# camera jolting, not as a strike. He attacks from where he stands.
	enemy.lunge_offset = Vector2.ZERO if boss else Vector2(-150, 95)
	add_child(enemy)

	# CanvasItems draw in tree order, so a late add_child would paint the boss
	# over the HP bars and the question panel. Park both fighters directly
	# above Background instead.
	var base := _background.get_index() + 1
	move_child(enemy, base)          # titan behind...
	move_child(hero, base + 1)       # ...hero in front of him

	var ed := request.enemy
	enemy.configure({
		&"idle": ed.idle_frames,
		&"attack": ed.attack_frames,
		&"damage": ed.damage_frames,
		&"defeat": ed.defeat_frames,
	}, ed.max_hp, base_scale * ed.display_scale, ed.ground_offset, ed.attack_scale)
	enemy.hp_changed.connect(_on_enemy_hp_changed)

	if boss:
		_layout_boss_bars()
		_build_timer()

	_pool = request.questions.duplicate()
	_pool.shuffle()


## General bars are positioned in Battle.tscn. The boss fight overrides them:
## a long bar across the top for him, a slim one along the bottom for the hero.
func _layout_boss_bars() -> void:
	_place_bar($EnemyHPBarBg, _enemy_fill, boss_bar_rect, Color(0.78, 0.13, 0.20))
	_place_bar($HeroHPBarBg, _hero_fill, hero_bar_rect_boss, Color(0.18, 0.8, 0.44))
	# Drawn last so they stay readable over the boss and the question panel.
	move_child($EnemyHPBarBg, get_child_count() - 1)
	move_child($HeroHPBarBg, get_child_count() - 1)


## The countdown only exists in fights whose enemy asks for one, so a General
## fight carries no timer node at all and _process does nothing.
func _build_timer() -> void:
	if not request.enemy.has_timer:
		return
	_time_left = request.enemy.timer_seconds
	_timer_label = Label.new()
	_timer_label.name = "TimerLabel"
	_timer_label.position = timer_rect.position
	_timer_label.size = timer_rect.size
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_label.add_theme_font_size_override(&"font_size", 30)
	add_child(_timer_label)
	_update_timer_label()


func _process(delta: float) -> void:
	# Time only runs while the fight is live: not during the arrival, not while
	# a defeat animation is playing, not after the battle has ended.
	if _timer_label == null:
		return
	if state != State.QUESTION and state != State.RESOLVING:
		return
	_time_left = maxf(0.0, _time_left - delta)
	_update_timer_label()
	if _time_left == 0.0:
		_on_timer_expired()


func _update_timer_label() -> void:
	_timer_label.text = "%d" % ceili(_time_left)
	_timer_label.modulate = Color(1, 0.25, 0.25) if _time_left <= timer_warning_at else Color.WHITE


## Running out is a loss, but not a death — the hero is thrown out of the
## encounter, he is not defeated. ADR-003: the Bug Lord keeps the damage he
## has already taken, so failing here is a setback, not a reset.
func _on_timer_expired() -> void:
	if state == State.ENDING or state == State.FINISHED:
		return
	state = State.ENDING
	_outcome = Outcome.TIMER_EXPIRED
	_panel.hide_panel()
	state = State.FINISHED
	battle_finished.emit(_outcome, request)
	print("Battle finished: TIMER_EXPIRED")


func _place_bar(bg: ColorRect, fill: ColorRect, r: Rect2, fill_color: Color) -> void:
	bg.position = r.position
	bg.size = r.size
	bg.color = Color(0.06, 0.06, 0.09, 0.85)
	fill.position = Vector2.ZERO
	fill.size = r.size
	fill.color = fill_color


# --------------------------------------------------------------------------
# Flow
# --------------------------------------------------------------------------

func _start() -> void:
	state = State.INTRO
	_panel.hide_panel()
	if request.mode == BattleRequest.Mode.BUG_LORD:
		await _boss_arrival()
	else:
		await get_tree().create_timer(0.4).timeout
	state = State.QUESTION
	_next_question()


## The Bug Lord rises into frame from below while the world changes colour
## around him — the only moment in the game where the background is not a
## constant.
func _boss_arrival() -> void:
	var target: Color = request.enemy.background_color
	var home := enemy.position
	enemy.position = home + Vector2(0, 420)
	enemy.modulate.a = 0.0

	var t := create_tween().set_parallel()
	t.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(enemy, "position", home, boss_arrival_time)
	t.tween_property(enemy, "modulate:a", 1.0, boss_arrival_time * 0.6)
	if _background and target.a > 0.0:
		t.tween_property(_background, "color", target, boss_arrival_time)
	await t.finished
	await get_tree().create_timer(0.3).timeout


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
	# Width comes from the bar's own background, so the same code drives both
	# the small General bars and the boss bar without knowing which is which.
	var full: float = (bar.get_parent() as Control).size.x
	var target := full * (float(current) / float(maxi(1, maximum)))
	var t := create_tween()
	t.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	t.tween_property(bar, "size:x", target, hp_bar_time)
