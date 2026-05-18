extends GutTest

# Tests avanzados: rotación, entidades muertas y ordenación

var turn_queue: TurnQueue

func before_each():
	turn_queue = autofree(TurnQueue.new())
	add_child(turn_queue)

func _make_entity(nombre: String, speed: int, hp: int = 30) -> BaseEntity:
	var stats = CharacterStats.new()
	stats.character_name = nombre
	stats.max_hp = hp
	stats.max_mp = 10
	stats.attack = 5
	stats.defense = 0
	stats.speed = speed

	var e = BaseEntity.new()
	e.stats = stats
	e.current_hp = hp
	e.current_mp = 10
	return e

func test_cola_rota_al_final():
	var e1 = add_child_autofree(_make_entity("A", 10))
	var e2 = add_child_autofree(_make_entity("B", 5))
	turn_queue.setup_queue([e1, e2] as Array[BaseEntity])

	var t1  = turn_queue.get_next_entity()
	var _t2 = turn_queue.get_next_entity()
	var t3  = turn_queue.get_next_entity()
	assert_eq(t3.stats.character_name, t1.stats.character_name,
		"Tras el ciclo completo debe volver al primero")

func test_entidad_muerta_es_saltada():
	var vivo   = add_child_autofree(_make_entity("Vivo", 10))
	var muerto = add_child_autofree(_make_entity("Muerto", 5))
	turn_queue.setup_queue([vivo, muerto] as Array[BaseEntity])

	muerto.take_damage(9999)

	var t1 = turn_queue.get_next_entity()
	var t2 = turn_queue.get_next_entity()
	assert_eq(t1.stats.character_name, "Vivo", "El primer turno debe ser del vivo")
	assert_eq(t2.stats.character_name, "Vivo", "El muerto debe saltarse siempre")

func test_orden_por_velocidad_con_tres_entidades():
	var rapido = add_child_autofree(_make_entity("Rapido", 30))
	var medio  = add_child_autofree(_make_entity("Medio", 15))
	var lento  = add_child_autofree(_make_entity("Lento", 5))
	# los pasamos en orden incorrecto a propósito
	turn_queue.setup_queue([lento, rapido, medio] as Array[BaseEntity])

	assert_eq(turn_queue.get_next_entity().stats.character_name, "Rapido", "Primero el más rápido")
	assert_eq(turn_queue.get_next_entity().stats.character_name, "Medio",  "Luego el del medio")
	assert_eq(turn_queue.get_next_entity().stats.character_name, "Lento",  "Por último el lento")

func test_un_solo_combatiente_siempre_es_su_turno():
	var solo = add_child_autofree(_make_entity("Solo", 10))
	turn_queue.setup_queue([solo] as Array[BaseEntity])

	for i in 3:
		assert_eq(turn_queue.get_next_entity().stats.character_name, "Solo",
			"Siempre debe tocarle al único combatiente")
