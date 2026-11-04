extends Node
## Глобальное состояние игры: сутки, ресурсы, решения дня, сохранение.

signal scene_requested(scene_name: String)

const SAVE_PATH := "user://save.json"
const TOTAL_NIGHTS := 6

var run_seed: int = 0
var day: int = 1
var phase: String = "day"  # "day" | "night" | "ending"

# Ресурсы дня
var water: int = 3
var fertilizer: int = 2
var sap: int = 0
var seeds: int = 0

# Решения текущего дня (влияют на ближайшую ночь)
var watered: bool = false
var fertilized: bool = false

var last_night_result: String = ""


func _ready() -> void:
	_setup_input()


# --- Управление -------------------------------------------------------------

func _setup_input() -> void:
	_add_action("move_left", [KEY_A, KEY_LEFT])
	_add_action("move_right", [KEY_D, KEY_RIGHT])
	_add_action("move_up", [KEY_W, KEY_UP])
	_add_action("move_down", [KEY_S, KEY_DOWN])
	_add_action("attack", [KEY_J, KEY_SPACE], [MOUSE_BUTTON_LEFT])
	_add_action("prune", [KEY_K, KEY_E], [MOUSE_BUTTON_RIGHT])
	_add_action("pause", [KEY_ESCAPE])


func _add_action(action: String, keys: Array, mouse_buttons: Array = []) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
	for b in mouse_buttons:
		var mb := InputEventMouseButton.new()
		mb.button_index = b
		InputMap.action_add_event(action, mb)


# --- Переходы между сценами --------------------------------------------------

func goto(scene_name: String) -> void:
	scene_requested.emit(scene_name)


func start_night() -> void:
	phase = "night"
	save_game()
	goto("night")


func continue_game() -> void:
	if load_game():
		goto(phase)
	else:
		new_game()


func new_game() -> void:
	randomize()
	run_seed = randi()
	day = 1
	phase = "day"
	water = 3
	fertilizer = 2
	sap = 0
	seeds = 0
	watered = false
	fertilized = false
	last_night_result = ""
	save_game()
	goto("day")


# --- Параметры ночи ------------------------------------------------------------

func night_seed() -> int:
	return hash(str(run_seed) + ":" + str(day))


## Всё, что сделано днём, превращается здесь в параметры ночного забега.
func night_params() -> Dictionary:
	var d := day
	var p := {
		"duration": 360.0 + (d - 1) * 24.0,   # 6–8 минут реального времени
		"core_distance": 2200.0 + d * 250.0,
		"leader_ticks": 18,                   # главный побег растёт раз в 9 с
		"branch_chance": 0.30 + 0.04 * d,
		"growth_mult": 1.0,
		"closure_base": 0.015 + 0.006 * d,
		"closure_growth": 0.05,
		"initial_branches": 10 + 2 * d,
		"sap_room_chance": 0.12,
		"nest_chance": 0.07 + 0.015 * d,
		"max_enemies": 2 + d,
		"spawn_interval": max(6.0, 15.0 - d),
	}
	if watered:
		# Полили — растение растёт быстрее и агрессивнее.
		p.branch_chance += 0.2
		p.growth_mult = 1.4
		p.leader_ticks = 13
		p.closure_base += 0.015
		p.max_enemies += 1
	if fertilized:
		# Удобрили — больше комнат с ресурсами.
		p.sap_room_chance += 0.15
	return p


## Итог ночи. Возвращает текст для утреннего экрана.
func finish_night(success: bool, sap_gained: int, seeds_gained: int, reason: String = "") -> void:
	if success:
		sap += sap_gained
		seeds += seeds_gained
		last_night_result = "%s Сок +%d, семена +%d." % [reason if reason != "" else "Вы вернулись до рассвета.", sap_gained, seeds_gained]
	else:
		var lost := _lose_one_resource()
		last_night_result = "%s Добыча ночи потеряна%s." % [reason if reason != "" else "Рассвет застал вас внутри.", lost]
	day += 1
	water = min(water + 1, 6)
	watered = false
	fertilized = false
	phase = "ending" if day > TOTAL_NIGHTS else "day"
	save_game()


func _lose_one_resource() -> String:
	if water > 0:
		water -= 1
		return ", растение забрало 1 воду"
	if fertilizer > 0:
		fertilizer -= 1
		return ", растение забрало 1 удобрение"
	if sap > 0:
		sap -= 1
		return ", растение забрало 1 сок"
	return ""


# --- Сохранение ----------------------------------------------------------------

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func to_dict() -> Dictionary:
	return {
		"version": 1,
		"run_seed": run_seed,
		"day": day,
		"phase": phase,
		"water": water,
		"fertilizer": fertilizer,
		"sap": sap,
		"seeds": seeds,
		"watered": watered,
		"fertilized": fertilized,
		"last_night_result": last_night_result,
	}


func from_dict(d: Dictionary) -> void:
	run_seed = int(d.get("run_seed", 0))
	day = int(d.get("day", 1))
	phase = str(d.get("phase", "day"))
	water = int(d.get("water", 3))
	fertilizer = int(d.get("fertilizer", 2))
	sap = int(d.get("sap", 0))
	seeds = int(d.get("seeds", 0))
	watered = bool(d.get("watered", false))
	fertilized = bool(d.get("fertilized", false))
	last_night_result = str(d.get("last_night_result", ""))


func save_game() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Не удалось сохранить игру: %s" % FileAccess.get_open_error())
		return
	f.store_string(JSON.stringify(to_dict(), "\t"))


func load_game() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return false
	from_dict(data)
	return true
