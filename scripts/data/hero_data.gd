extends Resource
class_name HeroData
## The hero's stats and animation sets.
##
## There is exactly one of these: resources/hero/hero.tres
##
## Two animation sets exist because the two battle layouts use different
## camera angles — 3/4 rear against Generals, straight rear against the
## Bug Lord. See ART_SPEC section 2.

@export_group("Combat")
@export var max_hp: int = 100
## HP the enemy loses on a correct answer.
@export var attack_damage: int = 25
## Damage the Ultimate deals to the Bug Lord's encounter pool.
@export var ultimate_damage: int = 500

@export_group("General fight (3/4 rear)")
@export var idle_frames: SpriteFrames
@export var attack_frames: SpriteFrames
@export var damage_frames: SpriteFrames
@export var defeat_frames: SpriteFrames

@export_group("Bug Lord fight (straight rear)")
@export var boss_idle_frames: SpriteFrames
@export var boss_attack_frames: SpriteFrames
@export var boss_damage_frames: SpriteFrames
@export var boss_defeat_frames: SpriteFrames
## Both ultimate halves live in this one resource, played as a single move.
@export var ultimate_frames: SpriteFrames

@export_group("Presentation")
@export var display_scale: float = 1.0
## Corrects art inconsistency: the character is drawn at a different relative
## size in the attack sheet than in the idle sheet. Tuned by eye, per character.
@export var attack_scale: float = 1.0
@export var ground_offset: Vector2 = Vector2.ZERO
