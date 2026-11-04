extends Control
## Два финала: срезать растение целиком или привить его к себе.

const UI := preload("res://scripts/ui_kit.gd")

const TEXTS := {
	"cut": {
		"title": "Комната",
		"color": Color(0.95, 0.88, 0.70),
		"bg": Color(0.20, 0.17, 0.14),
		"body": "Вы режете, пока секатор не тупится, а потом режете руками. К утру на полу лежат сухие плети, а в горшке пусто. Комната оказывается больше, чем вы помнили. Солнце падает на голые доски, и впервые за долгое время вам есть где пройти от кровати до окна.\n\nТишина. Только иногда по ночам вам снится, что вы снова идёте по стеблям.",
	},
	"graft": {
		"title": "Одно целое",
		"color": Color(0.60, 0.92, 0.55),
		"bg": Color(0.04, 0.10, 0.05),
		"body": "Вы прижимаете срез к ладони, и сердцевина прирастает. Тепло идёт по руке, по плечу, по груди. Утром вы просыпаетесь и не можете сказать, где кончается кровать и начинается корень. Растение больше не растёт. Теперь растёте вы.\n\nКомната полна зелени, и в ней наконец спокойно.",
	},
}


func _ready() -> void:
	UI.fullscreen(self)
	var kind: String = GameState.ending if TEXTS.has(GameState.ending) else "cut"
	var t: Dictionary = TEXTS[kind]
	RenderingServer.set_default_clear_color(t.bg)
	var col := UI.centered_column(self, t.bg)
	col.custom_minimum_size = Vector2(720, 0)
	col.add_child(UI.label(t.title, 56, t.color))
	col.add_child(UI.label(t.body, 19, UI.PALE))
	var mins := int(GameState.play_seconds) / 60
	col.add_child(UI.label("Ночей пройдено: %d из %d · надрезов, которые растение запомнило: %d · время в игре: %d мин" % [
		GameState.nights_won, GameState.TOTAL_NIGHTS, GameState.grudge, mins], 15, UI.PALE.darkened(0.3)))
	var b := UI.button("В меню", func(): GameState.goto("menu"))
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(b)
	var nb := UI.button("Начать заново", GameState.new_game)
	nb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(nb)
