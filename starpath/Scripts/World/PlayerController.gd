class_name PlayerController
extends CharacterBody2D

signal interaction_requested
signal menu_requested

@export var speed: float = 150.0

@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D

var _last_dir: String = "down"
var _tutorial_moved: bool = false

const SPRITE_PATH := "res://Assets/Characters/Heroes/Lyra.png"

func _ready() -> void:
	add_to_group("player")
	var sprite_texture := load(SPRITE_PATH) as Texture2D
	if sprite_texture:
		_setup_animations(sprite_texture)
	else:
		push_error("PlayerController: no se encontró " + SPRITE_PATH)

# Construye todas las animaciones desde el spritesheet en código
# Layout Pipoya 32x32:  fila 0 = abajo │ fila 1 = izquierda │ fila 2 = derecha │ fila 3 = arriba
func _setup_animations(sprite_texture: Texture2D) -> void:
	var frames := SpriteFrames.new()
	var dirs: Array[String] = ["down", "left", "right", "up"]

	for i in dirs.size():
		var row: int = i

		# Caminar
		var walk := "walk_" + dirs[i]
		frames.add_animation(walk)
		frames.set_animation_speed(walk, 8.0)
		frames.set_animation_loop(walk, true)
		for col in 3:
			var atlas       := AtlasTexture.new()
			atlas.atlas      = sprite_texture
			atlas.region     = Rect2(col * 32, row * 32, 32, 32)
			frames.add_frame(walk, atlas)

		# Idle
		var idle := "idle_" + dirs[i]
		frames.add_animation(idle)
		frames.set_animation_speed(idle, 1.0)
		frames.set_animation_loop(idle, false)
		var idle_atlas       := AtlasTexture.new()
		idle_atlas.atlas      = sprite_texture
		idle_atlas.region     = Rect2(32, row * 32, 32, 32)  # columna 1 = pose central
		frames.add_frame(idle, idle_atlas)

	anim_sprite.sprite_frames = frames
	# Sube el sprite 16 px para que el origen del CharacterBody2D quede en los pies.
	# Así el punto de comparación del Y-sort es la base del personaje, no su centro.
	anim_sprite.offset = Vector2(0, -16)
	anim_sprite.play("idle_down")

# Movimiento y animación

func _physics_process(_delta: float) -> void:
	# Bloquear si hay menú
	if DialogManager.is_open or ShopManager.is_open:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# Tutorial movimiento
	if not _tutorial_moved and velocity != Vector2.ZERO:
		_tutorial_moved = true
		TutorialManager.try_show(
			"movement",
			"Controles",
			"W  A  S  D   Moverse por el mundo\n\nE   Interactuar con personajes y objetos\n\nX   Abrir el menú del juego (equipamiento, guardar...)",
			false
		)

	var dir := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	).normalized()

	velocity = dir * speed
	move_and_slide()
	_update_animation(dir)

func _update_animation(dir: Vector2) -> void:
	if dir == Vector2.ZERO:
		var idle_anim := "idle_" + _last_dir
		if anim_sprite.animation != idle_anim:
			anim_sprite.play(idle_anim)
		return

	if abs(dir.y) >= abs(dir.x):
		_last_dir = "down" if dir.y > 0 else "up"
	else:
		_last_dir = "right" if dir.x > 0 else "left"

	var walk_anim := "walk_" + _last_dir
	if anim_sprite.animation != walk_anim:
		anim_sprite.play(walk_anim)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		interaction_requested.emit()
	if event is InputEventKey and event.pressed and not event.echo:
		if event.is_action_pressed("open_menu"):
			menu_requested.emit()
		if event.keycode == KEY_F1:
			print("─── DEBUG F1 ───")
			print("  player.global_position = ", global_position)
			var world_map := get_parent()
			var lower : TileMapLayer = world_map.get_node_or_null("tree_lower")
			if lower != null:
				var cell := lower.local_to_map(lower.to_local(global_position))
				var src_id := lower.get_cell_source_id(cell)
				print("  tree_lower cell       = ", cell)
				if src_id != -1:
					var ac  := lower.get_cell_atlas_coords(cell)
					var ts  := lower.tile_set
					if ts != null and ts.get_source(src_id) is TileSetAtlasSource:
						var atlas := ts.get_source(src_id) as TileSetAtlasSource
						var td    := atlas.get_tile_data(ac, 0)
						print("  atlas_coords          = ", ac)
						print("  tile_data.y_sort_origin = ", str(td.y_sort_origin) if td != null else "N/A")
						print("  tile world Y (top)    = ", lower.map_to_local(cell).y + lower.global_position.y)
						print("  comparison Y          = ", lower.map_to_local(cell).y + lower.global_position.y + (td.y_sort_origin if td != null else 0))
				else:
					print("  (ningún tile de tree_lower en esta celda)")
			else:
				print("  tree_lower no encontrado")
