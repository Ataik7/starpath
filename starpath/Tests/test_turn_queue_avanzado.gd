extends GutTest

# Tests avanzados de TurnQueue

var turn_queue: TurnQueue

func before_each():
	turn_queue = TurnQueue.new()
	add_child(turn_queue)

func after_each():
	turn_queue.queue_free()

func _make_entity(nombre: String, speed: int, hp: int = 30) -> BaseEntity:
	var stats            = CharacterStats.new()
	stats.character_name = nombre
	stats.max_hp         = hp
	stats.max_mp         = 10
	stats.attack         = 5
	stats.defense        = 0
	stats.speed          = speed

	var entity        = BaseEntity.new()
	entity.stats      = stats
	entity.current_hp = hp
	entity.current_mp = 10
	return entity


func test_cola_rota_al_final():
	var e1 = _make_entity("A", 10)
	var e2 = _make_entity("B", 5)
	add_child(e1)
	add_child(e2)

	var combatants: Array[BaseEntity] = [e1, e2]
	turn_queue.setup_queue(combatants)

	# Primer ciclo completo: A → B
	var t1 = turn_queue.get_next_entity()
	var t2 = turn_queue.get_next_entity()
	# Segundo ciclo: debe volver a A
	var t3 = turn_queue.get_next_entity()
	assert_eq(t3.stats.character_name, t1.stats.character_name,
		"La cola debe rotar y volver al primer combatiente")
	e1.queue_free()
	e2.queue_free()

func test_entidad_muerta_es_saltada():
	var vivo   = _make_entity("Vivo",   10)
	var muerto = _make_entity("Muerto", 5)
	add_child(vivo)
	add_child(muerto)

	var combatants: Array[BaseEntity] = [vivo, muerto]
	turn_queue.setup_queue(combatants)

	# Matar al segundo
	muerto.take_damage(9999)
	assert_false(muerto.is_alive, "El enemigo debe estar muerto")

	# Ambos turnos deben ser del vivo
	var t1 = turn_queue.get_next_entity()
	var t2 = turn_queue.get_next_entity()
	assert_eq(t1.stats.character_name, "Vivo", "El primer turno debe ser del vivo")
	assert_eq(t2.stats.character_name, "Vivo", "El segundo turno también debe ser del vivo")
	vivo.queue_free()
	muerto.queue_free()

func test_orden_por_velocidad_con_tres_entidades():
	var rapido = _make_entity("Rapido", 30)
	var medio  = _make_entity("Medio",  15)
	var lento  = _make_entity("Lento",  5)
	add_child(rapido)
	add_child(medio)
	add_child(lento)

	# Pasamos en orden aleatorio al setup
	var combatants: Array[BaseEntity] = [lento, rapido, medio]
	turn_queue.setup_queue(combatants)

	var t1 = turn_queue.get_next_entity()
	var t2 = turn_queue.get_next_entity()
	var t3 = turn_queue.get_next_entity()
	assert_eq(t1.stats.character_name, "Rapido", "El más rápido va primero")
	assert_eq(t2.stats.character_name, "Medio",  "El segundo va en medio")
	assert_eq(t3.stats.character_name, "Lento",  "El más lento va último")
	rapido.queue_free()
	medio.queue_free()
	lento.queue_free()

func test_un_solo_combatiente_siempre_es_su_turno():
	var solo = _make_entity("Solo", 10)
	add_child(solo)

	var combatants: Array[BaseEntity] = [solo]
	turn_queue.setup_queue(combatants)

	for i in 3:
		var t = turn_queue.get_next_entity()
		assert_eq(t.stats.character_name, "Solo",
			"Con un único combatiente, siempre debe ser su turno")
	solo.queue_free()
