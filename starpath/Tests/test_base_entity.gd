extends GutTest

# Tests de BaseEntity: daño, defensa, curación y MP

func _make_entity(hp: int, mp: int, defense: int) -> BaseEntity:
	var stats            = CharacterStats.new()
	stats.character_name = "TestEntity"
	stats.max_hp         = hp
	stats.max_mp         = mp
	stats.attack         = 10
	stats.defense        = defense
	stats.speed          = 10

	var entity        = BaseEntity.new()
	entity.stats      = stats
	entity.current_hp = hp
	entity.current_mp = mp
	return entity


# — Daño —

func test_dano_fisico_reduce_hp():
	var e = _make_entity(50, 20, 0)
	add_child(e)
	e.take_damage(15)
	assert_lt(e.current_hp, 50, "El HP debe bajar tras recibir daño físico")
	e.queue_free()

func test_defensa_mitiga_dano_fisico():
	var e = _make_entity(50, 20, 10)
	add_child(e)
	e.take_damage(10)
	# Con 10 de defensa, el daño efectivo es max(1, 10 - 5) = 5
	assert_eq(e.current_hp, 45, "La defensa debe reducir el daño físico a la mitad")
	e.queue_free()

func test_dano_magico_ignora_defensa():
	var e_con_defensa    = _make_entity(50, 20, 20)
	var e_sin_defensa    = _make_entity(50, 20, 0)
	add_child(e_con_defensa)
	add_child(e_sin_defensa)
	e_con_defensa.take_damage(10, true)
	e_sin_defensa.take_damage(10, true)
	assert_eq(e_con_defensa.current_hp, e_sin_defensa.current_hp,
		"El daño mágico debe ser igual independientemente de la defensa")
	e_con_defensa.queue_free()
	e_sin_defensa.queue_free()

func test_hp_no_baja_de_cero():
	var e = _make_entity(10, 10, 0)
	add_child(e)
	e.take_damage(9999)
	assert_eq(e.current_hp, 0, "El HP no puede bajar de 0")
	e.queue_free()

func test_dano_minimo_es_uno():
	var e = _make_entity(50, 20, 999)
	add_child(e)
	var hp_antes = e.current_hp
	e.take_damage(1)
	assert_eq(e.current_hp, hp_antes - 1, "El daño mínimo siempre debe ser 1")
	e.queue_free()


# — Defender —

func test_defender_reduce_dano_a_la_mitad():
	var e = _make_entity(50, 20, 0)
	add_child(e)
	e.is_defending = true
	e.take_damage(20)
	# Con defensa 0 y defendiendo: max(1, 20 >> 1) = 10
	assert_eq(e.current_hp, 40, "Defender debe reducir el daño efectivo a la mitad")
	e.queue_free()

func test_defender_se_desactiva_tras_recibir_golpe():
	var e = _make_entity(50, 20, 0)
	add_child(e)
	e.is_defending = true
	e.take_damage(5)
	assert_false(e.is_defending, "El estado de defensa debe desactivarse tras recibir un golpe")
	e.queue_free()


# — Curación —

func test_heal_hp_recupera_vida():
	var e = _make_entity(50, 20, 0)
	add_child(e)
	e.current_hp = 10
	e.heal_hp(20)
	assert_eq(e.current_hp, 30, "heal_hp debe recuperar la cantidad indicada")
	e.queue_free()

func test_heal_hp_no_supera_maximo():
	var e = _make_entity(50, 20, 0)
	add_child(e)
	e.current_hp = 45
	e.heal_hp(999)
	assert_eq(e.current_hp, 50, "El HP curado no puede superar el máximo")
	e.queue_free()

func test_heal_mp_recupera_mana():
	var e = _make_entity(50, 20, 0)
	add_child(e)
	e.current_mp = 5
	e.heal_mp(10)
	assert_eq(e.current_mp, 15, "heal_mp debe recuperar el mana indicado")
	e.queue_free()

func test_heal_mp_no_supera_maximo():
	var e = _make_entity(50, 20, 0)
	add_child(e)
	e.current_mp = 18
	e.heal_mp(999)
	assert_eq(e.current_mp, 20, "El MP curado no puede superar el máximo")
	e.queue_free()


# — MP —

func test_spend_mp_descuenta_correctamente():
	var e = _make_entity(50, 20, 0)
	add_child(e)
	var resultado = e.spend_mp(10)
	assert_true(resultado, "spend_mp debe devolver true si hay MP suficiente")
	assert_eq(e.current_mp, 10, "El MP debe bajar tras gastar")
	e.queue_free()

func test_spend_mp_falla_sin_mp():
	var e = _make_entity(50, 5, 0)
	add_child(e)
	var resultado = e.spend_mp(10)
	assert_false(resultado, "spend_mp debe devolver false si no hay MP suficiente")
	assert_eq(e.current_mp, 5, "El MP no debe cambiar si el gasto falla")
	e.queue_free()
