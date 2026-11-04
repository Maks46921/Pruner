extends Node
## Корневой узел: переключает сцены меню, дня и ночи.

const MainMenu := preload("res://scripts/menu/main_menu.gd")
const DayScene := preload("res://scripts/day/day_scene.gd")
const NightScene := preload("res://scripts/night/night_scene.gd")
const EndingScene := preload("res://scripts/day/ending_scene.gd")

var current: Node


func _ready() -> void:
	GameState.scene_requested.connect(_switch_to)
	_switch_to("menu")


func _switch_to(scene_name: String) -> void:
	get_tree().paused = false
	if current:
		current.queue_free()
		current = null
	match scene_name:
		"menu":
			current = MainMenu.new()
		"day":
			current = DayScene.new()
		"night":
			current = NightScene.new()
		"ending":
			current = EndingScene.new()
		_:
			push_error("Неизвестная сцена: %s" % scene_name)
			current = MainMenu.new()
	add_child(current)
