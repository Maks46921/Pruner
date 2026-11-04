extends Control
## День (временная версия). Полноценная комната с растением появится на шаге 2.

const UI := preload("res://scripts/ui_kit.gd")

var info: Label
var water_btn: Button
var fert_btn: Button


func _ready() -> void:
	UI.fullscreen(self)
	RenderingServer.set_default_clear_color(UI.BG_DAY)
	var col := UI.centered_column(self, UI.BG_DAY)
	col.add_child(UI.label("День %d из %d" % [GameState.day, GameState.TOTAL_NIGHTS], 40, UI.INK))
	if GameState.last_night_result != "":
		col.add_child(UI.label(GameState.last_night_result, 18, UI.INK))
	info = UI.label("", 20, UI.INK)
	col.add_child(info)
	water_btn = UI.button("", _on_water)
	fert_btn = UI.button("", _on_fertilize)
	col.add_child(water_btn)
	col.add_child(fert_btn)
	col.add_child(UI.label("Обрезка, надрез и прививка появятся на следующем шаге.", 14, UI.INK.lightened(0.4)))
	var sleep := UI.button("Спать", GameState.start_night)
	col.add_child(sleep)
	col.add_child(UI.button("В меню", func(): GameState.goto("menu")))
	for c in col.get_children():
		if c is Button:
			c.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	sleep.grab_focus.call_deferred()
	_refresh()


func _refresh() -> void:
	info.text = "Вода: %d   Удобрение: %d   Сок: %d   Семена: %d" % [
		GameState.water, GameState.fertilizer, GameState.sap, GameState.seeds]
	water_btn.text = "Полито ✓ (рост быстрее и злее)" if GameState.watered else "Полить (−1 вода)"
	water_btn.disabled = GameState.watered or GameState.water <= 0
	fert_btn.text = "Удобрено ✓ (больше сока ночью)" if GameState.fertilized else "Удобрить (−1 удобрение)"
	fert_btn.disabled = GameState.fertilized or GameState.fertilizer <= 0


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
