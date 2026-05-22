class_name Minimap
extends CanvasLayer

const FONT_PATH  := "res://Assets/Fonts/CinzelDecorative-Bold.ttf"
const MAP_PX     := 200          # tamaño del minimapa en pantalla
const ZOOM_LEVEL := 0.60         # cuánto mundo se ve (menor = más alejado)

# Mapa completo: el mundo mide ~1940×1940 px centrado en el origen.
# Zoom = 840/1940 ≈ 0.43 para ver todo el mapa en el panel.
const FULLMAP_PX   := 840
const FULLMAP_ZOOM := 0.43

# Límites del mundo en coordenadas globales (centrado en el origen)
const WORLD_LEFT   := -970.0
const WORLD_RIGHT  :=  970.0
const WORLD_TOP    := -970.0
const WORLD_BOTTOM :=  970.0

const C_PANEL  := Color(0.05, 0.04, 0.09, 0.90)
const C_BORDER := Color(0.65, 0.50, 0.16, 1.00)
const C_GOLD   := Color(0.96, 0.84, 0.40, 1.00)

var _font:     Font
var _mini_cam: Camera2D
var _full_cam: Camera2D
var _player:   Node2D
var _dot:      Control

var _mini_root:    Control   # panel del minimapa pequeño
var _full_overlay: Control   # panel del mapa completo

var _minimap_visible: bool = true
var _fullmap_visible: bool = false


func _ready() -> void:
	_font = load(FONT_PATH)
	_build_minimap()
	_build_fullmap()


	# Minimapa pequeño
func _build_minimap() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_mini_root = root

	var panel := PanelContainer.new()
	panel.anchor_left   = 1.0
	panel.anchor_top    = 0.0
	panel.anchor_right  = 1.0
	panel.anchor_bottom = 0.0
	panel.offset_left   = -(MAP_PX + 28.0)
	panel.offset_top    =  12.0
	panel.offset_right  = -12.0
	panel.offset_bottom =  MAP_PX + 62.0

	var sty := StyleBoxFlat.new()
	sty.bg_color     = C_PANEL
	sty.set_border_width_all(0)
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

	var svc := SubViewportContainer.new()
	svc.custom_minimum_size = Vector2(MAP_PX, MAP_PX)
	svc.stretch             = true
	svc.mouse_filter        = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(svc)

	var sv := SubViewport.new()
	sv.size                      = Vector2i(int(MAP_PX), int(MAP_PX))
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sv.disable_3d                = true
	sv.transparent_bg            = true
	svc.add_child(sv)

	sv.call_deferred("set", "world_2d", get_viewport().world_2d)

	_mini_cam = Camera2D.new()
	_mini_cam.zoom = Vector2(ZOOM_LEVEL, ZOOM_LEVEL)
	sv.add_child(_mini_cam)

	_dot = _PlayerDot.new()
	svc.add_child(_dot)

	var frame := _FrameOverlay.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	svc.add_child(frame)

	# Hint de teclas
	var hint := Label.new()
	hint.text = "M mapa   N ocultar"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 9)
	hint.add_theme_color_override("font_color", Color(0.50, 0.50, 0.70))
	vbox.add_child(hint)


	# Mapa completo
func _build_fullmap() -> void:
	_full_overlay = Control.new()
	_full_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_full_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_full_overlay)

	# Fondo oscuro
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color        = Color(0.0, 0.0, 0.0, 0.80)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_full_overlay.add_child(bg)

	# Panel centrado
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left   = -(FULLMAP_PX / 2.0 + 20)
	panel.offset_right  =  (FULLMAP_PX / 2.0 + 20)
	panel.offset_top    = -(FULLMAP_PX / 2.0 + 42)
	panel.offset_bottom =  (FULLMAP_PX / 2.0 + 42)

	var sty := StyleBoxFlat.new()
	sty.bg_color     = Color(0.05, 0.04, 0.09, 0.97)
	sty.set_border_width_all(0)
	sty.set_corner_radius_all(8)
	sty.content_margin_left   = 16
	sty.content_margin_right  = 16
	sty.content_margin_top    = 12
	sty.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", sty)
	_full_overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "✦  MAPA DEL MUNDO  ✦"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", C_GOLD)
	if _font:
		title.add_theme_font_override("font", _font)
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	# SubViewportContainer del mapa completo
	var svc := SubViewportContainer.new()
	svc.custom_minimum_size = Vector2(FULLMAP_PX, FULLMAP_PX)
	svc.stretch             = true
	svc.mouse_filter        = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(svc)

	var sv := SubViewport.new()
	sv.size                      = Vector2i(FULLMAP_PX, FULLMAP_PX)
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sv.disable_3d                = true
	sv.transparent_bg            = true
	svc.add_child(sv)

	sv.call_deferred("set", "world_2d", get_viewport().world_2d)

	# Cámara fija en el centro del mundo
	_full_cam = Camera2D.new()
	_full_cam.zoom     = Vector2(FULLMAP_ZOOM, FULLMAP_ZOOM)
	_full_cam.position = Vector2.ZERO
	sv.add_child(_full_cam)

	# Punto del jugador (se reposiciona en _process)
	var dot := _PlayerDot.new()
	dot.name = "FullDot"
	dot.custom_minimum_size = Vector2(8, 8)
	svc.add_child(dot)

	var frame := _FrameOverlay.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	svc.add_child(frame)

	vbox.add_child(HSeparator.new())

	var hint := Label.new()
	hint.text = "M  —  Cerrar mapa"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.55, 0.55, 0.75))
	vbox.add_child(hint)

	_full_overlay.hide()


	# Input
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_M:
			get_viewport().set_input_as_handled()
			_fullmap_visible = not _fullmap_visible
			_full_overlay.visible = _fullmap_visible
			# Ocultar minimapa mientras el mapa completo está abierto
			_mini_root.visible = _minimap_visible and not _fullmap_visible
		KEY_N:
			get_viewport().set_input_as_handled()
			if _fullmap_visible:
				return
			_minimap_visible = not _minimap_visible
			_mini_root.visible = _minimap_visible


	# Process
func _process(_delta: float) -> void:
	if _mini_cam == null:
		return
	if _player == null:
		var group := get_tree().get_nodes_in_group("player")
		if group.is_empty():
			return
		_player = group[0] as Node2D

	# Minimapa sigue al jugador (clampeado para que no muestre fuera del mapa)
	var view_half := (MAP_PX / 2.0) / ZOOM_LEVEL
	var pos       := _player.global_position
	_mini_cam.global_position = Vector2(
		clampf(pos.x, WORLD_LEFT + view_half, WORLD_RIGHT - view_half),
		clampf(pos.y, WORLD_TOP  + view_half, WORLD_BOTTOM - view_half)
	)

	# Punto del jugador en el mapa completo
	if _fullmap_visible and _full_overlay != null:
		var dot := _full_overlay.find_child("FullDot", true, false) as Control
		if dot:
			var half := FULLMAP_PX / 2.0
			var scaled := _player.global_position * FULLMAP_ZOOM
			dot.set_position(Vector2(half + scaled.x - 4, half + scaled.y - 4))
			dot.queue_redraw()


	# Clases internas
class _PlayerDot extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size / 2.0
		draw_circle(c + Vector2(1, 1), 4.0, Color(0, 0, 0, 0.6))
		draw_circle(c, 4.5, Color(1, 1, 1, 0.9))
		draw_circle(c, 3.0, Color(1.00, 0.88, 0.20, 1.0))


class _FrameOverlay extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		pass
