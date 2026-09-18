extends Resource
class_name WorldData
## One world on the Space Map, and the fight it leads to.

@export var world_id: String = ""
@export var display_name: String = ""
@export var sdlc_phase: String = ""
@export var general_name: String = ""
## The enemy fought here. Bugfall points at the Bug Lord, which is why it has
## no General — ADR-002.
@export var general: EnemyData
@export var planet_frames: SpriteFrames
@export var map_position: Vector2 = Vector2.ZERO
@export var order_index: int = 0

## Bugfall only: the Bug Lord's attacks call down lightning here. A property of
## the world rather than of him, because he is fought in eight places and only
## this one is his.
@export var storm_on_attack: bool = false
