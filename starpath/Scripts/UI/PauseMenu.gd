class_name PauseMenu
extends CanvasLayer

const HERO_PATHS: Array[String] = [
	"res://Resources/Characters/Hero.tres",
]
var _equip_hero_index: int = 0

# Compañeros conocidos (mismo orden que party_members puede registrarlos)
const ALL_COMPANIONS: Array = [
	{"id": "athelios",         "stats": "res://Resources/Characters/Athelios.tres"},
	{"id": "byran",            "stats": "res://Resources/Characters/Byran.tres"},
	{"id": "companion_futuro", "stats": ""},
]
const _CLASS_NAMES: Array[String] = ["Guerrero", "Mago", "Pícaro", "Sanador", "Paladín", "Arquero"]

const FONT_PATH := "res://Assets/Fonts/CinzelDecorative-Bold.ttf"
var _font: Font

# Paleta fantasía oscura / dorada
const C_BG        := Color(0.02, 0.01, 0.04, 0.90)   # negro noche
const C_PANEL     := Color(0.07, 0.06, 0.11, 0.98)   # panel oscuro cálido
const C_BORDER    := Color(0.72, 0.57, 0.20, 1.00)   # oro antiguo
const C_BORDER2   := Color(0.45, 0.35, 0.10, 1.00)   # oro oscuro
const C_TITLE     := Color(0.96, 0.84, 0.40, 1.00)   # oro brillante
const C_TEXT      := Color(0.92, 0.88, 0.80, 1.00)   # blanco cálido
const C_MUTED     := Color(0.60, 0.56, 0.48, 1.00)   # gris cálido
const C_BTN_NORM  := Color(0.09, 0.08, 0.13, 0.96)   # botón oscuro
const C_BTN_HOV   := Color(0.18, 0.14, 0.06, 0.98)   # hover dorado oscuro
const C_ACCENT    := Color(0.96, 0.84, 0.40, 1.00)   # oro acento
const C_HP        := Color(0.88, 0.28, 0.28, 1.00)   # rojo vida
const C_MP        := Color(0.35, 0.60, 1.00, 1.00)   # azul maná

const MAIN_MENU_SCENE := "res://Scenes/UI/menu_inicio.tscn"

const PORTRAIT_TEX: Dictionary = {
	"lyra":     "res://Assets/Characters/Heroes/Lyra.png",
	"athelios": "res://Assets/Characters/Heroes/Athelios.png",
	"byran":    "res://Assets/Characters/Heroes/Byran.png",
}
const PORTRAIT_COLOR: Dictionary = {
	"lyra":     Color(0.38, 0.20, 0.58),
	"athelios": Color(0.15, 0.38, 0.68),
	"byran":    Color(0.55, 0.28, 0.10),
}

var _main_panel:      Control
var _items_panel:     Control
var _equip_panel:     Control
var _skills_panel:    Control
var _slot_panel:      Control
var _options_panel:   Control
var _keyboard_panel:  Control
var _confirm_panel:   Control

var _rebinding_action: String = ""
var _rebinding_btn:    Button = null

var _skills_char_index: int           = 0
var _skills_char_lbl:   Label         = null
var _skills_info_vbox:  VBoxContainer = null
var _skills_list_vbox:  VBoxContainer = null
var _open_frame:   int    = -1
var _slot_mode:    String = "save"
var _feedback_lbl:      Label
var _slot_feedback_lbl: Label
var _party_list:        VBoxContainer = null
var _play_start_unix:   float = 0.0

# Equip panel — referencias para refrescar sin reconstruir
var _equip_char_lbl:      Label         = null
var _equip_info_vbox:     VBoxContainer = null
var _equip_slots_vbox:    VBoxContainer = null
var _equip_picker_vbox:   VBoxContainer = null

# Items / Slots / Options — referencias directas para refrescar
var _items_list_vbox:  VBoxContainer = null
var _slot_title_lbl2:  Label         = null
var _slot_list_vbox:   VBoxContainer = null

# Confirm panel — acción pendiente
var _pending_action:     Callable
var _confirm_title_lbl:  Label
var _btn_save_act:       Button
var _btn_nosave_act:     Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_font = load(FONT_PATH)
	_play_start_unix = Time.get_unix_time_from_system()
	_build_ui()

# Abrir / Cerrar / Toggle

func toggle() -> void:
	if ShopManager.is_open or DialogManager.is_open:
		return
	if visible:
		close()
	else:
		open()

func open() -> void:
	_open_frame = Engine.get_process_frames()
	visible = true
	get_tree().paused = true
	_set_minimap_visible(false)
	_refresh_stats()
	_show_main()

func close() -> void:
	visible = false
	get_tree().paused = false
	_set_minimap_visible(true)

func _set_minimap_visible(visible_flag: bool) -> void:
	var minimap := get_parent().get_node_or_null("Minimap") if get_parent() else null
	if minimap:
		minimap.visible = visible_flag

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		# Modo rebinding: captura la siguiente tecla para la acción pendiente
		if _rebinding_action != "":
			get_viewport().set_input_as_handled()
			if event.keycode != KEY_ESCAPE:
				SettingsManager.set_binding(_rebinding_action, event.keycode)
			_rebinding_action = ""
			_rebinding_btn    = null
			_refresh_keyboard_panel()
			return

		if event.keycode == KEY_ESCAPE or event.is_action_pressed("open_menu"):
			# Ignorar si el menú se acaba de abrir en este mismo frame
			# (evita que el mismo input que lo abre lo cierre de inmediato)
			if Engine.get_process_frames() == _open_frame:
				get_viewport().set_input_as_handled()
				return
			if _confirm_panel.visible:
				_confirm_panel.visible = false
			elif _keyboard_panel.visible:
				_show_options()
			elif _items_panel.visible or _equip_panel.visible or _skills_panel.visible or _slot_panel.visible or _options_panel.visible:
				_show_main()
			else:
				close()
			get_viewport().set_input_as_handled()

# Construcción de la UI

func _build_ui() -> void:
	# Fondo semitransparente
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = C_BG
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	_main_panel  = _build_main_panel()
	_items_panel = _build_items_panel()
	_equip_panel = _build_equip_panel()
	_slot_panel    = _build_slot_panel()
	_skills_panel   = _build_skills_panel()
	_options_panel  = _build_options_panel()
	_keyboard_panel = _build_keyboard_panel()
	_confirm_panel  = _build_confirm_panel()
	add_child(_main_panel)
	add_child(_items_panel)
	add_child(_equip_panel)
	add_child(_skills_panel)
	add_child(_slot_panel)
	add_child(_options_panel)
	add_child(_keyboard_panel)
	add_child(_confirm_panel)

# Panel principal

func _build_main_panel() -> Control:
	# Raíz a pantalla completa
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 0)
	root.add_child(hbox)

	# Panel izquierdo: personajes (~68 % ancho)
	var left_panel := PanelContainer.new()
	left_panel.size_flags_horizontal    = Control.SIZE_EXPAND_FILL
	left_panel.size_flags_stretch_ratio = 2.2
	var left_style := StyleBoxFlat.new()
	left_style.bg_color            = Color(0.05, 0.04, 0.09, 0.97)
	left_style.border_width_right  = 2
	left_style.border_color        = C_BORDER2
	left_panel.add_theme_stylebox_override("panel", left_style)
	hbox.add_child(left_panel)

	var left_margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		left_margin.add_theme_constant_override(side, 20)
	left_panel.add_child(left_margin)

	var left_vbox := VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", 0)
	left_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_margin.add_child(left_vbox)

	_party_list = VBoxContainer.new()
	_party_list.name                 = "PartyList"
	_party_list.size_flags_vertical  = Control.SIZE_EXPAND_FILL
	_party_list.add_theme_constant_override("separation", 0)
	left_vbox.add_child(_party_list)

	left_vbox.add_child(_separator_h(C_BORDER2, 1))
	var gold_lbl := Label.new()
	gold_lbl.name = "GoldLbl"
	gold_lbl.add_theme_font_size_override("font_size", 14)
	gold_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.30))
	if _font:
		gold_lbl.add_theme_font_override("font", _font)
	left_vbox.add_child(gold_lbl)

	# Panel derecho: botones (~32 % ancho)
	var right_panel := PanelContainer.new()
	right_panel.size_flags_horizontal    = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_stretch_ratio = 1.0
	var right_style := StyleBoxFlat.new()
	right_style.bg_color = Color(0.07, 0.06, 0.11, 0.98)
	right_panel.add_theme_stylebox_override("panel", right_style)
	hbox.add_child(right_panel)

	var right_margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		right_margin.add_theme_constant_override(side, 28)
	right_panel.add_child(right_margin)

	var right_vbox := VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 3)
	right_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_margin.add_child(right_vbox)

	var menu_title := Label.new()
	menu_title.text = "— MENÚ —"
	menu_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_title.add_theme_font_size_override("font_size", 16)
	menu_title.add_theme_color_override("font_color", C_TITLE)
	if _font:
		menu_title.add_theme_font_override("font", _font)
	right_vbox.add_child(menu_title)
	right_vbox.add_child(_separator_h(C_BORDER, 1))
	right_vbox.add_child(_spacer(2))

	var btn_equip := _make_button("⚔   Equipo", 220, 38)
	btn_equip.pressed.connect(_show_equip)
	right_vbox.add_child(btn_equip)

	var btn_skills := _make_button("✦   Habilidades", 220, 38)
	btn_skills.pressed.connect(_show_skills)
	right_vbox.add_child(btn_skills)

	var btn_items := _make_button("⚗   Objetos", 220, 38)
	btn_items.pressed.connect(_show_items)
	right_vbox.add_child(btn_items)

	right_vbox.add_child(_separator_h(C_BORDER2, 1))

	var btn_save := _make_button("💾   Guardar", 220, 38)
	btn_save.pressed.connect(func(): _show_slots("save"))
	right_vbox.add_child(btn_save)

	var btn_load := _make_button("📂   Cargar partida", 220, 38)
	btn_load.pressed.connect(func(): _show_slots("load"))
	right_vbox.add_child(btn_load)

	var btn_opts := _make_button("⚙   Opciones", 220, 38)
	btn_opts.pressed.connect(_show_options)
	right_vbox.add_child(btn_opts)

	right_vbox.add_child(_separator_h(C_BORDER2, 1))

	var btn_main_menu := _make_button("⌂   Menú Principal", 220, 38)
	btn_main_menu.pressed.connect(_on_main_menu_pressed)
	btn_main_menu.add_theme_color_override("font_color",       Color(0.60, 0.90, 1.00))
	btn_main_menu.add_theme_color_override("font_hover_color", Color(0.85, 1.00, 1.00))
	right_vbox.add_child(btn_main_menu)

	var btn_quit := _make_button("⏻   Salir del juego", 220, 38)
	btn_quit.pressed.connect(_on_quit_pressed)
	btn_quit.add_theme_color_override("font_color",       Color(1.0, 0.40, 0.40))
	btn_quit.add_theme_color_override("font_hover_color", Color(1.0, 0.65, 0.65))
	right_vbox.add_child(btn_quit)

	right_vbox.add_child(_separator_h(C_BORDER2, 1))

	var btn_close := _make_button("✕   Cerrar  [Esc]", 220, 38)
	btn_close.pressed.connect(close)
	right_vbox.add_child(btn_close)

	_feedback_lbl = Label.new()
	_feedback_lbl.add_theme_font_size_override("font_size", 12)
	_feedback_lbl.add_theme_color_override("font_color", C_ACCENT)
	_feedback_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback_lbl.modulate.a = 0.0
	right_vbox.add_child(_feedback_lbl)

	# Espaciador para empujar el panel Tiempo & Oro al fondo
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vbox.add_child(spacer)

	# Panel TIEMPO & ORO (abajo derecha, estilo FF9)
	var tgo_panel := PanelContainer.new()
	var tgo_style := StyleBoxFlat.new()
	tgo_style.bg_color    = Color(0.05, 0.04, 0.09, 0.98)
	tgo_style.border_color = C_BORDER2
	tgo_style.set_border_width_all(1)
	tgo_style.set_corner_radius_all(4)
	tgo_style.content_margin_left   = 14
	tgo_style.content_margin_right  = 14
	tgo_style.content_margin_top    = 10
	tgo_style.content_margin_bottom = 10
	tgo_panel.add_theme_stylebox_override("panel", tgo_style)
	right_vbox.add_child(tgo_panel)

	var tgo_vbox := VBoxContainer.new()
	tgo_vbox.add_theme_constant_override("separation", 6)
	tgo_panel.add_child(tgo_vbox)

	var tgo_title := Label.new()
	tgo_title.text = "TIEMPO & ORO"
	tgo_title.add_theme_font_size_override("font_size", 11)
	tgo_title.add_theme_color_override("font_color", C_MUTED)
	if _font:
		tgo_title.add_theme_font_override("font", _font)
	tgo_vbox.add_child(tgo_title)

	tgo_vbox.add_child(_separator_h(C_BORDER2, 1))

	var time_row := HBoxContainer.new()
	time_row.add_theme_constant_override("separation", 8)
	tgo_vbox.add_child(time_row)
	var time_icon := Label.new()
	time_icon.text = "⏱"
	time_icon.add_theme_font_size_override("font_size", 14)
	time_row.add_child(time_icon)
	var time_lbl := Label.new()
	time_lbl.name = "TimeLbl"
	time_lbl.text = "00:00:00"
	time_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	time_lbl.horizontal_alignment  = HORIZONTAL_ALIGNMENT_RIGHT
	time_lbl.add_theme_font_size_override("font_size", 15)
	time_lbl.add_theme_color_override("font_color", C_TEXT)
	if _font:
		time_lbl.add_theme_font_override("font", _font)
	time_row.add_child(time_lbl)

	var gold_row := HBoxContainer.new()
	gold_row.add_theme_constant_override("separation", 8)
	tgo_vbox.add_child(gold_row)
	var gold_icon := Label.new()
	gold_icon.text = "✦"
	gold_icon.add_theme_font_size_override("font_size", 14)
	gold_icon.add_theme_color_override("font_color", Color(1.0, 0.88, 0.30))
	gold_row.add_child(gold_icon)
	var gold_val := Label.new()
	gold_val.name = "TGOGoldLbl"
	gold_val.text = "0 G"
	gold_val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gold_val.horizontal_alignment  = HORIZONTAL_ALIGNMENT_RIGHT
	gold_val.add_theme_font_size_override("font_size", 15)
	gold_val.add_theme_color_override("font_color", Color(1.0, 0.88, 0.30))
	if _font:
		gold_val.add_theme_font_override("font", _font)
	gold_row.add_child(gold_val)

	return root

# Panel de objetos (pantalla completa)

func _build_items_panel() -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.visible = false

	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 0)
	root.add_child(hbox)

	# Panel izquierdo: título + volver
	var lp := PanelContainer.new()
	lp.size_flags_horizontal    = Control.SIZE_EXPAND_FILL
	lp.size_flags_stretch_ratio = 0.55
	var ls := StyleBoxFlat.new()
	ls.bg_color           = Color(0.05, 0.04, 0.09, 0.97)
	ls.border_width_right = 2
	ls.border_color       = C_BORDER2
	lp.add_theme_stylebox_override("panel", ls)
	hbox.add_child(lp)

	var lm := MarginContainer.new()
	for s in ["margin_left","margin_right","margin_top","margin_bottom"]:
		lm.add_theme_constant_override(s, 24)
	lp.add_child(lm)

	var lv := VBoxContainer.new()
	lv.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lv.add_theme_constant_override("separation", 0)
	lm.add_child(lv)

	var title_lbl := Label.new()
	title_lbl.text = "OBJETOS"
	title_lbl.add_theme_font_size_override("font_size", 22)
	title_lbl.add_theme_color_override("font_color", C_TITLE)
	if _font: title_lbl.add_theme_font_override("font", _font)
	lv.add_child(title_lbl)
	lv.add_child(_separator_h(C_BORDER, 1))
	lv.add_child(_spacer(12))

	var desc := Label.new()
	desc.text = "Usa objetos del inventario durante el mapa o batalla."
	desc.add_theme_font_size_override("font_size", 13)
	desc.add_theme_color_override("font_color", C_MUTED)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	lv.add_child(desc)

	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lv.add_child(sp)

	var btn_back := _make_button("◀  Volver", 180, 38)
	btn_back.pressed.connect(_show_main)
	lv.add_child(btn_back)

	# Panel derecho: lista de objetos
	var rp := PanelContainer.new()
	rp.size_flags_horizontal    = Control.SIZE_EXPAND_FILL
	rp.size_flags_stretch_ratio = 1.45
	var rs := StyleBoxFlat.new()
	rs.bg_color = Color(0.07, 0.06, 0.11, 0.98)
	rp.add_theme_stylebox_override("panel", rs)
	hbox.add_child(rp)

	var rm := MarginContainer.new()
	for s in ["margin_left","margin_right","margin_top","margin_bottom"]:
		rm.add_theme_constant_override(s, 24)
	rp.add_child(rm)

	var rv := VBoxContainer.new()
	rv.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rv.add_theme_constant_override("separation", 8)
	rm.add_child(rv)

	_lbl_colored(rv, "INVENTARIO", 11, C_MUTED)
	rv.add_child(_separator_h(C_BORDER2, 1))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rv.add_child(scroll)

	_items_list_vbox = VBoxContainer.new()
	_items_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_items_list_vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(_items_list_vbox)

	return root

# Navegación

func _show_main() -> void:
	_rebinding_action       = ""
	_rebinding_btn          = null
	_main_panel.visible     = true
	_items_panel.visible    = false
	_equip_panel.visible    = false
	_skills_panel.visible   = false
	_slot_panel.visible     = false
	_options_panel.visible  = false
	_keyboard_panel.visible = false

func _show_items() -> void:
	_main_panel.visible  = false
	_items_panel.visible = true
	_equip_panel.visible = false
	_slot_panel.visible  = false
	_refresh_item_list()

func _show_equip() -> void:
	_main_panel.visible  = false
	_items_panel.visible = false
	_equip_panel.visible = true
	_slot_panel.visible  = false
	_refresh_equip()

func _show_slots(mode: String) -> void:
	_slot_mode = mode
	_main_panel.visible    = false
	_items_panel.visible   = false
	_equip_panel.visible   = false
	_slot_panel.visible    = true
	_options_panel.visible = false
	_refresh_slot_list()

func _show_options() -> void:
	_rebinding_action       = ""
	_rebinding_btn          = null
	_main_panel.visible    = false
	_items_panel.visible   = false
	_equip_panel.visible   = false
	_slot_panel.visible    = false
	_options_panel.visible = true
	_keyboard_panel.visible = false
	_refresh_options()

func _show_skills() -> void:
	_main_panel.visible     = false
	_items_panel.visible    = false
	_equip_panel.visible    = false
	_skills_panel.visible   = true
	_slot_panel.visible     = false
	_options_panel.visible  = false
	_keyboard_panel.visible = false
	_refresh_skills_panel()

func _show_keyboard() -> void:
	_main_panel.visible    = false
	_items_panel.visible   = false
	_equip_panel.visible   = false
	_skills_panel.visible  = false
	_slot_panel.visible    = false
	_options_panel.visible = false
	_keyboard_panel.visible = true
	_refresh_keyboard_panel()

# Refresco de datos

func _refresh_stats() -> void:
	if _party_list == null:
		return

	for child in _party_list.get_children():
		child.queue_free()

	# Lyra
	var hero_stats: CharacterStats = load(HERO_PATHS[0])
	if hero_stats:
		_add_ff9_party_row(
			_party_list, "lyra", "LYRA", "Maga",
			Inventory.current_level,
			Inventory.current_xp, Inventory.xp_to_next(),
			Inventory.current_hp, Inventory.get_max_hp(),
			Inventory.current_mp, Inventory.get_max_mp()
		)

	# Compañeros
	for comp: Dictionary in ALL_COMPANIONS:
		var id    : String         = comp["id"]
		var spath : String         = comp["stats"]
		var cs    : CharacterStats = load(spath) if spath != "" else null
		if Inventory.has_party_member(id):
			var lvl   : int    = Inventory.get_companion_level(id)
			var xp    : int    = Inventory.get_companion_xp(id)
			var xpcap : int    = Inventory.companion_xp_to_next(id)
			var cls   : String = _CLASS_NAMES[cs.character_class] if cs else "???"
			var hp    : int    = Inventory.get_companion_hp(id)
			var mhp   : int    = Inventory.get_companion_max_hp(id)
			var mp    : int    = Inventory.get_companion_mp(id)
			var mmp   : int    = Inventory.get_companion_max_mp(id)
			_add_ff9_party_row(
				_party_list, id,
				cs.character_name.to_upper() if cs else id.to_upper(),
				cls, lvl, xp, xpcap,
				hp, mhp, mp, mmp
			)
		else:
			_add_empty_party_slot(_party_list)

	# Oro (barra inferior izquierda)
	var gold_lbl := _main_panel.find_child("GoldLbl", true, false) as Label
	if gold_lbl:
		gold_lbl.text = "✦  Oro:  %d" % Inventory.gold

	# Tiempo & Oro (panel inferior derecho)
	var elapsed := int(SaveManager.get_total_play_time())
	@warning_ignore("integer_division")
	var h := elapsed / 3600
	@warning_ignore("integer_division")
	var m := (elapsed % 3600) / 60
	var s := elapsed % 60
	var time_lbl := _main_panel.find_child("TimeLbl", true, false) as Label
	if time_lbl:
		time_lbl.text = "%02d:%02d:%02d" % [h, m, s]
	var tgo_gold := _main_panel.find_child("TGOGoldLbl", true, false) as Label
	if tgo_gold:
		tgo_gold.text = "%d G" % Inventory.gold

# Tarjeta de personaje estilo RPG

func _add_party_card(parent: Node, char_name: String, class_label: String,
		level: int, xp: int, xp_cap: int,
		hp: int, max_hp: int, mp: int, max_mp: int,
		atk: int, def_: int, spd: int) -> void:
	var card := PanelContainer.new()
	var cs := StyleBoxFlat.new()
	cs.bg_color    = Color(0.10, 0.08, 0.18, 0.95)
	cs.border_color = C_BORDER
	cs.set_border_width_all(1)
	cs.set_corner_radius_all(5)
	cs.content_margin_left   = 9
	cs.content_margin_right  = 9
	cs.content_margin_top    = 8
	cs.content_margin_bottom = 8
	cs.shadow_color = Color(0, 0, 0, 0.5)
	cs.shadow_size  = 4
	card.add_theme_stylebox_override("panel", cs)
	parent.add_child(card)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	card.add_child(vb)

	# Cabecera: nombre + nivel
	var hdr := HBoxContainer.new()
	vb.add_child(hdr)

	var nlbl := Label.new()
	nlbl.text = "✦ " + char_name
	nlbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nlbl.add_theme_font_size_override("font_size", 12)
	nlbl.add_theme_color_override("font_color", C_TITLE)
	if _font: nlbl.add_theme_font_override("font", _font)
	hdr.add_child(nlbl)

	var lvlbl := Label.new()
	lvlbl.text = "Nv.%d" % level
	lvlbl.add_theme_font_size_override("font_size", 11)
	lvlbl.add_theme_color_override("font_color", C_MUTED)
	if _font: lvlbl.add_theme_font_override("font", _font)
	hdr.add_child(lvlbl)

	# Clase
	var clbl := Label.new()
	clbl.text = class_label
	clbl.add_theme_font_size_override("font_size", 10)
	clbl.add_theme_color_override("font_color", C_MUTED)
	vb.add_child(clbl)

	vb.add_child(_separator_h(C_BORDER2, 1))

	# Barras HP / MP
	vb.add_child(_build_mini_bar("HP", hp, max_hp, C_HP,  Color(0.28, 0.06, 0.06)))
	vb.add_child(_build_mini_bar("MP", mp, max_mp, C_MP,  Color(0.05, 0.10, 0.28)))

	# Fila ATK / DEF / VEL
	var sr := HBoxContainer.new()
	sr.add_theme_constant_override("separation", 8)
	vb.add_child(sr)
	for pair2 in [["ATK", atk], ["DEF", def_], ["VEL", spd]]:
		var sl := Label.new()
		sl.text = "%s %d" % [pair2[0], pair2[1]]
		sl.add_theme_font_size_override("font_size", 10)
		sl.add_theme_color_override("font_color", C_MUTED)
		sr.add_child(sl)

	# Barra EXP dorada
	var xr := HBoxContainer.new()
	xr.add_theme_constant_override("separation", 4)
	vb.add_child(xr)

	var xbar := ProgressBar.new()
	xbar.min_value = 0
	xbar.max_value = xp_cap if xp_cap > 0 else 1
	xbar.value     = xp
	xbar.show_percentage = false
	xbar.custom_minimum_size     = Vector2(0, 5)
	xbar.size_flags_horizontal   = Control.SIZE_EXPAND_FILL
	var xfill := StyleBoxFlat.new()
	xfill.bg_color = C_BORDER
	xfill.set_corner_radius_all(2)
	var xbg := StyleBoxFlat.new()
	xbg.bg_color = Color(0.07, 0.05, 0.10)
	xbg.set_corner_radius_all(2)
	xbar.add_theme_stylebox_override("fill",       xfill)
	xbar.add_theme_stylebox_override("background", xbg)
	xr.add_child(xbar)

	var xlbl := Label.new()
	xlbl.text = "EXP  %d/%d" % [xp, xp_cap]
	xlbl.add_theme_font_size_override("font_size", 9)
	xlbl.add_theme_color_override("font_color", C_MUTED)
	xr.add_child(xlbl)

func _add_empty_party_slot(parent: Node) -> void:
	var outer := VBoxContainer.new()
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_theme_constant_override("separation", 0)
	parent.add_child(outer)

	var bg := PanelContainer.new()
	bg.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.06, 0.05, 0.10, 0.55)
	s.set_corner_radius_all(0)
	s.content_margin_left = 14
	s.content_margin_right = 14
	bg.add_theme_stylebox_override("panel", s)
	outer.add_child(bg)
	outer.add_child(_separator_h(C_BORDER2, 1))


# Fila FF9: retrato + nombre/nivel + stats como texto (sin barras).
func _add_ff9_party_row(parent: Node, char_id: String, char_name: String,
		class_label: String, level: int, _xp: int, _xp_cap: int,
		hp: int, max_hp: int, mp: int, max_mp: int) -> void:
	# Contenedor que ocupa 1/N del panel izquierdo
	var outer := VBoxContainer.new()
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_theme_constant_override("separation", 0)
	parent.add_child(outer)

	var bg_panel := PanelContainer.new()
	bg_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color              = Color(0.08, 0.07, 0.14, 0.80)
	bg_style.border_width_left     = 5
	bg_style.border_color          = PORTRAIT_COLOR.get(char_id, C_BORDER2)
	bg_style.set_corner_radius_all(0)
	bg_style.content_margin_left   = 14
	bg_style.content_margin_right  = 14
	bg_style.content_margin_top    = 10
	bg_style.content_margin_bottom = 10
	bg_panel.add_theme_stylebox_override("panel", bg_style)
	outer.add_child(bg_panel)

	# Separador fino entre filas (actúa como divisor estilo FF9)
	outer.add_child(_separator_h(C_BORDER2, 1))

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bg_panel.add_child(hbox)

	hbox.add_child(_make_portrait(char_id))

	var sv := VBoxContainer.new()
	sv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sv.size_flags_vertical   = Control.SIZE_SHRINK_CENTER
	sv.add_theme_constant_override("separation", 6)
	hbox.add_child(sv)

	# Nombre   Clase   Lv X
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 10)
	sv.add_child(name_row)

	var nlbl := Label.new()
	nlbl.text = char_name
	nlbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nlbl.add_theme_font_size_override("font_size", 18)
	nlbl.add_theme_color_override("font_color", C_TITLE)
	if _font:
		nlbl.add_theme_font_override("font", _font)
	name_row.add_child(nlbl)

	var clbl := Label.new()
	clbl.text = class_label
	clbl.add_theme_font_size_override("font_size", 12)
	clbl.add_theme_color_override("font_color", C_MUTED)
	name_row.add_child(clbl)

	var lvlbl := Label.new()
	lvlbl.text = "Lv  %d" % level
	lvlbl.custom_minimum_size  = Vector2(52, 0)
	lvlbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lvlbl.add_theme_font_size_override("font_size", 16)
	lvlbl.add_theme_color_override("font_color", C_TEXT)
	if _font:
		lvlbl.add_theme_font_override("font", _font)
	name_row.add_child(lvlbl)

	sv.add_child(_ff9_stat_row("HP", hp, max_hp, C_HP))
	sv.add_child(_ff9_stat_row("MP", mp, max_mp, C_MP))

# Fila de stat sin barra: "HP     80 / 80"
func _ff9_stat_row(tag: String, val: int, max_val: int, tag_color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)

	var tlbl := Label.new()
	tlbl.text = tag
	tlbl.custom_minimum_size = Vector2(44, 0)
	tlbl.add_theme_font_size_override("font_size", 13)
	tlbl.add_theme_color_override("font_color", tag_color)
	if _font:
		tlbl.add_theme_font_override("font", _font)
	row.add_child(tlbl)

	var vlbl := Label.new()
	vlbl.text = "%d / %d" % [val, max_val]
	vlbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vlbl.horizontal_alignment  = HORIZONTAL_ALIGNMENT_LEFT
	vlbl.add_theme_font_size_override("font_size", 13)
	vlbl.add_theme_color_override("font_color", C_TEXT)
	row.add_child(vlbl)

	return row

# Barra de HP/MP estilo FF9 con etiqueta y valor numérico.
func _build_ff9_bar(tag: String, val: int, max_val: int,
		bar_color: Color, bg_color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var tlbl := Label.new()
	tlbl.text = tag
	tlbl.custom_minimum_size = Vector2(32, 0)
	tlbl.add_theme_font_size_override("font_size", 12)
	tlbl.add_theme_color_override("font_color", bar_color)
	if _font:
		tlbl.add_theme_font_override("font", _font)
	row.add_child(tlbl)

	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = max_val if max_val > 0 else 1
	bar.value     = val
	bar.show_percentage = false
	bar.custom_minimum_size   = Vector2(0, 12)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var fill := StyleBoxFlat.new()
	fill.bg_color = bar_color
	fill.set_corner_radius_all(3)
	var bg2 := StyleBoxFlat.new()
	bg2.bg_color = bg_color
	bg2.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill",       fill)
	bar.add_theme_stylebox_override("background", bg2)
	row.add_child(bar)

	var vlbl := Label.new()
	vlbl.text = "%d / %d" % [val, max_val]
	vlbl.custom_minimum_size  = Vector2(88, 0)
	vlbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vlbl.add_theme_font_size_override("font_size", 12)
	vlbl.add_theme_color_override("font_color", C_TEXT)
	row.add_child(vlbl)

	return row

# Caja de retrato: se expande para llenar la altura de la fila (estilo FF9).
func _make_portrait(char_id: String) -> Control:
	var container := PanelContainer.new()
	container.custom_minimum_size = Vector2(78, 0)   # ancho mínimo; alto libre
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color    = PORTRAIT_COLOR.get(char_id, Color(0.20, 0.18, 0.28))
	style.border_color = C_BORDER2
	style.set_border_width_all(1)
	style.set_corner_radius_all(0)
	container.add_theme_stylebox_override("panel", style)

	if PORTRAIT_TEX.has(char_id):
		var tex := load(PORTRAIT_TEX[char_id]) as Texture2D
		if tex:
			var atlas := AtlasTexture.new()
			atlas.atlas  = tex
			atlas.region = Rect2(32, 0, 32, 32)   # frame central, fila 0 (idle abajo)
			var img_rect := TextureRect.new()
			img_rect.texture      = atlas
			img_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
			img_rect.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
			img_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			img_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			container.add_child(img_rect)

	return container

func _build_mini_bar(tag: String, val: int, max_val: int,
		bar_color: Color, bg_color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)

	var tlbl := Label.new()
	tlbl.text = tag
	tlbl.custom_minimum_size = Vector2(18, 0)
	tlbl.add_theme_font_size_override("font_size", 10)
	tlbl.add_theme_color_override("font_color", bar_color)
	if _font: tlbl.add_theme_font_override("font", _font)
	row.add_child(tlbl)

	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = max_val if max_val > 0 else 1
	bar.value     = val
	bar.show_percentage = false
	bar.custom_minimum_size     = Vector2(0, 7)
	bar.size_flags_horizontal   = Control.SIZE_EXPAND_FILL
	var fill := StyleBoxFlat.new()
	fill.bg_color = bar_color
	fill.set_corner_radius_all(3)
	var bg2 := StyleBoxFlat.new()
	bg2.bg_color = bg_color
	bg2.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill",       fill)
	bar.add_theme_stylebox_override("background", bg2)
	row.add_child(bar)

	var vlbl := Label.new()
	vlbl.text = "%d/%d" % [val, max_val]
	vlbl.custom_minimum_size     = Vector2(46, 0)
	vlbl.horizontal_alignment    = HORIZONTAL_ALIGNMENT_RIGHT
	vlbl.add_theme_font_size_override("font_size", 10)
	vlbl.add_theme_color_override("font_color", C_TEXT)
	row.add_child(vlbl)

	return row

func _set_stat_lbl(stat_name: String, value: String) -> void:
	var lbl := _main_panel.find_child(stat_name, true, false) as Label
	if lbl:
		lbl.text = value

func _set_lbl(parent: Node, node_name: String, text: String) -> void:
	var lbl := parent.get_node_or_null(node_name) as Label
	if lbl:
		lbl.text = text

func _refresh_item_list() -> void:
	if _items_list_vbox == null:
		return
	for child in _items_list_vbox.get_children():
		child.queue_free()
	var available: Array = Inventory.get_available()
	if available.is_empty():
		_lbl_colored(_items_list_vbox, "No tienes objetos.", 14, C_MUTED)
	else:
		for item: ItemData in available:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			_items_list_vbox.add_child(row)
			row.add_child(_item_icon_node(item, 20.0))
			var nlbl := Label.new()
			nlbl.text = item.item_name
			nlbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			nlbl.add_theme_font_size_override("font_size", 14)
			nlbl.add_theme_color_override("font_color", C_TEXT)
			row.add_child(nlbl)
			var qlbl := Label.new()
			qlbl.text = "×%d" % item.quantity
			qlbl.add_theme_font_size_override("font_size", 14)
			qlbl.add_theme_color_override("font_color", C_ACCENT)
			row.add_child(qlbl)
			# Botón Usar solo para consumibles
			if item.item_type == ItemData.ItemType.CONSUMABLE:
				var btn := Button.new()
				btn.text = "Usar"
				btn.custom_minimum_size = Vector2(60, 28)
				btn.add_theme_font_size_override("font_size", 12)
				var s := StyleBoxFlat.new()
				s.bg_color = Color(0.14, 0.24, 0.14)
				s.set_corner_radius_all(4)
				s.set_border_width_all(1)
				s.border_color = Color(0.30, 0.70, 0.30)
				var sh := StyleBoxFlat.new()
				sh.bg_color = Color(0.20, 0.40, 0.20)
				sh.set_corner_radius_all(4)
				btn.add_theme_stylebox_override("normal",  s)
				btn.add_theme_stylebox_override("hover",   sh)
				btn.add_theme_stylebox_override("pressed", sh)
				btn.add_theme_color_override("font_color", Color(0.60, 1.00, 0.60))
				# Deshabilitar si HP/MP ya están al máximo
				var at_max := false
				if item.effect_type == "heal_hp":
					at_max = Inventory.current_hp >= Inventory.get_max_hp()
				elif item.effect_type == "heal_mp":
					at_max = Inventory.current_mp >= Inventory.get_max_mp()
				btn.disabled = at_max
				btn.pressed.connect(_use_item_outside_combat.bind(item))
				row.add_child(btn)

func _use_item_outside_combat(item: ItemData) -> void:
	# Si no hay compañeros, usar directo en Lyra
	if Inventory.party_members.is_empty():
		_apply_item_to_target("lyra", item)
		return
	# Mostrar selector de personaje
	_show_target_selector(item)

func _show_target_selector(item: ItemData) -> void:
	# Panel selector centrado encima del inventario
	var selector := PanelContainer.new()
	selector.name = "TargetSelector"
	selector.set_anchors_preset(Control.PRESET_CENTER)
	selector.offset_left   = -160
	selector.offset_right  =  160
	selector.offset_top    = -120
	selector.offset_bottom =  120

	var sty := StyleBoxFlat.new()
	sty.bg_color     = Color(0.07, 0.06, 0.11, 0.98)
	sty.border_color = C_BORDER
	sty.set_border_width_all(2)
	sty.set_corner_radius_all(6)
	sty.content_margin_left   = 16
	sty.content_margin_right  = 16
	sty.content_margin_top    = 12
	sty.content_margin_bottom = 12
	selector.add_theme_stylebox_override("panel", sty)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	selector.add_child(vbox)

	var title := Label.new()
	title.text = "¿A quién usar %s?" % item.item_name
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", C_TITLE)
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	# Botón para Lyra (héroe principal)
	var is_hp := item.effect_type == "heal_hp"
	var lyra_cur  := Inventory.current_hp if is_hp else Inventory.current_mp
	var lyra_max  := Inventory.get_max_hp() if is_hp else Inventory.get_max_mp()
	var btn_lyra  := _make_target_btn("Lyra", lyra_cur, lyra_max, lyra_cur >= lyra_max)
	btn_lyra.pressed.connect(func():
		selector.queue_free()
		_apply_item_to_target("lyra", item)
	)
	vbox.add_child(btn_lyra)

	# Botones para cada compañero en el grupo
	for id in Inventory.party_members:
		var comp_cur := Inventory.get_companion_hp(id) if is_hp else Inventory.get_companion_mp(id)
		var comp_max := Inventory.get_companion_max_hp(id) if is_hp else Inventory.get_companion_max_mp(id)
		var cap_id   := id.capitalize()
		var btn_comp := _make_target_btn(cap_id, comp_cur, comp_max, comp_cur >= comp_max)
		btn_comp.pressed.connect(func():
			selector.queue_free()
			_apply_item_to_target(id, item)
		)
		vbox.add_child(btn_comp)

	vbox.add_child(HSeparator.new())

	var btn_cancel := Button.new()
	btn_cancel.text = "Cancelar"
	btn_cancel.add_theme_font_size_override("font_size", 12)
	btn_cancel.add_theme_color_override("font_color", C_MUTED)
	btn_cancel.pressed.connect(func(): selector.queue_free())
	vbox.add_child(btn_cancel)

	_items_panel.add_child(selector)

func _make_target_btn(char_name: String, cur: int, max_val: int, full: bool) -> Button:
	var btn := Button.new()
	btn.text     = "%s   %d / %d" % [char_name, cur, max_val]
	btn.disabled = full
	btn.custom_minimum_size = Vector2(280, 36)
	btn.add_theme_font_size_override("font_size", 13)
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.09, 0.08, 0.14)
	s.set_corner_radius_all(4)
	s.set_border_width_all(1)
	s.border_color = C_BORDER2
	var sh := StyleBoxFlat.new()
	sh.bg_color = Color(0.18, 0.14, 0.06)
	sh.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal",  s)
	btn.add_theme_stylebox_override("hover",   sh)
	btn.add_theme_stylebox_override("pressed", sh)
	btn.add_theme_color_override("font_color", C_MUTED if full else C_TEXT)
	return btn

func _apply_item_to_target(target_id: String, item: ItemData) -> void:
	if target_id == "lyra":
		if item.effect_type == "heal_hp":
			Inventory.current_hp = mini(Inventory.current_hp + item.amount, Inventory.get_max_hp())
		elif item.effect_type == "heal_mp":
			Inventory.current_mp = mini(Inventory.current_mp + item.amount, Inventory.get_max_mp())
	else:
		if item.effect_type == "heal_hp":
			Inventory.set_companion_hp(target_id, Inventory.get_companion_hp(target_id) + item.amount)
		elif item.effect_type == "heal_mp":
			Inventory.set_companion_mp(target_id, Inventory.get_companion_mp(target_id) + item.amount)
	Inventory.remove_item(item)
	_refresh_item_list()
	_refresh_stats()

# Helpers de construcción

func _make_centered_root(w: int, h: int) -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(w, h)
	panel.offset_left   = -w / 2.0
	panel.offset_top    = -h / 2.0
	panel.offset_right  =  w / 2.0
	panel.offset_bottom =  h / 2.0
	root.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 18)
	panel.add_child(margin)

	return root

func _style_panel(panel: PanelContainer, bg: Color, border: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color             = bg
	style.border_color         = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.shadow_color         = Color(0, 0, 0, 0.75)
	style.shadow_size          = 20
	style.shadow_offset        = Vector2(0, 6)
	panel.add_theme_stylebox_override("panel", style)

func _make_button(text: String, w: int, h: int) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(w, h)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

	# Normal: borde izquierdo dorado como acento RPG
	var s_norm := StyleBoxFlat.new()
	s_norm.bg_color             = C_BTN_NORM
	s_norm.set_corner_radius_all(4)
	s_norm.border_width_left    = 3
	s_norm.border_width_top     = 1
	s_norm.border_width_right   = 1
	s_norm.border_width_bottom  = 1
	s_norm.border_color         = C_BORDER2
	s_norm.content_margin_left  = 14
	s_norm.shadow_color         = Color(0, 0, 0, 0.4)
	s_norm.shadow_size          = 4

	# Hover: borde izquierdo más grueso y brillante
	var s_hov := StyleBoxFlat.new()
	s_hov.bg_color              = C_BTN_HOV
	s_hov.set_corner_radius_all(4)
	s_hov.border_width_left     = 4
	s_hov.border_width_top      = 1
	s_hov.border_width_right    = 1
	s_hov.border_width_bottom   = 1
	s_hov.border_color          = C_BORDER
	s_hov.content_margin_left   = 14
	s_hov.shadow_color          = Color(0.72, 0.57, 0.20, 0.3)
	s_hov.shadow_size           = 6

	var s_press := StyleBoxFlat.new()
	s_press.bg_color            = C_BORDER2
	s_press.set_corner_radius_all(4)
	s_press.border_width_left   = 4
	s_press.border_color        = C_BORDER
	s_press.content_margin_left = 14

	btn.add_theme_stylebox_override("normal",   s_norm)
	btn.add_theme_stylebox_override("hover",    s_hov)
	btn.add_theme_stylebox_override("pressed",  s_press)
	btn.add_theme_color_override("font_color",          C_TEXT)
	btn.add_theme_color_override("font_hover_color",    C_TITLE)
	btn.add_theme_color_override("font_pressed_color",  Color.WHITE)
	btn.add_theme_color_override("font_focus_color",    C_TEXT)
	btn.add_theme_font_size_override("font_size", 13)
	if _font:
		btn.add_theme_font_override("font", _font)

	return btn

func _lbl_colored(parent: Node, text: String, size: int, color: Color) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	parent.add_child(lbl)

func _separator_h(color: Color, thickness: int = 1) -> HSeparator:
	var sep := HSeparator.new()
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.content_margin_top    = thickness
	style.content_margin_bottom = thickness
	sep.add_theme_stylebox_override("separator", style)
	return sep

func _separator_v(color: Color) -> VSeparator:
	var sep := VSeparator.new()
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.content_margin_left  = 1
	style.content_margin_right = 1
	sep.add_theme_stylebox_override("separator", style)
	return sep

func _spacer(px: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, px)
	return c

# Panel de equipamiento (pantalla completa estilo FF9)

func _build_equip_panel() -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.visible = false

	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 0)
	root.add_child(hbox)

	# Panel izquierdo: INFO del personaje
	var left_panel := PanelContainer.new()
	left_panel.size_flags_horizontal    = Control.SIZE_EXPAND_FILL
	left_panel.size_flags_stretch_ratio = 1.1
	var ls := StyleBoxFlat.new()
	ls.bg_color           = Color(0.05, 0.04, 0.09, 0.97)
	ls.border_width_right = 2
	ls.border_color       = C_BORDER2
	left_panel.add_theme_stylebox_override("panel", ls)
	hbox.add_child(left_panel)

	var lm := MarginContainer.new()
	for s in ["margin_left","margin_right","margin_top","margin_bottom"]:
		lm.add_theme_constant_override(s, 20)
	left_panel.add_child(lm)

	var left_vbox := VBoxContainer.new()
	left_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_vbox.add_theme_constant_override("separation", 0)
	lm.add_child(left_vbox)

	_lbl_colored(left_vbox, "PERSONAJE", 11, C_MUTED)
	left_vbox.add_child(_separator_h(C_BORDER2, 1))
	left_vbox.add_child(_spacer(6))

	# Área dinámica: retrato + nombre/stats (se borra y repobla en _refresh_equip)
	_equip_info_vbox = VBoxContainer.new()
	_equip_info_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_equip_info_vbox.add_theme_constant_override("separation", 6)
	left_vbox.add_child(_equip_info_vbox)

	left_vbox.add_child(_spacer(8))
	var btn_back := _make_button("◀  Volver", 160, 36)
	btn_back.pressed.connect(_show_main)
	left_vbox.add_child(btn_back)

	# Panel derecho: selector + equipo + habilidades
	var right_panel := PanelContainer.new()
	right_panel.size_flags_horizontal    = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_stretch_ratio = 1.4
	var rs := StyleBoxFlat.new()
	rs.bg_color = Color(0.07, 0.06, 0.11, 0.98)
	right_panel.add_theme_stylebox_override("panel", rs)
	hbox.add_child(right_panel)

	var rm := MarginContainer.new()
	for s in ["margin_left","margin_right","margin_top","margin_bottom"]:
		rm.add_theme_constant_override(s, 20)
	right_panel.add_child(rm)

	var right_vbox := VBoxContainer.new()
	right_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vbox.add_theme_constant_override("separation", 10)
	rm.add_child(right_vbox)

	# Selector de personaje
	var sel_row := HBoxContainer.new()
	sel_row.add_theme_constant_override("separation", 8)
	sel_row.alignment = BoxContainer.ALIGNMENT_CENTER
	right_vbox.add_child(sel_row)

	var btn_prev := _make_button("◀", 32, 30)
	btn_prev.pressed.connect(func():
		var sz := _get_equip_chars().size()
		_equip_hero_index = (_equip_hero_index - 1 + sz) % sz
		_refresh_equip())
	sel_row.add_child(btn_prev)

	_equip_char_lbl = Label.new()
	_equip_char_lbl.custom_minimum_size     = Vector2(200, 0)
	_equip_char_lbl.horizontal_alignment    = HORIZONTAL_ALIGNMENT_CENTER
	_equip_char_lbl.add_theme_font_size_override("font_size", 17)
	_equip_char_lbl.add_theme_color_override("font_color", C_TITLE)
	if _font:
		_equip_char_lbl.add_theme_font_override("font", _font)
	sel_row.add_child(_equip_char_lbl)

	var btn_next := _make_button("▶", 32, 30)
	btn_next.pressed.connect(func():
		var sz := _get_equip_chars().size()
		_equip_hero_index = (_equip_hero_index + 1) % sz
		_refresh_equip())
	sel_row.add_child(btn_next)

	right_vbox.add_child(_separator_h(C_BORDER, 1))

	# Sección EQUIPO
	_lbl_colored(right_vbox, "EQUIPO", 11, C_MUTED)
	_equip_slots_vbox = VBoxContainer.new()
	_equip_slots_vbox.add_theme_constant_override("separation", 8)
	right_vbox.add_child(_equip_slots_vbox)

	# Picker inline — aparece al pulsar "Cambiar" en un slot
	_equip_picker_vbox = VBoxContainer.new()
	_equip_picker_vbox.add_theme_constant_override("separation", 4)
	_equip_picker_vbox.visible = false
	right_vbox.add_child(_equip_picker_vbox)

	return root

# Lista dinámica de personajes disponibles en el panel de equipamiento.
# Lyra siempre primero; luego los compañeros que se hayan unido.
func _get_equip_chars() -> Array:
	var result: Array = []
	result.append({"id": "lyra", "stats": "res://Resources/Characters/Hero.tres"})
	for comp: Dictionary in ALL_COMPANIONS:
		var id: String = comp["id"]
		if comp["stats"] != "" and Inventory.has_party_member(id):
			result.append({"id": id, "stats": comp["stats"]})
	return result

func _refresh_equip() -> void:
	var chars := _get_equip_chars()
	if chars.is_empty():
		return
	_equip_hero_index = clamp(_equip_hero_index, 0, chars.size() - 1)

	var char_entry : Dictionary     = chars[_equip_hero_index]
	var char_id    : String         = char_entry["id"]
	var spath      : String         = char_entry["stats"]
	var stats      : CharacterStats = load(spath)
	var is_lyra    : bool           = (char_id == "lyra")

	# Selector
	if _equip_char_lbl:
		_equip_char_lbl.text = stats.character_name.to_upper() if stats else char_id.to_upper()

	# Panel izquierdo: retrato grande + info estilo FF9
	for c in _equip_info_vbox.get_children():
		c.queue_free()

	var lvl : int = Inventory.current_level if is_lyra else Inventory.get_companion_level(char_id)
	var hp  : int = Inventory.current_hp        if is_lyra else Inventory.get_companion_hp(char_id)
	var mhp : int = Inventory.get_max_hp()      if is_lyra else Inventory.get_companion_max_hp(char_id)
	var mp  : int = Inventory.current_mp        if is_lyra else Inventory.get_companion_mp(char_id)
	var mmp : int = Inventory.get_max_mp()      if is_lyra else Inventory.get_companion_max_mp(char_id)
	var atk_bonus : int = Inventory.get_attack_bonus()  if is_lyra else Inventory.get_atk_bonus_for(char_id)
	var def_bonus : int = Inventory.get_defense_bonus() if is_lyra else Inventory.get_def_bonus_for(char_id)

	# Fila superior: retrato pequeño + nombre/HP/MP (estilo FF9 INFO)
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 14)
	_equip_info_vbox.add_child(top_row)

	top_row.add_child(_make_equip_portrait(char_id))

	var info_sv := VBoxContainer.new()
	info_sv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_sv.size_flags_vertical   = Control.SIZE_SHRINK_CENTER
	info_sv.add_theme_constant_override("separation", 4)
	top_row.add_child(info_sv)

	# Nombre + Nivel en la misma fila
	var cn_row := HBoxContainer.new()
	cn_row.add_theme_constant_override("separation", 10)
	info_sv.add_child(cn_row)
	var cn_lbl := Label.new()
	cn_lbl.text = stats.character_name if stats else char_id.capitalize()
	cn_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cn_lbl.add_theme_font_size_override("font_size", 17)
	cn_lbl.add_theme_color_override("font_color", C_TITLE)
	if _font: cn_lbl.add_theme_font_override("font", _font)
	cn_row.add_child(cn_lbl)
	var lv_lbl := Label.new()
	lv_lbl.text = "Lv %d" % lvl
	lv_lbl.add_theme_font_size_override("font_size", 15)
	lv_lbl.add_theme_color_override("font_color", C_TEXT)
	cn_row.add_child(lv_lbl)

	# HP / MP
	info_sv.add_child(_ff9_stat_row("HP", hp, mhp, C_HP))
	info_sv.add_child(_ff9_stat_row("MP", mp, mmp, C_MP))

	_equip_info_vbox.add_child(_separator_h(C_BORDER2, 1))

	# Stats en columna única estilo FF9 (dos grupos con separación)
	if stats:
		var group1 := [
			["Velocidad", stats.speed],
			["Fuerza",    stats.strength],
			["Magia",     stats.magic],
			["Espíritu",  stats.spirit],
		]
		var group2 := [
			["Ataque",      stats.attack   + atk_bonus],
			["Defensa",     stats.defense  + def_bonus],
			["Esquiva",     stats.evade],
			["Def. Mágica", stats.magic_defense],
			["Esq. Mágica", stats.magic_evade],
		]
		for entry in group1:
			_equip_info_vbox.add_child(_equip_stat_row(entry[0], entry[1]))
		_equip_info_vbox.add_child(_spacer(8))
		for entry in group2:
			_equip_info_vbox.add_child(_equip_stat_row(entry[0], entry[1]))

	# Slots de equipo (todos los personajes interactivos)
	for c in _equip_slots_vbox.get_children():
		c.queue_free()
	_hide_equip_picker()

	var w_item := Inventory.equipped_weapon if is_lyra else Inventory.get_equipped_weapon_for(char_id)
	var a_item := Inventory.equipped_armor  if is_lyra else Inventory.get_equipped_armor_for(char_id)
	_add_slot_row_unified(_equip_slots_vbox, "Arma:", w_item, char_id, ItemData.ItemType.WEAPON)
	_add_slot_row_unified(_equip_slots_vbox, "Armadura:", a_item, char_id, ItemData.ItemType.ARMOR)


# Retrato grande para el panel de equipo: llena el espacio disponible (estilo FF9).
func _make_equip_portrait(char_id: String) -> Control:
	var container := PanelContainer.new()
	container.custom_minimum_size    = Vector2(80, 80)
	container.size_flags_horizontal  = Control.SIZE_SHRINK_BEGIN
	container.size_flags_vertical    = Control.SIZE_SHRINK_BEGIN
	var style := StyleBoxFlat.new()
	style.bg_color    = PORTRAIT_COLOR.get(char_id, Color(0.20, 0.18, 0.28))
	style.border_color = C_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(0)
	container.add_theme_stylebox_override("panel", style)
	if PORTRAIT_TEX.has(char_id):
		var tex := load(PORTRAIT_TEX[char_id]) as Texture2D
		if tex:
			var atlas := AtlasTexture.new()
			atlas.atlas  = tex
			atlas.region = Rect2(32, 0, 32, 32)
			var img_rect := TextureRect.new()
			img_rect.texture      = atlas
			img_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
			img_rect.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
			img_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			img_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			container.add_child(img_rect)
	return container

const _ICON_POTIONS := "res://Assets/Icons/Items/PotionBottles.png"
const _ICON_WEAPONS := "res://Assets/Icons/Items/Weapons.png"
const _ICON_ARMOR   := "res://Assets/Icons/Items/Armor.png"
const _ICON_CELL_W  := 128.0 / 5.0   # 25.6 px por icono

# Crea un TextureRect con el icono del ítem desde el spritesheet correspondiente.
# Índices Potions : 0=azul(maná) 1=verde(antídoto) 2=amarillo 3=naranja 4=rojo(vida)
# Índices Weapons : 0=daga 1=espada 2=arco 3=hacha 4=bastón
# Índices Armor   : 0=casco 1=pecho 2=pantalón 3=botas 4=escudo
func _item_icon_node(item: ItemData, size: float = 20.0) -> TextureRect:
	var n    := item.item_name.to_lower()
	var path := _ICON_POTIONS
	var idx  := 2
	if item.item_type == ItemData.ItemType.CONSUMABLE:
		path = _ICON_POTIONS
		if   "poción" in n or "pocion" in n or "elixir" in n or "cura" in n: idx = 4
		elif "éter"   in n or "eter"   in n or "mana"   in n:                 idx = 0
		elif "antídoto" in n or "antidoto" in n:                               idx = 1
		else:                                                                  idx = 2
	elif item.item_type == ItemData.ItemType.WEAPON:
		path = _ICON_WEAPONS
		if   "bastón" in n or "báculo" in n or "vara" in n or "cayado" in n:  idx = 4
		elif "daga"   in n or "puñal"  in n or "cuchillo" in n:               idx = 0
		elif "arco"   in n:                                                    idx = 2
		elif "hacha"  in n:                                                    idx = 3
		else:                                                                  idx = 1
	else:
		path = _ICON_ARMOR
		if   "casco"  in n or "yelmo"  in n or "tiara" in n or "sombrero" in n: idx = 0
		elif "botas"  in n or "zapatos" in n or "sandalias" in n:               idx = 3
		elif "escudo" in n or "broquel" in n:                                   idx = 4
		else:                                                                   idx = 1
	var tex := load(path) as Texture2D
	var atlas := AtlasTexture.new()
	atlas.atlas       = tex
	atlas.filter_clip = true
	atlas.region      = Rect2(idx * _ICON_CELL_W, 0.0, _ICON_CELL_W, 32.0)
	var rect := TextureRect.new()
	rect.texture               = atlas
	rect.custom_minimum_size   = Vector2(size, size)
	rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rect.size_flags_vertical   = Control.SIZE_SHRINK_CENTER
	rect.stretch_mode          = TextureRect.STRETCH_SCALE
	rect.mouse_filter          = Control.MOUSE_FILTER_IGNORE
	return rect

# Slot interactivo unificado para todos los personajes.
func _add_slot_row_unified(parent: Node, slot_label: String, item: ItemData,
		char_id: String, slot_type: ItemData.ItemType) -> void:
	var box := PanelContainer.new()
	var box_style := StyleBoxFlat.new()
	box_style.bg_color              = Color(0.09, 0.08, 0.14, 0.85)
	box_style.border_width_left     = 3
	box_style.border_color          = C_BORDER2
	box_style.content_margin_left   = 14
	box_style.content_margin_right  = 12
	box_style.content_margin_top    = 10
	box_style.content_margin_bottom = 10
	box.add_theme_stylebox_override("panel", box_style)
	parent.add_child(box)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)

	var slot_lbl := Label.new()
	slot_lbl.text = slot_label
	slot_lbl.custom_minimum_size = Vector2(120, 0)
	slot_lbl.add_theme_font_size_override("font_size", 15)
	slot_lbl.add_theme_color_override("font_color", C_MUTED)
	row.add_child(slot_lbl)

	if item:
		var stat := "ATK+%d" % item.attack_bonus if item.item_type == ItemData.ItemType.WEAPON \
					else "DEF+%d" % item.defense_bonus
		row.add_child(_item_icon_node(item, 22.0))
		var item_lbl := Label.new()
		item_lbl.text = item.item_name
		item_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item_lbl.add_theme_font_size_override("font_size", 17)
		item_lbl.add_theme_color_override("font_color", C_TEXT)
		if _font: item_lbl.add_theme_font_override("font", _font)
		row.add_child(item_lbl)
		var stat_lbl := Label.new()
		stat_lbl.text = stat
		stat_lbl.add_theme_font_size_override("font_size", 13)
		stat_lbl.add_theme_color_override("font_color", C_ACCENT)
		row.add_child(stat_lbl)
		var c_item := item; var c_id := char_id
		var btn_q := _make_button("Quitar", 78, 28)
		btn_q.pressed.connect(func(): _do_unequip(c_id, c_item))
		row.add_child(btn_q)
	else:
		var empty_lbl := Label.new()
		empty_lbl.text = "— vacío —"
		empty_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		empty_lbl.add_theme_font_size_override("font_size", 15)
		empty_lbl.add_theme_color_override("font_color", Color(0.38, 0.34, 0.28, 0.55))
		row.add_child(empty_lbl)

	# Botón Cambiar — solo si hay ítems del tipo en el inventario
	var has_items := Inventory.items.any(func(i: ItemData) -> bool: return i.item_type == slot_type)
	if has_items:
		var c_id := char_id; var c_type := slot_type
		var btn_c := _make_button("Cambiar", 88, 28)
		btn_c.pressed.connect(func(): _show_equip_picker(c_id, c_type))
		row.add_child(btn_c)

# Muestra el picker de ítems para un slot concreto.
func _show_equip_picker(char_id: String, slot_type: ItemData.ItemType) -> void:
	if _equip_picker_vbox == null:
		return
	for c in _equip_picker_vbox.get_children():
		c.queue_free()

	_lbl_colored(_equip_picker_vbox, "SELECCIONAR EQUIPO", 11, C_MUTED)
	_equip_picker_vbox.add_child(_separator_h(C_BORDER2, 1))

	var is_lyra := (char_id == "lyra")
	var current_item: ItemData = null
	if slot_type == ItemData.ItemType.WEAPON:
		current_item = Inventory.equipped_weapon if is_lyra else Inventory.get_equipped_weapon_for(char_id)
	else:
		current_item = Inventory.equipped_armor if is_lyra else Inventory.get_equipped_armor_for(char_id)

	var found := false
	for item: ItemData in Inventory.items:
		if item.item_type != slot_type:
			continue
		found = true
		var is_cur := (item == current_item)
		var stat := "ATK+%d" % item.attack_bonus if slot_type == ItemData.ItemType.WEAPON \
					else "DEF+%d" % item.defense_bonus

		var prow := HBoxContainer.new()
		prow.add_theme_constant_override("separation", 10)
		_equip_picker_vbox.add_child(prow)

		prow.add_child(_item_icon_node(item, 18.0))
		var nlbl := Label.new()
		nlbl.text = item.item_name
		nlbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nlbl.add_theme_font_size_override("font_size", 14)
		nlbl.add_theme_color_override("font_color", C_MUTED if is_cur else C_TEXT)
		prow.add_child(nlbl)
		var slbl := Label.new()
		slbl.text = stat
		slbl.add_theme_font_size_override("font_size", 13)
		slbl.add_theme_color_override("font_color", C_ACCENT)
		prow.add_child(slbl)
		if is_cur:
			_lbl_colored(prow, "[puesto]", 12, C_MUTED)
		else:
			var c_item := item; var c_id := char_id
			var ebtn := _make_button("Equipar", 88, 26)
			ebtn.pressed.connect(func(): _do_equip(c_id, c_item))
			prow.add_child(ebtn)

	if not found:
		_lbl_colored(_equip_picker_vbox, "Sin equipo disponible.", 13, C_MUTED)

	var cancel_btn := _make_button("✕  Cancelar", 120, 28)
	cancel_btn.pressed.connect(_hide_equip_picker)
	_equip_picker_vbox.add_child(cancel_btn)
	_equip_picker_vbox.visible = true

func _hide_equip_picker() -> void:
	if _equip_picker_vbox:
		for c in _equip_picker_vbox.get_children():
			c.queue_free()
		_equip_picker_vbox.visible = false

func _do_equip(char_id: String, item: ItemData) -> void:
	if char_id == "lyra":
		Inventory.equip(item)
	else:
		Inventory.equip_for(char_id, item)
	_refresh_equip()
	_refresh_stats()

func _do_unequip(char_id: String, item: ItemData) -> void:
	if char_id == "lyra":
		Inventory.unequip(item)
	else:
		Inventory.unequip_for(char_id, item)
	_refresh_equip()
	_refresh_stats()

# Fila de equipo solo lectura (sin botón de desequipar).
# Panel de Habilidades

func _build_skills_panel() -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.visible = false

	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 0)
	root.add_child(hbox)

	# Panel izquierdo: info del personaje
	var left_panel := PanelContainer.new()
	left_panel.size_flags_horizontal    = Control.SIZE_EXPAND_FILL
	left_panel.size_flags_stretch_ratio = 1.1
	var ls := StyleBoxFlat.new()
	ls.bg_color           = Color(0.05, 0.04, 0.09, 0.97)
	ls.border_width_right = 2
	ls.border_color       = C_BORDER2
	left_panel.add_theme_stylebox_override("panel", ls)
	hbox.add_child(left_panel)

	var lm := MarginContainer.new()
	for s in ["margin_left","margin_right","margin_top","margin_bottom"]:
		lm.add_theme_constant_override(s, 20)
	left_panel.add_child(lm)

	var left_vbox := VBoxContainer.new()
	left_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_vbox.add_theme_constant_override("separation", 0)
	lm.add_child(left_vbox)

	_lbl_colored(left_vbox, "PERSONAJE", 11, C_MUTED)
	left_vbox.add_child(_separator_h(C_BORDER2, 1))
	left_vbox.add_child(_spacer(6))

	_skills_info_vbox = VBoxContainer.new()
	_skills_info_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_skills_info_vbox.add_theme_constant_override("separation", 6)
	left_vbox.add_child(_skills_info_vbox)

	left_vbox.add_child(_spacer(8))
	var btn_back := _make_button("◀  Volver", 160, 36)
	btn_back.pressed.connect(_show_main)
	left_vbox.add_child(btn_back)

	# Panel derecho: selector + habilidades
	var right_panel := PanelContainer.new()
	right_panel.size_flags_horizontal    = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_stretch_ratio = 1.4
	var rs := StyleBoxFlat.new()
	rs.bg_color = Color(0.07, 0.06, 0.11, 0.98)
	right_panel.add_theme_stylebox_override("panel", rs)
	hbox.add_child(right_panel)

	var rm := MarginContainer.new()
	for s in ["margin_left","margin_right","margin_top","margin_bottom"]:
		rm.add_theme_constant_override(s, 20)
	right_panel.add_child(rm)

	var right_vbox := VBoxContainer.new()
	right_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vbox.add_theme_constant_override("separation", 10)
	rm.add_child(right_vbox)

	# Selector de personaje
	var sel_row := HBoxContainer.new()
	sel_row.add_theme_constant_override("separation", 8)
	sel_row.alignment = BoxContainer.ALIGNMENT_CENTER
	right_vbox.add_child(sel_row)

	var btn_prev := _make_button("◀", 32, 30)
	btn_prev.pressed.connect(func():
		var sz := _get_equip_chars().size()
		_skills_char_index = (_skills_char_index - 1 + sz) % sz
		_refresh_skills_panel())
	sel_row.add_child(btn_prev)

	_skills_char_lbl = Label.new()
	_skills_char_lbl.custom_minimum_size  = Vector2(200, 0)
	_skills_char_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_skills_char_lbl.add_theme_font_size_override("font_size", 17)
	_skills_char_lbl.add_theme_color_override("font_color", C_TITLE)
	if _font: _skills_char_lbl.add_theme_font_override("font", _font)
	sel_row.add_child(_skills_char_lbl)

	var btn_next := _make_button("▶", 32, 30)
	btn_next.pressed.connect(func():
		var sz := _get_equip_chars().size()
		_skills_char_index = (_skills_char_index + 1) % sz
		_refresh_skills_panel())
	sel_row.add_child(btn_next)

	right_vbox.add_child(_separator_h(C_BORDER, 1))

	_lbl_colored(right_vbox, "HABILIDADES", 11, C_MUTED)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_vbox.add_child(scroll)

	_skills_list_vbox = VBoxContainer.new()
	_skills_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_skills_list_vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(_skills_list_vbox)

	return root

func _refresh_skills_panel() -> void:
	var chars := _get_equip_chars()
	if chars.is_empty():
		return
	_skills_char_index = clamp(_skills_char_index, 0, chars.size() - 1)

	var char_entry : Dictionary     = chars[_skills_char_index]
	var char_id    : String         = char_entry["id"]
	var spath      : String         = char_entry["stats"]
	var stats      : CharacterStats = load(spath)

	if _skills_char_lbl:
		_skills_char_lbl.text = stats.character_name if stats else char_id.capitalize()

	# Panel izquierdo: retrato + stats
	for c in _skills_info_vbox.get_children():
		c.queue_free()

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 14)
	_skills_info_vbox.add_child(top_row)
	top_row.add_child(_make_equip_portrait(char_id))

	var info_col := VBoxContainer.new()
	info_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info_col.add_theme_constant_override("separation", 4)
	top_row.add_child(info_col)

	var n_lbl := Label.new()
	n_lbl.text = stats.character_name if stats else char_id.capitalize()
	n_lbl.add_theme_font_size_override("font_size", 16)
	n_lbl.add_theme_color_override("font_color", C_TITLE)
	if _font: n_lbl.add_theme_font_override("font", _font)
	info_col.add_child(n_lbl)

	if stats:
		var cls_lbl := Label.new()
		cls_lbl.text = _CLASS_NAMES[stats.character_class] if stats.character_class < _CLASS_NAMES.size() else ""
		cls_lbl.add_theme_font_size_override("font_size", 13)
		cls_lbl.add_theme_color_override("font_color", C_MUTED)
		info_col.add_child(cls_lbl)

		var lvl_lbl := Label.new()
		var lv := Inventory.get_companion_level(char_id) if char_id != "lyra" else Inventory.current_level
		lvl_lbl.text = "Nv. %d" % lv
		lvl_lbl.add_theme_font_size_override("font_size", 13)
		lvl_lbl.add_theme_color_override("font_color", C_ACCENT)
		info_col.add_child(lvl_lbl)

	# Panel derecho: tarjetas de habilidad
	for c in _skills_list_vbox.get_children():
		c.queue_free()

	if stats == null or stats.skills.is_empty():
		_lbl_colored(_skills_list_vbox, "Sin habilidades.", 14, C_MUTED)
		return

	for sk: SkillData in stats.skills:
		if sk:
			_add_skill_card(_skills_list_vbox, sk)
# Tarjeta visual de habilidad con fondo, tipo, daño y coste MP.
func _add_skill_card(parent: Node, sk: SkillData) -> void:
	var card := PanelContainer.new()
	var is_magic := sk.is_magical
	var card_sty := StyleBoxFlat.new()
	card_sty.bg_color          = Color(0.10, 0.09, 0.15, 0.95) if is_magic else Color(0.13, 0.10, 0.08, 0.95)
	card_sty.border_color      = C_MP if is_magic else Color(0.9, 0.5, 0.2, 0.6)
	card_sty.border_width_left = 3
	card_sty.set_corner_radius_all(4)
	card_sty.content_margin_left   = 12
	card_sty.content_margin_right  = 12
	card_sty.content_margin_top    = 8
	card_sty.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", card_sty)
	parent.add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)
	var name_lbl := Label.new()
	name_lbl.text = sk.skill_name
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.add_theme_color_override("font_color", C_TEXT)
	row.add_child(name_lbl)
	var badge := PanelContainer.new()
	var badge_sty := StyleBoxFlat.new()
	badge_sty.bg_color = C_MP.darkened(0.5) if is_magic else Color(0.9, 0.5, 0.2, 0.25)
	badge_sty.set_corner_radius_all(3)
	badge_sty.content_margin_left = 6; badge_sty.content_margin_right = 6
	badge_sty.content_margin_top = 2; badge_sty.content_margin_bottom = 2
	badge.add_theme_stylebox_override("panel", badge_sty)
	row.add_child(badge)
	var type_lbl := Label.new()
	type_lbl.text = "Mág." if is_magic else "Fís."
	type_lbl.add_theme_font_size_override("font_size", 12)
	type_lbl.add_theme_color_override("font_color", C_MP if is_magic else Color(0.9, 0.5, 0.2))
	badge.add_child(type_lbl)
	var dmg_lbl := Label.new()
	if sk.damage > 0:
		dmg_lbl.text = "DMG  %d" % sk.damage
		dmg_lbl.add_theme_color_override("font_color", C_HP)
	elif sk.damage < 0:
		dmg_lbl.text = "CUR  %d" % abs(sk.damage)
		dmg_lbl.add_theme_color_override("font_color", Color(0.3, 0.8, 0.4))
	else:
		dmg_lbl.text = "—"
		dmg_lbl.add_theme_color_override("font_color", C_MUTED)
	dmg_lbl.custom_minimum_size = Vector2(72, 0)
	dmg_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	dmg_lbl.add_theme_font_size_override("font_size", 13)
	row.add_child(dmg_lbl)
	var mp_lbl := Label.new()
	mp_lbl.text = "MP  %d" % sk.mp_cost
	mp_lbl.custom_minimum_size = Vector2(52, 0)
	mp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	mp_lbl.add_theme_font_size_override("font_size", 13)
	mp_lbl.add_theme_color_override("font_color", C_MP)
	row.add_child(mp_lbl)
# Fila de habilidad: nombre · tipo · daño · coste MP.
func _add_skill_row(parent: Node, sk: SkillData) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)

	var name_lbl := Label.new()
	name_lbl.text = "• " + sk.skill_name
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.add_theme_color_override("font_color", C_TEXT)
	row.add_child(name_lbl)

	var type_lbl := Label.new()
	type_lbl.text = "Mág." if sk.is_magical else "Fís."
	type_lbl.custom_minimum_size = Vector2(32, 0)
	type_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	type_lbl.add_theme_font_size_override("font_size", 11)
	type_lbl.add_theme_color_override("font_color", C_MP if sk.is_magical else Color(0.9, 0.5, 0.2))
	row.add_child(type_lbl)

	var dmg_lbl := Label.new()
	if sk.damage > 0:
		dmg_lbl.text = "DMG %3d" % sk.damage
	elif sk.damage < 0:
		dmg_lbl.text = "CUR %3d" % abs(sk.damage)
	else:
		dmg_lbl.text = "  —    "
	dmg_lbl.custom_minimum_size = Vector2(58, 0)
	dmg_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	dmg_lbl.add_theme_font_size_override("font_size", 11)
	dmg_lbl.add_theme_color_override("font_color", C_MUTED)
	row.add_child(dmg_lbl)

	var mp_lbl := Label.new()
	mp_lbl.text = "MP %d" % sk.mp_cost
	mp_lbl.custom_minimum_size = Vector2(42, 0)
	mp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	mp_lbl.add_theme_font_size_override("font_size", 11)
	mp_lbl.add_theme_color_override("font_color", C_MP)
	row.add_child(mp_lbl)

# Guardar / Cargar

func _do_save(slot: int) -> void:
	SaveManager.save_game(slot)
	_refresh_slot_list()
	_show_slot_feedback("✓  Guardado en ranura %d" % (slot + 1))

func _do_load(slot: int) -> void:
	SaveManager.load_game(slot)
	TutorialManager.skip_all()
	_refresh_stats()
	_show_slot_feedback("✓  Partida cargada")

func _show_feedback(msg: String) -> void:
	_feedback_lbl.text = msg
	_feedback_lbl.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.5)
	tw.tween_property(_feedback_lbl, "modulate:a", 0.0, 0.5)

func _show_slot_feedback(msg: String) -> void:
	_slot_feedback_lbl.text = msg
	_slot_feedback_lbl.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.5)
	tw.tween_property(_slot_feedback_lbl, "modulate:a", 0.0, 0.5)

# Panel de ranuras (pantalla completa)

func _build_slot_panel() -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.visible = false

	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 0)
	root.add_child(hbox)

	# Panel izquierdo
	var lp := PanelContainer.new()
	lp.size_flags_horizontal    = Control.SIZE_EXPAND_FILL
	lp.size_flags_stretch_ratio = 0.55
	var ls := StyleBoxFlat.new()
	ls.bg_color           = Color(0.05, 0.04, 0.09, 0.97)
	ls.border_width_right = 2
	ls.border_color       = C_BORDER2
	lp.add_theme_stylebox_override("panel", ls)
	hbox.add_child(lp)

	var lm := MarginContainer.new()
	for s in ["margin_left","margin_right","margin_top","margin_bottom"]:
		lm.add_theme_constant_override(s, 24)
	lp.add_child(lm)

	var lv := VBoxContainer.new()
	lv.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lv.add_theme_constant_override("separation", 0)
	lm.add_child(lv)

	_slot_title_lbl2 = Label.new()
	_slot_title_lbl2.text = "GUARDAR"
	_slot_title_lbl2.add_theme_font_size_override("font_size", 22)
	_slot_title_lbl2.add_theme_color_override("font_color", C_TITLE)
	if _font: _slot_title_lbl2.add_theme_font_override("font", _font)
	lv.add_child(_slot_title_lbl2)
	lv.add_child(_separator_h(C_BORDER, 1))
	lv.add_child(_spacer(12))

	_slot_feedback_lbl = Label.new()
	_slot_feedback_lbl.add_theme_font_size_override("font_size", 13)
	_slot_feedback_lbl.add_theme_color_override("font_color", C_ACCENT)
	_slot_feedback_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	_slot_feedback_lbl.modulate.a = 0.0
	lv.add_child(_slot_feedback_lbl)

	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lv.add_child(sp)

	var btn_back := _make_button("◀  Volver", 180, 38)
	btn_back.pressed.connect(_show_main)
	lv.add_child(btn_back)

	# Panel derecho: lista de ranuras
	var rp := PanelContainer.new()
	rp.size_flags_horizontal    = Control.SIZE_EXPAND_FILL
	rp.size_flags_stretch_ratio = 1.45
	var rs := StyleBoxFlat.new()
	rs.bg_color = Color(0.07, 0.06, 0.11, 0.98)
	rp.add_theme_stylebox_override("panel", rs)
	hbox.add_child(rp)

	var rm := MarginContainer.new()
	for s in ["margin_left","margin_right","margin_top","margin_bottom"]:
		rm.add_theme_constant_override(s, 24)
	rp.add_child(rm)

	var rv := VBoxContainer.new()
	rv.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rv.add_theme_constant_override("separation", 6)
	rm.add_child(rv)

	_lbl_colored(rv, "RANURAS", 11, C_MUTED)
	rv.add_child(_separator_h(C_BORDER2, 1))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rv.add_child(scroll)

	_slot_list_vbox = VBoxContainer.new()
	_slot_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slot_list_vbox.add_theme_constant_override("separation", 4)
	scroll.add_child(_slot_list_vbox)

	return root

func _refresh_slot_list() -> void:
	if _slot_title_lbl2:
		_slot_title_lbl2.text = "GUARDAR" if _slot_mode == "save" else "CARGAR"
	if _slot_list_vbox == null:
		return
	for child in _slot_list_vbox.get_children():
		child.queue_free()

	for i in SaveManager.SLOT_COUNT:
		var info := SaveManager.get_slot_info(i)
		var row  := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_slot_list_vbox.add_child(row)

		var num_lbl := Label.new()
		num_lbl.text = "%02d" % (i + 1)
		num_lbl.custom_minimum_size = Vector2(28, 0)
		num_lbl.add_theme_font_size_override("font_size", 13)
		num_lbl.add_theme_color_override("font_color", C_MUTED)
		row.add_child(num_lbl)

		var info_lbl := Label.new()
		info_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_lbl.add_theme_font_size_override("font_size", 13)
		if info["empty"]:
			info_lbl.text = "── Vacía ──"
			info_lbl.add_theme_color_override("font_color", C_MUTED)
		else:
			info_lbl.text = "%s   ✦ %d oro   Nv.%d" % [info["save_date"], info["gold"], info["level"]]
			info_lbl.add_theme_color_override("font_color", C_TEXT)
		row.add_child(info_lbl)

		var captured_i := i
		if _slot_mode == "save":
			var lbl := "Guardar" if info["empty"] else "Sobreescribir"
			var btn := _make_button(lbl, 130, 30)
			btn.pressed.connect(func(): _do_save(captured_i))
			row.add_child(btn)
		else:
			var btn := _make_button("Cargar", 100, 30)
			btn.disabled = info["empty"]
			if not info["empty"]:
				btn.pressed.connect(func(): _do_load(captured_i))
			row.add_child(btn)

# Panel de opciones (pantalla completa)

func _build_options_panel() -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.visible = false

	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 0)
	root.add_child(hbox)

	# Panel izquierdo: título + audio
	var lp := PanelContainer.new()
	lp.size_flags_horizontal    = Control.SIZE_EXPAND_FILL
	lp.size_flags_stretch_ratio = 1.0
	var ls := StyleBoxFlat.new()
	ls.bg_color           = Color(0.05, 0.04, 0.09, 0.97)
	ls.border_width_right = 2
	ls.border_color       = C_BORDER2
	lp.add_theme_stylebox_override("panel", ls)
	hbox.add_child(lp)

	var lm := MarginContainer.new()
	for s in ["margin_left","margin_right","margin_top","margin_bottom"]:
		lm.add_theme_constant_override(s, 24)
	lp.add_child(lm)

	var lv := VBoxContainer.new()
	lv.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lv.add_theme_constant_override("separation", 14)
	lm.add_child(lv)

	var opt_title := Label.new()
	opt_title.text = "OPCIONES"
	opt_title.add_theme_font_size_override("font_size", 22)
	opt_title.add_theme_color_override("font_color", C_TITLE)
	if _font: opt_title.add_theme_font_override("font", _font)
	lv.add_child(opt_title)
	lv.add_child(_separator_h(C_BORDER, 1))

	_lbl_colored(lv, "AUDIO", 11, C_MUTED)
	lv.add_child(_make_volume_row("Música", "MusicSlider", "MusicVal"))
	lv.add_child(_make_volume_row("SFX",    "SFXSlider",   "SFXVal"))

	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lv.add_child(sp)

	var btn_keys := _make_button("⌨  Teclado", 180, 38)
	btn_keys.pressed.connect(_show_keyboard)
	lv.add_child(btn_keys)

	var btn_back := _make_button("◀  Volver", 180, 38)
	btn_back.pressed.connect(_show_main)
	lv.add_child(btn_back)

	# Panel derecho: vídeo
	var rp := PanelContainer.new()
	rp.size_flags_horizontal    = Control.SIZE_EXPAND_FILL
	rp.size_flags_stretch_ratio = 1.0
	var rs := StyleBoxFlat.new()
	rs.bg_color = Color(0.07, 0.06, 0.11, 0.98)
	rp.add_theme_stylebox_override("panel", rs)
	hbox.add_child(rp)

	var rm := MarginContainer.new()
	for s in ["margin_left","margin_right","margin_top","margin_bottom"]:
		rm.add_theme_constant_override(s, 24)
	rp.add_child(rm)

	var rv := VBoxContainer.new()
	rv.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rv.add_theme_constant_override("separation", 14)
	rm.add_child(rv)

	_lbl_colored(rv, "VÍDEO", 11, C_MUTED)
	rv.add_child(_separator_h(C_BORDER2, 1))

	var fs_row := HBoxContainer.new()
	fs_row.add_theme_constant_override("separation", 12)
	rv.add_child(fs_row)
	var fs_lbl := Label.new()
	fs_lbl.text = "Modo"
	fs_lbl.custom_minimum_size = Vector2(100, 0)
	fs_lbl.add_theme_font_size_override("font_size", 14)
	fs_lbl.add_theme_color_override("font_color", C_TEXT)
	fs_row.add_child(fs_lbl)
	var fs_btn := Button.new()
	fs_btn.name                  = "FullscreenBtn"
	fs_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fs_btn.add_theme_font_size_override("font_size", 14)
	fs_btn.pressed.connect(_on_fullscreen_toggle)
	fs_row.add_child(fs_btn)

	var res_row := HBoxContainer.new()
	res_row.add_theme_constant_override("separation", 12)
	rv.add_child(res_row)
	var res_lbl := Label.new()
	res_lbl.text = "Resolución"
	res_lbl.custom_minimum_size = Vector2(100, 0)
	res_lbl.add_theme_font_size_override("font_size", 14)
	res_lbl.add_theme_color_override("font_color", C_TEXT)
	res_row.add_child(res_lbl)
	var res_opt := OptionButton.new()
	res_opt.name                  = "ResolutionOpt"
	res_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	res_opt.add_theme_font_size_override("font_size", 14)
	for label in SettingsManager.RESOLUTION_LABELS:
		res_opt.add_item(label)
	res_opt.item_selected.connect(_on_resolution_selected)
	res_row.add_child(res_opt)

	var sp2 := Control.new()
	sp2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rv.add_child(sp2)

	return root

func _make_volume_row(label: String, slider_name: String, val_name: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var lbl := Label.new()
	lbl.text = label
	lbl.custom_minimum_size = Vector2(60, 0)
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", C_TEXT)
	row.add_child(lbl)

	var slider := HSlider.new()
	slider.name                 = slider_name
	slider.min_value            = 0
	slider.max_value            = 100
	slider.step                 = 1
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)

	var val_lbl := Label.new()
	val_lbl.name = val_name
	val_lbl.custom_minimum_size = Vector2(44, 0)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_lbl.add_theme_font_size_override("font_size", 13)
	val_lbl.add_theme_color_override("font_color", C_ACCENT)
	row.add_child(val_lbl)

	return row

func _refresh_options() -> void:
	# Audio
	var music_slider := _options_panel.find_child("MusicSlider", true, false) as HSlider
	var sfx_slider   := _options_panel.find_child("SFXSlider",   true, false) as HSlider
	var music_val    := _options_panel.find_child("MusicVal",     true, false) as Label
	var sfx_val      := _options_panel.find_child("SFXVal",       true, false) as Label

	if music_slider and not music_slider.value_changed.is_connected(_on_music_volume):
		music_slider.value = AudioManager.bgm_volume * 100
		music_slider.value_changed.connect(_on_music_volume)
	if sfx_slider and not sfx_slider.value_changed.is_connected(_on_sfx_volume):
		sfx_slider.value = AudioManager.sfx_volume * 100
		sfx_slider.value_changed.connect(_on_sfx_volume)
	if music_val:
		music_val.text = "%d%%" % int(AudioManager.bgm_volume * 100)
	if sfx_val:
		sfx_val.text = "%d%%" % int(AudioManager.sfx_volume * 100)

	# Vídeo
	var fs_btn  := _options_panel.find_child("FullscreenBtn",  true, false) as Button
	var res_opt := _options_panel.find_child("ResolutionOpt",  true, false) as OptionButton
	var fs      := SettingsManager.is_fullscreen()

	if fs_btn:
		fs_btn.text = "Pantalla completa  ✓" if fs else "Modo ventana"
	if res_opt:
		res_opt.selected = SettingsManager.get_resolution_idx()
		res_opt.disabled = fs

# Panel de teclado

func _build_keyboard_panel() -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.visible = false

	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 0)
	root.add_child(hbox)

	# Panel izquierdo (lista de teclas)
	var lp := PanelContainer.new()
	lp.size_flags_horizontal    = Control.SIZE_EXPAND_FILL
	lp.size_flags_stretch_ratio = 1.2
	var ls := StyleBoxFlat.new()
	ls.bg_color           = Color(0.05, 0.04, 0.09, 0.97)
	ls.border_width_right = 2
	ls.border_color       = C_BORDER2
	lp.add_theme_stylebox_override("panel", ls)
	hbox.add_child(lp)

	var lm := MarginContainer.new()
	for s in ["margin_left","margin_right","margin_top","margin_bottom"]:
		lm.add_theme_constant_override(s, 24)
	lp.add_child(lm)

	var lv := VBoxContainer.new()
	lv.name = "KeyboardVBox"
	lv.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lv.add_theme_constant_override("separation", 10)
	lm.add_child(lv)

	var title := Label.new()
	title.text = "TECLADO"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", C_TITLE)
	if _font: title.add_theme_font_override("font", _font)
	lv.add_child(title)
	lv.add_child(_separator_h(C_BORDER, 1))

	_lbl_colored(lv, "HAZ CLIC EN UNA TECLA PARA REASIGNARLA", 10, C_MUTED)
	lv.add_child(_separator_h(C_BORDER2, 1))

	var rows_vbox := VBoxContainer.new()
	rows_vbox.name = "KeyRows"
	rows_vbox.add_theme_constant_override("separation", 8)
	lv.add_child(rows_vbox)

	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lv.add_child(sp)

	var btn_reset := _make_button("↺  Restablecer por defecto", 260, 34)
	btn_reset.pressed.connect(func():
		SettingsManager.reset_bindings()
		_refresh_keyboard_panel()
	)
	lv.add_child(btn_reset)

	var btn_back := _make_button("◀  Volver", 180, 38)
	btn_back.pressed.connect(_show_options)
	lv.add_child(btn_back)

	# Panel derecho (info / ayuda)
	var rp := PanelContainer.new()
	rp.size_flags_horizontal    = Control.SIZE_EXPAND_FILL
	rp.size_flags_stretch_ratio = 0.8
	var rs := StyleBoxFlat.new()
	rs.bg_color = Color(0.07, 0.06, 0.11, 0.98)
	rp.add_theme_stylebox_override("panel", rs)
	hbox.add_child(rp)

	var rm := MarginContainer.new()
	for s in ["margin_left","margin_right","margin_top","margin_bottom"]:
		rm.add_theme_constant_override(s, 24)
	rp.add_child(rm)

	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 12)
	rm.add_child(rv)

	_lbl_colored(rv, "AYUDA", 11, C_MUTED)
	rv.add_child(_separator_h(C_BORDER2, 1))

	var help_texts := [
		"Haz clic en el botón de una acción para reasignarla.",
		"Luego pulsa la tecla que quieras asignar.",
		"Pulsa ESC para cancelar sin cambiar nada.",
	]
	for t: String in help_texts:
		var hl := Label.new()
		hl.text = t
		hl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hl.add_theme_font_size_override("font_size", 13)
		hl.add_theme_color_override("font_color", C_TEXT)
		rv.add_child(hl)
		rv.add_child(_spacer(4))

	return root

func _refresh_keyboard_panel() -> void:
	var rows_vbox := _keyboard_panel.find_child("KeyRows", true, false) as VBoxContainer
	if rows_vbox == null:
		return
	for c in rows_vbox.get_children():
		c.queue_free()

	for action: String in SettingsManager.DEFAULT_BINDINGS:
		var label: String  = SettingsManager.ACTION_LABELS.get(action, action)
		var key: Key       = SettingsManager.get_binding(action)
		var key_name: String = OS.get_keycode_string(key)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		rows_vbox.add_child(row)

		var lbl := Label.new()
		lbl.text = label
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_font_size_override("font_size", 15)
		lbl.add_theme_color_override("font_color", C_TEXT)
		row.add_child(lbl)

		var is_rebinding := (_rebinding_action == action)
		var btn := Button.new()
		btn.text                  = "[ Pulsa una tecla... ]" if is_rebinding else key_name
		btn.custom_minimum_size   = Vector2(130, 30)
		btn.size_flags_horizontal = Control.SIZE_SHRINK_END

		var sty := StyleBoxFlat.new()
		sty.bg_color     = Color(0.80, 0.65, 0.10, 0.25) if is_rebinding else C_BTN_NORM
		sty.border_color = C_BORDER if is_rebinding else C_BORDER2
		sty.set_border_width_all(1)
		sty.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("normal", sty)
		btn.add_theme_font_size_override("font_size", 14)
		btn.add_theme_color_override("font_color", C_TITLE if is_rebinding else C_TEXT)

		var c_action := action
		btn.pressed.connect(func():
			_rebinding_action = c_action
			_rebinding_btn    = btn
			_refresh_keyboard_panel()
		)
		row.add_child(btn)

func _on_music_volume(value: float) -> void:
	AudioManager.set_bgm_volume(value / 100.0)
	var lbl := _options_panel.find_child("MusicVal", true, false) as Label
	if lbl:
		lbl.text = "%d%%" % int(value)

func _on_sfx_volume(value: float) -> void:
	AudioManager.set_sfx_volume(value / 100.0)
	var lbl := _options_panel.find_child("SFXVal", true, false) as Label
	if lbl:
		lbl.text = "%d%%" % int(value)

func _on_fullscreen_toggle() -> void:
	SettingsManager.set_fullscreen(not SettingsManager.is_fullscreen())
	_refresh_options()

func _on_resolution_selected(idx: int) -> void:
	SettingsManager.set_resolution(idx)

# Salir del juego / Menú principal

func _request_confirm(title: String, save_label: String, nosave_label: String, action: Callable) -> void:
	_pending_action = action
	if _confirm_title_lbl:
		_confirm_title_lbl.text = title
	if _btn_save_act:
		_btn_save_act.text    = save_label
		_btn_save_act.visible = SaveManager.has_unsaved_changes
	if _btn_nosave_act:
		_btn_nosave_act.text = nosave_label
	var warn := _confirm_panel.find_child("WarnLbl", true, false) as Label
	if warn:
		warn.visible = SaveManager.has_unsaved_changes
	_confirm_panel.visible = true

func _on_quit_pressed() -> void:
	_request_confirm(
		"¿Salir del juego?",
		"💾  Guardar y salir",
		"✕  Salir sin guardar",
		func(): get_tree().quit()
	)

func _on_main_menu_pressed() -> void:
	_request_confirm(
		"¿Volver al menú principal?",
		"💾  Guardar e ir",
		"⌂  Ir sin guardar",
		func():
			AudioManager.stop_bgm()
			get_tree().paused = false
			SceneTransition.go_to(MAIN_MENU_SCENE)
	)

func _build_confirm_panel() -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.visible = false

	# Fondo oscuro semitransparente
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(overlay)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(380, 0)
	panel.offset_left  = -190
	panel.offset_right =  190
	panel.offset_top   = -110
	panel.offset_bottom =  110
	_style_panel(panel, C_PANEL, Color(1.0, 0.45, 0.45))
	root.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 20)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	_confirm_title_lbl = Label.new()
	_confirm_title_lbl.text = "¿Salir del juego?"
	_confirm_title_lbl.add_theme_font_size_override("font_size", 16)
	_confirm_title_lbl.add_theme_color_override("font_color", C_TITLE)
	vbox.add_child(_confirm_title_lbl)
	vbox.add_child(_separator_h(Color(1.0, 0.45, 0.45), 1))

	var warn := Label.new()
	warn.name = "WarnLbl"
	warn.text = "⚠  Tienes cambios sin guardar."
	warn.add_theme_font_size_override("font_size", 13)
	warn.add_theme_color_override("font_color", Color(1.0, 0.80, 0.30))
	warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(warn)

	_btn_save_act = _make_button("💾  Guardar y salir", 320, 38)
	_btn_save_act.pressed.connect(func():
		SaveManager.save_game(0)
		root.visible = false
		if _pending_action.is_valid():
			_pending_action.call()
	)
	vbox.add_child(_btn_save_act)

	_btn_nosave_act = _make_button("✕  Salir sin guardar", 320, 38)
	_btn_nosave_act.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
	_btn_nosave_act.pressed.connect(func():
		root.visible = false
		if _pending_action.is_valid():
			_pending_action.call()
	)
	vbox.add_child(_btn_nosave_act)

	var btn_cancel := _make_button("←  Cancelar", 320, 38)
	btn_cancel.pressed.connect(func(): root.visible = false)
	vbox.add_child(btn_cancel)

	return root

# Fila de estadística: "Nombre     XX" alineado a la derecha (estilo FF9).
func _equip_stat_row(stat_name: String, value: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	var nl := Label.new()
	nl.text = stat_name
	nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nl.add_theme_font_size_override("font_size", 16)
	nl.add_theme_color_override("font_color", C_TEXT)
	row.add_child(nl)
	var vl := Label.new()
	vl.text = str(value)
	vl.custom_minimum_size = Vector2(48, 0)
	vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vl.add_theme_font_size_override("font_size", 16)
	vl.add_theme_color_override("font_color", C_TEXT)
	if _font: vl.add_theme_font_override("font", _font)
	row.add_child(vl)
	return row
