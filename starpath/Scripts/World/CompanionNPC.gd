extends Node2D
class_name CompanionNPC

## ID único del compañero (debe coincidir con Inventory.has_party_member).
## Valores esperados: "athelios" | "byran"
@export var companion_id   : String        = ""
@export var speaker_name   : String        = "Compañero"
@export var npc_texture    : Texture2D
@export_range(0, 3) var sprite_row: int    = 0

## Diálogo mostrado antes de unirse
@export var pre_join_dialog  : Array[String] = ["Hola, viajero."]
## Frase corta al aceptar unirse (solo una línea)
@export var join_dialog      : Array[String] = ["¡Me uno a tu grupo!"]
## Diálogo después de haberse unido
@export var post_join_dialog : Array[String] = ["Ya somos un equipo."]

@onready var _sprite       : Sprite2D = $Sprite2D
@onready var _interact_area: Area2D   = $InteractArea

var _player    : PlayerController = null
var _in_range  : bool             = false
var _menu_open : bool             = false
var _menu_layer: CanvasLayer      = null
var _join_btn  : Button           = null

const C_BG     := Color(0.10, 0.07, 0.24, 0.98)
const C_BORDER := Color(0.85, 0.70, 0.15)
const C_TEXT   := Color(0.90, 0.90, 0.90)
const C_TITLE  := Color(1.0, 0.88, 0.30)

func _ready() -> void:
	# Si ya se unió (partida guardada), ocultarse de inmediato
	if Inventory.has_party_member(companion_id):
		_hide_from_world()
		return

	# Sprite del NPC en el mapa
	if npc_texture:
		var atlas   := AtlasTexture.new()
		atlas.atlas  = npc_texture
		atlas.region = Rect2(32, sprite_row * 32, 32, 32)
		_sprite.texture = atlas

	_interact_area.body_entered.connect(_on_body_entered)
	_interact_area.body_exited.connect(_on_body_exited)
	_build_menu()

## Elimina el NPC del mundo: oculta el sprite y desactiva colisiones.
func _hide_from_world() -> void:
	visible = false
	# Desactivar área de interacción
	if is_instance_valid(_interact_area):
		_interact_area.set_deferred("monitoring",  false)
		_interact_area.set_deferred("monitorable", false)
	# Cerrar menú si estuviera abierto
	if _menu_open:
		_close_menu()

# ── Construcción del menú ─────────────────────────────────────────────────────

func _build_menu() -> void:
	_menu_layer = CanvasLayer.new()
	_menu_layer.layer = 60
	_menu_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_menu_layer)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left   = -120
	panel.offset_right  =  120
	panel.offset_top    = -65
	panel.offset_bottom =  65

	var style := StyleBoxFlat.new()
	style.bg_color = C_BG
	style.border_color = C_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left   = 16
	style.content_margin_right  = 16
	style.content_margin_top    = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	_menu_layer.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = speaker_name
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", C_TITLE)
	vbox.add_child(title)

	vbox.add_child(_make_separator())

	var btn_talk := _make_btn("💬  Hablar")
	btn_talk.pressed.connect(_on_hablar)
	vbox.add_child(btn_talk)

	_join_btn = _make_btn("⚔  Unirse al grupo")
	_join_btn.pressed.connect(_on_unirse)
	vbox.add_child(_join_btn)

	_menu_layer.hide()

func _make_btn(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(200, 34)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.14, 0.10, 0.30)
	s.set_corner_radius_all(4)
	s.set_border_width_all(1)
	s.border_color = C_BORDER
	s.content_margin_left = 10
	var sh := StyleBoxFlat.new()
	sh.bg_color = Color(0.25, 0.18, 0.50)
	sh.set_corner_radius_all(4)
	sh.content_margin_left = 10
	btn.add_theme_stylebox_override("normal",  s)
	btn.add_theme_stylebox_override("hover",   sh)
	btn.add_theme_stylebox_override("pressed", sh)
	btn.add_theme_color_override("font_color", C_TEXT)
	btn.add_theme_font_size_override("font_size", 13)
	return btn

func _make_separator() -> HSeparator:
	var sep := HSeparator.new()
	var st := StyleBoxFlat.new()
	st.bg_color = C_BORDER
	st.content_margin_top    = 1
	st.content_margin_bottom = 1
	sep.add_theme_stylebox_override("separator", st)
	return sep

# ── Detección del jugador ─────────────────────────────────────────────────────

func _on_body_entered(body: Node2D) -> void:
	if body is not PlayerController:
		return
	_player   = body as PlayerController
	_in_range = true
	_player.interaction_requested.connect(_on_interact)

func _on_body_exited(body: Node2D) -> void:
	if body is not PlayerController:
		return
	_in_range = false
	if _player and _player.interaction_requested.is_connected(_on_interact):
		_player.interaction_requested.disconnect(_on_interact)
	_player = null
	if _menu_open:
		_close_menu()

# ── Interacción ───────────────────────────────────────────────────────────────

func _on_interact() -> void:
	if not _in_range or _menu_open:
		return
	if DialogManager.is_open:
		return
	_menu_open = true
	get_tree().paused = true
	_join_btn.visible = not Inventory.has_party_member(companion_id)
	_menu_layer.show()

func _close_menu() -> void:
	_menu_open = false
	get_tree().paused = false
	_menu_layer.hide()

func _unhandled_input(event: InputEvent) -> void:
	if not _menu_open:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.is_action_pressed("open_menu"):
			get_viewport().set_input_as_handled()
			_close_menu()

# ── Opciones del menú ─────────────────────────────────────────────────────────

func _on_hablar() -> void:
	_close_menu()
	var lines := post_join_dialog if Inventory.has_party_member(companion_id) else pre_join_dialog
	DialogManager.start_dialog(lines, speaker_name)

func _on_unirse() -> void:
	_close_menu()
	DialogManager.start_dialog(join_dialog, speaker_name)
	DialogManager.dialog_finished.connect(_on_join_confirmed, CONNECT_ONE_SHOT)

func _on_join_confirmed() -> void:
	Inventory.add_party_member(companion_id)
	_hide_from_world()
