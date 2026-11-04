extends Control
## Главное меню.

const UI := preload("res://scripts/ui_kit.gd")


func _ready() -> void:
	UI.fullscreen(self)
	var col := UI.centered_column(self, UI.BG_NIGHT)
	col.add_child(UI.label("СЕКАТОР", 64, Color(0.55, 0.85, 0.45)))
	col.add_child(UI.label("Днём вы ухаживаете за растением. Ночью проходите его насквозь.", 18, UI.PALE))
	col.add_child(Control.new())
	var cont := UI.button("Продолжить", GameState.continue_game)
	cont.disabled = not GameState.has_save()
	col.add_child(cont)
	col.add_child(UI.button("Новая игра", GameState.new_game))
	col.add_child(UI.button("Выход", func(): get_tree().quit()))
	for c in col.get_children():
		if c is Button:
			c.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if not cont.disabled:
		cont.grab_focus.call_deferred()
