extends Control

# Nodos principales
@onready var main_buttons:     VBoxContainer = $MainButtons
@onready var options_panel:    Panel         = $Options
@onready var music_slider:     HSlider       = $Options/OptionsMargin/VBox/MusicRow/MusicVolumeSlider
@onready var sfx_slider:       HSlider       = $Options/OptionsMargin/VBox/SFXRow/SFXVolumeSlider
@onready var window_mode_option: OptionButton = $Options/OptionsMargin/VBox/WindowModeRow/WindowModeOption
@onready var menu_music:       AudioStreamPlayer = $MenuMusic

# UI dinámica
var _music_pct:      Label
var _sfx_pct:        Label
var _load_panel:     Control
var _slot_list:      VBoxContainer
var _confirm_overlay: Control
var _font: Font

const WORLD_MAP_SCENE := "res://Scenes/World/WorldMap.tscn"
const FONT_PATH        := "res://Assets/Fonts/CinzelDecorative-Bold.ttf"


func _ready() -> void:
	_font = load(FONT_PATH)

	main_buttons.visible  = true
	options_panel.visible = false

	_setup_audio()
	_setup_window_mode()
	_build_load_panel()
	_build_confirm_dialog()

	# Mejoras visuales / UX
	_add_particles()
	_add_subtitle()
	_style_exit_button()
	_maybe_add_continue_button()
	_add_social_bar()


#  PARTÍCULAS DE AMBIENTE
func _add_particles() -> void:
	var vp := get_viewport_rect().size

	# Capa 1: brasas doradas (rápidas, pequeñas)
	var embers := CPUParticles2D.new()
	embers.position             = Vector2(vp.x * 0.5, vp.y + 30)
	embers.emitting             = true
	embers.amount               = 55
	embers.lifetime             = 9.0
	embers.randomness           = 1.0
	embers.emission_shape       = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	embers.emission_rect_extents = Vector2(vp.x * 0.52, 20)
	embers.direction            = Vector2(0.0, -1.0)
	embers.spread               = 18.0
	embers.gravity              = Vector2(0.0, 0.0)
	embers.initial_velocity_min = 22.0
	embers.initial_velocity_max = 58.0
	embers.angular_velocity_min = -30.0
	embers.angular_velocity_max = 30.0
	embers.scale_amount_min     = 1.2
	embers.scale_amount_max     = 3.2

	var ramp1 := Gradient.new()
	ramp1.set_color(0, Color(1.00, 0.72, 0.18, 1.00))
	ramp1.set_color(1, Color(1.00, 0.35, 0.05, 0.00))
	embers.color_ramp = ramp1
	add_child(embers)

	# Capa 2: polvo luminoso (lento, grande, difuso)
	var dust := CPUParticles2D.new()
	dust.position               = Vector2(vp.x * 0.5, vp.y + 20)
	dust.emitting               = true
	dust.amount                 = 30
	dust.lifetime               = 14.0
	dust.randomness             = 1.0
	dust.emission_shape         = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents  = Vector2(vp.x * 0.52, 15)
	dust.direction              = Vector2(0.0, -1.0)
	dust.spread                 = 40.0
	dust.gravity                = Vector2(0.0, 0.0)
	dust.initial_velocity_min   = 6.0
	dust.initial_velocity_max   = 18.0
	dust.scale_amount_min       = 3.0
	dust.scale_amount_max       = 7.0

	var ramp2 := Gradient.new()
	ramp2.set_color(0, Color(0.96, 0.86, 0.52, 0.50))
	ramp2.set_color(1, Color(0.80, 0.62, 0.28, 0.00))
	dust.color_ramp = ramp2
	add_child(dust)


#  SUBTÍTULO
func _add_subtitle() -> void:
	var lbl := Label.new()
	lbl.text                = "Una aventura de rol"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.anchor_left         = 0.5
	lbl.anchor_top          = 0.5
	lbl.anchor_right        = 0.5
	lbl.anchor_bottom       = 0.5
	lbl.offset_left         = -280.0
	lbl.offset_top          = -170.0     # justo bajo el TitleLabel (-178)
	lbl.offset_right        =  280.0
	lbl.offset_bottom       = -132.0
	lbl.add_theme_font_override("font", _font)
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color",        Color(1.0, 1.0, 1.0, 0.85))
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
	lbl.add_theme_constant_override("shadow_offset_x", 3)
	lbl.add_theme_constant_override("shadow_offset_y", 3)
	add_child(lbl)


#  ESTILO BOTÓN SALIR
func _make_rounded_style(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color                    = color
	s.corner_radius_top_left      = 16
	s.corner_radius_top_right     = 16
	s.corner_radius_bottom_right  = 16
	s.corner_radius_bottom_left   = 16
	s.shadow_color  = Color(0, 0, 0, 0.2)
	s.shadow_size   = 5
	s.shadow_offset = Vector2(0, 3.41)
	return s

func _style_exit_button() -> void:
	var btn := $MainButtons/ExitButton as Button
	btn.add_theme_stylebox_override("normal",  _make_rounded_style(Color(0.72, 0.18, 0.18)))
	btn.add_theme_stylebox_override("hover",   _make_rounded_style(Color(0.85, 0.25, 0.25)))
	btn.add_theme_stylebox_override("pressed", _make_rounded_style(Color(0.55, 0.12, 0.12)))
	btn.add_theme_color_override("font_color",         Color.WHITE)
	btn.add_theme_color_override("font_hover_color",   Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	btn.add_theme_color_override("font_focus_color",   Color.WHITE)


#  BOTÓN CONTINUAR
func _get_most_recent_slot() -> int:
	var best_slot := -1
	var best_date := ""
	for slot in range(SaveManager.SLOT_COUNT):
		var info := SaveManager.get_slot_info(slot)
		if info.get("empty", true):
			continue
		var date: String = info.get("save_date", "")
		if date > best_date:
			best_date = date
			best_slot = slot
	return best_slot

func _maybe_add_continue_button() -> void:
	var slot := _get_most_recent_slot()
	if slot == -1:
		return

	var info := SaveManager.get_slot_info(slot)
	var btn  := Button.new()
	btn.text                  = "Continuar  —  %s" % info.get("save_date", "")
	btn.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_override("font", _font)
	btn.add_theme_font_size_override("font_size", 26)
	btn.add_theme_color_override("font_color",         Color.BLACK)
	btn.add_theme_color_override("font_hover_color",   Color.BLACK)
	btn.add_theme_color_override("font_pressed_color", Color.BLACK)
	btn.add_theme_color_override("font_focus_color",   Color.BLACK)
	# Estilo dorado para distinguirlo
	btn.add_theme_stylebox_override("normal",  _make_rounded_style(Color(0.98, 0.88, 0.45)))
	btn.add_theme_stylebox_override("hover",   _make_rounded_style(Color(1.0,  0.95, 0.60)))
	btn.add_theme_stylebox_override("pressed", _make_rounded_style(Color(0.82, 0.72, 0.30)))
	btn.pressed.connect(func(): _load_slot(slot))
	main_buttons.add_child(btn)
	main_buttons.move_child(btn, 0)   # al principio de la lista

func _load_slot(slot: int) -> void:
	if SaveManager.load_game(slot):
		TutorialManager.skip_all()
		SceneTransition.go_to(WORLD_MAP_SCENE)


#  DIÁLOGO DE CONFIRMACIÓN — NUEVA PARTIDA
func _build_confirm_dialog() -> void:
	# Overlay full-screen
	_confirm_overlay = Control.new()
	_confirm_overlay.anchor_right  = 1.0
	_confirm_overlay.anchor_bottom = 1.0
	_confirm_overlay.visible       = false
	add_child(_confirm_overlay)

	# Fondo oscuro semitransparente
	var dim := ColorRect.new()
	dim.anchor_right  = 1.0
	dim.anchor_bottom = 1.0
	dim.color = Color(0, 0, 0, 0.60)
	_confirm_overlay.add_child(dim)

	# Panel centrado
	var panel := Panel.new()
	panel.anchor_left   = 0.5
	panel.anchor_top    = 0.5
	panel.anchor_right  = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left   = -220.0
	panel.offset_top    = -120.0
	panel.offset_right  =  220.0
	panel.offset_bottom =  120.0

	var ps := StyleBoxFlat.new()
	ps.bg_color                   = Color(0.07, 0.07, 0.13, 0.98)
	ps.border_width_left          = 1
	ps.border_width_right         = 1
	ps.border_width_top           = 1
	ps.border_width_bottom        = 1
	ps.border_color               = Color(0.40, 0.40, 0.70, 0.65)
	ps.corner_radius_top_left     = 14
	ps.corner_radius_top_right    = 14
	ps.corner_radius_bottom_right = 14
	ps.corner_radius_bottom_left  = 14
	ps.shadow_color               = Color(0, 0, 0, 0.55)
	ps.shadow_size                = 18
	ps.shadow_offset              = Vector2(0, 6)
	panel.add_theme_stylebox_override("panel", ps)
	_confirm_overlay.add_child(panel)

	# Contenido
	var margin := MarginContainer.new()
	margin.anchor_right  = 1.0
	margin.anchor_bottom = 1.0
	margin.add_theme_constant_override("margin_left",   28)
	margin.add_theme_constant_override("margin_top",    24)
	margin.add_theme_constant_override("margin_right",  28)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	# Título
	var title := Label.new()
	title.text                 = "Nueva Partida"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _font:
		title.add_theme_font_override("font", _font)
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color",        Color(0.98, 0.88, 0.45))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)
	vbox.add_child(title)

	# Separador
	var sep       := HSeparator.new()
	var sep_style := StyleBoxFlat.new()
	sep_style.bg_color            = Color(0.40, 0.40, 0.70, 0.40)
	sep_style.content_margin_top  = 0
	sep.add_theme_stylebox_override("separator", sep_style)
	vbox.add_child(sep)

	# Texto
	var lbl := Label.new()
	lbl.text                = "¿Iniciar una nueva partida?\nEl progreso sin guardar se perderá."
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.autowrap_mode       = TextServer.AUTOWRAP_WORD_SMART
	if _font:
		lbl.add_theme_font_override("font", _font)
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.88))
	vbox.add_child(lbl)

	# Botones
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	vbox.add_child(row)

	var ok_btn := Button.new()
	ok_btn.text = "Sí, empezar"
	ok_btn.custom_minimum_size = Vector2(130, 44)
	ok_btn.add_theme_stylebox_override("normal",  _make_rounded_style(Color(0.16, 0.50, 0.24)))
	ok_btn.add_theme_stylebox_override("hover",   _make_rounded_style(Color(0.20, 0.62, 0.29)))
	ok_btn.add_theme_stylebox_override("pressed", _make_rounded_style(Color(0.11, 0.36, 0.17)))
	ok_btn.add_theme_color_override("font_color",         Color.WHITE)
	ok_btn.add_theme_color_override("font_hover_color",   Color.WHITE)
	ok_btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	ok_btn.add_theme_color_override("font_focus_color",   Color.WHITE)
	if _font:
		ok_btn.add_theme_font_override("font", _font)
	ok_btn.add_theme_font_size_override("font_size", 18)
	ok_btn.pressed.connect(func():
		_confirm_overlay.visible = false
		main_buttons.visible     = true
		_start_new_game()
	)
	row.add_child(ok_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancelar"
	cancel_btn.custom_minimum_size = Vector2(130, 44)
	cancel_btn.add_theme_stylebox_override("normal",  _make_rounded_style(Color(0.22, 0.22, 0.33)))
	cancel_btn.add_theme_stylebox_override("hover",   _make_rounded_style(Color(0.30, 0.30, 0.46)))
	cancel_btn.add_theme_stylebox_override("pressed", _make_rounded_style(Color(0.15, 0.15, 0.24)))
	cancel_btn.add_theme_color_override("font_color",         Color.WHITE)
	cancel_btn.add_theme_color_override("font_hover_color",   Color.WHITE)
	cancel_btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	cancel_btn.add_theme_color_override("font_focus_color",   Color.WHITE)
	if _font:
		cancel_btn.add_theme_font_override("font", _font)
	cancel_btn.add_theme_font_size_override("font_size", 18)
	cancel_btn.pressed.connect(func():
		_confirm_overlay.visible = false
		main_buttons.visible     = true
	)
	row.add_child(cancel_btn)


func _start_new_game() -> void:
	Inventory.start_new_game()
	TutorialManager.reset()
	SaveManager.has_unsaved_changes = true
	SceneTransition.go_to(WORLD_MAP_SCENE)


#  AUDIO
func _ensure_bus(bus_name: String) -> int:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx != -1:
		return idx
	var new_idx := AudioServer.bus_count
	AudioServer.add_bus(new_idx)
	AudioServer.set_bus_name(new_idx, bus_name)
	AudioServer.set_bus_send(new_idx, "Master")
	return new_idx

func _setup_audio() -> void:
	_ensure_bus("Music")
	_ensure_bus("SFX")

	# Aplica los volúmenes guardados (ahora los buses ya existen)
	SettingsManager.set_music_volume(SettingsManager.get_music_volume())
	SettingsManager.set_sfx_volume(SettingsManager.get_sfx_volume())

	# Sincroniza el volumen del reproductor del menú
	if menu_music:
		var db := linear_to_db(SettingsManager.get_music_volume()) \
				  if SettingsManager.get_music_volume() > 0.0 else -80.0
		menu_music.volume_db = db

	# Sliders
	_music_pct = _make_pct_label()
	music_slider.get_parent().add_child(_music_pct)
	_sfx_pct = _make_pct_label()
	sfx_slider.get_parent().add_child(_sfx_pct)

	music_slider.set_value_no_signal(SettingsManager.get_music_volume())
	sfx_slider.set_value_no_signal(SettingsManager.get_sfx_volume())
	_music_pct.text = "%d%%" % int(music_slider.value * 100)
	_sfx_pct.text   = "%d%%" % int(sfx_slider.value  * 100)

	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)

func _make_pct_label() -> Label:
	var lbl := Label.new()
	lbl.custom_minimum_size      = Vector2(60, 0)
	lbl.horizontal_alignment     = HORIZONTAL_ALIGNMENT_RIGHT
	lbl.vertical_alignment       = VERTICAL_ALIGNMENT_CENTER
	if _font:
		lbl.add_theme_font_override("font", _font)
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.text = "100%"
	return lbl

func _on_music_changed(val: float) -> void:
	SettingsManager.set_music_volume(val)   # guarda y aplica al bus
	if menu_music:
		menu_music.volume_db = linear_to_db(val) if val > 0.0 else -80.0
	_music_pct.text = "%d%%" % int(val * 100)

func _on_sfx_changed(val: float) -> void:
	SettingsManager.set_sfx_volume(val)     # guarda y aplica al bus
	_sfx_pct.text = "%d%%" % int(val * 100)


#  VENTANA
func _setup_window_mode() -> void:
	window_mode_option.clear()
	window_mode_option.add_item("Ventana", 0)
	window_mode_option.add_item("Pantalla completa", 1)
	window_mode_option.select(1 if SettingsManager.is_fullscreen() else 0)

func _on_window_mode_selected(index: int) -> void:
	SettingsManager.set_fullscreen(index == 1)


#  PANEL CARGAR PARTIDA
func _build_load_panel() -> void:
	# Overlay full-screen (bloquea el fondo)
	_load_panel = Control.new()
	_load_panel.anchor_right  = 1.0
	_load_panel.anchor_bottom = 1.0
	_load_panel.visible = false
	add_child(_load_panel)

	var dim := ColorRect.new()
	dim.anchor_right  = 1.0
	dim.anchor_bottom = 1.0
	dim.color = Color(0.0, 0.0, 0.0, 0.75)
	_load_panel.add_child(dim)

	# Panel centrado con el mismo estilo que el diálogo de confirmación
	var panel := Panel.new()
	panel.anchor_left   = 0.5
	panel.anchor_top    = 0.5
	panel.anchor_right  = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left   = -310.0
	panel.offset_top    = -260.0
	panel.offset_right  =  310.0
	panel.offset_bottom =  260.0

	var ps := StyleBoxFlat.new()
	ps.bg_color                   = Color(0.07, 0.07, 0.13, 0.98)
	ps.border_width_left          = 1
	ps.border_width_right         = 1
	ps.border_width_top           = 1
	ps.border_width_bottom        = 1
	ps.border_color               = Color(0.40, 0.40, 0.70, 0.65)
	ps.corner_radius_top_left     = 14
	ps.corner_radius_top_right    = 14
	ps.corner_radius_bottom_right = 14
	ps.corner_radius_bottom_left  = 14
	ps.shadow_color               = Color(0, 0, 0, 0.55)
	ps.shadow_size                = 18
	ps.shadow_offset              = Vector2(0, 6)
	panel.add_theme_stylebox_override("panel", ps)
	_load_panel.add_child(panel)

	# Contenido
	var margin := MarginContainer.new()
	margin.anchor_right  = 1.0
	margin.anchor_bottom = 1.0
	margin.add_theme_constant_override("margin_left",   28)
	margin.add_theme_constant_override("margin_top",    24)
	margin.add_theme_constant_override("margin_right",  28)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	# Título
	var title := Label.new()
	title.text                 = "Cargar partida"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _font:
		title.add_theme_font_override("font", _font)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color",        Color(0.98, 0.88, 0.45))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)
	vbox.add_child(title)

	# Separador
	var sep       := HSeparator.new()
	var sep_style := StyleBoxFlat.new()
	sep_style.bg_color = Color(0.40, 0.40, 0.70, 0.40)
	sep.add_theme_stylebox_override("separator", sep_style)
	vbox.add_child(sep)

	# Lista de slots con scroll
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	_slot_list = VBoxContainer.new()
	_slot_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slot_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_slot_list)

	# Separador inferior
	var sep2       := HSeparator.new()
	var sep2_style := StyleBoxFlat.new()
	sep2_style.bg_color = Color(0.40, 0.40, 0.70, 0.40)
	sep2.add_theme_stylebox_override("separator", sep2_style)
	vbox.add_child(sep2)

	# Botón volver
	var back_btn := Button.new()
	back_btn.text                = "Volver"
	back_btn.custom_minimum_size = Vector2(0, 44)
	if _font:
		back_btn.add_theme_font_override("font", _font)
	back_btn.add_theme_font_size_override("font_size", 20)
	back_btn.add_theme_stylebox_override("normal",  _make_rounded_style(Color(0.22, 0.22, 0.33)))
	back_btn.add_theme_stylebox_override("hover",   _make_rounded_style(Color(0.30, 0.30, 0.46)))
	back_btn.add_theme_stylebox_override("pressed", _make_rounded_style(Color(0.15, 0.15, 0.24)))
	back_btn.add_theme_color_override("font_color",         Color.WHITE)
	back_btn.add_theme_color_override("font_hover_color",   Color.WHITE)
	back_btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	back_btn.add_theme_color_override("font_focus_color",   Color.WHITE)
	back_btn.pressed.connect(_on_load_back_pressed)
	vbox.add_child(back_btn)

func _populate_load_slots() -> void:
	for child in _slot_list.get_children():
		child.queue_free()

	var has_any := false
	for slot in range(SaveManager.SLOT_COUNT):
		var info := SaveManager.get_slot_info(slot)
		if info.get("empty", true):
			continue
		has_any = true
		var btn := Button.new()
		btn.text                = "Slot %d   Nv.%d   %s   %d ✦" % [slot + 1, info.get("level", 1), info.get("save_date", "??"), info.get("gold", 0)]
		btn.custom_minimum_size = Vector2(0, 44)
		if _font:
			btn.add_theme_font_override("font", _font)
		btn.add_theme_font_size_override("font_size", 16)
		btn.add_theme_stylebox_override("normal",  _make_rounded_style(Color(0.14, 0.28, 0.44)))
		btn.add_theme_stylebox_override("hover",   _make_rounded_style(Color(0.20, 0.38, 0.58)))
		btn.add_theme_stylebox_override("pressed", _make_rounded_style(Color(0.10, 0.20, 0.34)))
		btn.add_theme_color_override("font_color",         Color(0.95, 0.95, 1.0))
		btn.add_theme_color_override("font_hover_color",   Color.WHITE)
		btn.add_theme_color_override("font_pressed_color", Color.WHITE)
		btn.add_theme_color_override("font_focus_color",   Color.WHITE)
		btn.pressed.connect(_on_slot_selected.bind(slot))
		_slot_list.add_child(btn)

	if not has_any:
		var lbl := Label.new()
		lbl.text                 = "No hay partidas guardadas"
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if _font:
			lbl.add_theme_font_override("font", _font)
		lbl.add_theme_font_size_override("font_size", 18)
		lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.70))
		_slot_list.add_child(lbl)

func _on_slot_selected(slot: int) -> void:
	if SaveManager.load_game(slot):
		TutorialManager.skip_all()
		SceneTransition.go_to(WORLD_MAP_SCENE)

func _on_load_back_pressed() -> void:
	_load_panel.visible    = false
	main_buttons.visible   = true


#  BOTONES PRINCIPALES
func _on_new_game_pressed() -> void:
	main_buttons.visible     = false
	_confirm_overlay.move_to_front()
	_confirm_overlay.visible = true

func _on_load_game_pressed() -> void:
	main_buttons.visible = false
	_populate_load_slots()
	_load_panel.move_to_front()
	_load_panel.visible  = true

func _on_options_pressed() -> void:
	main_buttons.visible  = false
	options_panel.visible = true

func _on_back_options_pressed() -> void:
	options_panel.visible = false
	main_buttons.visible  = true

func _on_exit_pressed() -> void:
	get_tree().quit()


#  BARRA SOCIAL (esquina inferior)
const ICON_DISCORD := "res://Assets/Icons/UI/discord.svg"
const ICON_X       := "res://Assets/Icons/UI/x.svg"
const ICON_WEB     := "res://Assets/Icons/UI/web.svg"
const WEB_URL      := "https://web-starpath.vercel.app/"
const VERSION_TEXT := "v 0.1"

func _add_social_bar() -> void:
	# Contenedor principal anclado abajo
	var bar := HBoxContainer.new()
	bar.anchor_left   = 0.0
	bar.anchor_top    = 1.0
	bar.anchor_right  = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_left   =  20.0
	bar.offset_top    = -56.0
	bar.offset_right  = -20.0
	bar.offset_bottom = -12.0
	bar.add_theme_constant_override("separation", 8)
	add_child(bar)

	# Iconos izquierda
	var icons := HBoxContainer.new()
	icons.add_theme_constant_override("separation", 6)
	bar.add_child(icons)

	_add_icon_btn(icons, ICON_DISCORD, "",      true)   # sin URL → desactivado
	_add_icon_btn(icons, ICON_X,       "",      true)   # sin URL → desactivado
	_add_icon_btn(icons, ICON_WEB,     WEB_URL, false)  # activo

	# Espaciador
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)

	# Versión derecha
	var ver := Label.new()
	ver.text               = VERSION_TEXT
	ver.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ver.add_theme_font_size_override("font_size", 14)
	ver.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	if _font:
		ver.add_theme_font_override("font", _font)
	bar.add_child(ver)


func _add_icon_btn(parent: Node, icon_path: String, url: String, disabled: bool) -> void:
	var tex: Texture2D = load(icon_path)
	if tex == null:
		return

	var btn := TextureButton.new()
	btn.texture_normal          = tex
	btn.custom_minimum_size     = Vector2(28, 28)
	btn.ignore_texture_size     = true
	btn.stretch_mode            = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not disabled \
									 else Control.CURSOR_ARROW

	if disabled or url.is_empty():
		btn.modulate = Color(1, 1, 1, 0.35)   # grisado — aún no disponible
		btn.disabled = true
	else:
		btn.modulate = Color(1, 1, 1, 0.80)
		btn.pressed.connect(func(): OS.shell_open(url))
		# Hover: brillo al pasar el ratón
		btn.mouse_entered.connect(func(): btn.modulate = Color(1, 1, 1, 1.0))
		btn.mouse_exited.connect( func(): btn.modulate = Color(1, 1, 1, 0.80))

	parent.add_child(btn)
