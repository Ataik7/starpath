extends Node

const BGM_DIR := "res://Assets/Audio/BGM/"
const SFX_DIR := "res://Assets/Audio/SFX/"

var _bgm: AudioStreamPlayer
var _current_bgm: String = ""
var _sfx_pool: Array[AudioStreamPlayer] = []
const _SFX_POOL_SIZE := 6

var bgm_volume: float = 1.0
var sfx_volume: float = 1.0

func _ready() -> void:
	_bgm      = AudioStreamPlayer.new()
	_bgm.bus  = "Master"
	add_child(_bgm)
	for i in _SFX_POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_sfx_pool.append(p)

func set_bgm_volume(value: float) -> void:
	bgm_volume    = clampf(value, 0.0, 1.0)
	_bgm.volume_db = linear_to_db(bgm_volume) if bgm_volume > 0.0 else -80.0

func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)

func play_bgm(track: String, loop: bool = true) -> void:
	var path := BGM_DIR + track + ".ogg"
	if _current_bgm == path and _bgm.playing:
		return
	_current_bgm = path
	var stream = load(path)
	if stream == null:
		push_error("AudioManager: no se encontró " + path)
		return
	stream = stream.duplicate()
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = loop
	_bgm.stream = stream
	_bgm.play()

func stop_bgm() -> void:
	_bgm.stop()
	_current_bgm = ""

func play_sfx(sfx_name: String, volume: float = 1.0) -> void:
	var path := SFX_DIR + sfx_name + ".ogg"
	if not ResourceLoader.exists(path):
		return   # archivo aún no añadido → silencio sin error
	var stream = load(path)
	if stream == null:
		return
	# Buscar un player libre en el pool
	for p: AudioStreamPlayer in _sfx_pool:
		if not p.playing:
			p.stream    = stream
			p.volume_db = linear_to_db(clampf(sfx_volume * volume, 0.001, 1.0))
			p.play()
			return
	# Si todos ocupados, usar el primero igualmente
	_sfx_pool[0].stream    = stream
	_sfx_pool[0].volume_db = linear_to_db(clampf(sfx_volume * volume, 0.001, 1.0))
	_sfx_pool[0].play()
