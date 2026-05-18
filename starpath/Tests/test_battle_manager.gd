extends GutTest

# Tests del BattleManager y comportamiento de entidades en combate

var battle_manager: BattleManager
var turn_queue: TurnQueue

func before_each():
	turn_queue = autofree(TurnQueue.new())
	battle_manager = autofree(BattleManager.new())
	battle_manager.turn_queue = turn_queue
	add_child(battle_manager)
	add_child(turn_queue)

func _make_entity(nombre: String, hp: int, atk: int, spd: int) -> BaseEntity:
	var stats = CharacterStats.new()
	stats.character_name = nombre
	stats.max_hp = hp
	stats.max_mp = 20
	stats.attack = atk
	stats.defense = 5
	stats.speed = spd
	stats.xp_reward = 10
	stats.gold_reward = 5

	var e = BaseEntity.new()
	e.stats = stats
	e.current_hp = hp
	e.current_mp = 20
	return e

func test_estado_inicial_es_starting():
	assert_eq(battle_manager.current_state, BattleManager.BattleState.STARTING,
		"Al crearse, el estado debe ser STARTING")

func test_entidad_muere_al_llegar_a_cero_hp():
	var e = add_child_autofree(_make_entity("Slime", 10, 5, 10))
	e.take_damage(999)
	assert_false(e.is_alive, "La entidad debe morir al recibir daño letal")

func test_entidad_sobrevive_con_hp_restante():
	var e = add_child_autofree(_make_entity("Heroe", 50, 10, 12))
	e.take_damage(20)
	assert_true(e.is_alive, "La entidad debe sobrevivir si le queda HP")

func test_dano_no_supera_hp_actual():
	var e = add_child_autofree(_make_entity("Goblin", 30, 8, 9))
	e.take_damage(999)
	assert_lte(e.current_hp, 0, "El HP no puede quedar positivo tras daño letal")

func test_curacion_no_supera_maximo():
	var e = add_child_autofree(_make_entity("Heroe", 50, 10, 12))
	e.current_hp = 10
	e.heal_hp(999)
	assert_lte(e.current_hp, e.stats.max_hp, "La curación no puede superar el máximo")
