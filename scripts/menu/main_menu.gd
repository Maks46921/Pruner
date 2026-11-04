extends Control
## Главное меню: продолжить, новая игра, как играть, настройки.

const UI := preload("res://scripts/ui_kit.gd")

const HOW_TO := """День. Кликните ветвь растения. Каждая ветвь — то, что вы встретите ночью. Обрежьте её (2 раза в день, +1 сок), и ночью её не будет. Надрежьте (−2 сока), и угроза ослабнет, но растение запомнит. Срезанную ветвь можно привить к себе: это способность на одну ночь. Полив ускоряет рост, удобрение даёт больше сока.

Ночь. WASD — движение, J или ЛКМ — удар, K или ПКМ — секатор. Растение растёт прямо при вас: пунктир показывает, где прорастёт побег, красный пульс — какой стебель скоро зарастёт. Секатор вскрывает заросшее, срезает комнаты и подрезает побеги. Идите за золотым побегом к сердцевине, возьмите узел и вернитесь к жёлтому кольцу до рассвета.

Шесть суток, три яруса, одна сердцевина и два финала."""

var main_col: VBoxContainer
var how_box: Control
var settings_box: Control


func _ready() -> void:
	UI.fullscreen(self)
	Audio.play_music("night")
	RenderingServer.set_default_clear_color(UI.BG_NIGHT)
	main_col = UI.centered_column(self, UI.BG_NIGHT)
	main_col.add_child(UI.label("СЕКАТОР", 64, Color(0.55, 0.85, 0.45)))
	main_col.add_child(UI.label("Днём вы ухаживаете за растением. Ночью проходите его насквозь.", 18, UI.PALE))
	main_col.add_child(Control.new())
	var cont := UI.button("Продолжить", GameState.continue_game)
	cont.disabled = not GameState.has_save()
	main_col.add_child(cont)
	main_col.add_child(UI.button("Новая игра", GameState.new_game))
	main_col.add_child(UI.button("Как играть", func(): _show(how_box)))
	main_col.add_child(UI.button("Настройки", func(): _show(settings_box)))
	main_col.add_child(UI.button("Выход", func(): get_tree().quit()))
	_center_buttons(main_col)
	if not cont.disabled:
		cont.grab_focus.call_deferred()

	how_box = _overlay()
	var hc := UI.centered_column(how_box, Color(0.05, 0.04, 0.08, 0.97))
	hc.custom_minimum_size = Vector2(760, 0)
	hc.add_child(UI.label("Как играть", 36, UI.PALE))
	var how := UI.label(HOW_TO, 17, UI.PALE)
	how.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	hc.add_child(how)
	hc.add_child(UI.button("Назад", func(): _show(null)))
	_center_buttons(hc)

	settings_box = _overlay()
	var sc := UI.centered_column(settings_box, Color(0.05, 0.04, 0.08, 0.97))
	sc.add_child(UI.label("Настройки", 36, UI.PALE))
	sc.add_child(_slider("Музыка", Audio.music_volume, Audio.set_music_volume))
	sc.add_child(_slider("Звуки", Audio.sfx_volume, Audio.set_sfx_volume))
	var fs := CheckButton.new()
	fs.text = "Полный экран"
	fs.button_pressed = Audio.fullscreen
	fs.add_theme_font_size_override("font_size", 20)
	fs.toggled.connect(Audio.set_fullscreen)
	fs.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	sc.add_child(fs)
	sc.add_child(UI.button("Назад", func(): _show(null)))
	_center_buttons(sc)


func _overlay() -> Control:
	var c := Control.new()
	UI.fullscreen(c)
	c.visible = false
	add_child(c)
	return c


func _show(box: Control) -> void:
	how_box.visible = box == how_box
	settings_box.visible = box == settings_box


func _center_buttons(col: Container) -> void:
	for c in col.get_children():
		if c is Button:
			c.size_flags_horizontal = Control.SIZE_SHRINK_CENTER


func _slider(title: String, value: float, cb: Callable) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	var l := UI.label(title, 20, UI.PALE)
	l.custom_minimum_size = Vector2(120, 0)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(280, 24)
	s.value_changed.connect(cb)
	row.add_child(s)
	return row


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and (how_box.visible or settings_box.visible):
		_show(null)
