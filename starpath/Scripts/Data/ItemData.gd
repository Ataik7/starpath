class_name ItemData
extends Resource

enum ItemType { CONSUMABLE, WEAPON, ARMOR }

@export var item_name:     String   = "Poción"
@export var item_type:     ItemType = ItemType.CONSUMABLE
@export var effect_type:   String   = "heal_hp"   # "heal_hp" | "heal_mp"
@export var amount:        int      = 50
@export var quantity:      int      = 3
@export var targets_enemy: bool     = false
@export var price:          int    = 10
@export var attack_bonus:   int    = 0
@export var defense_bonus:  int    = 0
# "todo" | "guerrero" | "mago" | "objeto"
@export var shop_category:  String = "todo"
