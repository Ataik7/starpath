class_name HUD
extends CanvasLayer

const HERO_STATS_PATH := "res://Resources/Characters/Hero.tres"
const FONT_PATH       := "res://Assets/Fonts/CinzelDecorative-Bold.ttf"

const C_PANEL  := Color(0.05, 0.04, 0.09, 0.88)
const C_BORDER := Color(0.65, 0.50, 0.16, 1.00)
const C_TEXT   := Color(0.92, 0.88, 0.80, 1.00)
const C_HP     := Color(0.85, 0.22, 0.22, 1.00)
const C_HP_BG  := Color(0.30, 0.07, 0.07, 1.00)
const C_MP     := Color(0.25, 0.50, 0.95, 1.00)
const C_MP_BG  := Color(0.06, 0.12, 0.30, 1.00)

var _font:    Font
var _hp_bar:  ProgressBar
var _mp_bar:  ProgressBar
var _hp_lbl:  Label
var _mp_lbl:  Label
var _stats:   CharacterStats

func _ready() -> void:
	# El HUD de mundo fue reemplazado por el panel de grupo en el menú de pausa.
	visible = false

# Construcción

func _build_hud() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Panel inferior izquierdo
	var panel := PanelContainer.new()
	panel.anchor_left   = 0.0
	panel.anchor_top    = 1.0
	panel.anchor_right  = 0.0
	panel.anchor_bottom = 1.0
	panel.offset_left   =  12.0
	panel.offset_top    = -108.0
	panel.offset_right  =  230.0
	panel.offset_bottom = -12.0
	panel.mouse_filter  = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color             = C_PANEL
	style.border_color         = C_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.shadow_color         = Color(0, 0, 0, 0.6)
	style.shadow_size          = 10
	style.shadow_offset        = Vector2(0, 4)
	panel.add_theme_stylebox_override("panel", style)
	root.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   14)
	margin.add_theme_constant_override("margin_right",  14)
	margin.add_theme_constant_override("margin_top",    10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	# Nombre del personaje con sparkle
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 4)
	var name_sparkle := TextureRect.new()
	name_sparkle.texture = load("res://Assets/Icons/UI/sparkle.svg") as Texture2D
	name_sparkle.custom_minimum_size = Vector2(12, 12)
	name_sparkle.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	name_row.add_child(name_sparkle)
	var name_lbl := Label.new()
	name_lbl.text = "LYRA"
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.add_theme_color_override("font_color",        Color(0.96, 0.84, 0.40))
	name_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
	name_lbl.add_theme_constant_override("shadow_offset_x", 1)
	name_lbl.add_theme_constant_override("shadow_offset_y", 1)
	if _font:
		name_lbl.add_theme_font_override("font", _font)
	name_row.add_child(name_lbl)
	vbox.add_child(name_row)

	# Barra HP
	vbox.add_child(_build_bar_row("HP", C_HP, C_HP_BG, true))

	# Barra MP
	vbox.add_child(_build_bar_row("MP", C_MP, C_MP_BG, false))


func _build_bar_row(tag: String, bar_color: Color, bg_color: Color, is_hp: bool) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)

	# Fila etiqueta + valor
	var row := HBoxContainer.new()
	col.add_child(row)

	var tag_lbl := Label.new()
	tag_lbl.text = tag
	tag_lbl.custom_minimum_size = Vector2(26, 0)
	tag_lbl.add_theme_font_size_override("font_size", 11)
	tag_lbl.add_theme_color_override("font_color", bar_color)
	if _font:
		tag_lbl.add_theme_font_override("font", _font)
	row.add_child(tag_lbl)

	var val_lbl := Label.new()
	val_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	val_lbl.add_theme_font_size_override("font_size", 11)
	val_lbl.add_theme_color_override("font_color", C_TEXT)
	if _font:
		val_lbl.add_theme_font_override("font", _font)
	row.add_child(val_lbl)

	if is_hp:
		_hp_lbl = val_lbl
	else:
		_mp_lbl = val_lbl

	# Barra de progreso
	var bar := ProgressBar.new()
	bar.custom_minimum_size     = Vector2(0, 8)
	bar.show_percentage         = false

	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = bg_color
	bar_bg.set_corner_radius_all(4)

	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = bar_color
	bar_fill.set_corner_radius_all(4)

	bar.add_theme_stylebox_override("background", bar_bg)
	bar.add_theme_stylebox_override("fill",       bar_fill)
	col.add_child(bar)

	if is_hp:
		_hp_bar = bar
	else:
		_mp_bar = bar

	return col

# Refresco de datos

func _refresh() -> void:
	if _stats == null:
		return
	var hp    := Inventory.current_hp
	var max_hp := _stats.max_hp
	var mp    := Inventory.current_mp
	var max_mp := _stats.max_mp

	if _hp_bar:
		_hp_bar.max_value = max_hp
		_hp_bar.value     = hp
	if _mp_bar:
		_mp_bar.max_value = max_mp
		_mp_bar.value     = mp
	if _hp_lbl:
		_hp_lbl.text = "%d / %d" % [hp, max_hp]
	if _mp_lbl:
		_mp_lbl.text = "%d / %d" % [mp, max_mp]

# Llamar desde fuera cuando cambien HP/MP (p.ej. tras una batalla)
func update_stats(hp: int, mp: int) -> void:
	Inventory.current_hp = hp
	Inventory.current_mp = mp
	_refresh()
