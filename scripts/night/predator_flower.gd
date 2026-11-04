extends Node2D
## Хищный цветок: сидит в своей комнате, раскрывается, когда вы рядом, и кусает.
## Раскрытие видно заранее — от него надо уйти, а не реагировать в последний миг.

const TRIGGER_RANGE := 150.0

var graph: Node2D
var player: Node2D
var room_index := -1
var weak := false

var hp := 3
var _state := "idle"   # idle | opening | bite | rest
var _t := 0.0
var _anim := 0.0
var _flash := 0.0


func _bite_range() -> float:
	return 70.0 if weak else 95.0


func _open_time() -> float:
	return 1.5 if weak else 0.9


func _physics_process(delta: float) -> void:
	_anim += delta
	_flash -= delta
	if not graph.is_room_alive(room_index):
		queue_free()
		return
	var d := position.distance_to(player.position)
	_t -= delta
	match _state:
		"idle":
			if d < TRIGGER_RANGE:
				_state = "opening"
				_t = _open_time()
		"opening":
			if _t <= 0.0:
				_state = "bite"
				_t = 0.25
				if d < _bite_range():
					player.take_damage(1, position)
		"bite":
			if _t <= 0.0:
				_state = "rest"
				_t = 2.2
		"rest":
			if _t <= 0.0:
				_state = "idle"
	queue_redraw()


func take_hit(_dir: Vector2) -> void:
	hp -= 1
	_flash = 0.12
	if hp <= 0:
		graph.nodes[room_index].harvested = true
		queue_free()


func _draw() -> void:
	var open := 0.0
	match _state:
		"opening":
			open = 1.0 - clampf(_t / _open_time(), 0.0, 1.0)
		"bite":
			open = 1.0
		"rest":
			open = 0.1
	var col := Color(0.85, 0.22, 0.38) if _flash <= 0.0 else Color.WHITE
	# Зона укуса проявляется по мере раскрытия
	if open > 0.0 and _state != "rest":
		draw_circle(Vector2.ZERO, _bite_range(), Color(0.9, 0.2, 0.25, 0.12 + 0.18 * open))
		draw_arc(Vector2.ZERO, _bite_range(), 0, TAU, 48, Color(1, 0.3, 0.3, 0.3 + 0.5 * open), 2.0)
	var petals := 6
	for k in petals:
		var a := k * TAU / petals + sin(_anim * 1.5) * 0.08
		var len := 20.0 + 26.0 * open
		var dir := Vector2.from_angle(a)
		var tip := dir * len
		var side := dir.orthogonal() * (9.0 + 6.0 * open)
		draw_colored_polygon(PackedVector2Array([dir * 6.0 + side * 0.4, tip, dir * 6.0 - side * 0.4]), col)
	draw_circle(Vector2.ZERO, 12.0, col.darkened(0.5))
	if _state == "bite":
		draw_circle(Vector2.ZERO, 16.0, Color(1, 0.9, 0.9))
