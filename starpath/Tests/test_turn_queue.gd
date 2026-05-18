extends GutTest

# Tests de la cola de turnos (TurnQueue)

var turn_queue: TurnQueue

func before_each():
	turn_queue = TurnQueue.new()
	add_child(turn_queue)

func after_each():
	turn_queue.queue_free()

func _make_entity(nombre: String, speed: int) -> BaseEntity:
	var stats            = CharacterStats.new()
	stats.character_name = nombre
	stats.max_hp         = 30
	stats.max_mp         = 10
	stats.attack         = 5
	stats.defense        = 3
	stats.speed          = speed

	var entity           = BaseEntity.new()
	entity.stats         = stats
	entity.current_hp    = 30
	entity.current_mp    = 10
	return entity

func test_cola_vacia_al_inicio():
	assert_eq(turn_queue.queue.size(), 0, "La cola debe estar vacía al inicio")

func test_setup_llena_la_cola():
	var e1 = _make_entity("Rápido", 20)
	var e2 = _make_entity("Lento",  5)
	add_child(e1)
	add_child(e2)

	var combatants: Array[BaseEntity] = [e1, e2]
	turn_queue.setup_queue(combatants)

	assert_eq(turn_queue.queue.size(), 2, "La cola debe tener 2 combatientes")
	e1.queue_free()
	e2.queue_free()

func test_mas_rapido_va_primero():
	var rapido = _make_entity("Rápido", 20)
	var lento  = _make_entity("Lento",  5)
	add_child(rapido)
	add_child(lento)

	var combatants: Array[BaseEntity] = [lento, rapido]
	turn_queue.setup_queue(combatants)

	var primero = turn_queue.get_next_entity()
	assert_eq(primero.stats.character_name, "Rápido",
		"El personaje más rápido debe ir primero")

	rapido.queue_free()
	lento.queue_free()

func test_turno_avanza_al_siguiente():
	var e1 = _make_entity("A", 15)
	var e2 = _make_entity("B", 10)
	add_child(e1)
	add_child(e2)

	var combatants: Array[BaseEntity] = [e1, e2]
	turn_queue.setup_queue(combatants)

	var primero  = turn_queue.get_next_entity()
	var segundo  = turn_queue.get_next_entity()
	assert_ne(primero.stats.character_name, segundo.stats.character_name,
		"El segundo turno debe ser de un personaje diferente")

	e1.queue_free()
	e2.queue_free()
