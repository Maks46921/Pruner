extends Control
## День: комната с растением. Ресурсов не хватает на всё — это и есть выбор.

const UI := preload("res://scripts/ui_kit.gd")
const PlantView := preload("res://scripts/day/plant_view.gd")

const PANEL_W := 430.0

var view: Control
var info: Label
var result: Label
var card_title: Label
var card_body: Label
var prune_btn: Button
var notch_btn: Button
var graft_btn: Button
var water_btn: Button
var fert_btn: Button
var seed_btn: Button
var graft_info: Label
var selected := -1


func _ready() -> void:
	UI.fullscreen(self)
	RenderingServer.set_default_clear_color(UI.BG_DAY)
	Audio.play_music("day")

	view = PlantView.new()
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	view.offset_right = -PANEL_W
	view.branch_selected.connect(_on_branch_selected)
	add_child(view)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left = -PANEL_W
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.96, 0.93, 0.86)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	panel.add_child(outer)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 8)
	scroll.add_child(col)

	var title := "День %d из %d" % [GameState.day, GameState.TOTAL_NIGHTS]
	var sub := "Ресурсов не хватит на всё. Выберите ветвь на растении."
	if GameState.is_final():
		title = "Последний день"
		sub = "Растение заняло всю комнату. Этой ночью вы дойдёте до сердцевины и решите, чем всё кончится."
	else:
		var tn: Dictionary = GameState.TIERS[GameState.tier()]
		sub = "Этой ночью: %s. %s %s" % [tn.name.to_lower(), tn.desc, sub]
	col.add_child(_left(UI.label(title, 30, UI.INK)))
	col.add_child(_left(UI.label(sub, 14, UI.INK.lightened(0.3))))
	result = _left(UI.label(GameState.last_night_result, 14, UI.INK.lightened(0.25)))
	result.visible = GameState.last_night_result != ""
	col.add_child(result)
	info = _left(UI.label("", 16, UI.INK))
	col.add_child(info)
	col.add_child(HSeparator.new())

	card_title = _left(UI.label("Ветвь не выбрана", 20, UI.INK))
	col.add_child(card_title)
	card_body = _left(UI.label("Каждая ветвь — то, что вы встретите ночью. Срезанная ветвь ночью не вырастет, а её срез можно привить к себе.", 14, UI.INK))
	col.add_child(card_body)
	prune_btn = _btn("Обрезать", _on_prune)
	notch_btn = _btn("Надрезать", _on_notch)
	graft_btn = _btn("Привить к себе", _on_graft)
	for b in [prune_btn, notch_btn, graft_btn]:
		col.add_child(b)
	graft_info = _left(UI.label("", 15, Color(0.25, 0.45, 0.2)))
	col.add_child(graft_info)
	col.add_child(HSeparator.new())

	water_btn = _btn("", _on_water)
	fert_btn = _btn("", _on_fertilize)
	seed_btn = _btn("", _on_seed)
	for b in [water_btn, fert_btn, seed_btn]:
		col.add_child(b)
	col.add_child(_btn("В меню", func(): GameState.goto("menu")))
	# «Спать» всегда на виду, внизу панели
	var sleep := _btn("Спать", GameState.start_night)
	sleep.custom_minimum_size.y = 48
	sleep.add_theme_font_size_override("font_size", 22)
	outer.add_child(sleep)
	_refresh()


func _left(l: Label) -> Label:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.custom_minimum_size = Vector2(PANEL_W - 60, 0)
	return l


func _btn(text: String, cb: Callable) -> Button:
	var b := UI.button(text, cb)
	b.custom_minimum_size = Vector2(PANEL_W - 60, 38)
	b.add_theme_font_size_override("font_size", 16)
	return b


func _on_branch_selected(i: int) -> void:
	selected = i
	_refresh()


func _refresh() -> void:
	info.text = "Вода %d · Удобрение %d · Сок %d · Семена %d\nОбрезок на сегодня: %d" % [
		GameState.water, GameState.fertilizer, GameState.sap, GameState.seeds, GameState.prunes_left]
	if GameState.grudge > 0:
		info.text += " · Растение помнит надрезы: %d" % GameState.grudge

	var has_sel := selected >= 0 and selected < GameState.branches.size()
	prune_btn.visible = has_sel
	notch_btn.visible = has_sel
	graft_btn.visible = has_sel
	if has_sel:
		var b: Dictionary = GameState.branches[selected]
		var inf: Dictionary = GameState.BRANCH_INFO[b.type]
		card_title.text = inf.name
		var state_text := ""
		match b.state:
			"pruned":
				state_text = "Срезана: ночью её не будет."
			"notched":
				state_text = "Надрезана: " + inf.notch
			"grafted":
				state_text = "Привита к вам на эту ночь."
		card_body.text = "Ночью %s\nЕсли надрезать: %s\nЕсли срезать и привить: %s, %s\n%s" % [
			inf.night, inf.notch, inf.graft, inf.graft_desc, state_text]
		prune_btn.text = "Обрезать (+1 сок)"
		prune_btn.disabled = not GameState.can_prune(selected)
		notch_btn.text = "Надрезать (−%d сока)" % GameState.NOTCH_COST
		notch_btn.disabled = not GameState.can_notch(selected)
		graft_btn.text = "Привить к себе: %s" % inf.graft
		graft_btn.disabled = b.state != "pruned" or GameState.graft != ""
	if GameState.graft != "":
		var g: Dictionary = GameState.BRANCH_INFO[GameState.graft]
		graft_info.text = "Привито на ночь: %s, %s" % [g.graft, g.graft_desc]
	else:
		graft_info.text = ""

	water_btn.text = "Полито: растёт быстрее и злее" if GameState.watered else "Полить (−1 вода)"
	water_btn.disabled = GameState.watered or GameState.water <= 0
	fert_btn.text = "Удобрено: больше сока ночью" if GameState.fertilized else "Удобрить (−1 удобрение)"
	fert_btn.disabled = GameState.fertilized or GameState.fertilizer <= 0
	seed_btn.text = "Посадить семя (+1 удобрение)"
	seed_btn.disabled = GameState.seeds <= 0
	view.queue_redraw()


func _on_prune() -> void:
	Audio.play_sfx("cut")
	GameState.prune(selected)
	_refresh()


func _on_notch() -> void:
	Audio.play_sfx("cut", 0.2)
	GameState.notch(selected)
	_refresh()


func _on_graft() -> void:
	GameState.graft_branch(selected)
	_refresh()


func _on_water() -> void:
	GameState.water -= 1
	GameState.watered = true
	GameState.save_game()
	_refresh()


func _on_fertilize() -> void:
	GameState.fertilizer -= 1
	GameState.fertilized = true
	GameState.save_game()
	_refresh()


func _on_seed() -> void:
	GameState.plant_seed()
	_refresh()
