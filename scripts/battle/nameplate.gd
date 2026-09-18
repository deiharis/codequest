extends Control
class_name Nameplate
## A combatant's name and health: a cream plate above a gold-framed bar with a
## gem socket at its left end.
##
## Builds its own nodes rather than living in a scene file, for the same reason
## Combatant does — one battle scene serves nine fights, and what the plate
## shows differs per fight.

const FRAME_TEX := preload("res://assets/ui/hp_frame.png")
const PLATE_TEX := preload("res://assets/ui/nameplate.png")

## Bug Lord only. He is the campaign, not an encounter, so he gets a frame the
## Generals do not — a crest above a long rail, with his name beneath it.
const CREST_TEX := preload("res://assets/ui/boss_crest.png")
const BOSS_RAIL_TEX := preload("res://assets/ui/boss_rail.png")
const CREST_SIZE := Vector2(300, 93)
const BOSS_RAIL_H := 30.0
## The rail crosses the skull's jaw, so the eyes stay clear above it and the
## horns fall away below. That overlap is what makes crest and bar one object.
const BOSS_RAIL_Y := 66.0
const BOSS_CH := Vector2(14, 7)     ## channel inset: x each side, y top/bottom
const BOSS_FILL := Color(0.84, 0.46, 0.13)
const BOSS_FILL_LOW := Color(0.62, 0.13, 0.11)

## Native frame height, and where the channel sits inside it. These mirror the
## texture, so changing the art means changing these four numbers with it.
const FRAME_H := 52.0
const CH_LEFT := 54.0
const CH_RIGHT := 12.0
const CH_TOP := 15.0
const CH_BOTTOM := 15.0

const PLATE_H := 44.0
const PLATE_GAP := 4.0

## Health reads as a colour before it reads as a length. Green, amber, red.
const HP_HIGH := Color(0.20, 0.72, 0.34)
const HP_MID := Color(0.91, 0.66, 0.15)
const HP_LOW := Color(0.80, 0.16, 0.18)

## The bar's fill, drawn rather than filled. A single flat rectangle reads as a
## progress widget; banding it — bright band near the top, body, shadowed
## base, lit leading edge — reads as a lit surface, which is what makes it look
## like part of the game instead of part of the editor.
class BarFill extends Control:
	var color: Color = Color.WHITE:
		set(value):
			color = value
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		if size.x <= 0.5 or size.y <= 0.5:
			return
		var w := size.x
		var h := size.y
		draw_rect(Rect2(0.0, 0.0, w, h), color)
		draw_rect(Rect2(0.0, 0.0, w, h * 0.46), color.lightened(0.26))
		draw_rect(Rect2(0.0, h * 0.10, w, maxf(1.0, h * 0.17)), color.lightened(0.55))
		draw_rect(Rect2(0.0, h * 0.74, w, h * 0.26), color.darkened(0.34))
		draw_rect(Rect2(0.0, h - maxf(1.0, h * 0.10), w, maxf(1.0, h * 0.10)),
				color.darkened(0.52))
		# The leading edge catches the light, so the bar has a front.
		var cap := minf(5.0, w)
		draw_rect(Rect2(w - cap, 0.0, cap, h), color.lightened(0.62))


var bar_width: float = 300.0
var _boss: bool = false

var _plate: NinePatchRect
var _name: Label
var _frame: NinePatchRect
var _fill: BarFill


## A sized TextureRect, built in the order Godot requires.
##
## This exists because getting it wrong is silent: until expand_mode is set, a
## TextureRect's minimum size is its texture's, so any size assigned first is
## clamped straight back up — and the node then renders at full texture size
## while every position calculated from the intended size is wrong. That bug
## has been made three times in this file and its callers. Once, here, instead.
static func fitted(tex: Texture2D, pos: Vector2, size: Vector2) -> TextureRect:
	var tr := TextureRect.new()
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = Vector2.ZERO
	tr.texture = tex
	tr.position = pos
	tr.size = size
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


func setup(title: String, width: float) -> void:
	bar_width = width
	_build()
	_name.text = title
	custom_minimum_size = Vector2(bar_width, PLATE_H + PLATE_GAP + FRAME_H)
	size = custom_minimum_size


## The Bug Lord's frame. A separate builder rather than a separate class: the
## chrome differs, the bar logic does not, so set_hp() serves both.
func setup_boss(title: String, width: float) -> void:
	bar_width = width
	_boss = true

	# The crest sits so the rail passes just under the jaw, which is what makes
	# the two read as one object rather than a picture above a bar.
	var crest := fitted(CREST_TEX,
			Vector2((bar_width - CREST_SIZE.x) * 0.5, 0), CREST_SIZE)
	add_child(crest)
	move_child(crest, 0)

	_frame = NinePatchRect.new()
	_frame.texture = BOSS_RAIL_TEX
	_frame.patch_margin_left = 22
	_frame.patch_margin_right = 22
	_frame.patch_margin_top = 10
	_frame.patch_margin_bottom = 10
	_frame.position = Vector2(0, BOSS_RAIL_Y)
	_frame.size = Vector2(bar_width, BOSS_RAIL_H)
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame)

	_fill = BarFill.new()
	_fill.position = BOSS_CH
	_fill.size = Vector2(_channel_width(), BOSS_RAIL_H - BOSS_CH.y * 2.0)
	_fill.color = BOSS_FILL
	_frame.add_child(_fill)
	_frame.move_child(_fill, 0)

	_name = Label.new()
	_name.text = title.to_upper()
	_name.position = Vector2(0, BOSS_RAIL_Y + BOSS_RAIL_H + 2)
	_name.size = Vector2(bar_width, 34)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.theme_type_variation = &"Heading"
	_name.add_theme_font_size_override(&"font_size", 20)
	_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_name)

	custom_minimum_size = Vector2(bar_width, BOSS_RAIL_Y + BOSS_RAIL_H + 32)
	size = custom_minimum_size


func _build() -> void:
	# The cream plate, sized to the bar so the two read as one object.
	_plate = NinePatchRect.new()
	_plate.texture = PLATE_TEX
	_plate.patch_margin_left = 26
	_plate.patch_margin_right = 26
	_plate.patch_margin_top = 26
	_plate.patch_margin_bottom = 26
	_plate.position = Vector2.ZERO
	_plate.size = Vector2(bar_width, PLATE_H)
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_plate)

	_name = Label.new()
	_name.text = ""
	_name.position = Vector2(16, 0)
	_name.size = Vector2(bar_width - 32, PLATE_H)
	_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Ink on cream: the one place in the game that is dark-on-light, which is
	# what makes the plate read as a physical label rather than another layer.
	_name.add_theme_color_override(&"font_color", Color(0.15, 0.12, 0.09))
	_name.add_theme_font_size_override(&"font_size", 17)
	_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate.add_child(_name)

	_frame = NinePatchRect.new()
	_frame.texture = FRAME_TEX
	_frame.patch_margin_left = 54
	_frame.patch_margin_right = 14
	_frame.patch_margin_top = 14
	_frame.patch_margin_bottom = 14
	_frame.position = Vector2(0, PLATE_H + PLATE_GAP)
	_frame.size = Vector2(bar_width, FRAME_H)
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame)

	# The fill sits in the channel, under the frame's own bevel.
	_fill = BarFill.new()
	_fill.position = Vector2(CH_LEFT, CH_TOP)
	_fill.size = Vector2(_channel_width(), FRAME_H - CH_TOP - CH_BOTTOM)
	_fill.color = HP_HIGH
	_frame.add_child(_fill)
	_frame.move_child(_fill, 0)



func _channel_width() -> float:
	if _boss:
		return maxf(1.0, bar_width - BOSS_CH.x * 2.0)
	return maxf(1.0, bar_width - CH_LEFT - CH_RIGHT)


## Drive the bar. Width and colour move together, so a bar that is nearly empty
## is also red — readable at a glance without reading the number.
func set_hp(current: int, maximum: int, time: float = 0.3) -> void:
	if _fill == null:
		return
	var ratio := clampf(float(current) / float(maxi(1, maximum)), 0.0, 1.0)
	var target := _channel_width() * ratio
	var tint: Color
	if _boss:
		# He does not pass through green and amber — he is amber, then he is
		# nearly out. Eight worlds is a long drain, and the last one should look
		# like one.
		tint = BOSS_FILL_LOW if ratio < 0.2 else BOSS_FILL
	else:
		tint = HP_LOW if ratio < 0.25 else (HP_MID if ratio < 0.5 else HP_HIGH)

	var t := create_tween().set_parallel()
	t.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	t.tween_property(_fill, "size:x", target, time)
	t.tween_property(_fill, "color", tint, time)


func set_title(title: String) -> void:
	if _name:
		_name.text = title
