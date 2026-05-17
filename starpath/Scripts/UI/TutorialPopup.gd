class_name TutorialPopup
extends CanvasLayer

const FONT_PATH := "res://Assets/Fonts/CinzelDecorative-Bold.ttf"

const C_PANEL  := Color(0.05, 0.04, 0.09, 0.96)
const C_BORDER := Color(0.65, 0.50, 0.16, 1.00)
const C_TITLE  := Color(0.96, 0.84, 0.40, 1.00)
const C_TEXT   := Color(0.92, 0.88, 0.80, 1.00)
const C_HINT   := Color(0.55, 0.50, 0.42, 1.00)

var _font:      Font
var _panel:     PanelContainer
var _overlay:   ColorRect
var _title_lbl: Label
var _body_lbl:  Label
var _blocking:  bool = false

# Offsets base del panel (se calculan una vez y se restauran tras cada dismiss)
const _OFF_TOP_LARGE  := -340.0   # pasos con mucho texto (lore)
const _OFF_TOP_SMALL  := -250.0   # pasos cortos (movimiento, NPC, pausa)
const _OFF_BOTTOM     := -70.0

var _cur_off_top: float = _OFF_TOP_SMALL


func _ready() -> void:
	layer        = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible      = false
	_font        = load(FONT_PATH)
	_build_popup()
	TutorialManager.show_requested.connect(_on_show_requested)


# Construcción

func _build_popup() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Overlay oscuro (solo en pasos bloqueantes)
	_overlay = ColorRect.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.color        = Color(0, 0, 0, 0.55)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.visible      = false
	root.add_child(_overlay)

	# Panel inferior centrado
	_panel = PanelContainer.new()
	_panel.anchor_left   = 0.5
	_panel.anchor_top    = 1.0
	_panel.anchor_right  = 0.5
	_panel.anchor_bottom = 1.0
	_panel.offset_left   = -340.0
	_panel.offset_right  =  340.0
	_panel.offset_top    = _cur_off_top
	_panel.offset_bottom = _OFF_BOTTOM

	var sty := StyleBoxFlat.new()
	sty.bg_color    = C_PANEL
	sty.border_color = C_BORDER
	sty.set_border_width_all(2)
	sty.set_corner_radius_all(8)
	sty.shadow_color  = Color(0, 0, 0, 0.75)
	sty.shadow_size   = 18
	sty.shadow_offset = Vector2(0, 4)
	_panel.add_theme_stylebox_override("panel", sty)
	root.add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   26)
	margin.add_theme_constant_override("margin_right",  26)
	margin.add_theme_constant_override("margin_top",    16)
	margin.add_theme_constant_override("margin_bottom", 14)
	_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	# Título
	_title_lbl = Label.new()
	_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_lbl.add_theme_font_size_override("font_size", 17)
	_title_lbl.add_theme_color_override("font_color",        C_TITLE)
	_title_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
	_title_lbl.add_theme_constant_override("shadow_offset_x", 2)
	_title_lbl.add_theme_constant_override("shadow_offset_y", 2)
	if _font:
		_title_lbl.add_theme_font_override("font", _font)
	vbox.add_child(_title_lbl)

	# Separador dorado
	var sep     := HSeparator.new()
	var sep_sty := StyleBoxFlat.new()
	sep_sty.bg_color           = C_BORDER
	sep_sty.content_margin_top = 1
	sep.add_theme_stylebox_override("separator", sep_sty)
	vbox.add_child(sep)

	# Cuerpo
	_body_lbl = Label.new()
	_body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_lbl.add_theme_font_size_override("font_size", 14)
	_body_lbl.add_theme_color_override("font_color", C_TEXT)
	vbox.add_child(_body_lbl)

	# Pista de cierre
	var hint := Label.new()
	hint.text = "[ ESPACIO ]  Continuar"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", C_HINT)
	if _font:
		hint.add_theme_font_override("font", _font)
	vbox.add_child(hint)


# Mostrar

func _on_show_requested(_id: String, title: String, body: String, blocking: bool) -> void:
	_title_lbl.text  = title
	_body_lbl.text   = body
	_blocking        = blocking
	_overlay.visible = blocking
	_cur_off_top     = _OFF_TOP_LARGE if blocking else _OFF_TOP_SMALL

	if blocking:
		get_tree().paused = true

	# Arranca fuera de pantalla (50 px más abajo) y sube
	_panel.offset_top    = _cur_off_top + 50.0
	_panel.offset_bottom = _OFF_BOTTOM  + 50.0
	visible = true

	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_panel, "offset_top",    _cur_off_top, 0.30).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.parallel().tween_property(_panel, "offset_bottom", _OFF_BOTTOM, 0.30).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


# Cerrar

func _dismiss() -> void:
	if not visible:
		return
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_panel, "offset_top",    _cur_off_top + 50.0, 0.20).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(_panel, "offset_bottom", _OFF_BOTTOM + 50.0, 0.20).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		visible = false
		_overlay.visible = false
		if _blocking:
			get_tree().paused = false
	)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			get_viewport().set_input_as_handled()
			_dismiss()
	elif event is InputEventMouseButton and event.pressed:
		get_viewport().set_input_as_handled()
		_dismiss()
