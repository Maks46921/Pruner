extends SceneTree
## Дымовой тест: новая игра → ночь; бот идёт по графу к цели и пользуется секатором.
## Запуск: godot --headless --path . -s tests/smoke_test.gd --fixed-fps 60 -- [seed] [watered]

var main: Node
var frames := 0
var max_frames := 60 * 500
var seed_value := 12345
var watered := false
var path: Array = []
var path_goal := Vector2.INF
var replan_t := 0
var verbose := false
var last_pos := Vector2.ZERO
var still := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		seed_value = int(args[0])
	if args.size() > 1:
		watered = args[1] == "1"
	verbose = "-v" in args
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	frames += 1
	var gs = root.get_node("GameState")
	if frames == 5:
		gs.new_game()
		gs.run_seed = seed_value
		gs.watered = watered
	if frames == 10:
		gs.start_night()
	var night = main.current
	var is_night: bool = night != null and night.has_method("player_prune")
	if is_night and not night.ended:
		_bot(night)
	if is_night and frames % 1800 == 0:
		print("  t=%ds edges=%d core=%d hp=%d sap=%d reached=%s enemies=%d" % [
			frames / 60, night.graph.edges.size(), night.graph.core_index, night.player.hp,
			night.sap_collected, night.reached_core, night.enemies.get_child_count()])
	if is_night and not night.ended:
		if night.player.position.distance_to(last_pos) < 0.01:
			still += 1
		else:
			still = 0
		last_pos = night.player.position
		if false:
			print("   f=", frames, " pos=", night.player.position, " path=", path.slice(0, 3), " len=", path.size(), " target=", night.player.target, " vec=", Input.get_vector("move_left", "move_right", "move_up", "move_down"))
		if still == 120 and verbose:
			var p = night.player
			print("   STUCK f=", frames, " pos=", p.position, " vec=", Input.get_vector("move_left", "move_right", "move_up", "move_down"), " path0=", path[0])
			var g = night.graph
			for i in g.edges.size():
				var e = g.edges[i]
				var a: Vector2 = g.nodes[e.a].pos
				var b: Vector2 = g.nodes[e.b].pos
				var d := Geometry2D.get_closest_point_to_segment(p.position, a, b).distance_to(p.position)
				if d < 150:
					print("     e", i, " ", a, "->", b, " ", e.state, " grow=", e.grow, " d=", d)
			print("     secateur would: ", g._nearest_edge(p.position + p.facing * 14.0, 42.0, true), " near=", g.edge_state_near(p.position))
	if gs.day > 1:
		var used := 0.0
		print("RESULT seed=%d watered=%s t=%ds: %s" % [seed_value, watered, frames / 60, gs.last_night_result])
		return true
	return frames > max_frames


func _nearest_node(g, pos: Vector2) -> int:
	var best := 0
	var bd := INF
	for i in g.nodes.size():
		if g.nodes[i].grow < 1.0:
			continue
		var d: float = g.nodes[i].pos.distance_to(pos)
		if d < bd:
			bd = d
			best = i
	return best


## Маршрут по графу (поиск в ширину). Закрытые стебли бот вскрывает секатором.
func _visible_node(g, pos: Vector2) -> int:
	var order: Array = []
	for i in g.nodes.size():
		if g.nodes[i].grow >= 1.0:
			order.append([g.nodes[i].pos.distance_to(pos), i])
	order.sort()
	for pair in order:
		var np: Vector2 = g.nodes[pair[1]].pos
		var ok := true
		for k in range(1, 12):
			var q := pos.lerp(np, k / 12.0)
			if g.constrain(q, 10.0).distance_to(q) > 0.5:
				ok = false
				break
		if ok:
			return pair[1]
	return _nearest_node(g, pos)


func _plan(g, from_pos: Vector2, goal: Vector2) -> Array:
	var start := _visible_node(g, from_pos)
	var target := _nearest_node(g, goal)
	var prev := {start: -1}
	var queue := [start]
	while not queue.is_empty():
		var cur: int = queue.pop_front()
		if cur == target:
			break
		for e in g.edges:
			if e.grow < 1.0:
				continue
			var nxt := -1
			if e.a == cur:
				nxt = e.b
			elif e.b == cur:
				nxt = e.a
			if nxt >= 0 and not prev.has(nxt):
				prev[nxt] = cur
				queue.append(nxt)
	var result: Array = [goal]
	if not prev.has(target):
		return result
	var step := target
	while step != -1:
		result.push_front(g.nodes[step].pos)
		step = prev[step]
	# Если следующая почка уже видна напрямую, не возвращаться к стартовой.
	if result.size() > 2 and _clear_line(g, from_pos, result[1]):
		result.pop_front()
	return result


func _clear_line(g, a: Vector2, b: Vector2) -> bool:
	for k in range(1, 16):
		var q := a.lerp(b, k / 16.0)
		if g.constrain(q, 10.0).distance_to(q) > 0.5:
			return false
	return true


func _bot(night) -> void:
	var p = night.player
	if p.target == null:
		return
	replan_t -= 1
	if path_goal != p.target or replan_t <= 0 or path.is_empty():
		path = _plan(night.graph, p.position, p.target)
		path_goal = p.target
		replan_t = 30
	while path.size() > 1 and p.position.distance_to(path[0]) < 14.0:
		path.pop_front()
	var to: Vector2 = path[0] - p.position
	for a in ["move_left", "move_right", "move_up", "move_down", "attack", "prune"]:
		Input.action_release(a)
	var dz := maxf(3.0, to.length() * 0.38)
	if to.x < -dz: Input.action_press("move_left")
	if to.x > dz: Input.action_press("move_right")
	if to.y < -dz: Input.action_press("move_up")
	if to.y > dz: Input.action_press("move_down")
	if frames % 20 == 0:
		Input.action_press("attack")
	elif frames % 10 == 5 and night.graph.edge_state_near(p.position) != "":
		Input.action_press("prune")
