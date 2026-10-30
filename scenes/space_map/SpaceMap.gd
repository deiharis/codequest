extends Node2D
@export var database: WorldDatabase

@export_group("Backdrop")
## Nebula behind everything. Sits above the flat Background rect and below the
## stars this node draws itself.
@export var background_texture: Texture2D
@export var star_seed: int = 4
@export var star_count: int = 260

@export_group("Menu")
@export var back_rect: Rect2 = Rect2(24, 20, 116, 40)

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

@export_group("Progress")
## The campaign bar along the bottom. Planets sit between y 250 and y 564
## (lowest centre 500, half-box 64), so this strip is the only full-width space
## on the map that nothing else wants.
@export var progress_rect: Rect2 = Rect2(160, 598, 832, 16)

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
var _info_lock: Label
var _info_world: Label
var _hp_label: Label
var _cleared_label: Label
var _choice_layer: CanvasLayer
var _choice_title: Label
var _choice_phase: Label
var _choice_world: WorldData
var _info_general: Label
var _sprites: Dictionary = {}     ## world_id -> AnimatedSprite2D


func _ready() -> void:
	AudioManager.play_music(&"space_map")
	_load_worlds()
	_build_backdrop()
	_build_title()
	_build_back_button()
	_build_progress()
	_build_choice()
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

## Nebula art goes in as a child at z_index -9: above the flat Background rect
## at -10, below this node's own drawing, which is where the stars and the
## route are. Three layers, one ordering rule.
func _build_backdrop() -> void:
	if background_texture == null:
		return
	var art := TextureRect.new()
	art.name = "Nebula"
	# Expand first — until then a TextureRect's minimum size is the texture's.
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.custom_minimum_size = Vector2.ZERO
	art.texture = background_texture
	art.position = Vector2.ZERO
	art.size = get_viewport_rect().size
	art.z_index = -9
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(art)


## Stars, drawn rather than textured so they stay a single pixel crisp at any
## window size. Seeded: the same sky every launch, because a field that
## reshuffles on each boot reads as noise rather than as a place.
func _draw_stars() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = star_seed
	var view := get_viewport_rect().size
	for i in star_count:
		var p := Vector2(rng.randf() * view.x, rng.randf() * view.y)
		var r := rng.randf_range(0.6, 1.9)
		# Squared alpha: most stars faint, a few bright. An evenly lit field
		# looks printed on rather than deep.
		var a := rng.randf_range(0.10, 0.90)
		draw_circle(p, r, Color(1, 1, 1, a * a))


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
	_draw_stars()
	# Before the route's early return, or a map with too few worlds to draw a
	# spline would silently lose its progress bar as well.
	_draw_progress()
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

# --------------------------------------------------------------------------
# Campaign progress
# --------------------------------------------------------------------------
# The Bug Lord's health IS the campaign's progress bar (ADR-003): eight worlds,
# a thousand off him each. The title screen said so and this screen — the one
# where the player picks their next world — did not show it at all.

func _build_progress() -> void:
	var r := progress_rect

	var title := Label.new()
	title.name = "ProgressTitle"
	title.text = "THE BUG LORD"
	title.position = Vector2(r.position.x, r.position.y - 26.0)
	title.add_theme_font_size_override(&"font_size", 15)
	title.add_theme_color_override(&"font_color", Color(0.83, 0.69, 0.22))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)

	_hp_label = Label.new()
	_hp_label.name = "ProgressHP"
	_hp_label.theme_type_variation = &"Subtle"
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hp_label.position = Vector2(r.position.x, r.position.y - 25.0)
	_hp_label.size.x = r.size.x
	_hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hp_label)

	_cleared_label = Label.new()
	_cleared_label.name = "ProgressCleared"
	_cleared_label.theme_type_variation = &"Subtle"
	_cleared_label.position = Vector2(r.position.x, r.end.y + 5.0)
	_cleared_label.size.x = r.size.x
	_cleared_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cleared_label)

	_refresh_progress()


func _refresh_progress() -> void:
	var cleared := GameState.defeated_generals.size()
	var total := world_resources.size()
	if GameState.is_campaign_won():
		_hp_label.text = "nothing remains"
		_cleared_label.text = "Every world cleared."
	else:
		_hp_label.text = "%d / %d" % [GameState.bug_lord_hp, GameState.BUG_LORD_MAX_HP]
		_cleared_label.text = "%d of %d worlds cleared" % [cleared, total]


## Drawn rather than built from nodes: this node already has a `_draw` for the
## starfield and the route, and a bar is four rectangles. A ProgressBar plus a
## StyleBox to make it look like this would be more configuration than drawing.
func _draw_progress() -> void:
	var r := progress_rect
	var frac: float = float(GameState.bug_lord_hp) / float(GameState.BUG_LORD_MAX_HP)

	draw_rect(r.grow(2.0), Color(0.83, 0.69, 0.22, 0.85), false, 2.0)
	draw_rect(r, Color(0.04, 0.05, 0.09, 0.92))

	if frac > 0.0:
		# The same colours as his battle nameplate, taken from it rather than
		# copied — one source of truth for what the Bug Lord's health looks like.
		var fill: Color = Nameplate.BOSS_FILL.lerp(Nameplate.BOSS_FILL_LOW,
				clampf(1.0 - frac, 0.0, 1.0))
		draw_rect(Rect2(r.position, Vector2(r.size.x * frac, r.size.y)), fill)

	# One tick per world, so the bar reads as eight steps rather than a
	# continuous drain — which is what it actually is.
	var worlds := maxi(1, world_resources.size())
	for i in range(1, worlds):
		var x: float = r.position.x + r.size.x * (float(i) / float(worlds))
		draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y),
				Color(0.04, 0.05, 0.09, 0.75), 2.0)


func _build_title() -> void:
	if title_texture != null:
		var art := TextureRect.new()
		# Order matters: while expand_mode is the default, a TextureRect's
		# minimum size IS the texture's full size, so any size set first is
		# clamped straight back up to it. Expand first, then size.
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.custom_minimum_size = Vector2.ZERO
		art.texture = title_texture
		art.position = title_area.position
		art.size = title_area.size
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


## Returning to the menu needs no save step: progress is written the moment a
## world is cleared, so there is never unsaved state sitting on this screen.
func _build_back_button() -> void:
	var b := Button.new()
	b.name = "BackButton"
	b.text = "Menu"
	b.position = back_rect.position
	b.size = back_rect.size
	b.custom_minimum_size = back_rect.size
	b.pressed.connect(_on_back)
	add_child(b)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):     # Escape
		# Marked handled, or it carries on to the PauseMenu autoload and the
		# player both leaves the map and opens a pause menu over the title
		# screen. A scene that acts on an input owns it.
		get_viewport().set_input_as_handled()
		# Escape closes the planet panel first. Leaving the map out from under
		# an open dialog is the kind of thing that feels like a misclick.
		if _choice_layer and _choice_layer.visible:
			_close_choice()
			return
		_on_back()


func _on_back() -> void:
	SceneRouter.goto_scene("res://scenes/main/Main.tscn")


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

	# Why a world cannot be entered yet. A dimmed planet that refuses the click
	# tells the player they are wrong without telling them what would be right.
	_info_lock = Label.new()
	_info_lock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_lock.custom_minimum_size.x = 260
	_info_lock.add_theme_font_size_override(&"font_size", 14)
	_info_lock.add_theme_color_override(&"font_color", Color(0.83, 0.69, 0.22))
	_info_lock.visible = false
	box.add_child(_info_lock)


func _show_info(wd: WorldData, unlocked: bool) -> void:
	_info_world.text = wd.display_name
	_info_general.text = wd.general_name if not wd.general_name.is_empty() else wd.sdlc_phase
	# Locked worlds show the same information, dimmed — the player should be
	# able to see what is ahead of them, just not reach it.
	var tint := cleared_tint if unlocked else locked_tint
	_info_world.modulate = tint
	_info_general.modulate = tint * Color(1, 1, 1, 0.8)

	_info_lock.visible = not unlocked
	if not unlocked:
		_info_lock.text = _lock_reason()
	# Above the planet, unless that would push it off the top of the screen.
	# A locked world's readout carries a third line, so it needs to sit higher
	# or its extra height reaches down over the planet it describes.
	var lift := 56.0 if unlocked else 74.0
	var above := wd.map_position.y - planet_box.y * 0.62 - lift
	_info.position = Vector2(wd.map_position.x,
			above if above > title_area.end.y else wd.map_position.y + planet_box.y * 0.55)
	_info.visible = true


## What stands between the player and the world they just hovered. The blocker
## is always the next uncleared world in order, because unlocking is
## `order_index <= worlds cleared` — so naming that one world is both accurate
## and more useful than a count.
func _lock_reason() -> String:
	var next_index := GameState.current_world_index
	if next_index >= 0 and next_index < world_resources.size():
		return "Locked — clear %s first" % world_resources[next_index].display_name
	return "Locked"


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
		# The Space Map is a navigation screen, not a place. Its planets get a
		# clean interface chime rather than the leather-and-wood tick the rest
		# of the game uses — see AudioManager.hook_button.
		button.set_meta("hover_sfx", &"planet_hover")   # AudioManager.META_HOVER
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
		# Silence reads as a broken button. A refusal should be felt.
		_refuse(wd)
		return

	# A world whose lesson has already been played asks first. Before this, a
	# lesson could only be re-read from the Bugfall Archive — which is behind
	# seven worlds, so a student who forgot Reqoria's terms in world three had
	# no way back to them. The material is the point of the game; it should not
	# be reachable only by finishing it.
	if LessonBank.has_lesson(wd.world_id) and GameState.has_seen_lesson(wd.world_id):
		_open_choice(wd)
		return

	_travel_to(wd)


## A short shake on the planet that will not open, and the same thud the game
## uses when the hero is hit. Both say "no" without a dialog.
func _refuse(wd: WorldData) -> void:
	AudioManager.play(&"enemy_hit", 0.08, -14.0)
	var art: AnimatedSprite2D = _sprites.get(wd.world_id)
	if art == null:
		return
	var home := art.position
	var t := create_tween()
	t.set_trans(Tween.TRANS_SINE)
	for offset in [-7.0, 6.0, -4.0, 2.0, 0.0]:
		t.tween_property(art, "position:x", home.x + offset, 0.05)


func _travel_to(wd: WorldData) -> void:
	# The router instantiates the scene, calls `setup` on it, and only then
	# adds it to the tree — so RocketTravel has its destination before _ready().
	var configure := func(scene: Node) -> void:
		scene.setup(wd)

	SceneRouter.goto_scene("res://scenes/travel/RocketTravel.tscn", configure)


# --------------------------------------------------------------------------
# Revisit a world's lesson
# --------------------------------------------------------------------------

## On its own CanvasLayer for the same reason the pause menu is: this node is a
## Node2D, and a Control anchored to a Node2D has no rect to anchor against.
func _build_choice() -> void:
	_choice_layer = CanvasLayer.new()
	_choice_layer.name = "PlanetChoice"
	_choice_layer.layer = 90
	_choice_layer.visible = false
	add_child(_choice_layer)

	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.02, 0.05, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	# STOP: without it a click meant for this panel passes through to whatever
	# planet is underneath and launches a rocket.
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_choice_layer.add_child(dim)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_choice_layer.add_child(centre)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(400, 0)
	centre.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 10)
	panel.add_child(box)

	_choice_title = Label.new()
	_choice_title.theme_type_variation = &"Heading"
	_choice_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_choice_title)

	_choice_phase = Label.new()
	_choice_phase.theme_type_variation = &"Subtle"
	_choice_phase.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_choice_phase)

	var rule := ColorRect.new()
	rule.color = Color(0.58, 0.48, 0.16, 0.55)
	rule.custom_minimum_size = Vector2(0, 2)
	box.add_child(rule)

	box.add_child(_choice_button("Study the lesson again", _on_study))
	box.add_child(_choice_button("Travel there", _on_travel))
	box.add_child(_choice_button("Back to the map", _close_choice))


func _choice_button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.theme_type_variation = &"ScrollOption"
	b.text = text
	b.custom_minimum_size = Vector2(360, 44)
	b.pressed.connect(action)
	return b


func _open_choice(wd: WorldData) -> void:
	_choice_world = wd
	_choice_title.text = wd.display_name
	_choice_phase.text = wd.sdlc_phase
	_hide_info()                     # the hover readout would sit over the dim
	_choice_layer.visible = true


func _close_choice() -> void:
	_choice_layer.visible = false
	_choice_world = null


## Library mode: it marks nothing, starts no fight, and comes back here rather
## than to the Archive.
func _on_study() -> void:
	if _choice_world == null:
		return
	var wd := _choice_world
	_close_choice()
	WorldFlow.study(self, wd, "res://scenes/space_map/SpaceMap.tscn")


func _on_travel() -> void:
	if _choice_world == null:
		return
	var wd := _choice_world
	_close_choice()
	_travel_to(wd)
