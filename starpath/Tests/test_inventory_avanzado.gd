extends GutTest

# Tests del sistema de progresión: XP, niveles y compañeros

func before_each():
	Inventory.current_level = 1
	Inventory.current_xp = 0
	Inventory.gold = 0

func test_xp_se_acumula():
	Inventory.add_xp(50)
	assert_eq(Inventory.current_xp, 50, "La XP debe acumularse")

func test_xp_sube_nivel_al_llegar_al_umbral():
	Inventory.add_xp(100)
	assert_eq(Inventory.current_level, 2, "Debe subir a nivel 2 con 100 XP")

func test_xp_sobrante_se_conserva():
	Inventory.add_xp(150)
	# sube a nivel 2 y le sobran 50
	assert_eq(Inventory.current_xp, 50, "La XP sobrante debe conservarse")

func test_subida_multiple_de_nivel():
	# nivel 1→2 cuesta 100, nivel 2→3 cuesta 200, total 300
	Inventory.add_xp(300)
	assert_eq(Inventory.current_level, 3, "Con 300 XP debe llegar a nivel 3")

func test_max_hp_aumenta_al_subir_nivel():
	var hp_antes = Inventory.get_max_hp()
	Inventory.add_xp(100)
	assert_gt(Inventory.get_max_hp(), hp_antes, "El HP máximo debe crecer con el nivel")

func test_xp_to_next_crece_con_nivel():
	var umbral1 = Inventory.xp_to_next()
	Inventory.current_level = 2
	assert_gt(Inventory.xp_to_next(), umbral1, "El umbral de XP debe aumentar con el nivel")

func test_gold_no_cambia_al_ganar_xp():
	Inventory.gold = 200
	Inventory.add_xp(50)
	assert_eq(Inventory.gold, 200, "El oro no debe verse afectado al ganar XP")

func test_companion_xp_independiente_del_heroe():
	Inventory.add_xp(50)
	Inventory.add_companion_xp("athelios", 30)
	assert_eq(Inventory.current_xp, 50, "La XP del héroe no debe cambiar")
	assert_eq(Inventory.get_companion_xp("athelios"), 30, "La XP del compañero se guarda aparte")

func test_companion_sube_de_nivel():
	Inventory.add_companion_xp("byran", 100)
	assert_eq(Inventory.get_companion_level("byran"), 2, "El compañero debe subir de nivel")

func test_bonus_ataque_por_nivel():
	Inventory.current_level = 1
	var b1 = Inventory.get_level_atk_bonus()
	Inventory.current_level = 3
	assert_gt(Inventory.get_level_atk_bonus(), b1, "El bonus de ataque debe crecer con el nivel")
