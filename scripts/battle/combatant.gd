extends Node2D
class_name Combatant
## One fighter. The hero and every enemy are the same class — that symmetry is
## what lets a correct answer and a wrong answer run the same code with the
## arguments swapped.
##
## Owns its sprite, its HP, and its own movement. Knows nothing about questions,
## turns, or who it is fighting.

signal hp_changed(current: int, maximum: int)
signal died

## How far this fighter lunges toward its opponent when attacking.
@export var lunge_offset: Vector2 = Vector2(140, -90)
@export var lunge_time: float = 0.18

@export_group("Weight")
## The wind-up before a strike: a short pull back the other way, as a fraction
## of the lunge. A lunge that starts from rest reads as a drift; one that starts
## from a wind-up reads as a decision.
@export var anticipate_time: float = 0.10
@export var anticipate_fraction: float = 0.22
## Squash on the wind-up, stretch on the strike, as a fraction of normal size.
@export var squash: float = 0.07
## How far a fighter is knocked back by a blow, and how long before it recovers.
@export var recoil_distance: float = 26.0
@export var recoil_out: float = 0.07
@export var recoil_back: float = 0.28

## Sprite sheets were authored at differing frame heights, so every sheet is
## rescaled to this height before display. Without it a character changes size
## whenever it switches animation.
const REFERENCE_FRAME_HEIGHT := 443.0

var max_hp: int = 100
var current_hp: int = 100
var is_alive: bool = true
## Extra multiplier applied only to the attack animation. See EnemyData.
var attack_scale: float = 1.0

var sprite: AnimatedSprite2D

var _frames: Dictionary = {}     ## StringName -> SpriteFrames
var _home: Vector2 = Vector2.ZERO
## Fighters are not drawn at 1:1 — `configure` scales each one. Squash and
## stretch multiply this rather than Vector2.ONE, or every blow would snap the
## fighter back to unscaled size.
var _base_scale: Vector2 = Vector2.ONE


func _ensure_sprite() -> void:
	if sprite == null:
		sprite = AnimatedSprite2D.new()
		sprite.name = "Sprite"
		sprite.centered = true
		add_child(sprite)


## frames: { "idle": SpriteFrames, "attack": ..., "damage": ..., "defeat": ... }
## Extra keys are allowed (the hero passes "ultimate" too).
func configure(frames: Dictionary, hp: int, scale_factor: float,
		ground_offset: Vector2 = Vector2.ZERO, atk_scale: float = 1.0) -> void:
	_ensure_sprite()
	_frames = frames
	attack_scale = atk_scale
	max_hp = maxi(1, hp)          # never let a bad resource divide by zero
	current_hp = max_hp
	is_alive = true
	scale = Vector2.ONE * scale_factor
	_base_scale = scale
	position += ground_offset
	_home = position
	play_loop(&"idle")
	hp_changed.emit(current_hp, max_hp)


## Swap in a sheet, normalised so the character keeps its size across sheets.
func _apply_frames(f: SpriteFrames, anim: StringName) -> void:
	sprite.sprite_frames = f
	var h := _frame_height(f)
	var s := (REFERENCE_FRAME_HEIGHT / h) if h > 0.0 else 1.0
	if anim == &"attack":
		s *= attack_scale
	sprite.scale = Vector2.ONE * s
	sprite.play(&"default")


func _frame_height(f: SpriteFrames) -> float:
	if f == null or f.get_frame_count(&"default") == 0:
		return 0.0
	var tex := f.get_frame_texture(&"default", 0)
	return float(tex.get_height()) if tex else 0.0


## Start a looping animation and return immediately.
func play_loop(anim: StringName) -> void:
	var f: SpriteFrames = _frames.get(anim)
	if f == null:
		return
	_apply_frames(f, anim)


## Play an animation once and return when it has finished.
##
## Note: this waits on a timer sized from the frame count and fps rather than on
## `animation_finished`. That signal never fires while an animation is set to
## loop, and every SpriteFrames in this project currently has loop enabled.
## Timing from the data is immune to that, and needs no resource mutation.
func play_once(anim: StringName) -> void:
	var f: SpriteFrames = _frames.get(anim)
	if f == null:
		return
	_apply_frames(f, anim)
	await get_tree().create_timer(animation_length(anim), false).timeout
	if is_alive:
		play_loop(&"idle")


func animation_length(anim: StringName) -> float:
	var f: SpriteFrames = _frames.get(anim)
	if f == null:
		return 0.0
	var count := f.get_frame_count(&"default")
	var fps := f.get_animation_speed(&"default")
	if fps <= 0.0:
		fps = 8.0
	return float(count) / fps


## Wind up, strike, and stay there. Caller decides when to send us home, so
## damage and VFX can land while we are still forward.
func play_attack() -> void:
	var back := _home - lunge_offset * anticipate_fraction
	var a := create_tween().set_parallel()
	a.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	a.tween_property(self, "position", back, anticipate_time)
	a.tween_property(self, "scale",
			_base_scale * Vector2(1.0 + squash, 1.0 - squash), anticipate_time)
	await a.finished

	# EASE_IN, not EASE_OUT. A strike accelerates into its target; easing out
	# decelerates into it, which is exactly what made the old lunge feel soft.
	var t := create_tween().set_parallel()
	t.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(self, "position", _home + lunge_offset, lunge_time)
	t.tween_property(self, "scale",
			_base_scale * Vector2(1.0 - squash, 1.0 + squash), lunge_time)
	await t.finished

	await play_once(&"attack")


## Back to the mark, overshooting slightly and settling — the follow-through.
func return_home() -> void:
	var t := create_tween().set_parallel()
	t.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(self, "position", _home, lunge_time * 1.4)
	t.tween_property(self, "scale", _base_scale, lunge_time * 1.4)
	await t.finished


## Knocked back by a blow, then recovering. `from` is the attacker's position,
## because a fighter has no idea who hit it and the direction is the whole point.
##
## Deliberately not awaitable: it runs underneath the damage animation. Awaiting
## it would add a third of a second to every exchange for no added information.
func recoil(from: Vector2) -> void:
	var dir := position - from
	dir = dir.normalized() if dir.length() > 1.0 else Vector2.RIGHT

	var t := create_tween()
	t.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUINT)
	t.tween_property(self, "position", _home + dir * recoil_distance, recoil_out)
	t.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(self, "position", _home, recoil_back)


func apply_damage(amount: int) -> void:
	if not is_alive:
		return
	current_hp = clampi(current_hp - amount, 0, max_hp)
	hp_changed.emit(current_hp, max_hp)
	flash()
	if current_hp == 0:
		is_alive = false
		died.emit()


## Brief white flash. The cheapest hit feedback there is, and the most effective.
func flash(duration: float = 0.09) -> void:
	if sprite == null:
		return
	sprite.modulate = Color(6.0, 6.0, 6.0)
	var t := create_tween()
	t.tween_property(sprite, "modulate", Color.WHITE, duration)


func play_damage() -> void:
	await play_once(&"damage")


func play_defeat() -> void:
	is_alive = false
	await play_once(&"defeat")
	# Hold the last frame rather than snapping back to idle.
	var f: SpriteFrames = _frames.get(&"defeat")
	if f != null:
		_apply_frames(f, &"defeat")
		sprite.frame = maxi(0, f.get_frame_count(&"default") - 1)
		sprite.pause()
