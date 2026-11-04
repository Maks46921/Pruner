extends Node
## Музыка и звуки. Громкость и полноэкранный режим хранятся в user://settings.cfg.

const SETTINGS_PATH := "user://settings.cfg"
const MUSIC := {
	"day": preload("res://assets/audio/music_day.wav"),
	"night": preload("res://assets/audio/music_night.wav"),
	"final": preload("res://assets/audio/music_final.wav"),
}
const SFX := {
	"cut": preload("res://assets/audio/sfx_cut.wav"),
	"hit": preload("res://assets/audio/sfx_hit.wav"),
	"hurt": preload("res://assets/audio/sfx_hurt.wav"),
	"grow": preload("res://assets/audio/sfx_grow.wav"),
	"close": preload("res://assets/audio/sfx_close.wav"),
	"pickup": preload("res://assets/audio/sfx_pickup.wav"),
	"ui": preload("res://assets/audio/sfx_ui.wav"),
	"bite": preload("res://assets/audio/sfx_bite.wav"),
}

var music_volume := 0.7
var sfx_volume := 0.8
var fullscreen := false

var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _current := ""
var _sfx_pool: Array[AudioStreamPlayer] = []
var _last_played := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus("Music")
	_ensure_bus("SFX")
	_music_a = _make_player("Music")
	_music_b = _make_player("Music")
	for p in [_music_a, _music_b]:
		p.finished.connect(p.play)   # зацикливание
	for i in 10:
		_sfx_pool.append(_make_player("SFX"))
	load_settings()


func _ensure_bus(bus: String) -> void:
	if AudioServer.get_bus_index(bus) == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
		AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")


func _make_player(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p


## Плавно сменить музыку (кроссфейд 1,5 с).
func play_music(track: String) -> void:
	if track == _current or not MUSIC.has(track):
		return
	_current = track
	var old := _music_a if _music_a.playing else _music_b
	var new := _music_b if old == _music_a else _music_a
	new.stream = MUSIC[track]
	new.volume_db = -40.0
	new.play()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(new, "volume_db", 0.0, 1.5)
	if old.playing:
		tw.tween_property(old, "volume_db", -40.0, 1.5)
		tw.chain().tween_callback(old.stop)


func play_sfx(name: String, pitch_jitter := 0.08, min_gap := 0.05) -> void:
	if not SFX.has(name):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_played.get(name, -10.0)) < min_gap:
		return
	_last_played[name] = now
	for p in _sfx_pool:
		if not p.playing:
			p.stream = SFX[name]
			p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
			p.play()
			return


# --- Настройки ------------------------------------------------------------------

func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	_apply()
	save_settings()


func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	_apply()
	save_settings()


func set_fullscreen(on: bool) -> void:
	fullscreen = on
	_apply()
	save_settings()


func _apply() -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(maxf(music_volume, 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(maxf(sfx_volume, 0.0001)))
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		music_volume = float(cfg.get_value("audio", "music", music_volume))
		sfx_volume = float(cfg.get_value("audio", "sfx", sfx_volume))
		fullscreen = bool(cfg.get_value("video", "fullscreen", fullscreen))
	_apply()


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.save(SETTINGS_PATH)
