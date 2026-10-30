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
enum Outcome { VICTORY, HERO_DEFEATED }

signal battle_finished(outcome: Outcome, request: BattleRequest)

@export_group("Layout")
## Where each fighter stands. Tuned here rather than in the scene so both
## battle modes can share one Battle.tscn.
@export var hero_pos_general: Vector2 = Vector2(260, 430)
## X only. The Y is derived from the sprite's height so that the TOP of every
## General lands at enemy_top_general — display_scale runs from 1.05 to 1.75
## across the roster, so any fixed centre would put the big ones behind the
## nameplate and leave the small ones floating.
@export var enemy_pos_general: Vector2 = Vector2(884, 262)
@export var enemy_top_general: float = 126.0
@export var hero_pos_boss: Vector2 = Vector2(576, 500)
## Deliberately low. The Bug Lord is taller than the screen, so something must
## crop — this puts the crop at his feet, behind the question panel, rather
## than through his head.
@export var enemy_pos_boss: Vector2 = Vector2(576, 396)
## Multiplied by each character's display_scale. Art frames are ~443px tall, so
## this is what brings them down to a sensible size on a 1152x648 canvas.
@export var base_scale: float = 0.55

@export_group("Boss HP bars")
## The Bug Lord's bar spans the top of the screen. He is the only enemy that
## gets one this size — the scale of the bar is part of the scale of the fight.
## Only the vertical position is authored. The horizontal is computed from the
## viewport every time, so the boss frame cannot drift off centre when the bar
## width changes — which is exactly how it drifted before.
@export var boss_plate_y: float = 0.0
@export var boss_plate_width: float = 1040.0
## The hero's bar sits along the bottom, under the question panel.
@export var hero_plate_pos_boss: Vector2 = Vector2(28, 520)
@export var hero_plate_pos: Vector2 = Vector2(28, 470)
@export var enemy_plate_pos: Vector2 = Vector2(818, 12)
@export var plate_width: float = 318.0

@export_group("Bug Lord encounter")
## The encounter is a fixed-length exam, not an HP fight. Ten questions with a
## 70% pass mark means 7 correct wins and the 4th wrong answer loses — which is
## also the hit that empties a 100 HP hero against a 25-damage boss, so the two
## ways to fail land on the same question by construction.
@export var boss_questions: int = 10
@export var boss_pass_ratio: float = 0.7

@export_group("Timer")
## The countdown and the score share one washed panel in the top-right corner,
## clear of the boss crest and clear of the fight.
@export var info_rect: Rect2 = Rect2(1014, 562, 126, 76)
## Below this many seconds the countdown turns red.
@export var timer_warning_at: float = 5.0

@export_group("Boss entrance")
## How long the Bug Lord takes to rise into frame and the world to change.
@export var boss_arrival_time: float = 1.6

@export_group("Impact")
## Shake in pixels. The hero being hit shakes harder than the enemy being hit —
## the screen is the player's point of view, so it should flinch when they do.
@export var shake_on_enemy_hit: float = 5.0
@export var shake_on_hero_hit: float = 11.0
@export var shake_on_ultimate: float = 20.0
## The Ultimate's flurry. 24 cuts at 0.11s apart is about 2.5 seconds of blade,
## which is what the sequence is supposed to feel like — not a single hit.
@export var ultimate_slashes: int = 24
@export var ultimate_slash_gap: float = 0.11
@export var ultimate_slash_spread: float = 150.0

@export_group("Pacing")
@export var feedback_hold: float = 0.45
@export var impact_pause: float = 0.08
@export var hp_bar_time: float = 0.3
## Kept for the sandbox path, where no banner plays.
@export var result_hold: float = 1.2

var request: BattleRequest
var state: State = State.INTRO

var hero: Combatant
var enemy: Combatant

var _pool: Array[QuestionData] = []
var _used: Array[QuestionData] = []
var _outcome: Outcome = Outcome.VICTORY

var _correct: int = 0
var _wrong: int = 0
var _progress_label: Label

var _time_left: float = 0.0
var _timer_label: Label
var _info_panel: PanelContainer

## The info panel uses the question scroll's plate, so text on it reads the
## same way: light on dark, with the countdown turning red near the end.
const INK := Color(0.89, 0.92, 0.96)
const INK_DIM := Color(0.61, 0.65, 0.75)
const INK_WARN := Color(1.0, 0.33, 0.33)

@onready var _panel: Control = $QuestionPanel
@onready var _background: ColorRect = $Background

var _arena: TextureRect
var _storm: LightningStrike
var _feedback: HitFeedback

## What the arena is tinted to before the Bug Lord arrives: drained and cold.
## It tweens to white as he rises, so the world visibly turns his colour.
const ARENA_BEFORE_BOSS := Color(0.30, 0.34, 0.48)
var _hero_plate: Nameplate
var _enemy_plate: Nameplate


func _ready() -> void:
	# Running Battle.tscn on its own (F6) still gives a playable fight.
	if request == null:
		request = BattleRequest.debug_default()
	_build_arena()
	# The Bug Lord gets his own, and it is slower than the General's rather
	# than faster — weight comes from things taking longer.
	AudioManager.play_music(&"bug_lord" if _is_boss() else &"battle")
	_build_storm()
	_build_feedback()
	_build_combatants()
	_order_layers()
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
	enemy.position = enemy_pos_boss if boss else _general_anchor(request.enemy)
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
	if not boss:
		enemy.hp_changed.connect(_on_enemy_hp_changed)

	_build_plates(boss)
	if boss:
		_build_timer()

	_pool = request.questions.duplicate()
	_pool.shuffle()


## Place a General by its top edge rather than its centre. Sprite height is
## known: every sheet is normalised to one reference height, then scaled.
func _general_anchor(ed: EnemyData) -> Vector2:
	var h := Combatant.REFERENCE_FRAME_HEIGHT * base_scale * ed.display_scale
	return Vector2(enemy_pos_general.x, enemy_top_general + h * 0.5)


## Godot draws siblings in tree order, and this scene builds most of its nodes
## at runtime — so the order they happen to be created in is not the order they
## should be drawn in. Set it once, explicitly, from back to front:
##
##   arena · fighters · storm · plates · question scroll · countdown
##
## The scroll must be above the plates (it is the thing being read) and the
## countdown above the scroll (it must stay legible through the dim).
func _order_layers() -> void:
	for node in [_feedback, _hero_plate, _enemy_plate, _panel, _info_panel]:
		if node and node.get_parent() == self:
			move_child(node, get_child_count() - 1)


## Both fighters get a named plate. The flat rectangles that used to live in
## Battle.tscn are freed: the plate is built per fight because what it says
## changes per fight, and one scene still serves all nine.
func _build_plates(boss: bool) -> void:
	for old in ["HeroHPBarBg", "EnemyHPBarBg"]:
		var n := get_node_or_null(old)
		if n:
			n.queue_free()

	_hero_plate = Nameplate.new()
	_hero_plate.name = "HeroPlate"
	_hero_plate.position = hero_plate_pos_boss if boss else hero_plate_pos
	add_child(_hero_plate)
	_hero_plate.setup(request.hero.display_name, plate_width)
	_hero_plate.set_hp(hero.current_hp, hero.max_hp, 0.0)

	_enemy_plate = Nameplate.new()
	_enemy_plate.name = "EnemyPlate"
	_enemy_plate.position = Vector2(
			(get_viewport_rect().size.x - boss_plate_width) * 0.5,
			boss_plate_y) if boss else enemy_plate_pos
	add_child(_enemy_plate)
	if boss:
		_enemy_plate.setup_boss(request.enemy.display_name, boss_plate_width)
	else:
		_enemy_plate.setup(request.enemy.display_name, plate_width)

	if boss:
		# His bar is the campaign's progress bar, not this encounter's. Normal
		# attacks do him no damage, so a bar tracking the encounter would never
		# move — and the Ultimate's whole point is that this one does.
		_enemy_plate.set_hp(GameState.bug_lord_hp, GameState.BUG_LORD_MAX_HP, 0.0)
	else:
		_enemy_plate.set_hp(enemy.current_hp, enemy.max_hp, 0.0)




## The countdown only exists in fights whose enemy asks for one, so a General
## fight carries no timer node at all and _process does nothing.
func _build_timer() -> void:
	if not request.enemy.has_timer:
		return

	# Both readouts live on one washed panel. Dark ink on a pale wash, which is
	# the opposite of everything else on screen — so the eye finds it without
	# it having to shout.
	_info_panel = PanelContainer.new()
	_info_panel.name = "InfoPanel"
	_info_panel.theme_type_variation = &"ScrollHeader"
	_info_panel.position = info_rect.position
	_info_panel.size = info_rect.size
	_info_panel.custom_minimum_size = info_rect.size
	_info_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_info_panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info_panel.add_child(col)

	_timer_label = Label.new()
	_timer_label.name = "TimerLabel"
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_label.add_theme_font_size_override(&"font_size", 26)
	_timer_label.add_theme_color_override(&"font_color", INK)
	col.add_child(_timer_label)

	_progress_label = Label.new()
	_progress_label.name = "ProgressLabel"
	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_progress_label.add_theme_font_size_override(&"font_size", 13)
	_progress_label.add_theme_color_override(&"font_color", INK_DIM)
	col.add_child(_progress_label)
	_update_progress_label()


func _process(delta: float) -> void:
	# Time only runs while the fight is live: not during the arrival, not while
	# a defeat animation is playing, not after the battle has ended.
	# Time runs per question, and only while the question is on screen and
	# taking answers: not during the arrival, not while the panel is sliding,
	# not while the answer is resolving, not after the end.
	if _timer_label == null or state != State.QUESTION or not _panel.is_accepting():
		return
	_time_left = maxf(0.0, _time_left - delta)
	_update_timer_label()
	if _time_left == 0.0:
		_on_timer_expired()


func _update_progress_label() -> void:
	if _progress_label == null:
		return
	_progress_label.text = "%d / %d correct" % [_correct, _needed()]


func _update_timer_label() -> void:
	_timer_label.text = "%d" % ceili(_time_left)
	_timer_label.add_theme_color_override(&"font_color",
			INK_WARN if _time_left <= timer_warning_at else INK)


## Running out counts as a wrong answer: the Bug Lord strikes and the fight
## continues. Hesitation costs health, so the fight still resolves through HP
## rather than ending on one slow question.
func _on_timer_expired() -> void:
	if state != State.QUESTION:
		return
	_panel.lock()
	_on_answer_selected(-1, false)   # -1: no button was pressed


func _is_boss() -> bool:
	return request.mode == BattleRequest.Mode.BUG_LORD


## Correct answers needed to pass. Rounded up, so 70% of 10 is 7, not 6.
func _needed() -> int:
	return ceili(boss_questions * boss_pass_ratio)


## The arena sits above the flat Background rect and below everything else.
## Built here rather than placed in Battle.tscn because it changes per enemy,
## and one scene serves all nine fights.
func _build_arena() -> void:
	var tex: Texture2D = request.enemy.arena_texture
	if tex == null:
		return
	_arena = TextureRect.new()
	_arena.name = "Arena"
	# Expand first — until then a TextureRect's minimum size is the texture's.
	_arena.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_arena.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_arena.custom_minimum_size = Vector2.ZERO
	_arena.texture = tex
	_arena.position = Vector2.ZERO
	_arena.size = get_viewport_rect().size
	_arena.z_index = -9
	_arena.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if request.mode == BattleRequest.Mode.BUG_LORD:
		_arena.modulate = ARENA_BEFORE_BOSS
	add_child(_arena)


## Damage numbers and shake. It shakes this node, so everything in the battle
## moves together — including the HP plates and the countdown, since they are
## children too. At 5 to 11 pixels that reads as impact rather than as a fault.
## Exempting the UI would mean moving the world into its own child node, which
## is a bigger change than the effect is worth.
func _build_feedback() -> void:
	_feedback = HitFeedback.new()
	_feedback.name = "HitFeedback"
	_feedback.z_index = 2
	add_child(_feedback)
	_feedback.watch(self)


## Lightning belongs to the world, not to the enemy: the Bug Lord is fought in
## eight places and only Bugfall is his own. The flag is read from WorldData.
func _build_storm() -> void:
	if request.world_id.is_empty():
		return
	var world := WorldDatabase.load_default().by_id(request.world_id)
	if world == null or not world.storm_on_attack:
		return
	_storm = LightningStrike.new()
	_storm.name = "Storm"
	_storm.z_index = 3          # over the fighters; the panel is hidden by now
	add_child(_storm)


# --------------------------------------------------------------------------
# Flow
# --------------------------------------------------------------------------

func _start() -> void:
	state = State.INTRO
	_panel.hide_panel()
	if request.mode == BattleRequest.Mode.BUG_LORD:
		await _boss_arrival()
	else:
		await get_tree().create_timer(0.4, false).timeout
	state = State.QUESTION
	_next_question()


## The Bug Lord rises into frame from below while the world changes colour
## around him — the only moment in the game where the background is not a
## constant.
func _boss_arrival() -> void:
	AudioManager.play(&"boss_arrive", 0.0)
	var home := enemy.position
	enemy.position = home + Vector2(0, 420)
	enemy.modulate.a = 0.0

	var t := create_tween().set_parallel()
	t.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(enemy, "position", home, boss_arrival_time)
	t.tween_property(enemy, "modulate:a", 1.0, boss_arrival_time * 0.6)
	if _arena:
		t.tween_property(_arena, "modulate", Color.WHITE, boss_arrival_time)
	await t.finished
	await get_tree().create_timer(0.3, false).timeout


func _next_question() -> void:
	var q := _take_question()
	if q == null:
		push_warning("BattleController: no questions available")
		return
	_start_question_timer(q)
	await _panel.show_question(q)


## Each question carries its own limit, scaled to how much there is to read.
func _start_question_timer(q: QuestionData) -> void:
	if _timer_label == null:
		return
	_time_left = q.time_limit
	_update_timer_label()


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
	# No jitter on these two: they are musical, and a detuned chime reads as a
	# wrong note rather than as variety.
	AudioManager.play(&"answer_correct" if is_correct else &"answer_wrong", 0.0)
	await _panel.show_feedback(index, is_correct, feedback_hold)
	await _panel.hide_panel()          # the stage is clear before anyone swings

	if is_correct:
		_correct += 1
		# In the boss encounter the hero's normal attack lands for nothing.
		# Only the Ultimate hurts him, and only once the exam is passed.
		var dmg := 0 if _is_boss() else request.hero.attack_damage
		await _exchange_blow(hero, enemy, dmg)
	else:
		_wrong += 1
		await _exchange_blow(enemy, hero, request.enemy.attack_damage)
	_update_progress_label()


func _exchange_blow(attacker: Combatant, defender: Combatant, amount: int) -> void:
	if _storm and attacker == enemy:
		_storm.strike(3)        # not awaited: the sky breaks while he swings
		if _feedback:
			_feedback.screen_flash(Color(0.68, 0.84, 1.0), 0.4, 0.22)
	await attacker.play_attack()
	await get_tree().create_timer(impact_pause, false).timeout

	# On the impact frame, with the damage — not on the wind-up. The sound is
	# what makes the hit land, so it has to agree with the number appearing.
	AudioManager.play(&"sword_hit" if attacker == hero else &"enemy_hit")

	defender.apply_damage(amount)
	defender.recoil(attacker.position)
	if _feedback:
		var hurting_hero := defender == hero
		var at := defender.position + Vector2(0, -70)
		# Not awaited. The arc and the sparks play over the damage animation;
		# awaiting them would stop the fight to watch an effect finish.
		_feedback.slash(at, not hurting_hero)
		_feedback.sparks(at, not hurting_hero)
		_feedback.pop(amount, defender.position + Vector2(0, -90), hurting_hero)
		if amount > 0:
			_feedback.shake(shake_on_hero_hit if hurting_hero else shake_on_enemy_hit)

	await defender.play_damage()
	await attacker.return_home()


func _check_end_conditions() -> bool:
	if hero.current_hp == 0:
		return true
	if _is_boss():
		# End the moment the result is decided — no questions after the verdict.
		return _correct >= _needed() \
				or _wrong > boss_questions - _needed() \
				or _correct + _wrong >= boss_questions
	return enemy.current_hp == 0


func _finish() -> void:
	state = State.ENDING
	await _panel.hide_panel()

	if _is_boss():
		if _correct >= _needed():
			_outcome = Outcome.VICTORY
			await _play_ultimate()
		else:
			_outcome = Outcome.HERO_DEFEATED
			await hero.play_defeat()
	elif enemy.current_hp == 0:
		_outcome = Outcome.VICTORY
		await enemy.play_defeat()
	else:
		_outcome = Outcome.HERO_DEFEATED
		await hero.play_defeat()

	state = State.FINISHED
	battle_finished.emit(_outcome, request)
	print("Battle finished: ", Outcome.keys()[_outcome])

	await _show_result()
	await _leave()


## The beat between the last blow and the fade. A fight that simply stops feels
## like a scene change; a fight that announces its result feels like a fight.
func _show_result() -> void:
	if request.world_id.is_empty():
		return                       # the F6 sandbox stays put and says nothing

	var banner := ResultBanner.new()
	banner.name = "ResultBanner"
	add_child(banner)
	move_child(banner, get_child_count() - 1)

	AudioManager.play(&"victory" if _outcome == Outcome.VICTORY else &"defeat", 0.0)

	if _outcome != Outcome.VICTORY:
		await banner.show_result("DEFEATED", "The %s stands. Try again."
				% request.enemy.display_name, Color(0.88, 0.25, 0.25))
	elif _is_boss():
		var left: int = GameState.bug_lord_hp
		var tail := "He withdraws. %d HP remains." % left if left > 0 else "Nothing remains."
		await banner.show_result("ULTIMATE", tail, Color(0.95, 0.68, 0.22))
	else:
		await banner.show_result("VICTORY", "%s falls. The Bug Lord stirs."
				% request.enemy.display_name, Color(0.83, 0.69, 0.22))


## Decide where a finished battle goes next.
##
## A world is cleared in two fights, not one:
##
##   General beaten  ->  the Bug Lord rises, timed encounter, same world
##   Bug Lord beaten ->  world complete, 1000 off his persistent HP, back to map
##   either one lost ->  back to that world's General to try again
##
## Only the Bug Lord encounter completes a world. Beating the General alone
## does nothing permanent, which is what makes the boss the real gate.
##
## A battle with no world_id is the F6 sandbox: it records nothing and stays
## where it is, so testing a fight can never write to the save file.
func _leave() -> void:
	if request.world_id.is_empty():
		return

	if _outcome != Outcome.VICTORY:
		_goto_general()
		return

	if request.mode == BattleRequest.Mode.GENERAL:
		_goto_bug_lord()
		return

	# clear_world already ran during the Ultimate, where the damage was shown.
	# Both of these leave a fight the player has just won, so they wash out in
	# the Ultimate's own gold rather than in black.
	if GameState.is_campaign_won():
		SceneRouter.goto_scene("res://scenes/victory/Victory.tscn",
				Callable(), SceneRouter.Style.FADE, Color(0.98, 0.88, 0.62))
		return
	SceneRouter.goto_scene("res://scenes/space_map/SpaceMap.tscn",
			Callable(), SceneRouter.Style.FADE, Color(0.86, 0.72, 0.34))


func _goto_bug_lord() -> void:
	var r := BattleRequest.for_bug_lord(request.world_id)
	if r == null:
		push_error("BattleController: cannot start the Bug Lord encounter")
		SceneRouter.goto_scene("res://scenes/space_map/SpaceMap.tscn")
		return
	# The one transition in the game that closes rather than fades: the General
	# is done and the screen narrows onto what is waiting above.
	SceneRouter.goto_scene("res://scenes/battle/Battle.tscn",
			func(scene): scene.setup(r), SceneRouter.Style.IRIS)


## Losing sends the player back to the General, not to the map. The world is
## not finished until both fights are won, and restarting at the General keeps
## the two-stage shape intact.
func _goto_general() -> void:
	var world := WorldDatabase.load_default().by_id(request.world_id)
	# Bugfall has no General, so a failed final encounter returns to the map.
	# Restarting it here would trap the player in the fight they just lost.
	# Defeat washes dark red, both here and on the way back to the map. The
	# player already knows they lost; the colour is the game agreeing with them.
	const LOSS := Color(0.34, 0.06, 0.08)
	if world == null or world.general == null \
			or world.general.enemy_type == "bug_lord":
		SceneRouter.goto_scene("res://scenes/space_map/SpaceMap.tscn",
				Callable(), SceneRouter.Style.FADE, LOSS)
		return
	var r := BattleRequest.for_world(world)
	SceneRouter.goto_scene("res://scenes/battle/Battle.tscn",
			func(scene): scene.setup(r), SceneRouter.Style.FADE, LOSS)


## Passing the exam earns the one blow that actually counts. The Ultimate takes
## 1000 off the Bug Lord's persistent HP — the campaign's real progress — and
## then he withdraws rather than dying. He is beaten eight times, once per
## world, before there is nothing left of him (ADR-003).
func _play_ultimate() -> void:
	if _info_panel:
		_info_panel.hide()
	await hero.play_once(&"ultimate")

	# The `ultimate` sound is a 0.75s charge and then an impact, which is the
	# same shape as the light: the charge runs under the blinding fade, and the
	# boom lands on the frame the light collapses into him.
	AudioManager.play(&"ultimate", 0.0)
	if _feedback:
		# Screen coordinates, not world: the wipe draws on a CanvasLayer, which
		# is what keeps it steady while everything else shakes.
		await _feedback.blinding_collapse(
				hero.get_global_transform_with_canvas().origin)
		# Then two and a half seconds of blade. This is the whole point of the
		# Ultimate being a separate thing from a normal attack.
		await _feedback.slash_flurry(enemy.position, true, ultimate_slashes,
				ultimate_slash_gap, ultimate_slash_spread,
				&"sword_hit", shake_on_ultimate * 0.22)

	var changed := GameState.clear_world(request.world_id)
	if not changed:
		print("Bug Lord encounter passed, but %s was already cleared" % request.world_id)
	if _feedback:
		# The one moment the whole world reacts rather than just the thing hit.
		_feedback.screen_flash(Color(1.0, 0.95, 0.78), 0.9, 0.5)
		_feedback.shake(shake_on_ultimate)
		_feedback.sparks(enemy.position + Vector2(0, 40), true, 64, 2.2)
		_feedback.pop(GameState.BUG_LORD_DAMAGE_PER_WORLD,
				enemy.position + Vector2(0, 40), false)
	_enemy_plate.set_hp(GameState.bug_lord_hp, GameState.BUG_LORD_MAX_HP, 0.6)
	enemy.flash()
	await get_tree().create_timer(0.5, false).timeout

	# The eighth Ultimate is the one he does not walk away from.
	if GameState.is_campaign_won():
		await enemy.play_defeat()
	else:
		await _boss_withdraws()

	# Whatever his exit was, it ends the same way: white and violet out of him,
	# over everything. Awaited, so the result banner lands after the dust.
	if _feedback:
		AudioManager.play(&"burst", 0.0)
		await _feedback.burst_from(enemy.get_global_transform_with_canvas().origin)


## He leaves the way he arrived, and the world takes its colour back.
func _boss_withdraws() -> void:
	var t := create_tween().set_parallel()
	t.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(enemy, "position:y", enemy.position.y + 420, boss_arrival_time)
	t.tween_property(enemy, "modulate:a", 0.0, boss_arrival_time * 0.8)
	if _arena:
		t.tween_property(_arena, "modulate", ARENA_BEFORE_BOSS, boss_arrival_time)
	await t.finished


# --------------------------------------------------------------------------
# Health plates
# --------------------------------------------------------------------------

func _on_hero_hp_changed(current: int, maximum: int) -> void:
	if _hero_plate:
		_hero_plate.set_hp(current, maximum, hp_bar_time)


func _on_enemy_hp_changed(current: int, maximum: int) -> void:
	if _enemy_plate:
		_enemy_plate.set_hp(current, maximum, hp_bar_time)
