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
	await get_tree().create_timer(animation_length(anim)).timeout
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


## Lunge toward the opponent, swing, and stay there. Caller decides when to
## send us home, so damage and VFX can land while we are still forward.
func play_attack() -> void:
	var t := create_tween()
	t.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	t.tween_property(self, "position", _home + lunge_offset, lunge_time)
	await t.finished
	await play_once(&"attack")


func return_home() -> void:
	var t := create_tween()
	t.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(self, "position", _home, lunge_time * 1.4)
	await t.finished


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
