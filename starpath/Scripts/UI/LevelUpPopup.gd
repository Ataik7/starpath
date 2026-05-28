# LevelUpPopup — autoload CanvasLayer.
# Escucha Inventory.level_changed y muestra un panel dorado animado.
extends CanvasLayer

const FONT_PATH := "res://Assets/Fonts/CinzelDecorative-Bold.ttf"

const C_PANEL  := Color(0.04, 0.03, 0.08, 0.97)
const C_BORDER := Color(0.72, 0.57, 0.20, 1.00)
const C_GOLD   := Color(0.98, 0.88, 0.45, 1.00)
const C_GREEN  := Color(0.35, 0.95, 0.50, 1.00)
const C_HINT   := Color(0.55, 0.50, 0.42, 1.00)

var _font:      Font
var _panel:     PanelContainer
var _level_lbl: Label
var _gains_lbl: Label
var _auto_tw:   Tween


func _ready() -> void:
	layer        = 110
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible      = false
	_font        = load(FONT_PATH)
	_build()
	Inventory.level_changed.connect(_on_level_changed)


# Construcción

func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Panel centrado
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(360, 0)
	_panel.offset_left   = -180
	_panel.offset_right  =  180
	_panel.offset_top    = -120
	_panel.offset_bottom =  120

	var sty := StyleBoxFlat.new()
	sty.bg_color     = C_PANEL
	sty.border_color = C_BORDER
	sty.set_border_width_all(3)
	sty.set_corner_radius_all(10)
	sty.shadow_color  = Color(0.72, 0.57, 0.20, 0.60)
	sty.shadow_size   = 28
	_panel.add_theme_stylebox_override("panel", sty)
	root.add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   28)
	margin.add_theme_constant_override("margin_right",  28)
	margin.add_theme_constant_override("margin_top",    20)
	margin.add_theme_constant_override("margin_bottom", 16)
	_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	# Encabezado con sparkles
	var banner_row := HBoxContainer.new()
	banner_row.alignment = BoxContainer.ALIGNMENT_CENTER
	banner_row.add_theme_constant_override("separation", 6)
	for _i in 2:
		var sp := TextureRect.new()
		sp.texture = load("res://Assets/Icons/UI/sparkle.svg") as Texture2D
		sp.custom_minimum_size = Vector2(13, 13)
		sp.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		banner_row.add_child(sp)
		if _i == 0:
			var banner := Label.new()
			banner.text = "SUBIDA DE NIVEL"
			banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			banner.add_theme_font_size_override("font_size", 13)
			banner.add_theme_color_override("font_color", C_BORDER)
			if _font:
				banner.add_theme_font_override("font", _font)
			banner_row.add_child(banner)
	vbox.add_child(banner_row)

	# Número de nivel (grande)
	_level_lbl = Label.new()
	_level_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level_lbl.add_theme_font_size_override("font_size", 38)
	_level_lbl.add_theme_color_override("font_color",        C_GOLD)
	_level_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
	_level_lbl.add_theme_constant_override("shadow_offset_x", 3)
	_level_lbl.add_theme_constant_override("shadow_offset_y", 3)
	if _font:
		_level_lbl.add_theme_font_override("font", _font)
	vbox.add_child(_level_lbl)

	# Separador dorado
	var sep     := HSeparator.new()
	var sep_sty := StyleBoxFlat.new()
	sep_sty.bg_color           = C_BORDER
	sep_sty.content_margin_top = 1
	sep.add_theme_stylebox_override("separator", sep_sty)
	vbox.add_child(sep)

	# Mejoras de estadísticas
	_gains_lbl = Label.new()
	_gains_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gains_lbl.add_theme_font_size_override("font_size", 15)
	_gains_lbl.add_theme_color_override("font_color", C_GREEN)
	vbox.add_child(_gains_lbl)

	# Pista de cierre
	var hint := Label.new()
	hint.text                 = "[ ESPACIO / X ]  Continuar"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", C_HINT)
	if _font:
		hint.add_theme_font_override("font", _font)
	vbox.add_child(hint)


# Mostrar

func _on_level_changed(new_level: int) -> void:
	if _auto_tw:
		_auto_tw.kill()

	_level_lbl.text = "NIVEL  %d" % new_level
	_gains_lbl.text = "+10 HP   +5 MP   +2 ATK   +1 DEF   +1 VEL"
	_panel.modulate.a = 0.0
	visible = true

	_auto_tw = create_tween()
	_auto_tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_auto_tw.tween_property(_panel, "modulate:a", 1.0, 0.35)
	_auto_tw.tween_interval(4.0)
	_auto_tw.tween_callback(_dismiss)


# Cerrar

func _dismiss() -> void:
	if not visible:
		return
	if _auto_tw:
		_auto_tw.kill()
		_auto_tw = null
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_panel, "modulate:a", 0.0, 0.25)
	tw.tween_callback(func():
		visible = false
		_panel.modulate.a = 1.0
	)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_SPACE, KEY_ENTER, KEY_Z, KEY_X, KEY_ESCAPE]:
			get_viewport().set_input_as_handled()
			_dismiss()
	elif event is InputEventMouseButton and event.pressed:
		get_viewport().set_input_as_handled()
		_dismiss()
