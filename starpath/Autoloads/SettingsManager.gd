extends Node

const CONFIG_PATH := "user://settings.cfg"

const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280,  720),
	Vector2i(1920, 1080),
]
const RESOLUTION_LABELS: Array[String] = [
	"1280 × 720   (HD)",
	"1920 × 1080  (Full HD)",
]

# Keycodes por defecto para cada acción configurable.
const DEFAULT_BINDINGS: Dictionary = {
	"move_up":    KEY_W,
	"move_down":  KEY_S,
	"move_left":  KEY_A,
	"move_right": KEY_D,
	"interact":   KEY_E,
	"open_menu":  KEY_X,
}

# Nombres legibles para mostrar en la UI de configuración de teclado.
const ACTION_LABELS: Dictionary = {
	"move_up":    "Mover arriba",
	"move_down":  "Mover abajo",
	"move_left":  "Mover izquierda",
	"move_right": "Mover derecha",
	"interact":   "Interactuar",
	"open_menu":  "Abrir menú",
}

var _resolution_idx: int   = 0
var _fullscreen:     bool  = false
var _music_volume:   float = 1.0
var _sfx_volume:     float = 1.0
var _bindings:       Dictionary = {}

func _ready() -> void:
	_bindings = DEFAULT_BINDINGS.duplicate()
	_load_config()
	_apply_all()

# Teclado

func get_binding(action: String) -> Key:
	return (_bindings.get(action, DEFAULT_BINDINGS.get(action, KEY_NONE))) as Key

func set_binding(action: String, key: Key) -> void:
	_bindings[action] = key
	_apply_binding(action, key)
	_save_config()

func reset_bindings() -> void:
	_bindings = DEFAULT_BINDINGS.duplicate()
	_apply_all_bindings()
	_save_config()

func _apply_all_bindings() -> void:
	for action: String in DEFAULT_BINDINGS:
		_apply_binding(action, get_binding(action))

func _apply_binding(action: String, key: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	InputMap.action_erase_events(action)
	var ev := InputEventKey.new()
	ev.keycode = key
	InputMap.action_add_event(action, ev)

# Audio

func set_resolution(idx: int) -> void:
	_resolution_idx = clampi(idx, 0, RESOLUTIONS.size() - 1)
	if not _fullscreen:
		_apply_window_size()
	_save_config()

func set_fullscreen(enabled: bool) -> void:
	_fullscreen = enabled
	_apply_window_mode()
	_save_config()

func get_resolution_idx() -> int:
	return _resolution_idx

func is_fullscreen() -> bool:
	return _fullscreen

func set_music_volume(value: float) -> void:
	_music_volume = clampf(value, 0.0, 1.0)
	_apply_music_volume()
	_save_config()

func set_sfx_volume(value: float) -> void:
	_sfx_volume = clampf(value, 0.0, 1.0)
	_apply_sfx_volume()
	_save_config()

func get_music_volume() -> float:
	return _music_volume

func get_sfx_volume() -> float:
	return _sfx_volume

# Aplicación

func _apply_all() -> void:
	_apply_window_mode()
	_apply_music_volume()
	_apply_sfx_volume()
	_apply_all_bindings()

func _apply_window_mode() -> void:
	if _fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		_apply_window_size()

func _apply_window_size() -> void:
	var size := RESOLUTIONS[_resolution_idx]
	DisplayServer.window_set_size(size)
	var screen := DisplayServer.screen_get_size()
	DisplayServer.window_set_position(Vector2i(Vector2(screen - size) * 0.5))

func _apply_music_volume() -> void:
	var bus := AudioServer.get_bus_index("Music")
	if bus == -1:
		return
	AudioServer.set_bus_volume_db(bus, linear_to_db(_music_volume) if _music_volume > 0.0 else -80.0)

func _apply_sfx_volume() -> void:
	var bus := AudioServer.get_bus_index("SFX")
	if bus == -1:
		return
	AudioServer.set_bus_volume_db(bus, linear_to_db(_sfx_volume) if _sfx_volume > 0.0 else -80.0)

# Persistencia

func _save_config() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("video", "resolution_idx", _resolution_idx)
	cfg.set_value("video", "fullscreen",     _fullscreen)
	cfg.set_value("audio", "music_volume",   _music_volume)
	cfg.set_value("audio", "sfx_volume",     _sfx_volume)
	for action: String in DEFAULT_BINDINGS:
		cfg.set_value("keys", action, _bindings.get(action, DEFAULT_BINDINGS[action]))
	cfg.save(CONFIG_PATH)

func _load_config() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return
	_resolution_idx = cfg.get_value("video", "resolution_idx", 0)
	_fullscreen     = cfg.get_value("video", "fullscreen",     false)
	_music_volume   = cfg.get_value("audio", "music_volume",   1.0)
	_sfx_volume     = cfg.get_value("audio", "sfx_volume",     1.0)
	for action: String in DEFAULT_BINDINGS:
		_bindings[action] = cfg.get_value("keys", action, DEFAULT_BINDINGS[action]) as Key
