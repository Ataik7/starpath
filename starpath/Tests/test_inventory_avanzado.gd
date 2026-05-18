extends GutTest

# Tests avanzados del sistema de progresión del Inventario

func before_each():
	# Estado limpio antes de cada test
	Inventory.current_level = 1
	Inventory.current_xp    = 0
	Inventory.gold          = 0

func test_xp_se_acumula():
	Inventory.add_xp(50)
	assert_eq(Inventory.current_xp, 50, "La XP debe acumularse correctamente")

func test_xp_sube_nivel_al_llegar_al_umbral():
	# Con nivel 1, necesita 100 XP para subir
	Inventory.add_xp(100)
	assert_eq(Inventory.current_level, 2, "Debe subir a nivel 2 al alcanzar 100 XP")

func test_xp_sobrante_se_conserva():
	# Si se gana más XP de la necesaria, el sobrante pasa al siguiente nivel
	Inventory.add_xp(150)
	assert_eq(Inventory.current_xp, 50, "La XP sobrante debe conservarse tras subir de nivel")

func test_subida_multiple_de_nivel():
	# Nivel 1→2 cuesta 100 XP, nivel 2→3 cuesta 200 XP → total 300 XP para llegar a nivel 3
	Inventory.add_xp(300)
	assert_eq(Inventory.current_level, 3, "Debe subir dos niveles con 300 XP desde nivel 1")

func test_max_hp_aumenta_al_subir_nivel():
	var hp_nivel1 = Inventory.get_max_hp()
	Inventory.add_xp(100)  # sube a nivel 2
	var hp_nivel2 = Inventory.get_max_hp()
	assert_gt(hp_nivel2, hp_nivel1, "El HP máximo debe aumentar al subir de nivel")

func test_xp_to_next_crece_con_nivel():
	var umbral_nivel1 = Inventory.xp_to_next()
	Inventory.current_level = 2
	var umbral_nivel2 = Inventory.xp_to_next()
	assert_gt(umbral_nivel2, umbral_nivel1, "El umbral de XP debe crecer con el nivel")

func test_gold_no_cambia_al_ganar_xp():
	Inventory.gold = 200
	Inventory.add_xp(50)
	assert_eq(Inventory.gold, 200, "El oro no debe cambiar al ganar XP")

func test_companion_xp_independiente_del_heroe():
	Inventory.add_xp(50)
	Inventory.add_companion_xp("athelios", 30)
	assert_eq(Inventory.current_xp, 50, "La XP del héroe no debe verse afectada por la del compañero")
	assert_eq(Inventory.get_companion_xp("athelios"), 30, "La XP del compañero debe guardarse aparte")

func test_companion_sube_de_nivel():
	Inventory.add_companion_xp("byran", 100)
	assert_eq(Inventory.get_companion_level("byran"), 2,
		"El compañero debe subir a nivel 2 con 100 XP")

func test_bonus_ataque_por_nivel():
	Inventory.current_level = 1
	var bonus_nivel1 = Inventory.get_level_atk_bonus()
	Inventory.current_level = 3
	var bonus_nivel3 = Inventory.get_level_atk_bonus()
	assert_gt(bonus_nivel3, bonus_nivel1,
		"El bonus de ataque debe crecer con el nivel")
