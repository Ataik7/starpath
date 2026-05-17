extends Node2D
class_name NPC

@export var speaker_name : String        = "Aldeano"
@export var dialog_lines : Array[String] = ["Hola, viajero."]

@export var is_merchant  : bool          = false
@export var shop_name    : String        = "Tienda"
@export var shop_catalog : Array[ItemData] = []

@export var npc_texture  : Texture2D
@export_range(0, 3) var sprite_row: int = 0

@onready var _sprite       : Sprite2D = $Sprite2D
@onready var _hint         : Label    = $InteractHint
@onready var _interact_area: Area2D   = $InteractArea

var _player   : PlayerController = null
var _in_range : bool             = false

# Menú de opciones
var _menu_layer : CanvasLayer = null
var _menu_open  : bool        = false

const C_BG     := Color(0.10, 0.07, 0.24, 0.98)
const C_BORDER := Color(0.85, 0.70, 0.15)
const C_TEXT   := Color(0.90, 0.90, 0.90)
const C_TITLE  := Color(1.0, 0.88, 0.30)

func _ready() -> void:
	if npc_texture:
		var atlas    := AtlasTexture.new()
		atlas.atlas   = npc_texture
		atlas.region  = Rect2(32, sprite_row * 32, 32, 32)
		_sprite.texture = atlas

	if is_merchant and shop_catalog.is_empty():
		_fill_default_catalog()

	_hint.hide()
	_interact_area.body_entered.connect(_on_body_entered)
	_interact_area.body_exited.connect(_on_body_exited)
	_build_menu()

func _build_menu() -> void:
	_menu_layer = CanvasLayer.new()
	_menu_layer.layer = 60
	_menu_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_menu_layer)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	var h := 160 if is_merchant else 100
	panel.offset_left   = -110
	panel.offset_right  =  110
	panel.offset_top    = -h / 2.0
	panel.offset_bottom =  h / 2.0

	var style := StyleBoxFlat.new()
	style.bg_color   = C_BG
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

	if is_merchant:
		var btn_buy := _make_btn("🛒  Comprar")
		btn_buy.pressed.connect(_on_comprar)
		vbox.add_child(btn_buy)

		var btn_sell := _make_btn("✦  Vender")
		btn_sell.pressed.connect(_on_vender)
		vbox.add_child(btn_sell)

	_menu_layer.hide()

func _make_btn(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(180, 34)
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

# Detección del jugador
func _on_body_entered(body: Node2D) -> void:
	if body is not PlayerController:
		return
	_player   = body as PlayerController
	_in_range = true
	_player.interaction_requested.connect(_on_interact)
	if not DialogManager.is_open:
		_hint.show()
	TutorialManager.try_show(
		"npc",
		"Personajes",
		"Pulsa  E  para hablar con los personajes del mundo.\n\nAlgunos son comerciantes: podrás comprarles armas, armaduras y objetos con el oro que llevas.",
		false
	)

func _on_body_exited(body: Node2D) -> void:
	if body is not PlayerController:
		return
	_in_range = false
	if _player and _player.interaction_requested.is_connected(_on_interact):
		_player.interaction_requested.disconnect(_on_interact)
	_player = null
	_hint.hide()
	if _menu_open:
		_close_menu()

# Interacción
func _on_interact() -> void:
	if not _in_range or _menu_open:
		return
	if DialogManager.is_open or ShopManager.is_open:
		return
	_hint.hide()
	_menu_open = true
	get_tree().paused = true
	_menu_layer.show()

func _close_menu() -> void:
	_menu_open = false
	get_tree().paused = false
	_menu_layer.hide()
	if _in_range:
		_hint.show()

func _unhandled_input(event: InputEvent) -> void:
	if not _menu_open:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.is_action_pressed("open_menu"):
			get_viewport().set_input_as_handled()
			_close_menu()

# Opciones del menú
func _on_hablar() -> void:
	_close_menu()
	DialogManager.start_dialog(dialog_lines, speaker_name)
	DialogManager.dialog_finished.connect(_on_closed, CONNECT_ONE_SHOT)

func _on_comprar() -> void:
	_close_menu()
	ShopManager.open_shop(shop_catalog, shop_name)
	ShopManager.shop_closed.connect(_on_closed, CONNECT_ONE_SHOT)

func _on_vender() -> void:
	_close_menu()
	ShopManager.open_sell("Vender")
	ShopManager.shop_closed.connect(_on_closed, CONNECT_ONE_SHOT)

func _on_closed() -> void:
	if _in_range:
		_hint.show()

# Catálogo por defecto
func _fill_default_catalog() -> void:
	var sword             := ItemData.new()
	sword.item_name        = "Espada de Hierro"
	sword.item_type        = ItemData.ItemType.WEAPON
	sword.attack_bonus     = 15
	sword.price            = 50
	sword.shop_category    = "guerrero"
	shop_catalog.append(sword)

	var shield            := ItemData.new()
	shield.item_name       = "Escudo de Madera"
	shield.item_type       = ItemData.ItemType.ARMOR
	shield.defense_bonus   = 10
	shield.price           = 40
	shield.shop_category   = "guerrero"
	shop_catalog.append(shield)

	var armor             := ItemData.new()
	armor.item_name        = "Armadura de Cuero"
	armor.item_type        = ItemData.ItemType.ARMOR
	armor.defense_bonus    = 20
	armor.price            = 80
	armor.shop_category    = "guerrero"
	shop_catalog.append(armor)

	var staff             := ItemData.new()
	staff.item_name        = "Bastón de Roble"
	staff.item_type        = ItemData.ItemType.WEAPON
	staff.attack_bonus     = 10
	staff.price            = 35
	staff.shop_category    = "mago"
	shop_catalog.append(staff)

	var robe              := ItemData.new()
	robe.item_name         = "Túnica de Aprendiz"
	robe.item_type         = ItemData.ItemType.ARMOR
	robe.defense_bonus     = 7
	robe.price             = 30
	robe.shop_category     = "mago"
	shop_catalog.append(robe)

	var arcane_staff      := ItemData.new()
	arcane_staff.item_name      = "Báculo Arcano"
	arcane_staff.item_type      = ItemData.ItemType.WEAPON
	arcane_staff.attack_bonus   = 22
	arcane_staff.price          = 95
	arcane_staff.shop_category  = "mago"
	shop_catalog.append(arcane_staff)

	var pocion            := ItemData.new()
	pocion.item_name       = "Poción"
	pocion.item_type       = ItemData.ItemType.CONSUMABLE
	pocion.effect_type     = "heal_hp"
	pocion.amount          = 50
	pocion.price           = 20
	pocion.shop_category   = "objeto"
	shop_catalog.append(pocion)

	var eter              := ItemData.new()
	eter.item_name         = "Éter"
	eter.item_type         = ItemData.ItemType.CONSUMABLE
	eter.effect_type       = "heal_mp"
	eter.amount            = 30
	eter.price             = 15
	eter.shop_category     = "objeto"
	shop_catalog.append(eter)
