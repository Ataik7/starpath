extends Node2D

@onready var player:     PlayerController = $Player
@onready var pause_menu: PauseMenu        = $PauseMenu

var _debug_label: Label = null

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_F2 and event.pressed:
		if _debug_label == null:
			var layer := CanvasLayer.new()
			layer.layer = 99
			add_child(layer)
			_debug_label = Label.new()
			_debug_label.add_theme_font_size_override("font_size", 16)
			_debug_label.add_theme_color_override("font_color", Color.YELLOW)
			_debug_label.position = Vector2(10, 10)
			layer.add_child(_debug_label)
		else:
			_debug_label.get_parent().queue_free()
			_debug_label = null

func _process(_delta: float) -> void:
	if _debug_label and is_instance_valid(player):
		var p := player.global_position
		_debug_label.text = "Pos: (%.0f, %.0f)" % [p.x, p.y]

func _debug_print_tiles_at(world_pos: Vector2, rows_up: int = 1) -> void:
	var map := get_node_or_null("map1")
	if map == null:
		return
	for child in map.get_children():
		var layer := child as TileMapLayer
		if layer == null:
			continue
		var base_cell: Vector2i = layer.local_to_map(layer.to_local(world_pos))
		for dy in range(-rows_up, 1):
			for dx in range(-1, 2):
				var cell: Vector2i = base_cell + Vector2i(dx, dy)
				var src: int = layer.get_cell_source_id(cell)
				if src == -1:
					continue
				var ac: Vector2i = layer.get_cell_atlas_coords(cell)
				print("LETRERO → capa: %s | celda: %s | atlas: %s" % [layer.name, cell, ac])

# Sistema de seguidores
const _FOLLOW_STEPS : int = 22   # frames de separación entre personajes
const _HISTORY_MAX  : int = 300  # entradas máximas en el historial

const _FOLLOWER_TEX : Dictionary = {
	"athelios": "res://Assets/Characters/Heroes/Athelios.png",
	"byran":    "res://Assets/Characters/Heroes/Byran.png",
}

var _chars_layer  : Node2D = null
var _path_history : Array         = []   # Array de {pos:Vector2, dir:String}
var _followers    : Array         = []   # Array de FollowerController
var _last_party   : Array[String] = []

func _ready() -> void:
	AudioManager.play_bgm("exploration")
	player.menu_requested.connect(pause_menu.toggle)
	_extract_decorative_tiles()
	_elevate_tall_objects()
	_setup_map_layers()   # DESPUÉS de modificar tiles: garantiza z_index correcto
	call_deferred("_setup_rio_layer")
	call_deferred("_setup_camera_limits")
	call_deferred("_setup_character_layer")
	call_deferred("_setup_ysort_board")
	call_deferred("_setup_ysort_telescope")
	if Inventory.returning_from_battle:
		Inventory.returning_from_battle = false
		call_deferred("_restore_pre_battle_state")
	elif SaveManager.has_pending_spawn:
		call_deferred("_restore_saved_position")
	else:
		call_deferred("_trigger_lore_tutorial")

func _restore_pre_battle_state() -> void:
	# Alejarse del enemigo
	var back := Vector2.ZERO
	match Inventory.pre_battle_direction:
		"up":    back = Vector2(  0,  64)
		"down":  back = Vector2(  0, -64)
		"left":  back = Vector2( 64,   0)
		"right": back = Vector2(-64,   0)
	player.global_position = Inventory.pre_battle_position + back
	player._last_dir       = Inventory.pre_battle_direction

	# Si ganamos, eliminar el enemigo del mapa permanentemente
	if Inventory.battle_was_won and Inventory.last_enemy_id != "":
		Inventory.battle_was_won = false
		if Inventory.last_enemy_id not in Inventory.defeated_enemies:
			Inventory.defeated_enemies.append(Inventory.last_enemy_id)
		for child in get_children():
			if child.name == Inventory.last_enemy_id:
				child.queue_free()
				break

func _restore_saved_position() -> void:
	SaveManager.apply_pending_spawn(player)

func _trigger_lore_tutorial() -> void:
	TutorialManager.try_show(
		"lore",
		"STARPATH",
		"En el reino de Aetheria, una oscuridad sin nombre avanza desde las tierras del norte.\n\nLyra, joven maga del pueblo de Valden, recibe una señal del cosmos: las estrellas se apagan una a una.\n\nSolo tú puedes seguir el Camino de las Estrellas y descubrir la verdad antes de que la última luz se extinga.",
		true
	)

func _setup_rio_layer() -> void:
	var map := get_node_or_null("map1")
	if map == null:
		return
	var rio := map.find_child("rio", true, false)
	if rio == null:
		return
	for child in rio.get_children():
		if child is StaticBody2D:
			child.collision_layer = 2

func _setup_map_layers() -> void:
	var map := get_node_or_null("map1")
	if map == null:
		return
	var ground_layers := ["ground", "grass", "water", "water_grass", "farm", "building", "building_up", "farm_up"]
	var object_layers := ["tree"]
	for child in map.get_children():
		if child.name in ground_layers:
			child.z_index       = -10
			child.z_as_relative = false
		elif child.name in object_layers:
			child.z_index       = 10
			child.z_as_relative = false
		# Mueve los tiles de agua a la capa de colisión 2
		# para que BridgeArea pueda ignorarlos cambiando la máscara del jugador
		if child.name == "water" and child is TileMapLayer:
			var ts := child.tile_set.duplicate() as TileSet
			for i in ts.get_physics_layers_count():
				ts.set_physics_layer_collision_layer(i, 2)
			child.tile_set = ts

# Mueve arbustos (40-42), hierbas (48-49) y flores (51-55) de la capa "tree"
# a una nueva capa con z=-5 para que el jugador quede encima.
func _extract_decorative_tiles() -> void:
	var map := get_node_or_null("map1")
	if map == null:
		return

	var tree_layer: TileMapLayer = null
	for child in map.get_children():
		if child.name == "tree" and child is TileMapLayer:
			tree_layer = child
			break
	if tree_layer == null:
		return

	var deco_layer := TileMapLayer.new()
	deco_layer.name          = "deco_layer"
	deco_layer.z_index       = -5
	deco_layer.z_as_relative = false
	deco_layer.tile_set      = tree_layer.tile_set
	map.add_child(deco_layer)

	var deco_atlas_coords := [
		Vector2i(0, 5), Vector2i(1, 5), Vector2i(2, 5),  # arbustos  ID 40-42
		Vector2i(0, 6), Vector2i(1, 6),                   # hierbas   ID 48-49
		Vector2i(3, 6), Vector2i(4, 6), Vector2i(5, 6),  # flores    ID 51-53
		Vector2i(6, 6), Vector2i(7, 6)                    # flores    ID 54-55
	]

	var cells_to_move: Array = []
	for cell in tree_layer.get_used_cells():
		if tree_layer.get_cell_atlas_coords(cell) in deco_atlas_coords:
			cells_to_move.append(cell)

	for cell in cells_to_move:
		var src := tree_layer.get_cell_source_id(cell)
		var alt := tree_layer.get_cell_alternative_tile(cell)
		var ac  := tree_layer.get_cell_atlas_coords(cell)
		deco_layer.set_cell(cell, src, ac, alt)
		tree_layer.erase_cell(cell)

# Separa la capa "tree" en dos partes:
#   • Capa "tree" original (z=10):  conserva las hojas/copa  → tapa al jugador (z=0)
#   • tree_trunk (z=-1):            recibe los troncos       → jugador encima del tronco
# Con y_sort_enabled=false en WorldMap, el z_index es el único criterio de orden,
# así que z=10 > z=0 (jugador) > z=-1 funciona siempre, independientemente de la Y.
func _elevate_tall_objects() -> void:
	var map := get_node_or_null("map1")
	if map == null:
		return

	# Capa "building": antorcha y estatua
	var building_layer: TileMapLayer = null
	for child in map.get_children():
		if child.name == "building" and child is TileMapLayer:
			building_layer = child
			break
	if building_layer != null:
		var tall_layer := TileMapLayer.new()
		tall_layer.name          = "tall_objects"
		tall_layer.z_index       = 10
		tall_layer.z_as_relative = false
		tall_layer.tile_set      = building_layer.tile_set
		map.add_child(tall_layer)

		# Solo la CABEZA/LLAMA va a z=10; las PATAS se quedan en building.
		var tall_coords := [Vector2i(5, 28)]

		var cells_to_move: Array = []
		for cell in building_layer.get_used_cells():
			if building_layer.get_cell_atlas_coords(cell) in tall_coords:
				cells_to_move.append(cell)
		for cell in cells_to_move:
			var src := building_layer.get_cell_source_id(cell)
			var alt := building_layer.get_cell_alternative_tile(cell)
			var ac  := building_layer.get_cell_atlas_coords(cell)
			tall_layer.set_cell(cell, src, ac, alt)
			building_layer.erase_cell(cell)

	# Árboles
	# Separa troncos (atlas.y == 2) a una nueva capa z=-1.
	# Las hojas (atlas.y != 2) se quedan en la capa "tree" original.
	# _setup_map_layers() le asignará z=10 a "tree", que con y_sort=false
	# garantiza que las hojas SIEMPRE queden encima del jugador (z=0).
	var tree_layer2: TileMapLayer = null
	for child in map.get_children():
		if child.name == "tree" and child is TileMapLayer:
			tree_layer2 = child
			break
	if tree_layer2 == null:
		return

	var tree_trunk := TileMapLayer.new()
	tree_trunk.name          = "tree_trunk"
	tree_trunk.z_index       = -1
	tree_trunk.z_as_relative = false
	tree_trunk.tile_set      = tree_layer2.tile_set
	map.add_child(tree_trunk)

	# Mueve a tree_trunk todo lo que NO sea copa (atlas.y 0-1).
	# Copa (atlas.y=0,1) permanece en "tree" (z=10).
	# Troncos, tocones, troncos muertos, troncos caídos (atlas.y>=2) → z=-1.
	var trunk_cells: Array = []
	for cell in tree_layer2.get_used_cells():
		if tree_layer2.get_cell_atlas_coords(cell).y >= 2:
			trunk_cells.append(cell)

	for cell in trunk_cells:
		var src := tree_layer2.get_cell_source_id(cell)
		var alt := tree_layer2.get_cell_alternative_tile(cell)
		var ac  := tree_layer2.get_cell_atlas_coords(cell)
		tree_trunk.set_cell(cell, src, ac, alt)
		tree_layer2.erase_cell(cell)

# Agrupa al jugador y a los CompanionNPCs en un Node2D con y_sort_enabled=true.
# Así el orden de dibujado entre personajes depende de su Y en el mundo, sin
# alterar los z_index de los tilemaps (que usan z_as_relative=false).
func _setup_character_layer() -> void:
	var chars_layer := Node2D.new()
	chars_layer.name          = "CharactersLayer"
	chars_layer.y_sort_enabled = true
	chars_layer.z_index        = 0
	chars_layer.z_as_relative  = false
	add_child(chars_layer)

	# Jugador al contenedor
	player.reparent(chars_layer, true)

	# Compañeros al contenedor
	for child in get_children():
		if child is CompanionNPC:
			child.reparent(chars_layer, true)

	# Conectar señal de grupo
	_chars_layer = chars_layer
	Inventory.changed.connect(func():
		if _last_party.hash() != Inventory.party_members.hash():  # Bug 19: != por referencia siempre era true
			call_deferred("_update_followers")
	)
	call_deferred("_update_followers")

# Seguidores: registrar historial y mover

func _physics_process(_delta: float) -> void:
	if player == null:
		return

	# Solo añadir al historial si el jugador realmente se desplazó.
	# Sin esta comprobación, las entradas prepobladas se sobreescriben mientras
	# el jugador está quieto y todos los seguidores colapsan en su posición.
	var new_pos : Vector2 = player.global_position
	var add_entry := true
	if not _path_history.is_empty():
		var last   : Dictionary = _path_history.back()
		var lpos   : Vector2    = last["pos"] as Vector2
		add_entry = new_pos.distance_squared_to(lpos) > 0.25   # se movió > 0.5 px
	if add_entry:
		_path_history.append({"pos": new_pos, "dir": player._last_dir})
		if _path_history.size() > _HISTORY_MAX:
			_path_history.pop_front()

	# Mover seguidores
	for i in _followers.size():
		var f     : FollowerController = _followers[i]
		if not is_instance_valid(f):
			continue
		var delay : int        = (i + 1) * _FOLLOW_STEPS
		var idx   : int        = max(0, _path_history.size() - 1 - delay)
		var e     : Dictionary = _path_history[idx]
		f.update_from_history(e["pos"] as Vector2, e["dir"] as String)

# Dirección a vector
func _dir_to_vec(dir: String) -> Vector2:
	match dir:
		"up":    return Vector2( 0, -1)
		"down":  return Vector2( 0,  1)
		"left":  return Vector2(-1,  0)
		"right": return Vector2( 1,  0)
	return Vector2(0, 1)

# Sync seguidores con el grupo
func _update_followers() -> void:
	if _chars_layer == null:
		return
	# Sin cambios, salir (Bug 19: usar hash para comparación por contenido)
	if _last_party.hash() == Inventory.party_members.hash():
		return
	_last_party = Inventory.party_members.duplicate()

	# Limpiar seguidores
	for f in _followers:
		if is_instance_valid(f):
			f.queue_free()
	_followers.clear()

	# Prepoblar el historial con una "trayectoria virtual" detrás del jugador.
	# Así cada seguidor empieza ya en su posición correcta, sin apilarse.
	_path_history.clear()
	var dir_vec : Vector2 = _dir_to_vec(player._last_dir)
	var step    : float   = 2.5   # px/frame a velocidad normal (150 px/s a 60 fps)
	for j in _HISTORY_MAX:
		# 0 = más lejos, MAX-1 = más cerca
		var age    : int     = _HISTORY_MAX - 1 - j
		var offset : Vector2 = -dir_vec * step * age
		_path_history.append({"pos": player.global_position + offset,
							  "dir": player._last_dir})

	# Crear seguidores
	var fol_scene := preload("res://Scenes/World/FollowerController.tscn")
	for id in Inventory.party_members:
		if not _FOLLOWER_TEX.has(id):
			continue
		var f        : FollowerController = fol_scene.instantiate()
		var tex_path : String             = _FOLLOWER_TEX[id]
		var tex      : Texture2D          = load(tex_path) as Texture2D
		_chars_layer.add_child(f)
		# Posición inicial
		var delay   : int    = (_followers.size() + 1) * _FOLLOW_STEPS
		var idx     : int    = max(0, _path_history.size() - 1 - delay)
		var e       : Dictionary = _path_history[idx]
		f.global_position = e["pos"] as Vector2
		if tex:
			f.setup_texture(tex)
		_followers.append(f)

# Función genérica de y-sort para tiles de la capa "building".
#
# Agrupa los tiles coincidentes por COLUMNA X del mapa, creando una TileMapLayer
# independiente por cada grupo. Así cada instancia del mismo objeto (aunque estén
# en posiciones Y distintas) obtiene su propio sort anchor correcto:
#   position.y = borde inferior del tile más al sur de esa columna
#
# Resultado: el y_sort de _chars_layer ordena cada personaje contra cada objeto
# de forma completamente independiente y automática.
func _setup_ysort_objects(name_prefix: String, atlas_coords: Array) -> void:
	if _chars_layer == null:
		return
	var map := get_node_or_null("map1") as Node2D
	if map == null:
		return
	var building_layer: TileMapLayer = null
	for child in map.get_children():
		if child.name == "building" and child is TileMapLayer:
			building_layer = child
			break
	if building_layer == null:
		return

	var tile_size := building_layer.tile_set.tile_size

	# Agrupar celdas por columna X de mapa
	var col_groups: Dictionary = {}
	for cell in building_layer.get_used_cells():
		if building_layer.get_cell_atlas_coords(cell) in atlas_coords:
			if not col_groups.has(cell.x):
				col_groups[cell.x] = []
			col_groups[cell.x].append(cell)

	if col_groups.is_empty():
		return

	# Una TileMapLayer por grupo-columna
	var idx := 0
	for col_x: int in col_groups.keys():
		var cells: Array = col_groups[col_x]

		var max_cell_y := -9999
		for c: Vector2i in cells:
			if c.y > max_cell_y:
				max_cell_y = c.y

		var sort_anchor_y : float = building_layer.global_position.y + (max_cell_y + 1) * tile_size.y
		var cell_y_offset : int   = -(max_cell_y + 1)

		var obj_layer := TileMapLayer.new()
		obj_layer.name          = "%s_%d" % [name_prefix, idx]
		obj_layer.tile_set      = building_layer.tile_set
		obj_layer.z_index       = 0
		obj_layer.z_as_relative = true
		_chars_layer.add_child(obj_layer)
		obj_layer.global_position = Vector2(building_layer.global_position.x, sort_anchor_y)

		for cell: Vector2i in cells:
			var src := building_layer.get_cell_source_id(cell)
			var alt := building_layer.get_cell_alternative_tile(cell)
			var ac  := building_layer.get_cell_atlas_coords(cell)
			obj_layer.set_cell(Vector2i(cell.x, cell.y + cell_y_offset), src, ac, alt)
			building_layer.erase_cell(cell)

		idx += 1


# Tablón de anuncios — atlas columnas 6-7, filas 28-29
func _setup_ysort_board() -> void:
	_setup_ysort_objects("ysort_board", [
		Vector2i(6, 28), Vector2i(7, 28),
		Vector2i(6, 29), Vector2i(7, 29)
	])


# Telescopio/trípode — atlas(3, 113) parte superior, atlas(3, 114) base.
# Hay dos instancias en el mapa; se genera una capa independiente por cada una.
func _setup_ysort_telescope() -> void:
	_setup_ysort_objects("ysort_telescope", [
		Vector2i(3, 113),
		Vector2i(3, 114)
	])


func _setup_camera_limits() -> void:
	var map := get_node_or_null("map1")
	if map == null:
		return
	# Límites del mapa
	var ref_layer: TileMapLayer = null
	for child in map.get_children():
		if child is TileMapLayer and child.name == "ground":
			ref_layer = child
			break
	if ref_layer == null:
		return

	var rect      := ref_layer.get_used_rect()           # en coordenadas de tile
	var tile_size := ref_layer.tile_set.tile_size         # px por tile (ej. Vector2i(32,32))
	var origin: Vector2 = (map as Node2D).global_position

	var cam := player.get_node_or_null("Camera2D") as Camera2D
	if cam == null:
		return

	cam.limit_left   = int(origin.x + rect.position.x * tile_size.x)
	cam.limit_top    = int(origin.y + rect.position.y * tile_size.y)
	cam.limit_right  = int(origin.x + (rect.position.x + rect.size.x) * tile_size.x)
	cam.limit_bottom = int(origin.y + (rect.position.y + rect.size.y) * tile_size.y)
