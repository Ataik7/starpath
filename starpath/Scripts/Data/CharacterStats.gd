class_name CharacterStats
extends Resource

enum ClassType { GUERRERO, MAGO, PICARO, SANADOR, PALADIN, ARQUERO }

@export var character_name: String = "Héroe"
@export var character_class: ClassType = ClassType.GUERRERO
@export var max_hp: int = 100
@export var max_mp: int = 50
@export var attack: int = 20
@export var defense: int = 10
@export var speed: int = 15
@export var strength: int = 12
@export var magic: int = 10
@export var spirit: int = 8
@export var evade: int = 5
@export var magic_defense: int = 8
@export var magic_evade: int = 5
@export var skills: Array[SkillData] = []

# XP e oro que suelta este personaje al morir.
# Si xp_reward es 0 se calcula con (max_hp/2 + attack) como valor por defecto.
@export var xp_reward: int = 0
@export var gold_reward: int = 10
@export var drop_chance: float = 0.30  # 0.0 = nunca dropea, 1.0 = siempre
