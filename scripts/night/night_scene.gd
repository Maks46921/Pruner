extends Node2D
## Ночь: забег внутри растения в реальном времени.

const UI := preload("res://scripts/ui_kit.gd")
const PlantGraph := preload("res://scripts/night/plant_graph.gd")
const Player := preload("res://scripts/night/player.gd")
const ImmuneCell := preload("res://scripts/night/immune_cell.gd")
const Hud := preload("res://scripts/night/hud.gd")

const ATTACK_RANGE := 54.0
const ATTACK_ARC := 1.2  # радиан в каждую сторону

var graph: Node2D
var player: Node2D
var enemies: Node2D
var hud: CanvasLayer
var params: Dictionary

var time_left := 0.0
var sap_collected := 0
var seeds_collected := 0
var reached_core := false
var ended := false
var _spawn_acc := 0.0


func _ready() -> void:
	RenderingServer.set_default_clear_color(UI.BG_NIGHT)
	params = GameState.night_params()
	time_left = params.duration

	graph = PlantGraph.new()
	add_child(graph)
	graph.setup(params, GameState.night_seed())
	graph.core_revealed.connect(func(_p): hud.flash("Сердцевина проросла! Узел ждёт."))

	enemies = Node2D.new()
	add_child(enemies)

	player = Player.new()
	player.graph = graph
	player.night = self
	player.died.connect(func(): _end(false, "Растение вытолкнуло вас наружу."))
	add_child(player)

	var cam := Camera2D.new()
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 6.0
	player.add_child(cam)
	cam.make_current()

	hud = Hud.new()
	hud.resume_pressed.connect(_toggle_pause)
	hud.menu_pressed.connect(func(): GameState.goto("menu"))
	add_child(hud)
	var extras := ""
	if GameState.watered:
		extras += " Растение полито: оно растёт быстрее и злее."
	if GameState.fertilized:
		extras += " Удобрено: больше комнат с соком."
	hud.flash("Ночь %d. Доберитесь до сердцевины и вернитесь до рассвета.%s" % [GameState.day, extras], 6.0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not ended:
		_toggle_pause()
		get_viewport().set_input_as_handled()


func _toggle_pause() -> void:
	get_tree().paused = not get_tree().paused
	hud.show_pause(get_tree().paused)


func _physics_process(delta: float) -> void:
	if ended:
		return
	time_left -= delta
	_spawn_enemies(delta)

	if not reached_core and graph.core_index >= 0:
		var core: Vector2 = graph.node_pos(graph.core_index)
		if player.position.distance_to(core) < graph.CORE_RADIUS * 0.8:
			reached_core = true
			sap_collected += 2
			seeds_collected += 1
			hud.flash("Узел взят: сок +2, семя +1. Возвращайтесь к входу!", 4.0)

	if reached_core and player.position.distance_to(graph.node_pos(graph.entry_index)) < graph.ROOM_RADIUS * 0.7:
		_end(true, "Вы вернулись до рассвета.")
		return
	if time_left <= 0.0:
		_end(false, "Рассвет застал вас внутри.")
		return

	# Цель и стрелка-подсказка
	if reached_core:
		player.target = graph.node_pos(graph.entry_index)
		hud.set_objective("Цель: вернуться к входу (жёлтое кольцо)")
	elif graph.core_index >= 0:
		player.target = graph.node_pos(graph.core_index)
		hud.set_objective("Цель: добраться до сердцевины")
	else:
		player.target = graph.node_pos(graph.leader)
		hud.set_objective("Цель: следуйте за главным побегом (золотой пунктир)")
	hud.set_status(GameState.day, time_left, sap_collected, player.hp, player.max_hp)


func _spawn_enemies(delta: float) -> void:
	_spawn_acc += delta
	if _spawn_acc < float(params.spawn_interval):
		return
	_spawn_acc = 0.0
	if enemies.get_child_count() >= int(params.max_enemies):
		return
	var pos: Vector2 = graph.random_node_pos("nest")
	if pos == graph.node_pos(graph.entry_index):
		pos = graph.random_node_pos("bud")
	if pos.distance_to(player.position) < 260.0:
		return
	var cell := ImmuneCell.new()
	cell.graph = graph
	cell.player = player
	cell.position = pos
	cell.killed.connect(_on_cell_killed)
	enemies.add_child(cell)


func _on_cell_killed(_pos: Vector2) -> void:
	if randf() < 0.3:
		sap_collected += 1
		hud.flash("Клетка распалась: сок +1", 1.5)


func player_attack(pos: Vector2, facing: Vector2) -> void:
	for e in enemies.get_children():
		var to: Vector2 = e.position - pos
		if to.length() <= ATTACK_RANGE and absf(facing.angle_to(to)) <= ATTACK_ARC:
			e.take_hit(to.normalized())


func player_prune(pos: Vector2) -> void:
	var res: Dictionary = graph.use_secateur(pos, sap_collected)
	if res.action == "none":
		return
	sap_collected = maxi(0, sap_collected + int(res.get("sap", 0)))
	if res.has("hp"):
		player.take_damage(-int(res.hp), pos + Vector2(0, 1))
	hud.flash(res.text, 2.0)


func _end(success: bool, text: String) -> void:
	if ended:
		return
	ended = true
	player.set_physics_process(false)
	graph.set_physics_process(false)
	for e in enemies.get_children():
		e.set_physics_process(false)
	var detail := "Сок +%d, семена +%d" % [sap_collected, seeds_collected] if success else "Добыча ночи потеряна"
	hud.show_end("%s\n%s" % [text, detail])
	await get_tree().create_timer(2.5).timeout
	GameState.finish_night(success, sap_collected, seeds_collected, text)
	GameState.goto(GameState.phase)
