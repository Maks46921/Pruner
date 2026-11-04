extends CanvasLayer
## Интерфейс ночи: время до рассвета, ресурсы, цель, сообщения, пауза.

const UI := preload("res://scripts/ui_kit.gd")

signal resume_pressed
signal menu_pressed
signal choice_made(kind: String)

var status: Label
var objective: Label
var message: Label
var hint: Label
var dawn: ColorRect
var end_panel: Label
var pause_box: Control
var choice_box: Control

var _msg_t := 0.0


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	UI.fullscreen(root)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	dawn = ColorRect.new()
	UI.fullscreen(dawn)
	dawn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dawn.color = Color(1.0, 0.75, 0.45, 0.0)
	root.add_child(dawn)

	status = _corner_label(root, 16, 12, HORIZONTAL_ALIGNMENT_LEFT, 22)
	objective = _corner_label(root, 16, 44, HORIZONTAL_ALIGNMENT_LEFT, 18)
	objective.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))

	message = UI.label("", 22, UI.PALE)
	message.set_anchors_preset(Control.PRESET_CENTER_TOP)
	message.offset_left = -400
	message.offset_right = 400
	message.offset_top = 90
	message.offset_bottom = 140
	root.add_child(message)

	hint = UI.label("WASD — движение   J / ЛКМ — удар   K / ПКМ — секатор   Esc — пауза", 15, UI.PALE.darkened(0.3))
	hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint.offset_left = -500
	hint.offset_right = 500
	hint.offset_top = -40
	hint.offset_bottom = -12
	root.add_child(hint)

	end_panel = UI.label("", 34, UI.PALE)
	UI.fullscreen(end_panel)
	end_panel.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	end_panel.visible = false
	root.add_child(end_panel)

	pause_box = Control.new()
	UI.fullscreen(pause_box)
	pause_box.visible = false
	root.add_child(pause_box)
	var col := UI.centered_column(pause_box, Color(0, 0, 0, 0.7))
	col.add_child(UI.label("Пауза", 40, UI.PALE))
	var b1 := UI.button("Продолжить", func(): resume_pressed.emit())
	var b2 := UI.button("В меню (ночь начнётся заново)", func(): menu_pressed.emit())
	for b in [b1, b2]:
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(b)

	choice_box = Control.new()
	UI.fullscreen(choice_box)
	choice_box.visible = false
	root.add_child(choice_box)
	var cc := UI.centered_column(choice_box, Color(0.08, 0.0, 0.02, 0.85))
	cc.add_child(UI.label("Сердцевина", 44, Color(0.95, 0.45, 0.45)))
	cc.add_child(UI.label("Оно бьётся под ладонью, тёплое, как живое. Секатор в другой руке.", 18, UI.PALE))
	var c1 := UI.button("Срезать растение целиком", func(): choice_made.emit("cut"))
	var c2 := UI.button("Привить его к себе полностью", func(): choice_made.emit("graft"))
	for b in [c1, c2]:
		b.custom_minimum_size = Vector2(420, 52)
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		cc.add_child(b)
	cc.add_child(UI.label("Вернуть комнату себе или стать с ним одним целым.", 15, UI.PALE.darkened(0.3)))


func _corner_label(root: Control, x: float, y: float, align: int, size: int) -> Label:
	var l := UI.label("", size, UI.PALE)
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.position = Vector2(x, y)
	root.add_child(l)
	return l


func _process(delta: float) -> void:
	_msg_t -= delta
	message.modulate.a = clampf(_msg_t, 0.0, 1.0)


func set_status(night: int, time_left: float, sap: int, hp: int, max_hp: int, tier_name: String = "") -> void:
	var t := maxi(0, int(ceil(time_left)))
	var title := "Ночь %d · %s" % [night, tier_name] if night <= GameState.TOTAL_NIGHTS else "Последняя ночь"
	status.text = "%s   ·   До рассвета %d:%02d   ·   Сок %d   ·   Здоровье %d/%d" % [
		title, t / 60, t % 60, sap, hp, max_hp]
	# В последнюю минуту экран светлеет — рассвет близко.
	dawn.color.a = clampf((60.0 - time_left) / 60.0, 0.0, 1.0) * 0.35


func set_loot(seeds: int, water: int) -> void:
	if seeds > 0 or water > 0:
		status.text += "   ·   Семена %d   ·   Вода %d" % [seeds, water]


func set_objective(text: String) -> void:
	objective.text = text


func flash(text: String, seconds: float = 3.0) -> void:
	message.text = text
	_msg_t = seconds


func show_end(text: String) -> void:
	end_panel.text = text
	end_panel.visible = true


func show_pause(on: bool) -> void:
	pause_box.visible = on


func show_choice() -> void:
	choice_box.visible = true
