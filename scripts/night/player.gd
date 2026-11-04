extends Node2D
## Игрок внутри растения. Три действия: движение, удар, секатор.

signal died

const SPEED := 230.0
const RADIUS := 10.0
const ATTACK_CD := 0.35
const PRUNE_CD := 0.35
const INVULN_TIME := 1.0

var graph: Node2D
var night: Node

var speed_mult := 1.0
var swing_radius := 46.0
var max_hp := 5
var hp := 5
var facing := Vector2.RIGHT
var target: Variant = null  # куда указывает стрелка-подсказка

var _attack_cd := 0.0
var _prune_cd := 0.0
var _invuln := 0.0
var _swing_t := 0.0
var _cut_t := 0.0
var _knock := Vector2.ZERO


func _physics_process(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input.length() > 0.1:
		facing = input.normalized()
	var desired := position + input * SPEED * speed_mult * delta + _knock * delta
	_knock = _knock.move_toward(Vector2.ZERO, 1200.0 * delta)
	position = graph.constrain(desired, RADIUS)

	_attack_cd -= delta
	_prune_cd -= delta
	_invuln -= delta
	_swing_t -= delta
	_cut_t -= delta

	if Input.is_action_just_pressed("attack") and _attack_cd <= 0.0:
		_attack_cd = ATTACK_CD
		_swing_t = 0.15
		night.player_attack(position, facing)
	if Input.is_action_just_pressed("prune") and _prune_cd <= 0.0:
		_prune_cd = PRUNE_CD
		_cut_t = 0.2
		night.player_prune(position + facing * 14.0)
	queue_redraw()


func take_damage(amount: int, from: Vector2) -> void:
	if _invuln > 0.0 or hp <= 0:
		return
	hp -= amount
	_invuln = INVULN_TIME
	Audio.play_sfx("hurt")
	_knock = (position - from).normalized() * 380.0
	if hp <= 0:
		died.emit()


func _draw() -> void:
	var blink := _invuln > 0.0 and int(_invuln * 12.0) % 2 == 0
	var body := Color(0.96, 0.93, 0.86) if not blink else Color(1, 0.5, 0.5)
	# Стрелка к цели
	if target != null:
		var to: Vector2 = target - position
		if to.length() > 90.0:
			var d := to.normalized()
			var tip := d * 48.0
			var col := Color(1.0, 0.85, 0.35, 0.8)
			draw_line(d * 30.0, tip, col, 3.0)
			draw_line(tip, tip - d.rotated(0.5) * 10.0, col, 3.0)
			draw_line(tip, tip - d.rotated(-0.5) * 10.0, col, 3.0)
	# Тело
	draw_circle(Vector2.ZERO, RADIUS + 2.0, Color(0.1, 0.08, 0.06))
	draw_circle(Vector2.ZERO, RADIUS, body)
	draw_circle(facing * 5.0, 3.0, Color(0.1, 0.08, 0.06))
	# Удар
	if _swing_t > 0.0:
		var a := facing.angle()
		draw_arc(Vector2.ZERO, swing_radius, a - 1.1, a + 1.1, 16, Color(1, 1, 1, _swing_t / 0.15), 5.0)
	# Секатор
	if _cut_t > 0.0:
		var p := facing * 22.0
		var n := facing.orthogonal() * 9.0
		var c := Color(0.85, 0.95, 1.0, _cut_t / 0.2)
		draw_line(p - n, p + n + facing * 6.0, c, 3.0)
		draw_line(p + n, p - n + facing * 6.0, c, 3.0)
