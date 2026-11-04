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

# Ветви, видимые днём. Каждая ветвь — то, что вы встретите ночью.
# {"type": String, "state": "grown" | "pruned" | "notched" | "grafted"}
var branches: Array = []
var prunes_left: int = 2
var graft: String = ""      # тип ветви, привитой на эту ночь
var grudge: int = 0         # сколько раз растение надрезали: оно помнит

const PRUNES_PER_DAY := 2
const NOTCH_COST := 2

const BRANCH_INFO := {
	"predator": {
		"name": "Хищный побег",
		"night": "раскроются хищные цветы, которые кусают тех, кто подходит близко.",
		"notch": "цветы раскрываются медленнее и кусают ближе.",
		"graft": "Шипы", "graft_desc": "иммунные клетки ранятся, касаясь вас.",
		"color": Color(0.82, 0.25, 0.35),
	},
	"immune": {
		"name": "Бледная ветвь",
		"night": "больше иммунных узлов и клеток.",
		"notch": "иммунные клетки медленнее.",
		"graft": "Хлыст", "graft_desc": "удар бьёт почти вдвое дальше.",
		"color": Color(0.65, 0.72, 0.92),
	},
	"sap": {
		"name": "Сочная ветвь",
		"night": "больше комнат с соком.",
		"notch": "каждая комната с соком даёт на 1 больше.",
		"graft": "Сокосбор", "graft_desc": "каждая срезанная комната даёт +2 сока.",
		"color": Color(0.95, 0.62, 0.15),
	},
	"thorn": {
		"name": "Колючая ветвь",
		"night": "стебли зарастают чаще, появляются колючие камеры.",
		"notch": "стебли предупреждают о зарастании вдвое дольше.",
		"graft": "Кора", "graft_desc": "+2 к здоровью на ночь.",
		"color": Color(0.45, 0.30, 0.20),
	},
	"seed": {
		"name": "Семенная ветвь",
		"night": "появятся семенные камеры, семена можно посадить днём.",
		"notch": "семенные камеры дают по 2 семени.",
		"graft": "Ночное зрение", "graft_desc": "вы видите растение шире.",
		"color": Color(0.85, 0.80, 0.45),
	},
	"water": {
		"name": "Водяная ветвь",
		"night": "появятся водяные карманы, это вода на следующий день.",
		"notch": "водяные карманы дают по 2 воды.",
		"graft": "Лёгкий шаг", "graft_desc": "вы двигаетесь на 20% быстрее.",
		"color": Color(0.35, 0.65, 0.90),
	},
}


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
	grudge = 0
	_new_day()
	save_game()
	goto("day")


## Утро: растение отрастило новые ветви, секатор снова наточен.
func _new_day() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(run_seed) + ":branches:" + str(day))
	var pool := ["predator", "immune", "sap", "thorn", "seed", "water"]
	var count := 3 + mini(day, 3)
	branches.clear()
	# С первой ночи растение показывает и пользу, и угрозу.
	var must := ["sap", "immune"] if day == 1 else ["predator", "thorn"]
	for t in must:
		branches.append({"type": t, "state": "grown"})
	while branches.size() < count:
		branches.append({"type": pool[rng.randi_range(0, pool.size() - 1)], "state": "grown"})
	# Перемешать, чтобы порядок ветвей не подсказывал тип.
	for i in range(branches.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = branches[i]
		branches[i] = branches[j]
		branches[j] = tmp
	prunes_left = PRUNES_PER_DAY
	graft = ""
	watered = false
	fertilized = false


# --- Действия дня -------------------------------------------------------------

func can_prune(i: int) -> bool:
	return prunes_left > 0 and branches[i].state in ["grown", "notched"]


func prune(i: int) -> void:
	if not can_prune(i):
		return
	branches[i].state = "pruned"
	prunes_left -= 1
	sap += 1
	save_game()


func can_notch(i: int) -> bool:
	return sap >= NOTCH_COST and branches[i].state == "grown"


func notch(i: int) -> void:
	if not can_notch(i):
		return
	branches[i].state = "notched"
	sap -= NOTCH_COST
	grudge += 1
	save_game()


## Привить срезанную ветвь к себе: способность на ближайшую ночь.
func graft_branch(i: int) -> void:
	if branches[i].state != "pruned" or graft != "":
		return
	branches[i].state = "grafted"
	graft = branches[i].type
	save_game()


func plant_seed() -> void:
	if seeds <= 0:
		return
	seeds -= 1
	fertilizer += 1
	save_game()


func count_branches(t: String, states: Array) -> int:
	var n := 0
	for b in branches:
		if b.type == t and b.state in states:
			n += 1
	return n


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
		"spawn_interval": max(6.0, 15.0 - d),
	}
	# Ветви дня: живая ветвь добавляет своё в ночь, срезанная — убирает, надрезанная — ослабляет.
	var live := ["grown", "notched"]
	var predators := count_branches("predator", live)
	var immune := count_branches("immune", live)
	var saps := count_branches("sap", live)
	var thorns := count_branches("thorn", live)
	var seed_b := count_branches("seed", live)
	var water_b := count_branches("water", live)
	p.flower_chance = 0.07 * predators
	p.flower_weak = count_branches("predator", ["notched"]) > 0
	p.nest_chance = 0.03 + 0.05 * immune + 0.01 * d
	p.max_enemies = 1 + d / 2 + immune
	p.enemy_speed_mult = 0.75 if count_branches("immune", ["notched"]) > 0 else 1.0
	p.sap_room_chance = 0.05 + 0.08 * saps
	p.sap_bonus = 1 if count_branches("sap", ["notched"]) > 0 else 0
	p.thorn_room_chance = 0.05 * thorns
	p.closure_base += 0.01 * thorns + 0.004 * grudge
	p.warn_mult = 2.0 if count_branches("thorn", ["notched"]) > 0 else 1.0
	p.seed_room_chance = 0.02 + 0.05 * seed_b
	p.seed_bonus = 1 if count_branches("seed", ["notched"]) > 0 else 0
	p.water_room_chance = 0.02 + 0.05 * water_b
	p.water_bonus = 1 if count_branches("water", ["notched"]) > 0 else 0
	p.graft = graft
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


## Итог ночи. loot: {"sap", "seeds", "water"}.
func finish_night(success: bool, loot: Dictionary, reason: String = "") -> void:
	var gained_sap := int(loot.get("sap", 0))
	var gained_seeds := int(loot.get("seeds", 0))
	var gained_water := int(loot.get("water", 0))
	if success:
		sap += gained_sap
		seeds += gained_seeds
		water += gained_water
		var parts := ["сок +%d" % gained_sap, "семена +%d" % gained_seeds]
		if gained_water > 0:
			parts.append("вода +%d" % gained_water)
		last_night_result = "%s Добыча: %s." % [reason if reason != "" else "Вы вернулись до рассвета.", ", ".join(parts)]
	else:
		var lost := _lose_one_resource()
		last_night_result = "%s Добыча ночи потеряна%s." % [reason if reason != "" else "Рассвет застал вас внутри.", lost]
	day += 1
	water = mini(water + 1, 6)
	phase = "ending" if day > TOTAL_NIGHTS else "day"
	if phase == "day":
		_new_day()
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
		"version": 2,
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
		"branches": branches,
		"prunes_left": prunes_left,
		"graft": graft,
		"grudge": grudge,
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
	branches = []
	for b in d.get("branches", []):
		if typeof(b) == TYPE_DICTIONARY:
			branches.append({"type": str(b.get("type", "sap")), "state": str(b.get("state", "grown"))})
	prunes_left = int(d.get("prunes_left", PRUNES_PER_DAY))
	graft = str(d.get("graft", ""))
	grudge = int(d.get("grudge", 0))
	if branches.is_empty() and phase == "day":
		_new_day()


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
