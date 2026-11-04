extends Control
## Комната днём: окно, кровать и растение размером с комнату.
## Каждая ветвь кликабельна — это то, что вы встретите ночью.

signal branch_selected(index: int)

const WALL := Color(0.86, 0.80, 0.68)
const FLOOR := Color(0.62, 0.50, 0.38)
const WOOD := Color(0.45, 0.32, 0.22)
const LEAF := Color(0.30, 0.56, 0.26)
const LEAF_DARK := Color(0.20, 0.42, 0.18)
const INK := Color(0.16, 0.13, 0.10)

var selected := -1
var hovered := -1
var _paths: Array = []   # Array[PackedVector2Array] — точки каждой ветви
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_rebuild)
	_rebuild.call_deferred()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _trunk_base() -> Vector2:
	return Vector2(size.x * 0.55, size.y * 0.86)


func _trunk_top() -> Vector2:
	var s := _scale()
	return _trunk_base() + Vector2(0, -size.y * 0.50 * s)


func _scale() -> float:
	return 0.85 + 0.05 * GameState.day


## Пересчитать форму ветвей (детерминированно по дню).
func _rebuild() -> void:
	_paths.clear()
	var n := GameState.branches.size()
	if n == 0 or size.x <= 0.0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(GameState.run_seed) + ":view:" + str(GameState.day))
	var base := _trunk_base()
	var top := _trunk_top()
	for i in n:
		var t := (i + 0.5) / n
		var angle := lerpf(-PI * 0.97, -PI * 0.03, t) + rng.randf_range(-0.08, 0.08)
		var start := base.lerp(top, 0.45 + 0.55 * (1.0 - absf(t - 0.5) * 1.4))
		var length := size.y * rng.randf_range(0.42, 0.55) * _scale()
		var bend := rng.randf_range(-0.5, 0.5)
		var pts := PackedVector2Array()
		for k in 13:
			var u := k / 12.0
			var a := angle + bend * u
			if k == 0:
				pts.append(start)
			else:
				pts.append(pts[k - 1] + Vector2.from_angle(a) * length / 12.0)
		_paths.append(pts)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		hovered = _hit(event.position)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if hovered >= 0 else Control.CURSOR_ARROW
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var i := _hit(event.position)
		if i >= 0:
			selected = i
			branch_selected.emit(i)


func _hit(p: Vector2) -> int:
	var best := -1
	var best_d := 26.0
	for i in _paths.size():
		var pts: PackedVector2Array = _paths[i]
		for k in range(1, pts.size()):
			var d := Geometry2D.get_closest_point_to_segment(p, pts[k - 1], pts[k]).distance_to(p)
			if d < best_d:
				best_d = d
				best = i
	return best


func _draw() -> void:
	if _paths.size() != GameState.branches.size():
		_rebuild()
	# Стена, пол, окно, кровать
	draw_rect(Rect2(Vector2.ZERO, size), WALL)
	draw_rect(Rect2(0, size.y * 0.80, size.x, size.y * 0.20), FLOOR)
	var win := Rect2(size.x * 0.06, size.y * 0.10, size.x * 0.22, size.y * 0.30)
	draw_rect(win, Color(0.78, 0.88, 0.95))
	draw_rect(win, WOOD, false, 6.0)
	draw_line(win.position + Vector2(win.size.x * 0.5, 0), win.position + Vector2(win.size.x * 0.5, win.size.y), WOOD, 4.0)
	draw_line(win.position + Vector2(0, win.size.y * 0.5), win.position + Vector2(win.size.x, win.size.y * 0.5), WOOD, 4.0)
	var bed := Rect2(size.x * 0.03, size.y * 0.66, size.x * 0.24, size.y * 0.16)
	draw_rect(bed, Color(0.55, 0.62, 0.75))
	draw_rect(Rect2(bed.position, Vector2(bed.size.x * 0.28, bed.size.y * 0.6)), Color(0.95, 0.95, 0.92))
	draw_rect(Rect2(bed.position.x, bed.end.y, bed.size.x, 8), WOOD)

	# Горшок и ствол
	var base := _trunk_base()
	var top := _trunk_top()
	var s := _scale()
	draw_colored_polygon(PackedVector2Array([
		base + Vector2(-70, -10), base + Vector2(70, -10), base + Vector2(52, 60), base + Vector2(-52, 60)]),
		Color(0.70, 0.38, 0.25))
	draw_rect(Rect2(base + Vector2(-78, -22), Vector2(156, 16)), Color(0.62, 0.32, 0.20))
	draw_line(base + Vector2(0, -12), top, WOOD.darkened(0.1), 26.0 * s)
	draw_line(base + Vector2(0, -12), top, WOOD.lightened(0.1), 10.0 * s)
	# Лианы: растение обвило кровать, пол и стены
	var vines := [
		[base + Vector2(-50, -4), Vector2(size.x * 0.20, size.y * 0.60), Vector2(size.x * 0.05, size.y * 0.66)],
		[base + Vector2(-40, 30), Vector2(size.x * 0.30, size.y * 0.95), Vector2(size.x * 0.02, size.y * 0.90)],
		[base + Vector2(50, 20), Vector2(size.x * 0.85, size.y * 0.95), Vector2(size.x * 0.99, size.y * 0.75)],
		[top + Vector2(10, 40), Vector2(size.x * 0.92, size.y * 0.15), Vector2(size.x * 0.70, size.y * 0.02)],
		[top + Vector2(-10, 60), Vector2(size.x * 0.30, size.y * 0.02), Vector2(size.x * 0.12, size.y * 0.06)],
	]
	for v in vines:
		_draw_vine(v[0], v[1], v[2])
	for i in _paths.size():
		_draw_branch(i)


func _draw_vine(a: Vector2, ctrl: Vector2, b: Vector2) -> void:
	var prev := a
	for k in range(1, 25):
		var u := k / 24.0
		var p := a.lerp(ctrl, u).lerp(ctrl.lerp(b, u), u)
		draw_line(prev, p, LEAF_DARK, lerpf(7.0, 3.0, u))
		if k % 3 == 0:
			var dir := (p - prev).normalized().orthogonal() * (1.0 if k % 6 == 0 else -1.0)
			var tip := p + dir * 14.0
			draw_colored_polygon(PackedVector2Array([p, (p + tip) * 0.5 + (tip - p).orthogonal() * 0.4, tip, (p + tip) * 0.5 - (tip - p).orthogonal() * 0.4]), LEAF.darkened(0.1))
		prev = p


func _draw_branch(i: int) -> void:
	var b: Dictionary = GameState.branches[i]
	var info: Dictionary = GameState.BRANCH_INFO[b.type]
	var col: Color = info.color
	var pts: PackedVector2Array = _paths[i]
	var state: String = b.state
	var cut := state == "pruned" or state == "grafted"
	var last := 3 if cut else pts.size() - 1
	var width := 14.0 * _scale()
	var highlight := i == selected or i == hovered
	if highlight:
		for k in range(1, last + 1):
			draw_line(pts[k - 1], pts[k], Color(1, 1, 0.7, 0.6 if i == selected else 0.35), width + 12.0)
	for k in range(1, last + 1):
		var w := lerpf(width, width * 0.45, float(k) / pts.size())
		draw_line(pts[k - 1], pts[k], WOOD if k < 3 else LEAF_DARK, w)
	if cut:
		# Срез
		var tip := pts[last]
		draw_circle(tip, width * 0.45, Color(0.85, 0.75, 0.55))
		draw_arc(tip, width * 0.28, 0, TAU, 12, Color(0.6, 0.5, 0.35), 2.0)
		if state == "grafted":
			_draw_tag(tip + Vector2(0, -22), "привито", col)
		return
	# Листья вдоль ветви, окрашенные её природой
	var sway := sin(_t * 1.3 + i) * 0.12
	for k in range(3, pts.size(), 2):
		var dir := (pts[k] - pts[k - 1]).normalized()
		for side in [-1.0, 1.0]:
			var leaf_dir := dir.rotated(side * (0.9 + sway))
			var p0 := pts[k]
			var p1 := p0 + leaf_dir * 26.0 * _scale()
			var n := leaf_dir.orthogonal() * 8.0
			draw_colored_polygon(PackedVector2Array([p0, (p0 + p1) * 0.5 + n, p1, (p0 + p1) * 0.5 - n]),
				LEAF.lerp(col, 0.25))
	_draw_tip(pts[pts.size() - 1], (pts[pts.size() - 1] - pts[pts.size() - 2]).normalized(), b.type, col)
	if state == "notched":
		var m := pts[5]
		var nrm := (pts[6] - pts[4]).normalized().orthogonal() * 14.0
		draw_line(m - nrm, m + nrm, Color(0.95, 0.9, 0.7), 4.0)
		draw_line(m - nrm + Vector2(4, 0), m + nrm + Vector2(4, 0), Color(0.6, 0.15, 0.1), 2.0)


func _draw_tip(p: Vector2, dir: Vector2, type: String, col: Color) -> void:
	var pulse := 1.0 + 0.06 * sin(_t * 3.0)
	match type:
		"predator":
			for k in 5:
				var a := dir.angle() + (k - 2) * 0.45
				var tip := p + Vector2.from_angle(a) * 26.0 * pulse
				draw_colored_polygon(PackedVector2Array([p + Vector2.from_angle(a + 1.2) * 6.0, tip, p + Vector2.from_angle(a - 1.2) * 6.0]), col)
			draw_circle(p, 8.0, col.darkened(0.5))
		"immune":
			for k in 4:
				draw_circle(p + Vector2.from_angle(k * 1.6) * 10.0, 7.0, col)
		"sap":
			draw_circle(p, 12.0 * pulse, col)
			draw_circle(p + Vector2(-3, -3), 4.0, col.lightened(0.5))
		"thorn":
			for k in 8:
				var a := k * TAU / 8.0
				draw_line(p, p + Vector2.from_angle(a) * 16.0, col, 3.0)
			draw_circle(p, 6.0, col.darkened(0.3))
		"seed":
			for k in 3:
				draw_circle(p + Vector2.from_angle(k * TAU / 3.0) * 9.0, 6.0, col)
		"water":
			draw_circle(p, 10.0 * pulse, col)
			draw_colored_polygon(PackedVector2Array([p + Vector2(-7, -4), p + Vector2(0, -20), p + Vector2(7, -4)]), col)


func _draw_tag(p: Vector2, text: String, col: Color) -> void:
	var font := get_theme_default_font()
	draw_string(font, p + Vector2(-50, 0), text, HORIZONTAL_ALIGNMENT_CENTER, 100, 15, INK)
