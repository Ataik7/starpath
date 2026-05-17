class_name BattleHUD
extends CanvasLayer

const FONT_PATH := "res://Assets/Fonts/CinzelDecorative-Bold.ttf"

# ── Paleta ────────────────────────────────────────────────────────────────────
const C_BG      := Color(0.04, 0.04, 0.10, 0.88)
const C_BORDER  := Color(0.62, 0.48, 0.16, 1.00)
const C_SEP     := Color(0.55, 0.42, 0.12, 0.35)
const C_NAME    := Color(1.00, 0.96, 0.80, 1.00)
const C_TAG     := Color(0.88, 0.86, 0.78, 0.75)
const C_VAL     := Color(0.96, 0.94, 0.88, 1.00)
const C_HP_F    := Color(0.22, 0.82, 0.38, 1.00)
const C_HP_B    := Color(0.04, 0.16, 0.06, 1.00)
const C_SP_F    := Color(0.30, 0.58, 1.00, 1.00)
const C_SP_B    := Color(0.03, 0.06, 0.24, 1.00)

# ── Dimensiones ───────────────────────────────────────────────────────────────
const PANEL_W   := 230.0   # ancho del panel lateral derecho
const CARD_PAD  := 12.0    # padding interior de cada tarjeta
const BAR_H     := 10      # altura de las barras de HP/SP

var _hp_bars:   Dictionary = {}
var _sp_bars:   Dictionary = {}
var _hp_labels: Dictionary = {}
var _sp_labels: Dictionary = {}
var _cards:     Dictionary = {}
var _font:      Font
var _vbox:      VBoxContainer

# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_font = load(FONT_PATH) if ResourceLoader.exists(FONT_PATH) else null

	# Ocultar el Container heredado de la escena
	var legacy := get_node_or_null("Container")
	if legacy:
		legacy.hide()

	var vp := get_viewport().get_visible_rect().size

	# ── Panel compacto (solo el alto que necesite el contenido) ─────────────
	var panel := PanelContainer.new()
	var sty   := StyleBoxFlat.new()
	sty.bg_color              = C_BG
	sty.border_width_left     = 2
	sty.border_width_right    = 2
	sty.border_width_top      = 2
	sty.border_width_bottom   = 2
	sty.border_color          = C_BORDER
	sty.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", sty)
	panel.position     = Vector2(vp.x - PANEL_W - 8, 8)
	panel.custom_minimum_size = Vector2(PANEL_W, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)

	# ── VBox con las tarjetas (una por personaje) ────────────────────────────
	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 0)
	_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_vbox)

# ── API pública ───────────────────────────────────────────────────────────────

func setup(entities: Array[BaseEntity]) -> void:
	for entity in entities:
		_build_card(entity)

func set_active_entity(entity: BaseEntity) -> void:
	for ent: BaseEntity in _cards:
		var card: Control = _cards[ent]
		if ent == entity:
			card.modulate = Color(1.20, 1.20, 1.10)
		else:
			card.modulate = Color(0.55, 0.55, 0.55)

# ── Construcción de tarjetas ──────────────────────────────────────────────────

func _build_card(entity: BaseEntity) -> void:
# ── Contenedor de la tarjeta ─────────────────────────────────────────────
	var card := MarginContainer.new()
	card.add_theme_constant_override("margin_left",   int(CARD_PAD))
	card.add_theme_constant_override("margin_right",  int(CARD_PAD))
	card.add_theme_constant_override("margin_top",    int(CARD_PAD))
	card.add_theme_constant_override("margin_bottom", int(CARD_PAD))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_filter          = Control.MOUSE_FILTER_IGNORE
	_vbox.add_child(card)
	_cards[entity] = card

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(vb)

	# ── Nombre ───────────────────────────────────────────────────────────────
	var name_lbl := Label.new()
	name_lbl.text = entity.stats.character_name.to_upper()
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color",        C_NAME)
	name_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	name_lbl.add_theme_constant_override("shadow_offset_x", 1)
	name_lbl.add_theme_constant_override("shadow_offset_y", 1)
	if _font: name_lbl.add_theme_font_override("font", _font)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(name_lbl)

	# ── Barra HP ─────────────────────────────────────────────────────────────
	var hp_data := _stat_row("HP",
		entity.current_hp, entity.stats.max_hp, C_HP_F, C_HP_B)
	vb.add_child(hp_data[0])
	_hp_bars[entity]   = hp_data[1]
	_hp_labels[entity] = hp_data[2]

	# ── Barra SP ─────────────────────────────────────────────────────────────
	var sp_data := _stat_row("SP",
		entity.current_mp, entity.stats.max_mp, C_SP_F, C_SP_B)
	vb.add_child(sp_data[0])
	_sp_bars[entity]   = sp_data[1]
	_sp_labels[entity] = sp_data[2]

	entity.stats_changed.connect(func(): _refresh(entity))

# ── Fila de estadística: "TAG   [====barra====]   val / max" ──────────────────
func _stat_row(tag: String, val: int, max_val: int,
			   fill: Color, bg_col: Color) -> Array:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# — Fila superior: etiqueta + valor —
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 4)
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(top_row)

	var tag_lbl := Label.new()
	tag_lbl.text = tag
	tag_lbl.add_theme_font_size_override("font_size", 11)
	tag_lbl.add_theme_color_override("font_color", fill)
	if _font: tag_lbl.add_theme_font_override("font", _font)
	tag_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(tag_lbl)

	# Espaciador flexible
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter          = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(spacer)

	var val_lbl := Label.new()
	val_lbl.text                 = "%d / %d" % [val, max_val]
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_lbl.add_theme_font_size_override("font_size", 12)
	val_lbl.add_theme_color_override("font_color", C_VAL)
	if _font: val_lbl.add_theme_font_override("font", _font)
	val_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(val_lbl)

	# — Barra de progreso —
	var bar := ProgressBar.new()
	bar.show_percentage       = false
	bar.custom_minimum_size   = Vector2(0, BAR_H)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.min_value = 0
	bar.max_value = max(max_val, 1)
	bar.value     = val
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var fill_sty := StyleBoxFlat.new()
	fill_sty.bg_color = fill
	fill_sty.set_corner_radius_all(3)
	var bg_sty := StyleBoxFlat.new()
	bg_sty.bg_color = bg_col
	bg_sty.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill",       fill_sty)
	bar.add_theme_stylebox_override("background", bg_sty)
	col.add_child(bar)

	return [col, bar, val_lbl]

# ── Actualización en tiempo real ──────────────────────────────────────────────

func _refresh(entity: BaseEntity) -> void:
	if _hp_bars.has(entity):
		_hp_bars[entity].value  = entity.current_hp
		_hp_labels[entity].text = "%d / %d" % [entity.current_hp, entity.stats.max_hp]
	if _sp_bars.has(entity):
		_sp_bars[entity].value  = entity.current_mp
		_sp_labels[entity].text = "%d / %d" % [entity.current_mp, entity.stats.max_mp]
