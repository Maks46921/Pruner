extends Control
## Финал (временная заглушка до шага 3).

const UI := preload("res://scripts/ui_kit.gd")


func _ready() -> void:
	UI.fullscreen(self)
	var col := UI.centered_column(self, UI.BG_NIGHT)
	col.add_child(UI.label("Шесть ночей позади", 40, UI.PALE))
	col.add_child(UI.label(GameState.last_night_result, 18, UI.PALE))
	col.add_child(UI.label("Финальная ночь и два финала появятся на шаге 3.", 18, UI.PALE))
	var b := UI.button("В меню", func(): GameState.goto("menu"))
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(b)
