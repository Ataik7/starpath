extends GutTest

# Tests básicos de la cola de turnos

var turn_queue: TurnQueue

func before_each():
	turn_queue = autofree(TurnQueue.new())
	add_child(turn_queue)

func _make_entity(nombre: String, speed: int) -> BaseEntity:
	var stats = CharacterStats.new()
	stats.character_name = nombre
	stats.max_hp = 30
	stats.max_mp = 10
	stats.attack = 5
	stats.defense = 3
	stats.speed = speed

	var e = BaseEntity.new()
	e.stats = stats
	e.current_hp = 30
	e.current_mp = 10
	return e

func test_cola_vacia_al_inicio():
	assert_eq(turn_queue.queue.size(), 0, "La cola empieza vacía")

func test_setup_llena_la_cola():
	var e1 = add_child_autofree(_make_entity("Rapido", 20))
	var e2 = add_child_autofree(_make_entity("Lento", 5))
	turn_queue.setup_queue([e1, e2] as Array[BaseEntity])
	assert_eq(turn_queue.queue.size(), 2, "Deben quedar 2 combatientes en la cola")

func test_mas_rapido_va_primero():
	var rapido = add_child_autofree(_make_entity("Rapido", 20))
	var lento = add_child_autofree(_make_entity("Lento", 5))
	turn_queue.setup_queue([lento, rapido] as Array[BaseEntity])
	var primero = turn_queue.get_next_entity()
	assert_eq(primero.stats.character_name, "Rapido", "El más rápido va primero")

func test_turno_avanza_al_siguiente():
	var e1 = add_child_autofree(_make_entity("A", 15))
	var e2 = add_child_autofree(_make_entity("B", 10))
	turn_queue.setup_queue([e1, e2] as Array[BaseEntity])
	var t1 = turn_queue.get_next_entity()
	var t2 = turn_queue.get_next_entity()
	assert_ne(t1.stats.character_name, t2.stats.character_name, "El turno debe cambiar de personaje")
