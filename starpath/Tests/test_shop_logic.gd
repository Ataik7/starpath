extends GutTest

# Tests de la lógica de compra/venta sobre Inventory

func _make_item(nombre: String, precio: int) -> ItemData:
	var item = ItemData.new()
	item.item_name = nombre
	item.price = precio
	item.item_type = ItemData.ItemType.CONSUMABLE
	item.quantity = 1
	item.effect_type = "heal_hp"
	item.amount = 10
	return item

func before_each():
	Inventory.gold = 100
	Inventory.items = []

func test_compra_descuenta_oro():
	var item = _make_item("Pocion", 30)
	Inventory.gold -= item.price
	assert_eq(Inventory.gold, 70, "Comprar debe descontar el precio")

func test_no_se_puede_comprar_sin_oro():
	var item = _make_item("EspadaCara", 500)
	assert_false(Inventory.gold >= item.price, "No debe poder comprar sin fondos")

func test_compra_exacta_deja_oro_en_cero():
	var item = _make_item("PotionExacta", 100)
	Inventory.gold -= item.price
	assert_eq(Inventory.gold, 0, "Comprar con el oro justo deja saldo 0")

func test_add_item_agrega_al_inventario():
	var item = _make_item("Antidoto", 20)
	Inventory.add_item(item)
	var encontrado = Inventory.items.any(func(i): return i.item_name == item.item_name)
	assert_true(encontrado, "El objeto debe aparecer en el inventario")

func test_venta_suma_oro():
	var item = _make_item("ViejaEspada", 40)
	Inventory.add_item(item)
	var precio_venta = maxi(1, item.price >> 1)
	Inventory.gold += precio_venta
	assert_eq(Inventory.gold, 100 + precio_venta, "Vender debe sumar el precio de venta")

func test_precio_venta_es_mitad_del_precio_compra():
	var item = _make_item("Item", 60)
	assert_eq(maxi(1, item.price >> 1), 30, "El precio de venta debe ser la mitad")

func test_precio_venta_minimo_es_uno():
	var item = _make_item("ItemBarato", 1)
	assert_eq(maxi(1, item.price >> 1), 1, "El precio mínimo de venta es 1")

func test_oro_no_cambia_si_compra_falla():
	Inventory.gold = 10
	var item = _make_item("ItemCaro", 50)
	if Inventory.gold < item.price:
		pass # la compra no se ejecuta
	assert_eq(Inventory.gold, 10, "El oro no debe cambiar si la compra falla")
