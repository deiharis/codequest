extends Resource
class_name EnemyData

@export var enemy_id: String = ""
@export var display_name: String = ""
@export var enemy_type: String = "general"
@export var idle_frames: SpriteFrames
@export var attack_frames: SpriteFrames
@export var damage_frames: SpriteFrames
@export var defeat_frames: SpriteFrames
@export var max_hp: int = 100
@export var has_timer: bool = false
@export var timer_seconds: float = 30.0
@export var attack_effect_color: Color = Color.WHITE
