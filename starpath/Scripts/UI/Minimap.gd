class_name Minimap
extends CanvasLayer

const FONT_PATH  := "res://Assets/Fonts/CinzelDecorative-Bold.ttf"
const MAP_PX     := 200          # tamaño del minimapa en pantalla
const ZOOM_LEVEL := 0.60         # cuánto mundo se ve (menor = más alejado)

const C_PANEL    := Color(0.05, 0.04, 0.09, 0.90)
const C_BORDER   := Color(0.65, 0.50, 0.16, 1.00)
const C_GOLD     := Color(0.96, 0.84, 0.40, 1.00)
const C_DOT      := Color(1.00, 0.90, 0.20, 1.00)   # punto del jugador

var _font:     Font
var _mini_cam: Camera2D
var _player:   Node2D
var _dot:      Control          # indicador del jugador (siempre al centro)


func _ready() -> void:
	_font = load(FONT_PATH)
	_build_minimap()


# Construcción

func _build_minimap() -> void:
	# Raíz transparente a pantalla completa
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Panel (esquina superior derecha)
	var panel := PanelContainer.new()
	panel.anchor_left   = 1.0
	panel.anchor_top    = 0.0
	panel.anchor_right  = 1.0
	panel.anchor_bottom = 0.0
	panel.offset_left   = -(MAP_PX + 28.0)
	panel.offset_top    =  12.0
	panel.offset_right  = -12.0
	panel.offset_bottom =  MAP_PX + 50.0   # 50 = márgenes + título

	var sty := StyleBoxFlat.new()
	sty.bg_color   = C_PANEL
	sty.border_color = C_BORDER
	sty.set_border_width_all(1)
	sty.set_corner_radius_all(6)
	sty.shadow_color  = Color(0, 0, 0, 0.65)
	sty.shadow_size   = 12
	sty.shadow_offset = Vector2(0, 4)
	panel.add_theme_stylebox_override("panel", sty)
	root.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   8)
	margin.add_theme_constant_override("margin_right",  8)
	margin.add_theme_constant_override("margin_top",    6)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	# Título
	var title := Label.new()
	title.text = "✦  MAPA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 10)
	title.add_theme_color_override("font_color",        C_GOLD)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
	title.add_theme_constant_override("shadow_offset_x", 1)
	title.add_theme_constant_override("shadow_offset_y", 1)
	if _font:
		title.add_theme_font_override("font", _font)
	vbox.add_child(title)

	# SubViewportContainer
	var svc := SubViewportContainer.new()
	svc.custom_minimum_size = Vector2(MAP_PX, MAP_PX)
	svc.stretch             = true
	svc.mouse_filter        = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(svc)

	# SubViewport (comparte el World2D del juego)
	var sv := SubViewport.new()
	sv.size                      = Vector2i(int(MAP_PX), int(MAP_PX))
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sv.disable_3d                = true
	sv.transparent_bg            = false
	svc.add_child(sv)

	# Compartir el mundo 2D tras un frame (el viewport principal ya existe)
	sv.call_deferred("set", "world_2d", get_viewport().world_2d)

	# Cámara del minimapa
	_mini_cam = Camera2D.new()
	_mini_cam.zoom = Vector2(ZOOM_LEVEL, ZOOM_LEVEL)
	sv.add_child(_mini_cam)

	# Punto del jugador (siempre en el centro del minimapa)
	_dot = _PlayerDot.new()
	svc.add_child(_dot)

	# Borde interior sobre el viewport (marco de cierre)
	var frame := _FrameOverlay.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	svc.add_child(frame)


# Actualizar posición de cámara

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_M:
			visible = not visible

func _process(_delta: float) -> void:
	if _mini_cam == null:
		return
	if _player == null:
		# El jugador puede estar en CharactersLayer tras el reparenting → buscar por grupo
		var group := get_tree().get_nodes_in_group("player")
		if group.is_empty():
			return
		_player = group[0] as Node2D
	_mini_cam.global_position = _player.global_position


# Nodo interno: punto amarillo centrado

class _PlayerDot extends Control:
	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size / 2.0
		# Sombra
		draw_circle(c + Vector2(1, 1), 4.0, Color(0, 0, 0, 0.6))
		# Punto exterior blanco
		draw_circle(c, 4.5, Color(1, 1, 1, 0.9))
		# Punto interior dorado
		draw_circle(c, 3.0, Color(1.00, 0.88, 0.20, 1.0))


# Nodo interno: borde interior del viewport

class _FrameOverlay extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0.65, 0.50, 0.16, 0.70), false, 1.5)
