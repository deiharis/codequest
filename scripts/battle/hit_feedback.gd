extends Node2D
class_name HitFeedback
## Everything that turns "the numbers changed" into "I hit it": damage numbers,
## screen shake, the blade's arc, sparks off the impact, and the screen flash.
##
## One node rather than four. It already lives above the fighters and below the
## UI, the battle already orders it correctly, and it is already called at the
## exact frame a blow lands — a second effects node would mean a second thing to
## place in the tree and a second chance to place it wrong.
##
## Owns no battle state. It is told what happened and shows it.

## How far a number drifts up before it fades, and how long it lives.
@export var rise: float = 62.0
@export var life: float = 0.85
@export var damage_color: Color = Color(1.0, 0.86, 0.32)
@export var hero_hurt_color: Color = Color(1.0, 0.42, 0.40)

## Shake is offset on the node the battle passes in, decaying to nothing.
@export var shake_falloff: float = 9.0

## The blade's arc.
## Radius and thickness together decide whether this reads as a blade or a
## leaf. Rendered the polygon maths at four progress values before picking:
## r96/t30 was a fat teardrop. A thin band on a wide arc is a sword.
@export var slash_radius: float = 150.0
@export var slash_thickness: float = 15.0
@export var slash_time: float = 0.15
@export var hero_slash_color: Color = Color(1.0, 0.97, 0.86, 0.92)
@export var enemy_slash_color: Color = Color(1.0, 0.62, 0.58, 0.9)

## The Ultimate's blinding light and the Bug Lord's burst. Shares the flash's
## CanvasLayer so neither is dragged around by the screen shake.
@export var blind_in: float = 0.8
@export var blind_collapse: float = 0.2
@export var burst_grow: float = 0.22
@export var burst_hold: float = 0.18
@export var burst_fade: float = 0.6
@export var violet: Color = Color(0.42, 0.16, 0.66)

var _flash: ColorRect
var _wipe: Wipe

var _shake_target: Node2D
var _shake_home: Vector2 = Vector2.ZERO
var _shake: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	set_process(false)
	_build_flash()


## The full-screen flash lives on its own CanvasLayer, inside this node.
##
## A CanvasLayer ignores its parent's transform, which is exactly what is wanted
## here: this node is inside the thing that shakes, and a flash that shakes with
## the screen would show the arena's edges sliding out from under it.
func _build_flash() -> void:
	var layer := CanvasLayer.new()
	layer.name = "FlashLayer"
	layer.layer = 100          # over the fight and the UI, under SceneRouter's fade
	add_child(layer)

	_flash = ColorRect.new()
	_flash.name = "Flash"
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color.WHITE
	_flash.modulate.a = 0.0
	layer.add_child(_flash)

	_wipe = Wipe.new()
	_wipe.name = "Wipe"
	_wipe.set_anchors_preset(Control.PRESET_FULL_RECT)
	_wipe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wipe.modulate.a = 0.0
	layer.add_child(_wipe)


## The node that moves when the screen shakes. Usually the battle root, so the
## arena, the fighters and the storm all move together and the UI does not.
func watch(target: Node2D) -> void:
	_shake_target = target
	_shake_home = target.position


## One damage number, rising and fading from a world position.
func pop(amount: int, at: Vector2, hurting_hero: bool) -> void:
	if amount <= 0:
		return

	var label := Label.new()
	label.text = "-%d" % amount
	label.position = at + Vector2(-40, -20)
	label.size = Vector2(80, 32)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override(&"font_size", 24 if hurting_hero else 21)
	label.add_theme_color_override(&"font_color",
			hero_hurt_color if hurting_hero else damage_color)
	# An outline, because the number has to be legible over any arena.
	label.add_theme_color_override(&"font_outline_color", Color(0.02, 0.02, 0.04))
	label.add_theme_constant_override(&"outline_size", 5)
	add_child(label)

	# Sideways drift so repeated hits do not stack into one column.
	var drift := _rng.randf_range(-22.0, 22.0)

	var t := create_tween().set_parallel()
	t.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	t.tween_property(label, "position", label.position + Vector2(drift, -rise), life)
	t.tween_property(label, "scale", Vector2.ONE * 1.12, life * 0.22)
	t.chain().tween_property(label, "scale", Vector2.ONE, life * 0.20)
	t.chain().tween_property(label, "modulate:a", 0.0, life * 0.42)
	await t.finished
	label.queue_free()


## Kick the camera. Amount is in pixels of initial offset.
func shake(amount: float) -> void:
	if _shake_target == null:
		return
	_shake = maxf(_shake, amount)
	set_process(true)


func _process(delta: float) -> void:
	if _shake_target == null:
		set_process(false)
		return
	_shake = move_toward(_shake, 0.0, shake_falloff * delta * 10.0)
	if _shake <= 0.05:
		_shake_target.position = _shake_home
		set_process(false)
		return
	_shake_target.position = _shake_home + Vector2(
			_rng.randf_range(-_shake, _shake),
			_rng.randf_range(-_shake, _shake))


## A blade's arc across the point it lands on.
##
## The node is placed so the MIDDLE of the arc sits on `at` — centring the node
## on the impact instead would draw a curve that passes around the target rather
## than through it, which is the obvious mistake and looks like a halo.
func slash(at: Vector2, by_hero: bool) -> void:
	var arc := Slash.new()
	arc.radius = slash_radius
	arc.thickness = slash_thickness
	arc.color = hero_slash_color if by_hero else enemy_slash_color
	# Hero swings down-left to up-right; the enemy answers the other way. The
	# jitter stops repeated blows tracing the same line.
	arc.span = 2.0
	arc.start_angle = (2.5 if by_hero else -0.6) + _rng.randf_range(-0.22, 0.22)

	var mid := arc.start_angle + arc.span * 0.5
	arc.position = at - Vector2(cos(mid), sin(mid)) * arc.radius
	add_child(arc)

	var t := create_tween()
	t.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
	t.tween_property(arc, "progress", 1.0, slash_time)
	t.tween_property(arc, "modulate:a", 0.0, slash_time * 0.9)
	await t.finished
	arc.queue_free()


## The furthest corner of the screen from a point. A circle of this radius
## centred there covers the whole viewport, whatever the aspect ratio.
func _corner_distance(from: Vector2) -> float:
	var size := get_viewport_rect().size
	var furthest := 0.0
	for c in [Vector2.ZERO, Vector2(size.x, 0.0), Vector2(0.0, size.y), size]:
		furthest = maxf(furthest, from.distance_to(c))
	return furthest


## The Ultimate's opening: white floods in until it blinds, then collapses to a
## point on the hero. Awaitable — the fight waits for this.
##
## `at` is in SCREEN coordinates, not world: this draws on a CanvasLayer, which
## ignores the battle's transform (that is what keeps it steady while the screen
## shakes). Callers pass `node.get_global_transform_with_canvas().origin`.
func blinding_collapse(at: Vector2) -> void:
	if _wipe == null:
		return
	_wipe.center = at
	_wipe.core_color = Color.WHITE
	_wipe.edge_color = Color(0, 0, 0, 0)
	_wipe.radius = _corner_distance(at)
	_wipe.modulate.a = 0.0

	# In slowly — it has to read as building, not as a cut to white.
	var t := create_tween()
	t.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	t.tween_property(_wipe, "modulate:a", 1.0, blind_in)
	await t.finished

	# Then gone, inward, fast. EASE_IN so it accelerates as it shrinks and the
	# light reads as being pulled into him rather than fading out.
	var c := create_tween()
	c.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	c.tween_property(_wipe, "radius", 0.0, blind_collapse)
	await c.finished
	_wipe.modulate.a = 0.0


## The Bug Lord going up: white core inside a violet shadow, out from him and
## over everything. Awaitable.
func burst_from(at: Vector2) -> void:
	if _wipe == null:
		return
	_wipe.center = at
	_wipe.core_color = Color.WHITE
	_wipe.edge_color = violet
	_wipe.edge_scale = 1.55
	_wipe.radius = 0.0
	_wipe.modulate.a = 1.0

	var reach := _corner_distance(at)
	var t := create_tween()
	t.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	t.tween_property(_wipe, "radius", reach, burst_grow)
	await t.finished

	await get_tree().create_timer(burst_hold, false).timeout
	var f := create_tween()
	f.tween_property(_wipe, "modulate:a", 0.0, burst_fade)
	await f.finished
	_wipe.edge_scale = 1.0
	_wipe.edge_color = Color(0, 0, 0, 0)


## Several slashes in quick succession, scattered around a point.
##
## The Ultimate is not one blow, so one arc reads as a weak normal attack with a
## flash bolted on. Three staggered cuts across the width of the target read as
## a flurry. Awaitable, because at that moment the fight genuinely is waiting on
## the animation.
## `sound` and `shake_each` exist because a long flurry without them is 2.5
## seconds of silent, motionless blade — the cuts appear and the rest of the
## game sits still behind them. One sword hit and one small kick per cut is what
## makes it a sustained assault rather than a slideshow.
func slash_flurry(at: Vector2, by_hero: bool, count: int = 3,
		gap: float = 0.1, spread: float = 90.0,
		sound: StringName = &"", shake_each: float = 0.0) -> void:
	for i in count:
		var offset := Vector2(_rng.randf_range(-spread, spread),
				_rng.randf_range(-spread * 0.55, spread * 0.55))
		slash(at + offset, by_hero)          # not awaited: they overlap
		if sound != &"":
			# Well below the master: twenty-four of these at full level is noise,
			# not a flurry. The jitter keeps them from phasing into one tone.
			AudioManager.play(sound, 0.12, -9.0)
		if shake_each > 0.0:
			shake(shake_each)
		if i < count - 1:
			await get_tree().create_timer(gap, false).timeout


## Sparks off the impact. CPUParticles2D rather than a hand-rolled particle
## loop — it is built in, it is one configuration block, and nothing here needs
## behaviour a custom system would give.
func sparks(at: Vector2, by_hero: bool, count: int = 20, power: float = 1.0) -> void:
	var p := CPUParticles2D.new()
	p.position = at
	p.amount = count
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = 0.5
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = 110.0 * power
	p.initial_velocity_max = 400.0 * power
	p.gravity = Vector2(0, 780)
	p.damping_min = 40.0
	p.damping_max = 120.0
	p.scale_amount_min = 1.6
	p.scale_amount_max = 4.0

	# Sparks cool as they fall: bright core, hot middle, dark and gone.
	var ramp := Gradient.new()
	var hot := Color(1.0, 0.92, 0.6) if by_hero else Color(1.0, 0.55, 0.42)
	ramp.set_color(0, Color(1.0, 1.0, 0.95))
	ramp.set_color(1, Color(hot.r, hot.g, hot.b, 0.0))
	ramp.add_point(0.35, hot)
	p.color_ramp = ramp

	add_child(p)
	p.emitting = true
	await get_tree().create_timer(p.lifetime + 0.2, false).timeout
	if is_instance_valid(p):
		p.queue_free()


## A wash of colour over everything. Used for the Ultimate and for Bugfall's
## lightning — the two moments the whole world is supposed to react, not just
## the thing being hit.
func screen_flash(color: Color, strength: float = 0.5, fade: float = 0.28) -> void:
	if _flash == null:
		return
	_flash.color = color
	_flash.modulate.a = strength
	var t := create_tween()
	t.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUINT)
	t.tween_property(_flash, "modulate:a", 0.0, fade)


## The crescent itself. An inner class because nothing outside this file has any
## use for it, and `_draw` is the only way to get a tapered arc without an
## artist supplying one as a texture.
class Slash extends Node2D:
	var radius: float = 96.0
	var thickness: float = 30.0
	var span: float = 1.7
	var start_angle: float = 0.0
	var color: Color = Color.WHITE

	## How far the blade has travelled, 0 to 1. Redraws on every change, which
	## is what makes the tween animate it.
	var progress: float = 0.0:
		set(value):
			progress = value
			queue_redraw()

	const SEGMENTS := 28
	## The arc is a trailing band, not a growing one: the tail chases the head
	## so the blade reads as passing through rather than being painted on.
	const TRAIL := 0.5

	func _draw() -> void:
		if progress <= 0.0:
			return
		var head := start_angle + span * progress
		var tail := start_angle + span * maxf(0.0, progress - TRAIL)
		if is_equal_approx(head, tail):
			return

		var outer := PackedVector2Array()
		var inner := PackedVector2Array()
		for i in SEGMENTS + 1:
			var t := float(i) / SEGMENTS
			var a: float = lerpf(tail, head, t)
			# Thin at the tail, full in the middle, thin again at the leading
			# edge: a blade has no width at its ends.
			var w: float = thickness * sin(PI * t)
			var dir := Vector2(cos(a), sin(a))
			outer.append(dir * (radius + w * 0.5))
			inner.append(dir * (radius - w * 0.5))

		inner.reverse()
		outer.append_array(inner)
		draw_colored_polygon(outer, color)


## The full-screen circle used by both `blinding_collapse` and `burst_from`.
##
## One node for a light that shrinks to nothing and an explosion that grows from
## nothing, because they are the same drawing played in opposite directions.
class Wipe extends Control:
	var center: Vector2 = Vector2.ZERO
	var core_color: Color = Color.WHITE
	## Drawn behind the core at `radius * edge_scale`. Transparent by default,
	## so the blinding light is plain white and only the burst has a shadow.
	var edge_color: Color = Color(0, 0, 0, 0)
	var edge_scale: float = 1.0

	var radius: float = 0.0:
		set(value):
			radius = value
			queue_redraw()

	func _draw() -> void:
		if radius <= 0.5:
			return
		if edge_color.a > 0.0:
			draw_circle(center, radius * edge_scale, edge_color)
		draw_circle(center, radius, core_color)
