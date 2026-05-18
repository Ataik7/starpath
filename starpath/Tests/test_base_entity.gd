extends GutTest

# Pruebas de la entidad base del combate

func _make_entity(hp: int, mp: int, defense: int) -> BaseEntity:
	var stats = CharacterStats.new()
	stats.character_name = "TestEntity"
	stats.max_hp = hp
	stats.max_mp = mp
	stats.attack = 10
	stats.defense = defense
	stats.speed = 10

	var e = BaseEntity.new()
	e.stats = stats
	e.current_hp = hp
	e.current_mp = mp
	return e


func test_dano_fisico_reduce_hp():
	var e = add_child_autofree(_make_entity(50, 20, 0))
	e.take_damage(15)
	assert_lt(e.current_hp, 50, "El HP debe bajar tras recibir daño físico")

func test_defensa_mitiga_dano_fisico():
	var e = add_child_autofree(_make_entity(50, 20, 10))
	e.take_damage(10)
	# defensa 10 → daño efectivo max(1, 10 - 5) = 5 → HP queda en 45
	assert_eq(e.current_hp, 45, "La defensa debe reducir el daño físico")

func test_dano_magico_ignora_defensa():
	var con_def = add_child_autofree(_make_entity(50, 20, 20))
	var sin_def = add_child_autofree(_make_entity(50, 20, 0))
	con_def.take_damage(10, true)
	sin_def.take_damage(10, true)
	assert_eq(con_def.current_hp, sin_def.current_hp,
		"El daño mágico no debe verse afectado por la defensa")

func test_hp_no_baja_de_cero():
	var e = add_child_autofree(_make_entity(10, 10, 0))
	e.take_damage(9999)
	assert_eq(e.current_hp, 0, "El HP no puede quedar negativo")

func test_dano_minimo_es_uno():
	var e = add_child_autofree(_make_entity(50, 20, 999))
	var antes = e.current_hp
	e.take_damage(1)
	assert_eq(e.current_hp, antes - 1, "Siempre debe hacerse al menos 1 de daño")

func test_defender_reduce_dano_a_la_mitad():
	var e = add_child_autofree(_make_entity(50, 20, 0))
	e.is_defending = true
	e.take_damage(20)
	assert_eq(e.current_hp, 40, "Defender debe reducir el daño a la mitad")

func test_defender_se_desactiva_tras_recibir_golpe():
	var e = add_child_autofree(_make_entity(50, 20, 0))
	e.is_defending = true
	e.take_damage(5)
	assert_false(e.is_defending, "La guardia debe caer tras recibir el golpe")

func test_heal_hp_recupera_vida():
	var e = add_child_autofree(_make_entity(50, 20, 0))
	e.current_hp = 10
	e.heal_hp(20)
	assert_eq(e.current_hp, 30, "heal_hp debe sumar los puntos indicados")

func test_heal_hp_no_supera_maximo():
	var e = add_child_autofree(_make_entity(50, 20, 0))
	e.current_hp = 45
	e.heal_hp(999)
	assert_eq(e.current_hp, 50, "No se puede curar por encima del máximo")

func test_heal_mp_recupera_mana():
	var e = add_child_autofree(_make_entity(50, 20, 0))
	e.current_mp = 5
	e.heal_mp(10)
	assert_eq(e.current_mp, 15, "heal_mp debe sumar el mana indicado")

func test_heal_mp_no_supera_maximo():
	var e = add_child_autofree(_make_entity(50, 20, 0))
	e.current_mp = 18
	e.heal_mp(999)
	assert_eq(e.current_mp, 20, "El MP no puede superar el máximo")

func test_spend_mp_descuenta_correctamente():
	var e = add_child_autofree(_make_entity(50, 20, 0))
	var ok = e.spend_mp(10)
	assert_true(ok, "Debe devolver true si hay MP suficiente")
	assert_eq(e.current_mp, 10, "El MP debe bajar la cantidad gastada")

func test_spend_mp_falla_sin_mp():
	var e = add_child_autofree(_make_entity(50, 5, 0))
	var ok = e.spend_mp(10)
	assert_false(ok, "Debe devolver false si no hay MP suficiente")
	assert_eq(e.current_mp, 5, "El MP no debe cambiar si no hay suficiente")
