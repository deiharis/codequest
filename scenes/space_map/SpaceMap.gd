extends Node2D
## The galaxy map: eight worlds as a constellation, connected by the path the
## player travels along.
##
## Everything here is built from WorldDatabase at runtime. Positions live in
## each WorldData because where a world sits is data, not presentation — the
## script decides how a planet looks, never which planets exist or where.

## The worlds shown on the map. Comes from one explicit resource rather than a
## directory scan — see WorldDatabase for why the scan had to go.
@export var database: WorldDatabase

@export_group("Title")
## Drop the CodeQuest title art here. Until then a text placeholder stands in,
## so the space is never empty and the layout never shifts when the art lands.
@export var title_texture: Texture2D
@export var title_area: Rect2 = Rect2(226, 18, 700, 140)

@export_group("Planets")
## Planet art is 85px; this is the box each one is centred in.
@export var planet_box: Vector2 = Vector2(128, 128)
@export var hover_scale: float = 1.28
@export var hover_time: float = 0.14
## Locked worlds stay visible and part of the composition — dimmed, not hidden.
@export var locked_tint: Color = Color(0.42, 0.45, 0.58, 1.0)
@export var cleared_tint: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var unlocked_tint: Color = Color(1.0, 1.0, 1.0, 1.0)

@export_group("Path")
@export var path_color: Color = Color(1.0, 1.0, 1.0, 0.7)
@export var path_dot_radius: float = 1.1
@export var path_dot_gap: float = 7.0
## Dots stop this far from a planet's centre. The art is 85px, so ~42 puts the
## trail right against its edge.
@export var path_clearance: float = 42.0
## Change this to reroll the wander. Same number always gives the same path, so
## a layout you like is reproducible.
@export var path_seed: int = 7
## How far the route strays, as a fraction of each segment's own length. Scaled
## rather than absolute: a short hop between close planets bends less than a
## long one, which is what stops neighbouring curves from invading each other.
@export var path_wander_min: float = 0.10
@export var path_wander_max: float = 0.26
## Hard ceiling in pixels, whatever the fraction works out to.
@export var path_wander_cap: float = 70.0

var world_resources: Array[WorldData] = []

var _info: Control
var _info_world: Label
var _info_general: Label
var _sprites: Dictionary = {}     ## world_id -> AnimatedSprite2D


func _ready() -> void:
	_load_worlds()
	_build_title()
	_build_info_panel()
	_spawn_planet_nodes()
	queue_redraw()                 # the path is drawn under everything


func _load_worlds() -> void:
	if database == null:
		database = WorldDatabase.load_default()
	if database == null:
		push_error("SpaceMap: no WorldDatabase at %s" % WorldDatabase.DEFAULT_PATH)
		return
	world_resources = database.in_order()


# --------------------------------------------------------------------------
# The connecting path
# --------------------------------------------------------------------------

## Drawn as dots rather than a Line2D because Godot has no dashed line, and a
## dotted trail reads as a route rather than a border.
##
## The whole route is ONE Catmull-Rom spline through every planet, not a chain
## of separate arcs. That is what makes it flow: a spline is smooth where it
## passes through a point, so the curve leaving a planet continues the curve
## that arrived, instead of kinking. Two offset waypoints are inserted between
## each pair of planets, pushed sideways by random amounts, and the spline is
## pulled through those too — so the path meanders without ever missing a
## planet or bending sharply at one.
func _draw() -> void:
	var route := _route_points()
	if route.size() < 4:
		return
	_draw_dotted_spline(route)


## Planets, with ONE randomly offset waypoint threaded between each pair.
##
## One, not two: two independent offsets per segment could push opposite ways
## and produce an S violent enough to swing into the neighbouring segment, so
## adjacent trails crossed. A single mid-segment offset gives each pair a clean
## bow, and the spline still meanders because every bow is a different size and
## side — and because Catmull-Rom smooths them into one continuous route.
##
## The first and last points are duplicated because Catmull-Rom needs a
## neighbour on each side of every segment it draws.
func _route_points() -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = path_seed

	var pts := PackedVector2Array()
	for i in range(world_resources.size()):
		var here: Vector2 = world_resources[i].map_position
		pts.append(here)
		if i == world_resources.size() - 1:
			break
		var next: Vector2 = world_resources[i + 1].map_position
		var perp := (next - here).normalized().orthogonal()
		pts.append(here.lerp(next, 0.5) + perp * _wander(rng, here.distance_to(next)))

	var out := PackedVector2Array()
	out.append(pts[0] + (pts[0] - pts[1]))        # phantom start
	out.append_array(pts)
	out.append(pts[-1] + (pts[-1] - pts[-2]))     # phantom end
	return out


## A sideways push, either direction, proportional to how far the segment runs
## and capped so a long stretch cannot bow absurdly.
func _wander(rng: RandomNumberGenerator, length: float) -> float:
	var amount := minf(length * rng.randf_range(path_wander_min, path_wander_max),
			path_wander_cap)
	return amount if rng.randf() < 0.5 else -amount


func _draw_dotted_spline(route: PackedVector2Array) -> void:
	var last := _catmull(route, 1, 0.0)
	var since := path_dot_gap
	var per_segment := 48

	for seg in range(1, route.size() - 2):
		for i in range(per_segment + 1):
			var p := _catmull(route, seg, float(i) / per_segment)
			since += last.distance_to(p)
			last = p
			if since < path_dot_gap:
				continue
			if _too_near_a_planet(p):
				continue
			since = 0.0
			draw_circle(p, path_dot_radius, path_color)


## Standard Catmull-Rom: the curve passes through p1 and p2, with p0 and p3
## setting the tangents at each end.
func _catmull(pts: PackedVector2Array, i: int, t: float) -> Vector2:
	var p0 := pts[i - 1]
	var p1 := pts[i]
	var p2 := pts[i + 1]
	var p3 := pts[i + 2]
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1)
			+ (-p0 + p2) * t
			+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
			+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)


## Keeps the trail off the planet art itself while letting it run right up to
## the edge, so the route visibly connects rather than floating near.
func _too_near_a_planet(p: Vector2) -> bool:
	for wd in world_resources:
		if p.distance_to(wd.map_position) < path_clearance:
			return true
	return false


# --------------------------------------------------------------------------
# Title
# --------------------------------------------------------------------------

func _build_title() -> void:
	if title_texture != null:
		var art := TextureRect.new()
		art.texture = title_texture
		art.position = title_area.position
		art.size = title_area.size
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(art)
		return

	var placeholder := Label.new()
	placeholder.text = "CODEQUEST"
	placeholder.position = title_area.position
	placeholder.size = title_area.size
	placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	placeholder.add_theme_font_size_override(&"font_size", 64)
	placeholder.add_theme_color_override(&"font_color", Color(0.83, 0.69, 0.22))
	add_child(placeholder)


# --------------------------------------------------------------------------
# Hover readout
# --------------------------------------------------------------------------

## One shared panel that moves to whichever planet is hovered, rather than a
## label per planet. Eight permanent labels would clutter the composition the
## constellation exists to create.
func _build_info_panel() -> void:
	_info = Control.new()
	_info.name = "PlanetInfo"
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info.visible = false
	add_child(_info)

	var box := VBoxContainer.new()
	box.size = Vector2(260, 60)
	box.position = Vector2(-130, 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override(&"separation", 2)
	_info.add_child(box)

	_info_world = Label.new()
	_info_world.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_world.custom_minimum_size.x = 260
	_info_world.add_theme_font_size_override(&"font_size", 22)
	box.add_child(_info_world)

	_info_general = Label.new()
	_info_general.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_general.custom_minimum_size.x = 260
	_info_general.add_theme_font_size_override(&"font_size", 15)
	box.add_child(_info_general)


func _show_info(wd: WorldData, unlocked: bool) -> void:
	_info_world.text = wd.display_name
	_info_general.text = wd.general_name if not wd.general_name.is_empty() else wd.sdlc_phase
	# Locked worlds show the same information, dimmed — the player should be
	# able to see what is ahead of them, just not reach it.
	var tint := cleared_tint if unlocked else locked_tint
	_info_world.modulate = tint
	_info_general.modulate = tint * Color(1, 1, 1, 0.8)
	# Above the planet, unless that would push it off the top of the screen.
	var above := wd.map_position.y - planet_box.y * 0.62 - 56.0
	_info.position = Vector2(wd.map_position.x,
			above if above > title_area.end.y else wd.map_position.y + planet_box.y * 0.55)
	_info.visible = true


func _hide_info() -> void:
	_info.visible = false


# --------------------------------------------------------------------------
# Planets
# --------------------------------------------------------------------------

func _spawn_planet_nodes() -> void:
	var container: Node2D = $Planets
	for wd in world_resources:
		var unlocked := GameState.is_world_unlocked(wd.order_index)
		var cleared := GameState.is_general_defeated(wd.world_id)

		var button := Button.new()
		# map_position is the planet's centre, so the box is placed around it.
		button.position = wd.map_position - planet_box * 0.5
		button.custom_minimum_size = planet_box
		button.size = planet_box
		button.flat = true
		# Locked planets still respond to the mouse: they report what they are
		# and refuse the click, which is more informative than a dead button.
		button.disabled = false
		container.add_child(button)

		var art := AnimatedSprite2D.new()
		if wd.planet_frames:
			art.sprite_frames = wd.planet_frames
			art.play(&"default")
		art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # pixel-art planets
		art.position = planet_box * 0.5
		art.modulate = (cleared_tint if cleared else unlocked_tint) if unlocked else locked_tint
		button.add_child(art)
		_sprites[wd.world_id] = art

		button.mouse_entered.connect(_on_hover.bind(wd, unlocked))
		button.mouse_exited.connect(_on_unhover.bind(wd, unlocked, cleared))
		button.pressed.connect(_on_planet_pressed.bind(wd, unlocked))


func _on_hover(wd: WorldData, unlocked: bool) -> void:
	_show_info(wd, unlocked)
	var art: AnimatedSprite2D = _sprites.get(wd.world_id)
	if art == null:
		return
	_tween_planet(art, Vector2.ONE * hover_scale,
			Color(1.25, 1.25, 1.25) if unlocked else locked_tint * 1.45)


func _on_unhover(wd: WorldData, unlocked: bool, cleared: bool) -> void:
	_hide_info()
	var art: AnimatedSprite2D = _sprites.get(wd.world_id)
	if art == null:
		return
	var rest := (cleared_tint if cleared else unlocked_tint) if unlocked else locked_tint
	_tween_planet(art, Vector2.ONE, rest)


func _tween_planet(art: AnimatedSprite2D, target_scale: Vector2, tint: Color) -> void:
	var t := create_tween().set_parallel()
	t.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(art, "scale", target_scale, hover_time)
	t.tween_property(art, "modulate", tint, hover_time)


func _on_planet_pressed(wd: WorldData, unlocked: bool) -> void:
	if not unlocked:
		return
	# The router instantiates the scene, calls `setup` on it, and only then
	# adds it to the tree — so RocketTravel has its destination before _ready().
	var configure := func(scene: Node) -> void:
		scene.setup(wd)

	SceneRouter.goto_scene("res://scenes/travel/RocketTravel.tscn", configure)
