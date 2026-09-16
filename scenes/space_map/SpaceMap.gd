extends Node2D

var world_resources: Array[WorldData] = []

func _ready():
	_load_worlds()
	_spawn_planet_nodes()

func _load_worlds():
	var dir = DirAccess.open("res://resources/worlds/")
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			world_resources.append(load("res://resources/worlds/" + file_name))
		file_name = dir.get_next()
	dir.list_dir_end()
	world_resources.sort_custom(func(a, b): return a.order_index < b.order_index)

func _spawn_planet_nodes():
	var planets_container = $Planets
	for wd in world_resources:
		var unlocked = GameState.is_world_unlocked(wd.order_index)

		var button = Button.new()
		button.position = wd.map_position
		button.disabled = not unlocked
		button.flat = true
		button.custom_minimum_size = Vector2(128, 128)

		var anim_sprite = AnimatedSprite2D.new()
		if wd.planet_frames:
			anim_sprite.sprite_frames = wd.planet_frames
			anim_sprite.play("default")
		anim_sprite.modulate = Color(1,1,1,1) if unlocked else Color(0.3,0.3,0.3,1)
		anim_sprite.position = Vector2(64, 64)

		button.add_child(anim_sprite)
		button.pressed.connect(_on_planet_pressed.bind(wd))
		planets_container.add_child(button)

func _on_planet_pressed(wd: WorldData) -> void:
	# The router instantiates the scene, calls `configure` on it, and only then
	# adds it to the tree — so RocketTravel has its destination before _ready().
	var configure := func(scene: Node) -> void:
		scene.setup(wd)

	SceneRouter.goto_scene("res://scenes/travel/RocketTravel.tscn", configure)
	
