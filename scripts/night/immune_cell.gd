extends Node2D
## Иммунная клетка: медленнее игрока, преследует его по стеблям.

signal killed(pos: Vector2)

const SPEED := 105.0
const RADIUS := 11.0
const CHASE_RANGE := 420.0

var graph: Node2D
var player: Node2D
var hp := 2
var speed_mult := 1.0
var thorny_player := false  # прививка «Шипы»

var _knock := Vector2.ZERO
var _flash := 0.0
var _hit_cd := 0.0
var _wander := Vector2.ZERO
var _t := 0.0


func _ready() -> void:
	_t = randf() * 10.0
	_wander = position


func _physics_process(delta: float) -> void:
	_t += delta
	_flash -= delta
	_hit_cd -= delta
	var to_player := player.position - position
	var dir := Vector2.ZERO
	if to_player.length() < CHASE_RANGE:
		dir = to_player.normalized()
	else:
		if position.distance_to(_wander) < 24.0 or randf() < 0.004:
			_wander = graph.random_node_pos()
		dir = (_wander - position).normalized()
	var desired := position + dir * SPEED * speed_mult * delta + _knock * delta
	_knock = _knock.move_toward(Vector2.ZERO, 1000.0 * delta)
	position = graph.constrain(desired, RADIUS * 0.6)
	if to_player.length() < RADIUS + 12.0 and _hit_cd <= 0.0:
		_hit_cd = 0.8
		player.take_damage(1, position)
		if thorny_player:
			take_hit(-to_player.normalized())
	queue_redraw()


func take_hit(dir: Vector2) -> void:
	hp -= 1
	_flash = 0.12
	_knock = dir * 520.0
	if hp <= 0:
		killed.emit(position)
		queue_free()


func _draw() -> void:
	var wobble := 1.0 + 0.08 * sin(_t * 7.0)
	var col := Color(0.78, 0.86, 1.0) if _flash <= 0.0 else Color(1, 1, 1)
	draw_circle(Vector2.ZERO, RADIUS * wobble, col.darkened(0.35))
	draw_circle(Vector2.ZERO, RADIUS * 0.8 * wobble, col)
	draw_circle(Vector2(2, -2), RADIUS * 0.35, Color(0.35, 0.40, 0.75))
