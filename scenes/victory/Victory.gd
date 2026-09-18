extends Control
## Shown once the Bug Lord's persistent HP reaches zero.
##
## Deliberately plain: it states what was achieved, offers a new campaign, and
## nothing else. A results screen that celebrates louder than the fight did
## feels unearned.

@onready var _summary: Label = $Layout/Summary


func _ready() -> void:
	_summary.text = "%d worlds cleared\nThe Bug Lord is gone." \
			% GameState.defeated_generals.size()
	$Layout/PlayAgain.pressed.connect(_on_play_again)


## A new campaign means a genuinely new campaign — the save is cleared, not
## edited, so there is no half-finished state left behind.
func _on_play_again() -> void:
	GameState.reset()
	SceneRouter.goto_scene("res://scenes/space_map/SpaceMap.tscn")
