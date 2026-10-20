extends CanvasLayer
## Dialogue box, objective text, terror meter, fades and title cards.

signal advanced

const CHARS_PER_SEC := 55.0

var box: PanelContainer
var name_label: Label
var body: RichTextLabel
var hint: Label
var objective: Label
var meter_box: VBoxContainer
var meter: ProgressBar
var meter_label: Label
var fade: ColorRect
var title: Label
var subtitle: Label
var typing := false
var waiting := false


func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	objective = Label.new()
	objective.position = Vector2(20, 14)
	objective.add_theme_font_size_override("font_size", 22)
	_outline(objective)
	root.add_child(objective)

	meter_box = VBoxContainer.new()
	meter_box.position = Vector2(900, 12)
	meter_box.custom_minimum_size = Vector2(360, 0)
	root.add_child(meter_box)
	meter_label = Label.new()
	meter_label.add_theme_font_size_override("font_size", 20)
	_outline(meter_label)
	meter_box.add_child(meter_label)
	meter = ProgressBar.new()
	meter.custom_minimum_size = Vector2(360, 24)
	meter.max_value = 100.0
	meter.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.9, 0.2, 0.2)
	fill.set_corner_radius_all(6)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.6)
	bg.set_corner_radius_all(6)
	meter.add_theme_stylebox_override("fill", fill)
	meter.add_theme_stylebox_override("background", bg)
	meter_box.add_child(meter)
	meter_box.visible = false

	fade = ColorRect.new()
	fade.color = Color.BLACK
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Center in the space above the dialogue box so the two never overlap.
	center.offset_bottom = -200
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.add_child(center)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 18)
	center.add_child(tv)
	title = Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 84)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	tv.add_child(title)
	subtitle = Label.new()
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 26)
	tv.add_child(subtitle)

	box = PanelContainer.new()
	box.anchor_left = 0.0
	box.anchor_right = 1.0
	box.anchor_top = 1.0
	box.anchor_bottom = 1.0
	box.offset_left = 40
	box.offset_right = -40
	box.offset_top = -190
	box.offset_bottom = -20
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.1, 0.9)
	sb.set_corner_radius_all(12)
	sb.set_border_width_all(3)
	sb.border_color = Color(1, 1, 1, 0.8)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	box.add_theme_stylebox_override("panel", sb)
	root.add_child(box)
	var v := VBoxContainer.new()
	box.add_child(v)
	name_label = Label.new()
	name_label.add_theme_font_size_override("font_size", 24)
	v.add_child(name_label)
	body = RichTextLabel.new()
	body.bbcode_enabled = true
	body.fit_content = true
	body.scroll_active = false
	body.custom_minimum_size = Vector2(0, 96)
	body.add_theme_font_size_override("normal_font_size", 22)
	body.add_theme_font_size_override("italics_font_size", 22)
	body.add_theme_font_size_override("bold_font_size", 22)
	body.add_theme_font_size_override("bold_italics_font_size", 22)
	v.add_child(body)
	hint = Label.new()
	hint.text = "SPACE >>"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	v.add_child(hint)
	box.visible = false


func _outline(l: Label) -> void:
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("advance") and not event.is_echo():
		if typing:
			typing = false
		elif waiting:
			advanced.emit()


func say(speaker: String, text: String, color: Color = Color.WHITE, translation: String = "") -> void:
	box.visible = true
	name_label.text = speaker
	name_label.visible = speaker != ""
	name_label.add_theme_color_override("font_color", color)
	var full := text
	if translation != "":
		full += "\n[color=#a8d8ff][i](" + translation + ")[/i][/color]"
	body.text = full
	body.visible_characters = 0
	hint.visible = false
	typing = true
	var total := body.get_total_character_count()
	var shown := 0.0
	while typing and body.visible_characters < total:
		await get_tree().process_frame
		shown += get_process_delta_time() * CHARS_PER_SEC
		body.visible_characters = int(shown)
	typing = false
	body.visible_characters = -1
	hint.visible = true
	waiting = true
	await advanced
	waiting = false


func hide_box() -> void:
	box.visible = false


func set_objective(text: String) -> void:
	objective.text = text


func show_meter(on: bool, label: String = "") -> void:
	meter_box.visible = on
	meter_label.text = label
	meter.value = 0.0


func set_meter(v: float) -> void:
	var tw := create_tween()
	tw.tween_property(meter, "value", v, 0.2)


func fade_set(a: float) -> void:
	fade.modulate.a = a


func fade_to(a: float, dur: float) -> void:
	var tw := create_tween()
	tw.tween_property(fade, "modulate:a", a, dur)
	await tw.finished


func show_title(big: String, small: String) -> void:
	title.text = big
	subtitle.text = small
