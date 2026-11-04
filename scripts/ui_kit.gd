extends RefCounted
## Небольшие помощники для интерфейса, собранного кодом.

const BG_DAY := Color(0.93, 0.89, 0.80)
const BG_NIGHT := Color(0.05, 0.04, 0.08)
const INK := Color(0.16, 0.13, 0.10)
const PALE := Color(0.90, 0.92, 0.85)


static func fullscreen(ctrl: Control) -> void:
	ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	ctrl.offset_left = 0
	ctrl.offset_top = 0
	ctrl.offset_right = 0
	ctrl.offset_bottom = 0


static func label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func button(text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(320, 44)
	b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(func(): Audio.play_sfx("ui", 0.0))
	b.pressed.connect(callback)
	return b


## Центрированная колонка поверх фона заданного цвета.
static func centered_column(parent: Control, bg: Color) -> VBoxContainer:
	var rect := ColorRect.new()
	rect.color = bg
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fullscreen(rect)
	parent.add_child(rect)
	var center := CenterContainer.new()
	fullscreen(center)
	parent.add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.custom_minimum_size = Vector2(560, 0)
	center.add_child(col)
	return col
