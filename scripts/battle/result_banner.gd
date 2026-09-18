extends Control
class_name ResultBanner
## The beat between the last blow and the fade out. Without it a fight simply
## stops; with it, it ends.

const HOLD := 1.25


## Sweep a banner across the screen, hold, and leave. Awaitable, so the battle
## does not route anywhere until the player has had the moment.
func show_result(title: String, subtitle: String, accent: Color) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var view := get_viewport_rect().size

	# A dark band rather than a full-screen wash: the fighters stay visible,
	# which matters when the thing being celebrated is lying on the floor.
	var band := ColorRect.new()
	band.color = Color(0.03, 0.04, 0.07, 0.86)
	band.position = Vector2(0, view.y * 0.34)
	band.size = Vector2(view.x, 0)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(band)

	var edge := ColorRect.new()
	edge.color = accent
	edge.position = Vector2(0, view.y * 0.34)
	edge.size = Vector2(view.x, 2)
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(edge)

	var head := Label.new()
	head.text = title
	head.theme_type_variation = &"Title"
	head.add_theme_color_override(&"font_color", accent)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.position = Vector2(0, view.y * 0.36)
	head.size = Vector2(view.x, 70)
	head.modulate.a = 0.0
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(head)

	var sub := Label.new()
	sub.text = subtitle
	sub.theme_type_variation = &"Subtle"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.position = Vector2(0, view.y * 0.36 + 62)
	sub.size = Vector2(view.x, 30)
	sub.modulate.a = 0.0
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sub)

	var band_h := 120.0
	var open := create_tween().set_parallel()
	open.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	open.tween_property(band, "size:y", band_h, 0.22)
	open.tween_property(band, "position:y", view.y * 0.34 - band_h * 0.12, 0.22)
	open.tween_property(edge, "position:y", view.y * 0.34 - band_h * 0.12, 0.22)
	await open.finished

	# Text arrives after the band, not with it — a title that slides in with its
	# own background reads as one graphic; arriving after reads as an event.
	var t := create_tween().set_parallel()
	t.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(head, "modulate:a", 1.0, 0.18)
	t.tween_property(head, "position:y", view.y * 0.36 - 6, 0.26)
	t.chain().tween_property(sub, "modulate:a", 1.0, 0.20)
	await t.finished

	await get_tree().create_timer(HOLD).timeout

	var out := create_tween().set_parallel()
	out.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	out.tween_property(self, "modulate:a", 0.0, 0.3)
	await out.finished
	queue_free()
