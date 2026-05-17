# DialogManager.gd  –  Autoload (CanvasLayer)
# Gestiona la caja de diálogo RPG con efecto de máquina de escribir.
##
# Uso desde cualquier script:
#   DialogManager.start_dialog(["Línea 1", "Línea 2"], "Nombre NPC")
##
# El jugador pulsa Enter/Espacio para avanzar.
# La señal `dialog_finished` se emite al cerrar el diálogo.

extends CanvasLayer

signal dialog_finished

# true mientras el diálogo está abierto (el PlayerController lo comprueba)
var is_open: bool = false

# Nodos UI
var _panel:      PanelContainer
var _name_label: Label
var _text_label: RichTextLabel
var _hint_label: Label

# Estado del efecto máquina de escribir
var _lines:      Array[String] = []
var _line_index: int           = 0
var _full_text:  String        = ""
var _char_index: int           = 0
var _typing:     bool          = false
var _timer:      float         = 0.0

const TYPE_SPEED := 0.035   # segundos por carácter

#
func _ready() -> void:
	layer = 128          # por encima de cualquier elemento de juego
	_build_ui()
	_panel.hide()

func _build_ui() -> void:
	# Panel principal — anclado al borde inferior, hijo directo del CanvasLayer
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.offset_top    = -170
	_panel.offset_bottom = -10
	_panel.offset_left   =  10
	_panel.offset_right  = -10

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color              = Color(0.10, 0.07, 0.24, 0.97)
	panel_style.border_color          = Color(0.85, 0.70, 0.15, 1.0)
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(4)
	panel_style.content_margin_left   = 22
	panel_style.content_margin_right  = 22
	panel_style.content_margin_top    = 12
	panel_style.content_margin_bottom = 10
	_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_panel)

	# Layout vertical dentro del panel
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	_panel.add_child(vbox)

	# Nombre del hablante
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 14)
	_name_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.3))
	vbox.add_child(_name_label)

	# Texto del diálogo
	_text_label = RichTextLabel.new()
	_text_label.bbcode_enabled      = false
	_text_label.fit_content         = false
	_text_label.scroll_active       = false
	_text_label.custom_minimum_size = Vector2(0, 90)
	_text_label.add_theme_font_size_override("normal_font_size", 16)
	_text_label.add_theme_color_override("default_color", Color.WHITE)
	vbox.add_child(_text_label)

	# Indicador de avance ▼
	_hint_label = Label.new()
	_hint_label.text                 = "▼"
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint_label.add_theme_font_size_override("font_size", 13)
	_hint_label.add_theme_color_override("font_color", Color(0.85, 0.70, 0.15))
	_hint_label.visible = false
	vbox.add_child(_hint_label)

#
# Inicia un diálogo.  `lines` = array de frases, `speaker` = nombre (opcional).
func start_dialog(lines: Array[String], speaker: String = "") -> void:
	if is_open or lines.is_empty():
		return
	is_open     = true
	_lines      = lines
	_line_index = 0
	_name_label.text    = speaker
	_name_label.visible = speaker.length() > 0
	_panel.show()
	_show_line(_lines[0])

func _show_line(text: String) -> void:
	_full_text  = text
	_char_index = 0
	_typing     = true
	_timer      = 0.0
	_hint_label.hide()
	_text_label.text = ""

# Máquina de escribir
func _process(delta: float) -> void:
	if not is_open or not _typing:
		return
	_timer += delta
	while _typing and _timer >= TYPE_SPEED:
		_timer      -= TYPE_SPEED
		_char_index += 1
		_text_label.text = _full_text.left(_char_index)
		if _char_index >= _full_text.length():
			_typing = false
			_hint_label.show()

# Entrada del jugador
func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if not event.is_action_pressed("ui_accept"):
		return
	get_viewport().set_input_as_handled()
	if _typing:
		# Saltar el efecto: mostrar la línea completa al instante
		_char_index      = _full_text.length()
		_text_label.text = _full_text
		_typing          = false
		_hint_label.show()
	else:
		_advance()

func _advance() -> void:
	_line_index += 1
	if _line_index < _lines.size():
		_show_line(_lines[_line_index])
	else:
		_close()

func _close() -> void:
	is_open = false
	_panel.hide()
	_lines      = []
	_line_index = 0
	dialog_finished.emit()
