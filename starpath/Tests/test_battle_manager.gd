extends GutTest

# Tests del sistema de combate por turnos

var battle_manager: BattleManager
var turn_queue: TurnQueue

func before_each():
	turn_queue    = TurnQueue.new()
	battle_manager            = BattleManager.new()
	battle_manager.turn_queue = turn_queue
	add_child(battle_manager)
	add_child(turn_queue)

func after_each():
	battle_manager.queue_free()
	turn_queue.queue_free()

func _make_entity(character_name: String, hp: int, attack: int, speed: int) -> BaseEntity:
	var stats       = CharacterStats.new()
	stats.character_name = character_name
	stats.max_hp    = hp
	stats.max_mp    = 20
	stats.attack    = attack
	stats.defense   = 5
	stats.speed     = speed
	stats.xp_reward = 10
	stats.gold_reward = 5

	var entity      = BaseEntity.new()
	entity.stats    = stats
	entity.current_hp = hp
	entity.current_mp = 20
	return entity

func test_estado_inicial_es_starting():
	assert_eq(battle_manager.current_state, BattleManager.BattleState.STARTING,
		"El estado inicial debe ser STARTING")

func test_entidad_muere_al_llegar_a_cero_hp():
	var entity = _make_entity("Slime", 10, 5, 10)
	add_child(entity)
	entity.take_damage(999)  # daño masivo para ignorar defensa
	assert_false(entity.is_alive, "La entidad debe morir al llegar a 0 HP")
	entity.queue_free()

func test_entidad_sobrevive_con_hp_restante():
	var entity = _make_entity("Heroe", 50, 10, 12)
	add_child(entity)
	entity.take_damage(20)
	assert_true(entity.is_alive, "La entidad debe seguir viva si le queda HP")
	entity.queue_free()

func test_dano_no_supera_hp_actual():
	var entity = _make_entity("Goblin", 30, 8, 9)
	add_child(entity)
	entity.take_damage(999)
	assert_lte(entity.current_hp, 0, "El HP no debe quedar en positivo tras daño letal")
	entity.queue_free()

func test_curacion_no_supera_maximo():
	var entity = _make_entity("Heroe", 50, 10, 12)
	add_child(entity)
	entity.current_hp = 10
	entity.heal_hp(999)
	assert_lte(entity.current_hp, entity.stats.max_hp, "El HP curado no puede superar el máximo")
	entity.queue_free()
