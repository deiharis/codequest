extends Resource
class_name EnemyData
## Everything the battle needs to know about one enemy.
##
## One .tres per General plus one for the Bug Lord. The battle scene is
## configured entirely from this — no enemy is ever named in code.

@export_group("Identity")
## Must match the asset folder name exactly, e.g. "regression_dragon".
@export var enemy_id: String = ""
@export var display_name: String = ""
## "general" or "bug_lord". Decides which battle layout is used.
@export var enemy_type: String = "general"

@export_group("Animation")
@export var idle_frames: SpriteFrames
@export var attack_frames: SpriteFrames
@export var damage_frames: SpriteFrames
@export var defeat_frames: SpriteFrames

@export_group("Presentation")
## Size relative to the hero at 1.0. See ART_SPEC section 4.
@export var display_scale: float = 1.0
## Nudge in pixels if this character's art sits too high or low on the ground.
@export var ground_offset: Vector2 = Vector2.ZERO
## Corrects art inconsistency: the character is drawn at a different relative
## size in the attack sheet than in the idle sheet. Tuned by eye, per character.
@export var attack_scale: float = 1.0
## Tints this enemy's attack VFX.
@export var attack_effect_color: Color = Color.WHITE
## The battle background fades to this when this enemy arrives. Leave black
## to keep the default. Used to make the Bug Lord's entrance change the world.
@export var background_color: Color = Color.BLACK

@export_group("Combat")
@export var max_hp: int = 100
## HP the hero loses on a wrong answer.
@export var attack_damage: int = 15

@export_group("Timer")
## Bug Lord encounters only. Generals never have a timer.
@export var has_timer: bool = false
@export var timer_seconds: float = 60.0
