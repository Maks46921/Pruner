extends Node2D
## Ночь: забег внутри растения в реальном времени.

const UI := preload("res://scripts/ui_kit.gd")
const PlantGraph := preload("res://scripts/night/plant_graph.gd")
const Player := preload("res://scripts/night/player.gd")
const ImmuneCell := preload("res://scripts/night/immune_cell.gd")
const Hud := preload("res://scripts/night/hud.gd")
const PredatorFlower := preload("res://scripts/night/predator_flower.gd")

const THORN_PERIOD := 2.0
const GRAFT_TEXT := {
	"predator": "Шипы: клетки ранятся о вас.",
	"immune": "Хлыст: удар бьёт дальше.",
	"sap": "Сокосбор: комнаты дают больше сока.",
	"thorn": "Кора: +2 к здоровью.",
	"seed": "Ночное зрение: вы видите шире.",
	"water": "Лёгкий шаг: вы быстрее.",
}

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
var water_collected := 0
var attack_range := ATTACK_RANGE
var _thorn_t := 0.0
var reached_core := false
var ended := false
var _spawn_acc := 0.0


func _ready() -> void:
	RenderingServer.set_default_clear_color(UI.BG_NIGHT)
	params = GameState.night_params()
	time_left = params.duration

	graph = PlantGraph.new()
	add_child(graph)
	graph.room_grown.connect(_on_room_grown)
	enemies = Node2D.new()
	graph.setup(params, GameState.night_seed())
	RenderingServer.set_default_clear_color(graph.background)
	Audio.play_music("final" if params.final else "night")
	graph.stem_warning.connect(_on_stem_warning)
	graph.sprouted.connect(_on_sprouted)
	graph.core_revealed.connect(func(_p): hud.flash("Сердцевина проросла! Узел ждёт."))

	add_child(enemies)

	player = Player.new()
	player.graph = graph
	player.night = self
	_apply_graft()
	player.died.connect(func(): _end(false, "Растение вытолкнуло вас наружу."))
	add_child(player)

	var cam := Camera2D.new()
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 6.0
	player.add_child(cam)
	cam.make_current()
	if params.get("graft", "") == "seed":
		cam.zoom = Vector2(0.72, 0.72)
	# Цветы, которые уже стоят к началу ночи
	for i in graph.nodes.size():
		if graph.nodes[i].kind == "flower" and graph.nodes[i].grow >= 1.0:
			_on_room_grown(i, "flower")

	hud = Hud.new()
	hud.resume_pressed.connect(_toggle_pause)
	hud.menu_pressed.connect(func(): GameState.goto("menu"))
	add_child(hud)
	var extras := ""
	if GameState.watered:
		extras += " Растение полито: оно растёт быстрее и злее."
	if GameState.fertilized:
		extras += " Удобрено: больше комнат с соком."
	var g: String = params.get("graft", "")
	if g != "":
		extras += " Привито: " + GRAFT_TEXT.get(g, "")
	hud.choice_made.connect(_on_choice)
	var tier: Dictionary = GameState.TIERS[params.tier]
	if params.final:
		# В финал вы берёте с собой весь сок, накопленный за шесть дней.
		sap_collected = GameState.sap
		hud.flash("Последняя ночь. Путь к сердцевине зарос. Весь ваш сок (%d) с вами.%s" % [sap_collected, extras], 6.0)
	else:
		hud.flash("Ночь %d · %s. %s Доберитесь до сердцевины и вернитесь до рассвета.%s" % [
			GameState.day, tier.name, tier.desc, extras], 7.0)


func _exit_tree() -> void:
	Engine.time_scale = 1.0


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not ended and not hud.choice_box.visible:
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
	_thorns(delta)
	_slow_motion(delta)

	if not reached_core and graph.core_index >= 0:
		var core: Vector2 = graph.node_pos(graph.core_index)
		if player.position.distance_to(core) < graph.CORE_RADIUS * 0.8:
			reached_core = true
			if params.final:
				Engine.time_scale = 1.0
				get_tree().paused = true
				hud.show_choice()
				return
			sap_collected += 2
			seeds_collected += 1
			hud.flash("Узел взят: сок +2, семя +1. Возвращайтесь к входу!", 4.0)

	if reached_core and player.position.distance_to(graph.node_pos(graph.entry_index)) < graph.ROOM_RADIUS * 0.7:
		_end(true, "Вы вернулись до рассвета.")
		return
	if time_left <= 0.0:
		_end(false, "Рассвет застал вас внутри.")
		return
	if params.final:
		player.target = graph.node_pos(graph.core_index)
		hud.set_objective("Цель: сердцевина")
		hud.set_status(GameState.day, time_left, sap_collected, player.hp, player.max_hp, "Сердцевина")
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
	hud.set_status(GameState.day, time_left, sap_collected, player.hp, player.max_hp, GameState.TIERS[params.tier].name)
	hud.set_loot(seeds_collected, water_collected)


## Лёгкое замедление, когда рядом вот-вот что-то прорастёт или зарастёт: без паники.
func _slow_motion(delta: float) -> void:
	var target_scale := 0.75 if graph.danger_near(player.position, 110.0) else 1.0
	Engine.time_scale = move_toward(Engine.time_scale, target_scale, delta * 3.0)


func _on_stem_warning(i: int) -> void:
	var e: Dictionary = graph.edges[i]
	if player and graph.node_pos(e.a).distance_to(player.position) < 700.0:
		Audio.play_sfx("close", 0.1, 0.5)


func _on_sprouted(pos: Vector2) -> void:
	if player and pos.distance_to(player.position) < 600.0:
		Audio.play_sfx("grow", 0.15, 0.3)


func _on_choice(kind: String) -> void:
	get_tree().paused = false
	ended = true
	GameState.choose_ending(kind)
	GameState.goto("ending")


func _apply_graft() -> void:
	match params.get("graft", ""):
		"thorn":
			player.max_hp += 2
			player.hp = player.max_hp
		"water":
			player.speed_mult = 1.2
		"immune":
			attack_range = ATTACK_RANGE * 1.8
			player.swing_radius = 46.0 * 1.8


func _on_room_grown(index: int, kind: String) -> void:
	if kind != "flower" or player == null:
		return
	var f := PredatorFlower.new()
	f.graph = graph
	f.player = player
	f.room_index = index
	f.weak = bool(params.get("flower_weak", false))
	f.position = graph.node_pos(index)
	enemies.add_child(f)


## Колючие камеры колют каждые 2 с, пока вы внутри.
func _thorns(delta: float) -> void:
	_thorn_t -= delta
	if _thorn_t > 0.0:
		return
	_thorn_t = THORN_PERIOD
	for n in graph.nodes:
		if n.kind == "thorn" and not n.harvested and n.grow >= 1.0:
			if player.position.distance_to(n.pos) < n.radius:
				player.take_damage(1, n.pos)
				hud.flash("Колючая камера! Срежьте её секатором или уходите.", 2.0)


func _spawn_enemies(delta: float) -> void:
	_spawn_acc += delta
	if _spawn_acc < float(params.spawn_interval):
		return
	_spawn_acc = 0.0
	var cells := 0
	for e in enemies.get_children():
		if e.has_signal("killed"):
			cells += 1
	if cells >= int(params.max_enemies):
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
	cell.speed_mult = float(params.get("enemy_speed_mult", 1.0))
	cell.thorny_player = params.get("graft", "") == "predator"
	cell.killed.connect(_on_cell_killed)
	enemies.add_child(cell)


func _on_cell_killed(_pos: Vector2) -> void:
	if randf() < 0.3:
		sap_collected += 1
		hud.flash("Клетка распалась: сок +1", 1.5)


func player_attack(pos: Vector2, facing: Vector2) -> void:
	Audio.play_sfx("hit")
	for e in enemies.get_children():
		var to: Vector2 = e.position - pos
		var reach := attack_range + (30.0 if not e.has_signal("killed") else 0.0)
		if to.length() <= reach and absf(facing.angle_to(to)) <= ATTACK_ARC:
			e.take_hit(to.normalized())


func player_prune(pos: Vector2) -> void:
	var res: Dictionary = graph.use_secateur(pos, sap_collected)
	Audio.play_sfx("cut")
	if res.action == "none":
		return
	if res.action == "harvest":
		Audio.play_sfx("pickup", 0.0)
	sap_collected = maxi(0, sap_collected + int(res.get("sap", 0)))
	seeds_collected += int(res.get("seeds", 0))
	water_collected += int(res.get("water", 0))
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
	var detail := "Сок +%d, семена +%d, вода +%d" % [sap_collected, seeds_collected, water_collected] if success else "Добыча ночи потеряна"
	hud.show_end("%s\n%s" % [text, detail])
	Engine.time_scale = 1.0
	await get_tree().create_timer(2.5).timeout
	if params.final:
		GameState.retry_final(text)
	else:
		GameState.finish_night(success, {"sap": sap_collected, "seeds": seeds_collected, "water": water_collected}, text)
	GameState.goto(GameState.phase)
