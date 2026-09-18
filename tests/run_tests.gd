extends Node
## CodeQuest automated checks — T1 to T5 from docs/TEST_STRATEGY.md
##
## Run from the project folder:
##
##     godot --headless res://tests/TestRunner.tscn
##
## Run as a SCENE, not with --script. Autoloads are only created when a main
## scene runs, and BattleController references GameState at compile time — so
## under --script that script fails to compile and T4 silently checks nothing.
## A test that skips itself is worse than one that fails.
##
## Exits 0 if everything passes, 1 if anything fails, so it can gate a commit
## or a build later without changes.
##
## Deliberately no test framework. These five checks cover pure data and pure
## logic; a framework would be more machinery than that justifies.
##
## Scripts are reached with load() rather than by class name, because global
## class names are not guaranteed to be registered in a --script run.

const SAVE_PATH := "user://savegame.json"

var _checks := 0
var _failures: Array[String] = []


func _ready() -> void:
	print("\nCodeQuest checks\n" + "=".repeat(60))

	# T2 and T3 exercise the real GameState, which writes to the real save
	# file. Back it up first: a test suite that destroys the player's progress
	# is worse than no test suite.
	var backup := _read_save()

	_t1_question_bank()
	_t2_progression()
	_t3_save_round_trip()
	_t4_exam_threshold()
	_t5_world_database()

	_restore_save(backup)
	_report()
	get_tree().quit(1 if not _failures.is_empty() else 0)


# --------------------------------------------------------------------------
# T1 — Question bank integrity
# --------------------------------------------------------------------------

func _t1_question_bank() -> void:
	_section("T1  Question bank integrity")

	var f := FileAccess.open("res://data/questions.csv", FileAccess.READ)
	if f == null:
		_fail("questions.csv could not be opened")
		return

	var seen_text := {}
	var per_enemy := {}
	var row_no := 0
	var first := true

	while not f.eof_reached():
		var row := f.get_csv_line()
		row_no += 1
		if first:
			first = false
			continue
		if row.size() < 7 or row[0].is_empty():
			continue

		var where := "row %d (%s)" % [row_no, row[1].substr(0, 40)]

		_check(row.size() >= 7, "%s has at least 7 columns" % where)
		for i in range(2, 6):
			_check(not row[i].strip_edges().is_empty(), "%s option %d is not blank" % [where, i - 1])
		_check("ABCD".find(row[6].strip_edges().to_upper()) >= 0,
				"%s answer key is A-D, got '%s'" % [where, row[6]])
		_check(row.size() > 7 and not row[7].strip_edges().is_empty(),
				"%s has an explanation" % where)

		var key := row[1].strip_edges().to_lower()
		_check(not seen_text.has(key), "%s is not a duplicate of row %s" % [where, str(seen_text.get(key, "?"))])
		seen_text[key] = row_no

		per_enemy[row[0]] = int(per_enemy.get(row[0], 0)) + 1

	f.close()
	print("     %d questions across %d pools" % [seen_text.size(), per_enemy.size()])

	# Every pool a world will ask for must exist and be big enough to run an
	# encounter without repeating.
	var db = _world_database()
	if db == null:
		return
	var bank: GDScript = load("res://scripts/data/question_bank.gd")
	for w in db.in_order():
		if w.general != null and w.general.enemy_type != "bug_lord":
			var pool: Array = bank.for_enemy(w.general.enemy_id)
			_check(not pool.is_empty(), "%s has General questions" % w.world_id)
		var boss_key: String = "bug_lord_" + w.world_id
		var boss_pool: Array = bank.for_enemy(boss_key)
		_check(boss_pool.size() >= 10,
				"%s has at least 10 Bug Lord questions (has %d)" % [boss_key, boss_pool.size()])


# --------------------------------------------------------------------------
# T2 — Progression arithmetic
# --------------------------------------------------------------------------

func _t2_progression() -> void:
	_section("T2  Progression arithmetic")

	var gs = _fresh_game_state()
	if gs == null:
		return

	var ids := ["reqoria", "architara", "codexis", "testara",
			"gitforge", "deployon", "legacyon", "bugfall"]

	_check(gs.bug_lord_hp == gs.BUG_LORD_MAX_HP, "starts at %d HP" % gs.BUG_LORD_MAX_HP)
	_check(gs.is_world_unlocked(0), "world 0 unlocked on a fresh save")
	_check(not gs.is_world_unlocked(1), "world 1 locked on a fresh save")

	for i in ids.size():
		var changed: bool = gs.clear_world(ids[i])
		_check(changed, "clearing %s changed state" % ids[i])
		_check(gs.is_world_unlocked(i + 1) or i == ids.size() - 1,
				"world %d unlocked after %d clears" % [i + 1, i + 1])

	_check(gs.bug_lord_hp == 0, "8 clears take him to 0, got %d" % gs.bug_lord_hp)
	_check(gs.is_campaign_won(), "campaign reads as won")

	# The anti-farming guard: replaying a cleared world must cost him nothing.
	var before: int = gs.bug_lord_hp
	var again: bool = gs.clear_world("reqoria")
	_check(not again, "re-clearing reqoria reports no change")
	_check(gs.bug_lord_hp == before, "re-clearing reqoria does no damage")
	_check(gs.defeated_generals.size() == 8, "still exactly 8 cleared worlds")

	gs.free()


# --------------------------------------------------------------------------
# T3 — Save round-trip
# --------------------------------------------------------------------------

func _t3_save_round_trip() -> void:
	_section("T3  Save round-trip")

	var gs = _fresh_game_state()
	if gs == null:
		return
	gs.clear_world("reqoria")
	gs.clear_world("architara")
	var expect_hp: int = gs.bug_lord_hp
	gs.save_game()
	gs.free()

	var gs2 = _fresh_game_state()
	var ok: bool = gs2.load_game()
	_check(ok, "a saved file loads")
	_check(gs2.defeated_generals.size() == 2, "2 cleared worlds survive the round-trip")
	_check(gs2.defeated_generals.has("reqoria") and gs2.defeated_generals.has("architara"),
			"the right world ids survive")
	_check(gs2.bug_lord_hp == expect_hp, "HP survives exactly (%d)" % expect_hp)
	gs2.free()

	# A corrupt save must be refused outright, not half-applied: a partly
	# loaded save is worse than none, because nothing reports it.
	_write_raw("this is not json at all {{{")
	var gs3 = _fresh_game_state()
	_check(not gs3.load_game(), "invalid JSON is refused")
	_check(gs3.defeated_generals.is_empty(), "nothing was half-applied")
	_check(gs3.bug_lord_hp == gs3.BUG_LORD_MAX_HP, "HP left at full after a refused load")
	gs3.free()

	_write_raw('{"version": 999, "defeated_generals": ["reqoria"], "bug_lord_hp": 1}')
	var gs4 = _fresh_game_state()
	_check(not gs4.load_game(), "a future save version is refused")
	_check(gs4.defeated_generals.is_empty(), "a refused version applies nothing")
	gs4.free()


# --------------------------------------------------------------------------
# T4 — Exam threshold
# --------------------------------------------------------------------------

func _t4_exam_threshold() -> void:
	_section("T4  Bug Lord exam threshold")

	var script: GDScript = load("res://scripts/battle/BattleController.gd")
	if script == null:
		_fail("BattleController.gd failed to load — T4 checked nothing")
		return
	var bc = script.new()
	if bc == null or not ("boss_questions" in bc):
		_fail("BattleController has no boss_questions — T4 checked nothing")
		if bc:
			bc.free()
		return

	var questions: int = bc.boss_questions
	var needed: int = ceili(questions * bc.boss_pass_ratio)
	var allowed_wrong: int = questions - needed

	_check(questions == 10, "encounter is 10 questions, got %d" % questions)
	_check(is_equal_approx(bc.boss_pass_ratio, 0.7), "pass mark is 70%")
	_check(needed == 7, "7 correct needed, got %d" % needed)
	_check(allowed_wrong == 3, "3 wrong answers allowed, got %d" % allowed_wrong)
	bc.free()

	# ADR-025 claims the two ways to fail land on the same question by
	# construction. That is only true while these numbers agree, so check it
	# rather than trusting the comment.
	var hero: Resource = load("res://resources/hero/hero.tres")
	var boss: Resource = load("res://resources/enemies/bug_lord/bug_lord.tres")
	if hero == null or boss == null:
		_fail("hero.tres or bug_lord.tres could not be loaded")
		return

	var hits_to_kill := ceili(float(hero.max_hp) / float(boss.attack_damage))
	_check(hits_to_kill == allowed_wrong + 1,
			"the %dth wrong answer both fails the exam and empties the hero (kill takes %d)"
					% [allowed_wrong + 1, hits_to_kill])


# --------------------------------------------------------------------------
# T5 — World database integrity
# --------------------------------------------------------------------------

func _t5_world_database() -> void:
	_section("T5  World database integrity")

	var db = _world_database()
	if db == null:
		return

	var worlds: Array = db.in_order()
	_check(worlds.size() == 8, "8 worlds, got %d" % worlds.size())

	var seen := {}
	for i in worlds.size():
		var w = worlds[i]
		_check(w.order_index == i, "%s has order_index %d, expected %d" % [w.world_id, w.order_index, i])
		_check(not seen.has(w.order_index), "order_index %d is not duplicated" % w.order_index)
		seen[w.order_index] = true

		_check(not w.world_id.is_empty(), "world %d has an id" % i)
		# Defect #7: a SpriteFrames once loaded as a WorldData through a
		# directory scan. This is the check that makes that impossible to miss.
		_check(w.general != null, "%s has a General assigned" % w.world_id)
		if w.general != null:
			_check(not w.general.enemy_id.is_empty(), "%s's enemy has an id" % w.world_id)
			_check(w.general.idle_frames != null, "%s's enemy has idle frames" % w.world_id)
			_check(w.general.attack_frames != null, "%s's enemy has attack frames" % w.world_id)
		_check(w.planet_frames != null, "%s has planet frames" % w.world_id)
		_check(db.by_id(w.world_id) == w, "%s is findable by id" % w.world_id)

	var bugfall = db.by_id("bugfall")
	if bugfall != null and bugfall.general != null:
		_check(bugfall.general.enemy_type == "bug_lord", "bugfall's holder is the Bug Lord (ADR-002)")


# --------------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------------

func _world_database():
	var db = load("res://resources/worlds/world_database.tres")
	if db == null:
		_fail("world_database.tres could not be loaded")
	return db


func _fresh_game_state():
	var gs = load("res://scripts/autoload/GameState.gd").new()
	if gs == null:
		_fail("GameState.gd could not be instantiated")
	return gs


func _read_save() -> PackedByteArray:
	if not FileAccess.file_exists(SAVE_PATH):
		return PackedByteArray()
	return FileAccess.get_file_as_bytes(SAVE_PATH)


func _restore_save(bytes: PackedByteArray) -> void:
	if bytes.is_empty():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_buffer(bytes)
		f.close()


func _write_raw(text: String) -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(text)
		f.close()


func _section(title: String) -> void:
	print("\n" + title + "\n" + "-".repeat(60))


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(label)
	print("  FAIL  " + label)


func _fail(label: String) -> void:
	_checks += 1
	_failures.append(label)
	print("  FAIL  " + label)


func _report() -> void:
	print("\n" + "=".repeat(60))
	if _failures.is_empty():
		print("PASSED  %d checks, no failures" % _checks)
	else:
		print("FAILED  %d of %d checks" % [_failures.size(), _checks])
		for f in _failures:
			print("   - " + f)
	print("")
