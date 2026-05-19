extends HSlider

# Nombre del bus de audio que controla este slider.
# Configurado desde el Inspector (export).
@export var audio_bus_name: String = "Music"

@onready var popup: Label = $VolumePopup

var audio_bus_id: int = -1
var _hide_timer: Timer


func _ready() -> void:
	# Bus válido
	audio_bus_id = AudioServer.get_bus_index(audio_bus_name)
	if audio_bus_id == -1:
		push_warning("Audio bus '%s' no encontrado. Los sliders funcionarán cuando crees el bus en: Editor → Audio (pestaña inferior)." % audio_bus_name)

	# Sync slider
	if audio_bus_id != -1:
		var current_db := AudioServer.get_bus_volume_db(audio_bus_id)
		value = db_to_linear(current_db) if current_db > -79.0 else 0.0
	else:
		value = 0.5

	# Conectar slider
	value_changed.connect(_on_value_changed)

	# Popup volumen
	if popup:
		popup.visible = false

	# Timer popup
	_hide_timer = Timer.new()
	_hide_timer.wait_time = 1.5
	_hide_timer.one_shot = true
	_hide_timer.timeout.connect(_hide_popup)
	add_child(_hide_timer)


func _on_value_changed(new_value: float) -> void:
	# Obtener bus
	if audio_bus_id == -1:
		audio_bus_id = AudioServer.get_bus_index(audio_bus_name)
	if audio_bus_id == -1:
		return

	# Actualizar volumen
	var db := linear_to_db(new_value) if new_value > 0.0 else -80.0
	AudioServer.set_bus_volume_db(audio_bus_id, db)

	# Mostrar popup
	if popup:
		popup.text = "%d%%" % int(new_value * 100)
		popup.visible = true

		# Posición popup
		var handle_x := size.x * new_value
		popup.global_position = global_position + Vector2(handle_x - popup.size.x / 2.0, -40.0)

		# Reset timer
		_hide_timer.start()


func _hide_popup() -> void:
	if popup:
		popup.visible = false
