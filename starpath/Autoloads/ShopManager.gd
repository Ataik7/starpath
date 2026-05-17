# ShopManager.gd  –  Autoload (CanvasLayer)
# Tienda RPG: lista de items, oro del jugador, compra con Enter, cierra con Escape.

extends CanvasLayer

signal shop_closed

var is_open:   bool            = false
var _catalog:  Array[ItemData] = []
var _filtered: Array[ItemData] = []
var _selected: int             = 0
var _current_category: String  = "todo"

# Nodos UI (compra)
var _overlay:     ColorRect
var _panel:       PanelContainer
var _title_label: Label
var _gold_label:  Label
var _cat_buttons: Array[Button] = []
var _items_vbox:  VBoxContainer
var _msg_label:   Label
var _item_rows:   Array[HBoxContainer] = []

# Nodos UI (venta)
var _sell_panel:    PanelContainer
var _sell_vbox:     VBoxContainer
var _sell_gold_lbl: Label
var _sell_msg_lbl:  Label
var _sell_items:    Array[ItemData] = []
var _sell_selected: int             = 0

const COLOR_SELECTED    := Color(1.00, 0.95, 0.35)
const COLOR_NORMAL      := Color(0.90, 0.90, 0.90)
const COLOR_CANT_AFFORD := Color(0.50, 0.50, 0.50)

const CATEGORIES := [
	{"label": "Todo",     "key": "todo"},
	{"label": "Guerrero", "key": "guerrero"},
	{"label": "Mago",     "key": "mago"},
	{"label": "Objetos",  "key": "objeto"},
]

#
func _ready() -> void:
	layer = 127
	_build_ui()
	_build_sell_ui()
	_overlay.hide()
	_panel.hide()
	_sell_panel.hide()

func _build_ui() -> void:
	# Fondo oscuro semitransparente
	_overlay = ColorRect.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.color        = Color(0, 0, 0, 0.55)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)

	# Panel centrado
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left   = -220
	_panel.offset_right  =  220
	_panel.offset_top    = -210
	_panel.offset_bottom =  210

	var style := StyleBoxFlat.new()
	style.bg_color     = Color(0.10, 0.07, 0.24, 0.98)
	style.border_color = Color(0.85, 0.70, 0.15)
	style.set_border_width_all(3)
	style.set_corner_radius_all(6)
	style.content_margin_left   = 22
	style.content_margin_right  = 22
	style.content_margin_top    = 16
	style.content_margin_bottom = 14
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_panel.add_child(vbox)

	# Cabecera: título + oro
	var header := HBoxContainer.new()
	vbox.add_child(header)

	_title_label = Label.new()
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.add_theme_font_size_override("font_size", 17)
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.30))
	header.add_child(_title_label)

	_gold_label = Label.new()
	_gold_label.add_theme_font_size_override("font_size", 14)
	_gold_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.30))
	header.add_child(_gold_label)

	vbox.add_child(HSeparator.new())

	# Botones de categoría
	var cat_row := HBoxContainer.new()
	cat_row.add_theme_constant_override("separation", 6)
	vbox.add_child(cat_row)

	for cat in CATEGORIES:
		var btn := Button.new()
		btn.text = cat["label"]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 12)
		btn.focus_mode = Control.FOCUS_NONE
		var key: String = cat["key"]
		btn.pressed.connect(func(): _set_category(key))
		cat_row.add_child(btn)
		_cat_buttons.append(btn)

	vbox.add_child(HSeparator.new())

	# Lista de items
	_items_vbox = VBoxContainer.new()
	_items_vbox.add_theme_constant_override("separation", 6)
	vbox.add_child(_items_vbox)

	vbox.add_child(HSeparator.new())

	# Mensaje de feedback
	_msg_label = Label.new()
	_msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(_msg_label)

	# Pista de controles
	var hint := Label.new()
	hint.text = "↑↓ Seleccionar   Enter Comprar   Esc Salir"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.55, 0.55, 0.75))
	vbox.add_child(hint)

#
func open_shop(catalog: Array[ItemData], title: String = "Tienda") -> void:
	if is_open or catalog.is_empty():
		return
	is_open           = true
	_catalog          = catalog
	_selected         = 0
	_current_category = "todo"
	_title_label.text = title
	_msg_label.text   = ""
	_apply_filter()
	_refresh_cat_buttons()
	_refresh_gold()
	_overlay.show()
	_panel.show()

func _set_category(cat: String) -> void:
	if _current_category == cat:
		return
	_current_category = cat
	_selected         = 0
	_msg_label.text   = ""
	_apply_filter()
	_refresh_cat_buttons()

func _apply_filter() -> void:
	if _current_category == "todo":
		_filtered = _catalog.duplicate()
	else:
		_filtered = _catalog.filter(func(item: ItemData) -> bool:
			return item.shop_category == _current_category
		)
	_populate_items()
	_refresh_selection()

func _refresh_cat_buttons() -> void:
	for i in _cat_buttons.size():
		var btn := _cat_buttons[i]
		var is_active: bool = (CATEGORIES[i]["key"] as String) == _current_category
		if is_active:
			btn.add_theme_color_override("font_color", Color(0.10, 0.07, 0.24))
			var s := StyleBoxFlat.new()
			s.bg_color = Color(1.0, 0.88, 0.30)
			s.set_corner_radius_all(4)
			btn.add_theme_stylebox_override("normal", s)
			btn.add_theme_stylebox_override("hover",  s)
			btn.add_theme_stylebox_override("pressed", s)
		else:
			btn.add_theme_color_override("font_color", Color(0.80, 0.80, 0.80))
			var s := StyleBoxFlat.new()
			s.bg_color = Color(0.20, 0.16, 0.38)
			s.set_corner_radius_all(4)
			btn.add_theme_stylebox_override("normal",  s)
			btn.add_theme_stylebox_override("hover",   s)
			btn.add_theme_stylebox_override("pressed", s)

func _populate_items() -> void:
	for child in _items_vbox.get_children():
		child.queue_free()
	_item_rows.clear()

	if _filtered.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "— Sin artículos —"
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.75))
		_items_vbox.add_child(empty_lbl)
		return

	for item in _filtered:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		_items_vbox.add_child(row)

		# Flecha selección
		var arrow := Label.new()
		arrow.text = "▶"
		arrow.add_theme_font_size_override("font_size", 14)
		arrow.custom_minimum_size = Vector2(18, 0)
		row.add_child(arrow)

		# Nombre
		var name_lbl := Label.new()
		name_lbl.text = item.item_name
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_font_size_override("font_size", 14)
		row.add_child(name_lbl)

		# Bonus de stat
		var stat_lbl := Label.new()
		stat_lbl.add_theme_font_size_override("font_size", 13)
		stat_lbl.custom_minimum_size    = Vector2(64, 0)
		stat_lbl.horizontal_alignment   = HORIZONTAL_ALIGNMENT_CENTER
		match item.item_type:
			ItemData.ItemType.WEAPON: stat_lbl.text = "ATK +%d" % item.attack_bonus
			ItemData.ItemType.ARMOR:  stat_lbl.text = "DEF +%d" % item.defense_bonus
			_:                        stat_lbl.text = ""
		row.add_child(stat_lbl)

		# Precio
		var price_lbl := Label.new()
		price_lbl.text = "%d ✦" % item.price
		price_lbl.add_theme_font_size_override("font_size", 13)
		price_lbl.custom_minimum_size  = Vector2(56, 0)
		price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(price_lbl)

		_item_rows.append(row)

func _refresh_gold() -> void:
	_gold_label.text = "Oro: %d ✦" % Inventory.gold

func _refresh_selection() -> void:
	for i in _item_rows.size():
		var can_afford := _filtered[i].price <= Inventory.gold
		var color: Color
		if i == _selected:
			color = COLOR_SELECTED
		elif can_afford:
			color = COLOR_NORMAL
		else:
			color = COLOR_CANT_AFFORD
		for child in _item_rows[i].get_children():
			if child is Label:
				child.add_theme_color_override("font_color", color)
		# Mostrar/ocultar flecha
		_item_rows[i].get_child(0).visible = (i == _selected)

# Entrada
func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	# Modo venta
	if _sell_panel.visible:
		if event.is_action_pressed("ui_up"):
			get_viewport().set_input_as_handled()
			if not _sell_items.is_empty():
				_sell_selected = (_sell_selected - 1 + _sell_items.size()) % _sell_items.size()
				_sell_msg_lbl.text = ""
				_refresh_sell_selection()
		elif event.is_action_pressed("ui_down"):
			get_viewport().set_input_as_handled()
			if not _sell_items.is_empty():
				_sell_selected = (_sell_selected + 1) % _sell_items.size()
				_sell_msg_lbl.text = ""
				_refresh_sell_selection()
		elif event.is_action_pressed("ui_accept"):
			get_viewport().set_input_as_handled()
			_try_sell()
		elif event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			_close_sell()
		return
	# Modo compra
	if event.is_action_pressed("ui_up"):
		get_viewport().set_input_as_handled()
		if _filtered.is_empty():
			return
		_selected = (_selected - 1 + _filtered.size()) % _filtered.size()
		_msg_label.text = ""
		_refresh_selection()
	elif event.is_action_pressed("ui_down"):
		get_viewport().set_input_as_handled()
		if _filtered.is_empty():
			return
		_selected = (_selected + 1) % _filtered.size()
		_msg_label.text = ""
		_refresh_selection()
	elif event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_try_buy()
	elif event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()

func _try_buy() -> void:
	if _filtered.is_empty():
		return
	var item := _filtered[_selected]
	if Inventory.gold < item.price:
		_msg_label.text = "¡Oro insuficiente!"
		_msg_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
		return
	Inventory.gold -= item.price
	Inventory.add_item(item)
	_refresh_gold()
	_refresh_selection()
	_msg_label.text = "¡" + item.item_name + " comprado!"
	_msg_label.add_theme_color_override("font_color", Color(0.35, 1.0, 0.5))

func _close() -> void:
	is_open = false
	_overlay.hide()
	_panel.hide()
	_catalog  = []
	_filtered = []
	shop_closed.emit()

# Panel de venta

func _build_sell_ui() -> void:
	_sell_panel = PanelContainer.new()
	_sell_panel.set_anchors_preset(Control.PRESET_CENTER)
	_sell_panel.offset_left   = -210
	_sell_panel.offset_right  =  210
	_sell_panel.offset_top    = -190
	_sell_panel.offset_bottom =  190

	var style := StyleBoxFlat.new()
	style.bg_color     = Color(0.10, 0.07, 0.24, 0.98)
	style.border_color = Color(0.85, 0.70, 0.15)
	style.set_border_width_all(3)
	style.set_corner_radius_all(6)
	style.content_margin_left   = 22
	style.content_margin_right  = 22
	style.content_margin_top    = 16
	style.content_margin_bottom = 14
	_sell_panel.add_theme_stylebox_override("panel", style)
	add_child(_sell_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_sell_panel.add_child(vbox)

	var header := HBoxContainer.new()
	vbox.add_child(header)

	var title_lbl := Label.new()
	title_lbl.name = "SellTitle"
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.add_theme_font_size_override("font_size", 17)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.30))
	title_lbl.text = "✦  Vender"
	header.add_child(title_lbl)

	_sell_gold_lbl = Label.new()
	_sell_gold_lbl.add_theme_font_size_override("font_size", 14)
	_sell_gold_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.30))
	header.add_child(_sell_gold_lbl)

	vbox.add_child(HSeparator.new())

	_sell_vbox = VBoxContainer.new()
	_sell_vbox.add_theme_constant_override("separation", 6)
	vbox.add_child(_sell_vbox)

	vbox.add_child(HSeparator.new())

	_sell_msg_lbl = Label.new()
	_sell_msg_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sell_msg_lbl.add_theme_font_size_override("font_size", 13)
	vbox.add_child(_sell_msg_lbl)

	var hint := Label.new()
	hint.text = "↑↓ Seleccionar   Enter Vender   Esc Salir"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.55, 0.55, 0.75))
	vbox.add_child(hint)

func open_sell(title: String = "Vender") -> void:
	if is_open:
		return
	is_open         = true
	_sell_selected  = 0
	_sell_msg_lbl.text = ""
	var title_lbl := _sell_panel.find_child("SellTitle", true, false) as Label
	if title_lbl:
		title_lbl.text = "✦  " + title
	_populate_sell_items()
	_sell_gold_lbl.text = "Oro: %d ✦" % Inventory.gold
	_overlay.show()
	_sell_panel.show()

func _populate_sell_items() -> void:
	for child in _sell_vbox.get_children():
		child.queue_free()

	_sell_items = Inventory.get_available()

	if _sell_items.is_empty():
		var lbl := Label.new()
		lbl.text = "— No tienes objetos —"
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.75))
		_sell_vbox.add_child(lbl)
		return

	for item: ItemData in _sell_items:
		var sell_price: int = maxi(1, item.price >> 1)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		_sell_vbox.add_child(row)

		var arrow := Label.new()
		arrow.text = "▶"
		arrow.add_theme_font_size_override("font_size", 14)
		arrow.custom_minimum_size = Vector2(18, 0)
		row.add_child(arrow)

		var name_lbl := Label.new()
		var qty := " ×%d" % item.quantity if item.item_type == ItemData.ItemType.CONSUMABLE else ""
		name_lbl.text = item.item_name + qty
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_font_size_override("font_size", 14)
		name_lbl.add_theme_color_override("font_color", COLOR_NORMAL)
		row.add_child(name_lbl)

		var price_lbl := Label.new()
		price_lbl.text = "%d ✦" % sell_price
		price_lbl.add_theme_font_size_override("font_size", 13)
		price_lbl.custom_minimum_size  = Vector2(56, 0)
		price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		price_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.30))
		row.add_child(price_lbl)

	_refresh_sell_selection()

func _refresh_sell_selection() -> void:
	var rows := _sell_vbox.get_children()
	for i in rows.size():
		var row = rows[i]
		if not row is HBoxContainer:
			continue
		var is_sel: bool = (i == _sell_selected)
		row.get_child(0).visible = is_sel  # flecha
		for child in row.get_children():
			if child is Label:
				child.add_theme_color_override("font_color",
					COLOR_SELECTED if is_sel else COLOR_NORMAL)

func _try_sell() -> void:
	if _sell_items.is_empty() or _sell_selected >= _sell_items.size():
		return
	var item := _sell_items[_sell_selected]
	var sell_price: int = maxi(1, item.price >> 1)
	Inventory.gold += sell_price
	Inventory.remove_item(item)
	_sell_msg_lbl.text = item.item_name + " vendido: +%d ✦" % sell_price
	_sell_msg_lbl.add_theme_color_override("font_color", Color(0.35, 1.0, 0.5))
	_sell_gold_lbl.text = "Oro: %d ✦" % Inventory.gold
	_populate_sell_items()
	if not _sell_items.is_empty():
		_sell_selected = mini(_sell_selected, _sell_items.size() - 1)

func _close_sell() -> void:
	is_open = false
	_overlay.hide()
	_sell_panel.hide()
	_sell_items = []
	shop_closed.emit()
