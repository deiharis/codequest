extends RefCounted
class_name QuestionBank
## Loads every question from one CSV and hands out the ones belonging to a
## given enemy.
##
## Content lives in data/questions.csv so it can be edited in a spreadsheet,
## reviewed in a diff, and written by someone who does not open Godot. The file
## is read once per run and cached.
##
## CSV columns, in order:
##   enemy_id, question, option_a, option_b, option_c, option_d, correct,
##   explanation, [seconds]
## `correct` is the letter A-D. `seconds` is optional — left blank, the time
## limit is derived from how much there is to read. Rows starting with # are
## ignored.

const CSV_PATH := "res://data/questions.csv"

## Time limits scale with reading load. Fitted to the actual question set,
## whose question-plus-options length runs 62 to 205 characters: the shortest
## recall questions land on the 15s floor, the longest approach 30s.
## ponytail: character count is a crude proxy for difficulty — add a `seconds`
## column for any question playtesting shows needs a different limit.
const TIME_MIN := 15.0
const TIME_MAX := 30.0
const CHARS_AT_MIN := 100
const CHARS_AT_MAX := 210

static var _by_enemy: Dictionary = {}


## All questions for one enemy, freshly shuffled. Empty if the id is unknown.
static func for_enemy(enemy_id: String) -> Array[QuestionData]:
	if _by_enemy.is_empty():
		_load()
	var list: Array[QuestionData] = _by_enemy.get(enemy_id, [] as Array[QuestionData])
	var out := list.duplicate()
	out.shuffle()
	return out


## Forces a re-read. Useful while editing the CSV with the game running.
static func reload() -> void:
	_by_enemy.clear()
	_load()


static func _load() -> void:
	var f := FileAccess.open(CSV_PATH, FileAccess.READ)
	if f == null:
		push_error("QuestionBank: cannot open %s" % CSV_PATH)
		return

	var first := true
	while not f.eof_reached():
		var row := f.get_csv_line()          # handles quoted commas for us
		if first:
			first = false
			continue                          # header
		if row.size() < 7 or row[0].is_empty() or row[0].begins_with("#"):
			continue

		var q := QuestionData.new()
		q.question_text = row[1]
		q.options = [row[2], row[3], row[4], row[5]] as Array[String]
		q.correct_option_index = _letter_to_index(row[6])
		q.explanation = row[7] if row.size() > 7 else ""
		q.time_limit = _time_for(q)
		if row.size() > 8 and not row[8].strip_edges().is_empty():
			q.time_limit = float(row[8])

		if not _by_enemy.has(row[0]):
			_by_enemy[row[0]] = [] as Array[QuestionData]
		_by_enemy[row[0]].append(q)

	f.close()


## Linear between the two character counts, clamped at both ends.
static func _time_for(q: QuestionData) -> float:
	var chars := q.question_text.length()
	for o in q.options:
		chars += o.length()
	var t := inverse_lerp(float(CHARS_AT_MIN), float(CHARS_AT_MAX), float(chars))
	return lerpf(TIME_MIN, TIME_MAX, clampf(t, 0.0, 1.0))


static func _letter_to_index(letter: String) -> int:
	var i := "ABCD".find(letter.strip_edges().to_upper())
	if i < 0:
		push_warning("QuestionBank: bad correct-answer letter '%s', defaulting to A" % letter)
		return 0
	return i
