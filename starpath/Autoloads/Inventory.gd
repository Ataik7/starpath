extends Node

signal changed
signal level_changed(new_level: int)

const HERO_STATS_PATH := "res://Resources/Characters/Hero.tres"

var items:            Array[ItemData] = []
var gold:             int             = 150
var equipped_weapon:  ItemData        = null
var equipped_armor:   ItemData        = null

# IDs de compañeros que se han unido al grupo ("athelios", "byran", …)
var party_members: Array[String] = []

func add_party_member(id: String) -> void:
	if not has_party_member(id):
		party_members.append(id)
		_add_starter_equipment(id)
		changed.emit()

func has_party_member(id: String) -> bool:
	return id in party_members

# XP y nivel independiente de cada compañero (companion_id → int)
var companion_xp:    Dictionary = {}
var companion_level: Dictionary = {}

func get_companion_level(id: String) -> int:
	return companion_level.get(id, 1)

func get_companion_xp(id: String) -> int:
	return companion_xp.get(id, 0)

func companion_xp_to_next(id: String) -> int:
	return get_companion_level(id) * 100

func add_companion_xp(id: String, amount: int) -> void:
	if not companion_xp.has(id):
		companion_xp[id] = 0
	if not companion_level.has(id):
		companion_level[id] = 1
	companion_xp[id] += amount
	while companion_xp[id] >= companion_xp_to_next(id):
		companion_xp[id] -= companion_xp_to_next(id)
		companion_level[id] += 1
	changed.emit()

# Equipo equipado por cada compañero (companion_id → ItemData | null)
var companion_weapon: Dictionary = {}
var companion_armor:  Dictionary = {}

func get_equipped_weapon_for(id: String) -> ItemData:
	return companion_weapon.get(id, null)

func get_equipped_armor_for(id: String) -> ItemData:
	return companion_armor.get(id, null)

func get_atk_bonus_for(id: String) -> int:
	var w: ItemData = get_equipped_weapon_for(id)
	return w.attack_bonus if w else 0

func get_def_bonus_for(id: String) -> int:
	var a: ItemData = get_equipped_armor_for(id)
	return a.defense_bonus if a else 0

func equip_for(id: String, item: ItemData) -> void:
	if item.item_type == ItemData.ItemType.WEAPON:
		companion_weapon[id] = item
	elif item.item_type == ItemData.ItemType.ARMOR:
		companion_armor[id] = item
	changed.emit()

func unequip_for(id: String, item: ItemData) -> void:
	if companion_weapon.get(id) == item:
		companion_weapon[id] = null
	elif companion_armor.get(id) == item:
		companion_armor[id] = null
	changed.emit()

# Equipo inicial del compañero
func _add_starter_equipment(id: String) -> void:
	# Solo si no tiene ya equipo
	if companion_weapon.get(id) != null or companion_armor.get(id) != null:
		return
	match id:
		"athelios":
			var dagger := ItemData.new()
			dagger.item_name = "Daga de Sombra"
			dagger.item_type = ItemData.ItemType.WEAPON
			dagger.attack_bonus = 9
			dagger.price = 120
			dagger.shop_category = "guerrero"
			companion_weapon["athelios"] = dagger

			var leather := ItemData.new()
			leather.item_name = "Armadura de Cuero"
			leather.item_type = ItemData.ItemType.ARMOR
			leather.defense_bonus = 5
			leather.price = 90
			leather.shop_category = "guerrero"
			companion_armor["athelios"] = leather
		"byran":
			var sword := ItemData.new()
			sword.item_name = "Espada Corta"
			sword.item_type = ItemData.ItemType.WEAPON
			sword.attack_bonus = 14
			sword.price = 150
			sword.shop_category = "guerrero"
			companion_weapon["byran"] = sword

			var mail := ItemData.new()
			mail.item_name = "Cota de Malla"
			mail.item_type = ItemData.ItemType.ARMOR
			mail.defense_bonus = 10
			mail.price = 130
			mail.shop_category = "guerrero"
			companion_armor["byran"] = mail

var current_hp: int = 0
var current_mp: int = 0

# HP y MP de los compañeros (companion_id → int)
var companion_hp: Dictionary = {}
var companion_mp: Dictionary = {}

func get_companion_hp(id: String) -> int:
	return companion_hp.get(id, get_companion_max_hp(id))

func get_companion_mp(id: String) -> int:
	return companion_mp.get(id, get_companion_max_mp(id))

func get_companion_max_hp(id: String) -> int:
	var stats_path := "res://Resources/Characters/%s.tres" % id.capitalize()
	var stats := load(stats_path) as CharacterStats
	if stats == null:
		return 80
	var lvl := get_companion_level(id)
	return stats.max_hp + (lvl - 1) * 10

func get_companion_max_mp(id: String) -> int:
	var stats_path := "res://Resources/Characters/%s.tres" % id.capitalize()
	var stats := load(stats_path) as CharacterStats
	if stats == null:
		return 50
	var lvl := get_companion_level(id)
	return stats.max_mp + (lvl - 1) * 5

func set_companion_hp(id: String, value: int) -> void:
	companion_hp[id] = clampi(value, 0, get_companion_max_hp(id))

func set_companion_mp(id: String, value: int) -> void:
	companion_mp[id] = clampi(value, 0, get_companion_max_mp(id))

# Posición guardada justo antes de entrar en combate
var pre_battle_position:  Vector2 = Vector2.ZERO
var pre_battle_direction: String  = "down"
var returning_from_battle: bool   = false
var last_enemy_id:         String  = ""
var battle_was_won:        bool    = false
var defeated_enemies:      Array[String] = []
var battle_enemy_scenes:   Array[String] = []
var battle_was_fled:       bool          = false

# Progresión
var current_level: int = 1
var current_xp:    int = 0

# Base stats leídas de Hero.tres en _ready() (no cambian por nivel)
var _base_max_hp: int = 80
var _base_max_mp: int = 100

# HP máximo actual
func get_max_hp() -> int:
	return _base_max_hp + (current_level - 1) * 10

# MP máximo actual
func get_max_mp() -> int:
	return _base_max_mp + (current_level - 1) * 5

# XP para siguiente nivel
func xp_to_next() -> int:
	return current_level * 100

# Dar XP y subir nivel si toca
func add_xp(amount: int) -> void:
	current_xp += amount
	while current_xp >= xp_to_next():
		current_xp -= xp_to_next()
		current_level += 1
		_apply_level_up()
	changed.emit()

func _apply_level_up() -> void:
	current_hp = get_max_hp()   # HP y MP restaurados al nuevo máximo
	current_mp = get_max_mp()
	level_changed.emit(current_level)

# Bonus ATK por nivel
func get_level_atk_bonus() -> int:
	return (current_level - 1) * 2

# Bonus DEF por nivel
func get_level_def_bonus() -> int:
	return current_level - 1

# Inicializar HP/MP
func init_stats() -> void:
	current_hp = get_max_hp()
	current_mp = get_max_mp()

func _ready() -> void:
	var base: CharacterStats = load(HERO_STATS_PATH)
	if base:
		_base_max_hp = base.max_hp
		_base_max_mp = base.max_mp
	init_stats()

# Reset para nueva partida
func start_new_game() -> void:
	gold            = 150
	current_level   = 1
	current_xp      = 0
	items.clear()
	equipped_weapon = null
	equipped_armor  = null
	party_members.clear()
	companion_xp.clear()
	companion_level.clear()
	companion_weapon.clear()
	companion_armor.clear()
	init_stats()

	var pocion := ItemData.new()
	pocion.item_name   = "Poción"
	pocion.item_type   = ItemData.ItemType.CONSUMABLE
	pocion.effect_type = "heal_hp"
	pocion.amount      = 50
	pocion.quantity    = 3
	items.append(pocion)

	var eter := ItemData.new()
	eter.item_name   = "Éter"
	eter.item_type   = ItemData.ItemType.CONSUMABLE
	eter.effect_type = "heal_mp"
	eter.amount      = 30
	eter.quantity    = 2
	items.append(eter)

	var staff := ItemData.new()
	staff.item_name     = "Bastón de Aprendiz"
	staff.item_type     = ItemData.ItemType.WEAPON
	staff.attack_bonus  = 6
	staff.price         = 80
	staff.shop_category = "mago"
	items.append(staff)
	equipped_weapon = staff

	var robe := ItemData.new()
	robe.item_name      = "Túnica de Iniciada"
	robe.item_type      = ItemData.ItemType.ARMOR
	robe.defense_bonus  = 4
	robe.price          = 60
	robe.shop_category  = "mago"
	items.append(robe)
	equipped_armor = robe

func use_item(item: ItemData) -> void:
	item.quantity -= 1
	changed.emit()

func get_available() -> Array[ItemData]:
	var result: Array[ItemData] = []
	for item in items:
		if item.quantity > 0:
			result.append(item)
	return result

# Añadir item
func add_item(source: ItemData) -> void:
	if source.item_type == ItemData.ItemType.CONSUMABLE:
		for item in items:
			if item.item_name == source.item_name:
				item.quantity += 1
				changed.emit()
				return
	var copy          := source.duplicate() as ItemData
	copy.quantity      = 1
	items.append(copy)
	changed.emit()

func equip(item: ItemData) -> void:
	if item.item_type == ItemData.ItemType.WEAPON:
		equipped_weapon = item
	elif item.item_type == ItemData.ItemType.ARMOR:
		equipped_armor = item
	changed.emit()

func unequip(item: ItemData) -> void:
	if item == equipped_weapon:
		equipped_weapon = null
	elif item == equipped_armor:
		equipped_armor = null
	changed.emit()

# Quitar item
func remove_item(item: ItemData) -> void:
	if item.item_type == ItemData.ItemType.CONSUMABLE:
		item.quantity -= 1
		if item.quantity <= 0:
			items.erase(item)
	else:
		unequip(item)
		items.erase(item)
	changed.emit()

func get_attack_bonus() -> int:
	return equipped_weapon.attack_bonus if equipped_weapon else 0

func get_defense_bonus() -> int:
	return equipped_armor.defense_bonus if equipped_armor else 0
