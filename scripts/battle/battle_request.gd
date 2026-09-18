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

const BUG_LORD_PATH := "res://resources/enemies/bug_lord/bug_lord.tres"

var hero: HeroData
var enemy: EnemyData
var questions: Array[QuestionData] = []
var mode: Mode = Mode.GENERAL
var hero_start_hp: int = -1   ## -1 means "use hero.max_hp"
## Which world this fight belongs to. Empty means "not part of the campaign" —
## the F6 sandbox — and the battle then records nothing and routes nowhere.
var world_id: String = ""


## Convenience for the sandbox and for BattleController's own fallback.
## question_list is optional: left empty, the enemy's own questions are pulled
## from data/questions.csv, which is what every real fight does.
static func make(hero_data: HeroData, enemy_data: EnemyData,
		question_list: Array[QuestionData] = [], world_id: String = "") -> BattleRequest:
	var r := BattleRequest.new()
	r.hero = hero_data
	r.enemy = enemy_data
	r.questions = question_list if not question_list.is_empty() \
			else QuestionBank.for_enemy(enemy_data.enemy_id)
	r.world_id = world_id
	r.mode = Mode.BUG_LORD if enemy_data.enemy_type == "bug_lord" else Mode.GENERAL
	return r


## The fight a world leads to.
##
## Bugfall has no General (ADR-002) — its holder is the Bug Lord himself, so
## clicking it goes straight to the final encounter with no General first.
static func for_world(world: WorldData) -> BattleRequest:
	if world.general != null and world.general.enemy_type == "bug_lord":
		return for_bug_lord(world.world_id)
	var hero_data: HeroData = load("res://resources/hero/hero.tres")
	return make(hero_data, world.general, [], world.world_id)


## The Bug Lord encounter that follows a General's defeat. He is fought once
## per world, always with the same encounter HP — the damage that accumulates
## is the persistent pool in GameState, not this fight (ADR-004).
static func for_bug_lord(world_id: String) -> BattleRequest:
	var hero_data: HeroData = load("res://resources/hero/hero.tres")
	var boss: EnemyData = load(BUG_LORD_PATH)
	if hero_data == null or boss == null:
		return null
	# Each world has its own boss pool, keyed "bug_lord_<world_id>". Nothing is
	# shared between worlds, so no question is ever seen twice in a campaign.
	var pool := QuestionBank.for_enemy("bug_lord_" + world_id)
	if pool.is_empty():
		push_error("BattleRequest: no questions for bug_lord_%s" % world_id)
	return make(hero_data, boss, pool, world_id)


## Loads a playable battle from disk with no arguments. Used when Battle.tscn
## is run directly (F6) so the scene is always testable on its own.
static func debug_default() -> BattleRequest:
	var hero_data: HeroData = load("res://resources/hero/hero.tres")
	# Swap this path to any enemy .tres to test that fight with F6. The mode
	# follows from the resource's enemy_type, so pointing it at bug_lord.tres
	# gives the full boss layout with no other change.
	var enemy_data: EnemyData = load("res://resources/enemies/ambiguous_client/ambiguous_client.tres")
	return make(hero_data, enemy_data)
