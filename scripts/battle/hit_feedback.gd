extends Node2D
class_name HitFeedback
## Damage numbers and screen shake: the two cheapest things that turn "the
## numbers changed" into "I hit it".
##
## Lives above the fighters and below the UI. Owns no battle state — it is told
## what happened and shows it.

## How far a number drifts up before it fades, and how long it lives.
@export var rise: float = 62.0
@export var life: float = 0.85
@export var damage_color: Color = Color(1.0, 0.86, 0.32)
@export var hero_hurt_color: Color = Color(1.0, 0.42, 0.40)

## Shake is offset on the node the battle passes in, decaying to nothing.
@export var shake_falloff: float = 9.0

var _shake_target: Node2D
var _shake_home: Vector2 = Vector2.ZERO
var _shake: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	set_process(false)


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
