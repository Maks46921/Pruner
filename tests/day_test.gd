extends SceneTree
## Тест дня: действия с ветвями и их влияние на параметры ночи. Делает снимок экрана дня.

var main: Node
var frames := 0


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _check(cond: bool, what: String) -> void:
	print(("OK   " if cond else "FAIL ") + what)


func _process(_delta: float) -> bool:
	frames += 1
	var gs = root.get_node("GameState")
	if frames == 3:
		gs.new_game()
		gs.run_seed = 7
		gs.day = 2
		gs._new_day()
		gs.sap = 3
		gs.goto("day")
	if frames == 10:
		var types := []
		for b in gs.branches:
			types.append(b.type)
		print("branches day 2: ", types)
		var pred := types.find("predator")
		var before: Dictionary = gs.night_params()
		gs.prune(pred)
		var after: Dictionary = gs.night_params()
		_check(before.flower_chance > after.flower_chance, "обрезка хищного побега убирает цветы (%.2f → %.2f)" % [before.flower_chance, after.flower_chance])
		_check(gs.sap == 4, "обрезка даёт сок")
		gs.graft_branch(pred)
		_check(gs.graft == "predator" and gs.night_params().graft == "predator", "прививка срезанной ветви")
		var th := types.find("thorn")
		var c0: float = gs.night_params().closure_base
		gs.notch(th)
		var p2: Dictionary = gs.night_params()
		_check(p2.warn_mult == 2.0, "надрез колючей ветви удлиняет предупреждение")
		_check(gs.grudge == 1 and p2.closure_base > c0 - 0.0001, "растение помнит надрез")
		_check(gs.prunes_left == 1, "осталась одна обрезка")
		gs.save_game()
		gs.branches = []
		gs.load_game()
		_check(gs.branches.size() == types.size() and gs.graft == "predator", "сохранение ветвей и прививки")
		main.current.selected = pred
		main.current.view.selected = pred
		main.current._refresh()
	if frames == 40:
		var out := OS.get_cmdline_user_args()
		if out.size() > 0:
			root.get_viewport().get_texture().get_image().save_png(out[0])
		return true
	return false
