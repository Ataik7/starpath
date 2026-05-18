extends GutTest

# Tests básicos del Autoload Inventory

func before_each():
	Inventory.gold = 0
	Inventory.current_level = 1

func test_gold_empieza_en_cero():
	assert_eq(Inventory.gold, 0, "El oro inicial debe ser 0")

func test_sumar_oro():
	Inventory.gold += 100
	assert_eq(Inventory.gold, 100, "Debe acumular 100 de oro")

func test_nivel_inicial_es_uno():
	assert_eq(Inventory.current_level, 1, "El nivel inicial debe ser 1")

func test_max_hp_mayor_que_cero():
	var hp = Inventory.get_max_hp()
	assert_gt(hp, 0, "El HP máximo debe ser positivo")

func test_max_hp_crece_con_nivel():
	var hp1 = Inventory.get_max_hp()
	Inventory.current_level = 2
	var hp2 = Inventory.get_max_hp()
	assert_gt(hp2, hp1, "El HP máximo debe crecer al subir de nivel")

func test_bonus_ataque_no_negativo():
	var bonus = Inventory.get_attack_bonus()
	assert_gte(bonus, 0, "El bonus de ataque no puede ser negativo")

func test_bonus_defensa_no_negativo():
	var bonus = Inventory.get_defense_bonus()
	assert_gte(bonus, 0, "El bonus de defensa no puede ser negativo")

func test_hp_actual_no_supera_maximo():
	Inventory.current_hp = Inventory.get_max_hp()
	assert_lte(Inventory.current_hp, Inventory.get_max_hp(), "El HP no puede superar el máximo")
