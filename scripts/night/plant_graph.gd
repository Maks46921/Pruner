extends Node2D
## Мир ночного забега: граф стеблей и почек, растущий в реальном времени.
##
## Рост идёт фиксированными тиками (TICK), а действия игрока мгновенные.
## Каждый новый побег сначала «предупреждает» о себе пунктиром (TELEGRAPH_TIME),
## каждый зарастающий стебель пульсирует красным (WARN_TIME), прежде чем закрыться.

signal core_revealed(pos: Vector2)
signal stem_warning(edge_index: int)
signal room_grown(index: int, kind: String)
signal sprouted(pos: Vector2)

## Шесть типов комнат ночи (плюс вход и сердцевина).
const ROOM_KINDS := ["sap", "nest", "flower", "thorn", "seed", "water"]

const TICK := 0.5
const STEM_WIDTH := 36.0
const BUD_RADIUS := 24.0
const ROOM_RADIUS := 48.0
const CORE_RADIUS := 64.0
const MIN_NODE_GAP := 95.0
const MIN_EDGE_GAP := 50.0
const SEG_MIN := 120.0
const SEG_MAX := 175.0
const TELEGRAPH_TIME := 2.5
const WARN_TIME := 4.0
const NOTCH_TIME := 20.0
const GROW_SPEED := 1.1

var C_STEM := Color(0.25, 0.50, 0.22)
var C_STEM_IN := Color(0.36, 0.64, 0.30)
const C_NOTCH := Color(0.62, 0.80, 0.45)
const C_WARN := Color(0.85, 0.22, 0.18)
var C_CLOSED := Color(0.22, 0.13, 0.09)
var C_BUD := Color(0.33, 0.62, 0.28)
const C_ENTRY := Color(0.95, 0.88, 0.55)
const C_CORE := Color(0.80, 0.12, 0.22)
const C_SAP := Color(0.95, 0.62, 0.15)
const C_NEST := Color(0.70, 0.78, 0.95)
const C_STUMP := Color(0.40, 0.33, 0.25)
const C_FLOWER := Color(0.85, 0.22, 0.38)
const C_THORN := Color(0.50, 0.33, 0.22)
const C_SEED := Color(0.88, 0.82, 0.48)
const C_WATER := Color(0.35, 0.65, 0.92)
const C_TELEGRAPH := Color(0.70, 0.95, 0.55)
const C_LEADER := Color(1.0, 0.85, 0.35)

var nodes: Array[Dictionary] = []
var edges: Array[Dictionary] = []
var pending: Array[Dictionary] = []
var params: Dictionary = {}
var rng := RandomNumberGenerator.new()

var entry_index := 0
var core_index := -1
var core_pos := Vector2.ZERO
var leader := 0
var elapsed := 0.0
var duration := 360.0

var _leader_pending := false
var leader_ticks := 18

## Палитры ярусов: стебель, сердцевина стебля, почка, закрытый стебель, фон.
const PALETTES := {
	"soil": [Color(0.36, 0.42, 0.20), Color(0.48, 0.55, 0.28), Color(0.42, 0.50, 0.24), Color(0.20, 0.12, 0.07), Color(0.07, 0.05, 0.03)],
	"bark": [Color(0.42, 0.36, 0.26), Color(0.55, 0.48, 0.34), Color(0.40, 0.48, 0.26), Color(0.18, 0.11, 0.08), Color(0.06, 0.05, 0.06)],
	"crown": [Color(0.25, 0.55, 0.24), Color(0.38, 0.70, 0.32), Color(0.33, 0.65, 0.30), Color(0.20, 0.13, 0.10), Color(0.03, 0.05, 0.10)],
	"heart": [Color(0.50, 0.20, 0.22), Color(0.68, 0.30, 0.30), Color(0.60, 0.25, 0.28), Color(0.15, 0.05, 0.06), Color(0.08, 0.02, 0.04)],
}
var background := Color(0.05, 0.04, 0.08)
var _tick_acc := 0.0
var _tick_count := 0
var _time := 0.0


func setup(p: Dictionary, seed_value: int) -> void:
	params = p
	duration = p.duration
	rng.seed = seed_value
	nodes.clear()
	edges.clear()
	pending.clear()
	entry_index = _add_node(Vector2.ZERO, "entry", -1, 1.0)
	core_pos = Vector2.from_angle(rng.randf_range(-PI, PI)) * float(p.core_distance)
	leader = entry_index
	var pal: Array = PALETTES.get(p.get("tier", "crown"), PALETTES.crown)
	C_STEM = pal[0]
	C_STEM_IN = pal[1]
	C_BUD = pal[2]
	C_CLOSED = pal[3]
	background = pal[4]
	var avg_seg := (SEG_MIN + SEG_MAX) * 0.5
	var segments := maxf(1.0, float(p.core_distance) / avg_seg - 3.0)
	var core_at := float(p.get("core_at", 0.55))
	if core_at <= 0.0:
		# Финальная ночь: путь к сердцевине уже пророс.
		var guard := 0
		while core_index < 0 and guard < 60:
			guard += 1
			_grow_leader(true)
		# Каждый четвёртый стебель пути уже зарос: без секатора не пройти.
		var e: int = nodes[core_index].parent_edge
		var k := 0
		while e >= 0:
			k += 1
			if k % 4 == 0:
				edges[e].state = "closed"
			e = nodes[edges[e].a].parent_edge
	else:
		for i in 3:
			_grow_leader(true)
		var interval := maxf(2.5, core_at * duration / segments - TELEGRAPH_TIME)
		leader_ticks = maxi(2, int(round(interval / TICK)))
	var made := 0
	var attempts := 0
	while made < int(p.initial_branches) and attempts < 200:
		attempts += 1
		if _schedule_branch(true):
			made += 1


# --- Построение графа ----------------------------------------------------------

func _radius_for(kind: String) -> float:
	match kind:
		"entry", "sap", "nest", "flower", "thorn", "seed", "water":
			return ROOM_RADIUS
		"core":
			return CORE_RADIUS
	return BUD_RADIUS


func _add_node(pos: Vector2, kind: String, parent_edge: int, grow: float) -> int:
	nodes.append({
		"pos": pos,
		"kind": kind,
		"radius": _radius_for(kind),
		"grow": grow,
		"parent_edge": parent_edge,
		"harvested": false,
	})
	return nodes.size() - 1


func _connect(a: int, pos: Vector2, kind: String, instant: bool) -> int:
	var e := edges.size()
	edges.append({
		"a": a,
		"b": -1,
		"grow": 1.0 if instant else 0.0,
		"state": "open",
		"warn_t": 0.0,
		"notch_t": 0.0,
	})
	var idx := _add_node(pos, kind, e, 1.0 if instant else 0.0)
	edges[e].b = idx
	if kind == "core":
		core_index = idx
		core_revealed.emit(pos)
	return idx


func degree(i: int) -> int:
	var n := 0
	for e in edges:
		if e.a == i or e.b == i:
			n += 1
	return n


## Главный побег тянется к сердцевине. Его нельзя срезать.
func _grow_leader(instant: bool) -> void:
	if core_index >= 0 or _leader_pending:
		return
	var from: Vector2 = nodes[leader].pos
	var to_core := core_pos - from
	var pos: Vector2
	var kind := "bud"
	if to_core.length() < SEG_MAX * 1.3:
		pos = core_pos
		kind = "core"
	else:
		var dir := to_core.normalized().rotated(rng.randf_range(-0.55, 0.55))
		pos = from + dir * rng.randf_range(SEG_MIN, SEG_MAX)
	if instant:
		leader = _connect(leader, pos, kind, true)
	else:
		_leader_pending = true
		pending.append({"from": leader, "to": pos, "kind": kind, "t": TELEGRAPH_TIME, "leader": true})


## Боковая ветвь из случайной почки. Возвращает true, если место нашлось.
func _schedule_branch(instant: bool, exclude_from: int = -1) -> bool:
	for attempt in 14:
		var from := rng.randi_range(0, nodes.size() - 1)
		if from == exclude_from or from == core_index or nodes[from].grow < 1.0:
			continue
		if degree(from) >= (4 if from == entry_index else 3):
			continue
		var origin: Vector2 = nodes[from].pos
		var dir := Vector2.from_angle(rng.randf_range(-PI, PI))
		var pos := origin + dir * rng.randf_range(SEG_MIN, SEG_MAX)
		if not _is_free_spot(origin, pos):
			continue
		var kind := _roll_kind()
		if instant:
			_connect(from, pos, kind, true)
		else:
			pending.append({"from": from, "to": pos, "kind": kind, "t": TELEGRAPH_TIME, "leader": false})
		return true
	return false


func _roll_kind() -> String:
	var roll := rng.randf()
	var acc := 0.0
	for k in ROOM_KINDS:
		acc += float(params.get(k + "_room_chance" if k != "nest" and k != "flower" else k + "_chance", 0.0))
		if roll < acc:
			return k
	return "bud"


func _is_free_spot(origin: Vector2, pos: Vector2) -> bool:
	if pos.distance_to(core_pos) < CORE_RADIUS + MIN_NODE_GAP:
		return false
	for n in nodes:
		if n.pos.distance_to(pos) < MIN_NODE_GAP:
			return false
	for p in pending:
		if p.to.distance_to(pos) < MIN_NODE_GAP:
			return false
	for e in edges:
		var a: Vector2 = nodes[e.a].pos
		var b: Vector2 = nodes[e.b].pos
		var q := Geometry2D.get_closest_point_to_segment(pos, a, b)
		if q.distance_to(pos) < MIN_EDGE_GAP:
			return false
		if a != origin and b != origin and Geometry2D.segment_intersects_segment(origin, pos, a, b) != null:
			return false
	return true


# --- Симуляция ---------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_time += delta
	elapsed += delta
	_tick_acc += delta
	while _tick_acc >= TICK:
		_tick_acc -= TICK
		_tick()

	for i in range(pending.size() - 1, -1, -1):
		var p: Dictionary = pending[i]
		p.t -= delta
		if p.t <= 0.0:
			pending.remove_at(i)
			var idx := _connect(p.from, p.to, p.kind, false)
			sprouted.emit(p.to)
			if p.leader:
				_leader_pending = false
				leader = idx

	var grow_rate := GROW_SPEED * float(params.get("growth_mult", 1.0))
	for e in edges:
		if e.grow < 1.0:
			e.grow = minf(1.0, e.grow + delta * grow_rate)
		elif nodes[e.b].grow < 1.0:
			nodes[e.b].grow = minf(1.0, nodes[e.b].grow + delta * 3.0)
			if nodes[e.b].grow >= 1.0:
				room_grown.emit(e.b, nodes[e.b].kind)
		if e.notch_t > 0.0:
			e.notch_t -= delta
		if e.state == "warning":
			e.warn_t -= delta
			if e.warn_t <= 0.0:
				e.state = "closed"
	queue_redraw()


func _tick() -> void:
	_tick_count += 1
	if _tick_count % leader_ticks == 0:
		_grow_leader(false)
	if rng.randf() < float(params.branch_chance):
		_schedule_branch(false)
	var progress := clampf(elapsed / duration, 0.0, 1.0)
	var closure_chance := float(params.closure_base) + float(params.closure_growth) * progress
	if rng.randf() < closure_chance:
		_start_closure()


func _start_closure() -> void:
	var candidates: Array[int] = []
	for i in edges.size():
		var e: Dictionary = edges[i]
		if e.state == "open" and e.grow >= 1.0 and e.notch_t <= 0.0:
			candidates.append(i)
	if candidates.is_empty():
		return
	var i: int = candidates[rng.randi_range(0, candidates.size() - 1)]
	edges[i].state = "warning"
	edges[i].warn_t = WARN_TIME * float(params.get("warn_mult", 1.0))
	stem_warning.emit(i)


# --- Геометрия: где можно стоять --------------------------------------------------

func _edge_points(e: Dictionary) -> Array[Vector2]:
	var a: Vector2 = nodes[e.a].pos
	var b: Vector2 = nodes[e.b].pos
	return [a, a.lerp(b, e.grow)]


## Возвращает ближайшую к pos точку, где может находиться тело радиуса r.
func constrain(pos: Vector2, r: float) -> Vector2:
	var best := pos
	var best_d := INF
	for e in edges:
		if e.state == "closed" or e.grow <= 0.0:
			continue
		var pts := _edge_points(e)
		var q := Geometry2D.get_closest_point_to_segment(pos, pts[0], pts[1])
		var allowed := maxf(STEM_WIDTH * 0.5 - r, 1.0)
		var d := pos.distance_to(q)
		if d <= allowed:
			return pos
		if d - allowed < best_d:
			best_d = d - allowed
			best = q + (pos - q).limit_length(allowed)
	for n in nodes:
		var rad: float = n.radius * n.grow
		if rad <= r:
			continue
		var allowed := rad - r
		var d: float = pos.distance_to(n.pos)
		if d <= allowed:
			return pos
		if d - allowed < best_d:
			best_d = d - allowed
			best = n.pos + (pos - n.pos).limit_length(allowed)
	return best


func random_node_pos(kind: String = "") -> Vector2:
	var pool: Array[int] = []
	for i in nodes.size():
		if nodes[i].grow >= 1.0 and (kind == "" or nodes[i].kind == kind) and not nodes[i].harvested:
			pool.append(i)
	if pool.is_empty():
		return nodes[entry_index].pos
	return nodes[pool[rng.randi_range(0, pool.size() - 1)]].pos


func node_pos(i: int) -> Vector2:
	return nodes[i].pos


# --- Секатор -------------------------------------------------------------------------

## Контекстное действие секатора в точке pos. Возвращает описание результата.
func use_secateur(pos: Vector2, night_sap: int) -> Dictionary:
	# 1. Закрытый или зарастающий стебель рядом — самое срочное: вскрыть или надрезать.
	var blocked := _nearest_edge(pos, 42.0, true)
	if blocked >= 0:
		return _notch_edge(blocked, night_sap)
	# 2. Комната: срезать и забрать ресурс.
	for i in nodes.size():
		var n: Dictionary = nodes[i]
		if n.harvested or n.grow < 1.0 or not (n.kind in ROOM_KINDS):
			continue
		if pos.distance_to(n.pos) < n.radius + 16.0:
			n.harvested = true
			var res := _harvest_result(n.kind)
			res["index"] = i
			return res
	# 3. Побег, который вот-вот вырастет: подрезать и перенаправить рост.
	for i in pending.size():
		var p: Dictionary = pending[i]
		if p.leader:
			continue
		var from: Vector2 = nodes[p.from].pos
		var q := Geometry2D.get_closest_point_to_segment(pos, from, p.to)
		if q.distance_to(pos) < 40.0:
			pending.remove_at(i)
			_schedule_branch(false, p.from)
			return {"action": "redirect", "text": "Побег подрезан, рост ушёл в сторону"}
	# 4. Открытый стебель: надрез защищает его от зарастания.
	var open_edge := _nearest_edge(pos, 30.0, false)
	if open_edge >= 0:
		return _notch_edge(open_edge, night_sap)
	return {"action": "none"}


func _harvest_result(kind: String) -> Dictionary:
	var graft_sap := 2 if params.get("graft", "") == "sap" else 0
	match kind:
		"sap":
			var n := 3 + int(params.get("sap_bonus", 0)) + graft_sap
			return {"action": "harvest", "sap": n, "text": "Комната срезана: сок +%d" % n}
		"nest":
			return {"action": "harvest", "sap": 1 + graft_sap, "text": "Иммунный узел срезан: клетки больше не рождаются здесь"}
		"flower":
			return {"action": "harvest", "sap": 2 + graft_sap, "text": "Хищный цветок срезан: сок +%d" % (2 + graft_sap)}
		"thorn":
			return {"action": "harvest", "sap": 2 + graft_sap, "text": "Колючая камера срезана: сок +%d" % (2 + graft_sap)}
		"seed":
			var n := 1 + int(params.get("seed_bonus", 0))
			return {"action": "harvest", "seeds": n, "sap": graft_sap, "text": "Семенная камера срезана: семена +%d" % n}
		"water":
			var n := 1 + int(params.get("water_bonus", 0))
			return {"action": "harvest", "water": n, "sap": graft_sap, "text": "Водяной карман срезан: вода +%d" % n}
	return {"action": "none"}


func is_room_alive(i: int) -> bool:
	return i >= 0 and i < nodes.size() and not nodes[i].harvested


func _nearest_edge(pos: Vector2, max_d: float, only_blocked: bool) -> int:
	var best := -1
	var best_d := max_d
	for i in edges.size():
		var e: Dictionary = edges[i]
		if e.grow < 1.0 or (only_blocked and e.state == "open"):
			continue
		var pts := _edge_points(e)
		var d := Geometry2D.get_closest_point_to_segment(pos, pts[0], pts[1]).distance_to(pos)
		if d < best_d:
			best_d = d
			best = i
	return best


func _notch_edge(i: int, night_sap: int) -> Dictionary:
	var e: Dictionary = edges[i]
	var was: String = e.state
	e.state = "open"
	e.notch_t = NOTCH_TIME
	if was == "closed":
		if night_sap > 0:
			return {"action": "reopen", "sap": -1, "text": "Стебель вскрыт: сок −1"}
		return {"action": "reopen", "hp": -1, "text": "Стебель вскрыт голыми руками: −1 здоровье"}
	if was == "warning":
		return {"action": "notch", "text": "Надрез: стебель не зарастёт ещё 20 с"}
	return {"action": "notch", "text": "Надрез: стебель защищён на 20 с"}


## Есть ли рядом рост, который вот-вот изменит путь (для замедления времени).
func danger_near(pos: Vector2, radius: float) -> bool:
	for p in pending:
		if p.t < 1.2 and Geometry2D.get_closest_point_to_segment(pos, nodes[p.from].pos, p.to).distance_to(pos) < radius:
			return true
	for e in edges:
		if e.state == "warning" and e.warn_t < 1.5:
			var pts := _edge_points(e)
			if Geometry2D.get_closest_point_to_segment(pos, pts[0], pts[1]).distance_to(pos) < radius:
				return true
	return false


## Ближайший к точке закрытый или зарастающий стебель (для подсказок).
func edge_state_near(pos: Vector2) -> String:
	for e in edges:
		if e.state == "open" or e.grow < 1.0:
			continue
		var pts := _edge_points(e)
		if Geometry2D.get_closest_point_to_segment(pos, pts[0], pts[1]).distance_to(pos) < 60.0:
			return e.state
	return ""


# --- Отрисовка ------------------------------------------------------------------------

func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(_time * 6.0)
	# Предупреждения о росте
	for p in pending:
		var from: Vector2 = nodes[p.from].pos
		var col: Color = C_LEADER if p.leader else C_TELEGRAPH
		col.a = 0.35 + 0.45 * pulse
		draw_dashed_line(from, p.to, col, 4.0, 14.0)
		draw_arc(p.to, _radius_for(p.kind) * (1.0 - p.t / TELEGRAPH_TIME * 0.5), 0, TAU, 32, col, 3.0)
	# Стебли — внешний слой
	for e in edges:
		if e.grow <= 0.0:
			continue
		var pts := _edge_points(e)
		var col := C_STEM
		var w := STEM_WIDTH
		if e.state == "warning":
			col = C_STEM.lerp(C_WARN, 0.4 + 0.6 * pulse)
		elif e.state == "closed":
			col = C_CLOSED
			w = STEM_WIDTH * 0.55
		draw_line(pts[0], pts[1], col, w)
		draw_circle(pts[1], w * 0.5, col)
	# Стебли — внутренний слой и метки
	for e in edges:
		if e.grow <= 0.0:
			continue
		var pts := _edge_points(e)
		if e.state == "closed":
			_draw_thorns(pts[0], pts[1])
			continue
		var inner := C_NOTCH if e.notch_t > 0.0 else C_STEM_IN
		draw_line(pts[0], pts[1], inner, STEM_WIDTH * 0.45)
		if e.notch_t > 0.0:
			var mid: Vector2 = (pts[0] + pts[1]) * 0.5
			var n: Vector2 = (pts[1] - pts[0]).normalized().orthogonal() * STEM_WIDTH * 0.6
			draw_line(mid - n, mid + n, C_NOTCH.lightened(0.3), 3.0)
	# Почки и комнаты
	for i in nodes.size():
		_draw_node(nodes[i], pulse)


func _draw_thorns(a: Vector2, b: Vector2) -> void:
	var dir := (b - a)
	var len := dir.length()
	if len < 1.0:
		return
	dir /= len
	var n := dir.orthogonal()
	var steps := int(len / 18.0)
	for s in steps:
		var p := a + dir * (s + 0.5) * 18.0
		var side := 1.0 if s % 2 == 0 else -1.0
		draw_line(p, p + (n * side + dir * 0.4) * 16.0, C_CLOSED.lightened(0.25), 3.0)


func _draw_node(n: Dictionary, pulse: float) -> void:
	var r: float = n.radius * n.grow
	if r <= 0.5:
		return
	var pos: Vector2 = n.pos
	if n.harvested:
		draw_circle(pos, r * 0.7, C_STUMP)
		draw_arc(pos, r * 0.45, 0, TAU, 24, C_STUMP.lightened(0.2), 2.0)
		return
	match n.kind:
		"entry":
			draw_circle(pos, r, C_STEM)
			draw_circle(pos, r * 0.75, C_ENTRY.darkened(0.55))
			draw_arc(pos, r * 0.75, 0, TAU, 40, C_ENTRY, 3.0)
		"core":
			draw_circle(pos, r * (1.0 + 0.06 * pulse), C_CORE.darkened(0.3))
			draw_circle(pos, r * 0.6 * (1.0 + 0.1 * pulse), C_CORE)
			draw_circle(pos, r * 0.25, C_CORE.lightened(0.5))
		"sap":
			draw_circle(pos, r, C_STEM)
			draw_circle(pos, r * 0.7, C_SAP.darkened(0.25))
			for k in 3:
				var off := Vector2.from_angle(k * TAU / 3.0 + _time * 0.5) * r * 0.35
				draw_circle(pos + off, r * 0.15, C_SAP.lightened(0.2))
		"nest":
			draw_circle(pos, r, C_STEM.darkened(0.2))
			draw_circle(pos, r * 0.72, C_NEST.darkened(0.5))
			for k in 5:
				var off := Vector2.from_angle(k * TAU / 5.0 - _time * 0.8) * r * 0.45
				draw_circle(pos + off, r * 0.12, C_NEST)
		"flower":
			# Цветок рисует night_scene (он живой и раскрывается); здесь — его ложе.
			draw_circle(pos, r, C_STEM.darkened(0.25))
			draw_circle(pos, r * 0.7, C_FLOWER.darkened(0.6))
		"thorn":
			draw_circle(pos, r, C_STEM.darkened(0.3))
			draw_circle(pos, r * 0.75, C_THORN.darkened(0.3))
			for k in 10:
				var dir := Vector2.from_angle(k * TAU / 10.0)
				draw_line(pos + dir * r * 0.35, pos + dir * r * 0.72, C_THORN.lightened(0.35), 3.0)
		"seed":
			draw_circle(pos, r, C_STEM)
			draw_circle(pos, r * 0.7, C_SEED.darkened(0.45))
			for k in 4:
				var off := Vector2.from_angle(k * TAU / 4.0 + 0.4) * r * 0.32
				draw_circle(pos + off, r * 0.14, C_SEED)
		"water":
			draw_circle(pos, r, C_STEM)
			draw_circle(pos, r * 0.7, C_WATER.darkened(0.3))
			var wob := sin(_time * 2.0) * 3.0
			draw_arc(pos + Vector2(0, wob), r * 0.4, PI * 0.15, PI * 0.85, 12, C_WATER.lightened(0.4), 3.0)
		_:
			draw_circle(pos, r, C_BUD)
			draw_circle(pos, r * 0.5, C_STEM_IN)
