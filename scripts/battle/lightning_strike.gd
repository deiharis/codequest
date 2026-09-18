extends Node2D
class_name LightningStrike
## Black lightning with a red shadow, for the Bug Lord's attacks in Bugfall.
##
## Drawn rather than animated from sprites: a bolt is a jagged line, and code
## makes a different one every time. Eight hand-drawn bolts would repeat within
## one fight; this never does.

## Core and shadow. The core is black so the bolt reads as a tear in the sky
## rather than as light — on a red arena, a bright bolt would vanish into it.
@export var core_color: Color = Color(0.02, 0.0, 0.02, 1.0)
@export var shadow_color: Color = Color(0.85, 0.05, 0.12, 0.55)
@export var core_width: float = 3.0
@export var shadow_width: float = 11.0

## How long one strike lives, and how hard the screen flashes with it.
@export var duration: float = 0.34
@export var flash_color: Color = Color(0.55, 0.03, 0.08, 0.30)

var _bolts: Array = []          ## Array[PackedVector2Array]
var _alpha: float = 0.0
var _flash: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	set_process(false)
	_rng.randomize()


## Fire a storm: several bolts at once, then fade. Awaitable so the battle can
## hold on it if it ever needs to.
func strike(count: int = 3) -> void:
	var view := get_viewport_rect().size
	_bolts.clear()
	for i in count:
		var from := Vector2(_rng.randf_range(60.0, view.x - 60.0), -20.0)
		var to := Vector2(from.x + _rng.randf_range(-190.0, 190.0),
				_rng.randf_range(view.y * 0.55, view.y * 0.95))
		_bolts.append(_make_bolt(from, to, 6))
		# A fork from partway down, on most bolts but not all.
		if _rng.randf() < 0.7:
			var pts: PackedVector2Array = _bolts[-1]
			var mid: Vector2 = pts[pts.size() / 2]
			_bolts.append(_make_bolt(mid,
					mid + Vector2(_rng.randf_range(-150.0, 150.0),
							_rng.randf_range(60.0, 190.0)), 4))

	_alpha = 1.0
	_flash = 1.0
	set_process(true)

	var t := create_tween()
	# Two quick pulses before it dies: a single clean fade reads as a
	# cross-dissolve, not as lightning.
	t.tween_property(self, "_alpha", 0.35, duration * 0.18)
	t.tween_property(self, "_alpha", 1.0, duration * 0.10)
	t.tween_property(self, "_alpha", 0.0, duration * 0.72)
	t.parallel().tween_property(self, "_flash", 0.0, duration * 0.55)
	await t.finished

	set_process(false)
	_bolts.clear()
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


## Midpoint displacement: split each segment, push its centre sideways, repeat.
## Every pass halves the offset, which is what gives a bolt big kinks and small
## ones at the same time.
func _make_bolt(from: Vector2, to: Vector2, passes: int) -> PackedVector2Array:
	var pts := PackedVector2Array([from, to])
	var offset := from.distance_to(to) * 0.16

	for p in passes:
		var next := PackedVector2Array()
		for i in range(pts.size() - 1):
			var a := pts[i]
			var b := pts[i + 1]
			var mid := (a + b) * 0.5
			mid += (b - a).normalized().orthogonal() * _rng.randf_range(-offset, offset)
			next.append(a)
			next.append(mid)
		next.append(pts[pts.size() - 1])
		pts = next
		offset *= 0.5

	return pts


func _draw() -> void:
	if _flash > 0.001:
		var c := flash_color
		c.a *= _flash
		draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), c)

	if _alpha <= 0.001:
		return

	# Shadow first, then core over it, so every bolt is edged in red.
	for pts in _bolts:
		var s := shadow_color
		s.a *= _alpha
		draw_polyline(pts, s, shadow_width)
	for pts in _bolts:
		var c := core_color
		c.a *= _alpha
		draw_polyline(pts, c, core_width)
