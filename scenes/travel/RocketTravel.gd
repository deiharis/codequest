extends Node2D

signal travel_finished

var destination_world: WorldData

func setup(world_data: WorldData):
	destination_world = world_data

func _ready():
	$DestinationPlanet.visible = false
	$Rocket.play("fly")
	$Stars.emitting = true

	var viewport_size = get_viewport_rect().size
	var start_x = -$Rocket.sprite_frames.get_frame_texture("fly", 0).get_width()
	$Rocket.position = Vector2(start_x, viewport_size.y / 2)

	# Phase 1: launch/travel
	var tween = create_tween()
	tween.tween_property($Rocket, "position:x", viewport_size.x * 0.4, 1.5)
	tween.tween_callback(_show_destination)

func _show_destination():
	var viewport_size = get_viewport_rect().size
	if destination_world and destination_world.planet_frames:
		$DestinationPlanet.sprite_frames = destination_world.planet_frames
		$DestinationPlanet.play("default")

	var start_x = viewport_size.x + 400
	var end_x = viewport_size.x * 0.85
	$DestinationPlanet.position = Vector2(start_x, viewport_size.y / 2)
	$DestinationPlanet.visible = true

	var rocket_slow_point = viewport_size.x * 0.55   # where the rocket noticeably slows
	var rocket_exit_x = viewport_size.x + 300

	var tween = create_tween()

	# Planet drifts in slowly across the whole approach
	tween.tween_property($DestinationPlanet, "position:x", end_x, 4.5)

	# Phase A: rocket flies normally up to the slow point (fast)
	var phase_a = tween.parallel().tween_property($Rocket, "position:x", rocket_slow_point, 1.0)
	phase_a.set_trans(Tween.TRANS_LINEAR)

	# Phase B: rocket crawls the rest of the way, then exits (slow, cinematic)
	var phase_b = tween.tween_property($Rocket, "position:x", rocket_exit_x, 4.0)
	phase_b.set_ease(Tween.EASE_IN_OUT)
	phase_b.set_trans(Tween.TRANS_CUBIC)

	tween.tween_callback(_arrive)
	
	
	
func _arrive():
	$Stars.emitting = false
	await get_tree().create_timer(0.5).timeout
	travel_finished.emit()
