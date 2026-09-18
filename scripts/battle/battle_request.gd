extends RefCounted
class_name BattleRequest
## Everything a battle needs to be set up. Built by whoever starts the fight
## (the world flow, or the debug sandbox) and handed to BattleController.
##
## Deliberately RefCounted, not Resource: this is runtime state, created fresh
## per battle and never saved to disk.

enum Mode {
	GENERAL,   ## hero bottom-left facing up-right, enemy top-right
	BUG_LORD,  ## hero bottom-centre facing up, boss filling the top of screen
}

var hero: HeroData
var enemy: EnemyData
var questions: Array[QuestionData] = []
var mode: Mode = Mode.GENERAL
var hero_start_hp: int = -1   ## -1 means "use hero.max_hp"


## Convenience for the sandbox and for BattleController's own fallback.
## question_list is optional: left empty, the enemy's own questions are pulled
## from data/questions.csv, which is what every real fight does.
static func make(hero_data: HeroData, enemy_data: EnemyData,
		question_list: Array[QuestionData] = []) -> BattleRequest:
	var r := BattleRequest.new()
	r.hero = hero_data
	r.enemy = enemy_data
	r.questions = question_list if not question_list.is_empty() \
			else QuestionBank.for_enemy(enemy_data.enemy_id)
	r.mode = Mode.BUG_LORD if enemy_data.enemy_type == "bug_lord" else Mode.GENERAL
	return r


## Loads a playable battle from disk with no arguments. Used when Battle.tscn
## is run directly (F6) so the scene is always testable on its own.
static func debug_default() -> BattleRequest:
	var hero_data: HeroData = load("res://resources/hero/hero.tres")
	# ponytail: temporary — points the F6 sandbox at the boss fight.
	# Revert to ambiguous_client.tres when Bug Lord testing is done.
	var enemy_data: EnemyData = load("res://resources/enemies/bug_lord/bug_lord.tres")
	return make(hero_data, enemy_data)
