class_name EnemyWalker
extends CharacterBody2D

# Enemigo deambulante del mapa del mundo.
##
# Uso:
#   1. Instancia Scenes/World/EnemyWalker.tscn en WorldMap.
#   2. (Opcional) Asigna enemy_texture en el Inspector para cambiar el sprite.
#   3. Ajusta speed y wander_radius según el enemigo.

# Exportables
@export var speed:         float      = 55.0
@export var wander_radius: float      = 180.0
@export var enemy_texture: Texture2D  = null
# Escenas que se cargarán en batalla (1 o 2 entradas).
# Vacío = usa los esqueletos por defecto.
@export var battle_scenes: Array[String] = []

# Constantes
const _DEFAULT_TEX  := "res://Assets/Characters/Enemies/Skeleton.png"
const BATTLE_SCENE  := "res://Scenes/Battle/BattleScene.tscn"

# Nodos hijos
@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _detect: Area2D           = $DetectionArea

# Estado
var _spawn:        Vector2 = Vector2.ZERO
var _dir:          Vector2 = Vector2.ZERO
var _last_dir:     String  = "down"
var _move_timer:   float   = 0.0
var _wait_timer:   float   = 0.0
var _waiting:      bool    = false
var _in_battle:    bool    = false
var _freeze_timer: float   = 0.0
var _stuck_frames: int     = 0


# Inicialización

func _ready() -> void:
	if name in Inventory.defeated_enemies:
		queue_free()
		return
	_spawn = global_position
	add_to_group("enemy_walkers")

	# Si el jugador huyó de este enemigo, quedarse quieto unos segundos
	# y deshabilitar la detección para que no reinicie la batalla al instante
	if Inventory.battle_was_fled and Inventory.last_enemy_id == name:
		Inventory.battle_was_fled = false
		_freeze_timer = 4.0
		_detect.set_deferred("monitoring", false)

	# Sprite
	var tex: Texture2D = enemy_texture
	if tex == null:
		tex = load(_DEFAULT_TEX)

	if tex:
		_setup_animations(tex)

	_detect.body_entered.connect(_on_player_detected)
	_pick_dir()


func _setup_animations(tex: Texture2D) -> void:
	var frames := SpriteFrames.new()

	# Fila del spritesheet para cada dirección.
	# Si el sprite tiene 4 filas (down/left/right/up) se usa el índice real;
	# si solo tiene 3 (down/left/right), "up" reutiliza la fila 2 (right).
	var img := tex.get_image() if tex.has_method("get_image") else null
	var rows: int = 4
	if img != null:
		rows = img.get_height() / 32 as int
	var dir_rows := {
		"down":  0,
		"left":  1,
		"right": 2,
		"up":    3 if rows >= 4 else 0,   # reutiliza "down" si no hay fila arriba
	}

	for dir: String in ["down", "left", "right", "up"]:
		var row: int = dir_rows[dir]

		# Caminar (3 frames)
		var walk: String = "walk_" + dir
		frames.add_animation(walk)
		frames.set_animation_speed(walk, 6.0)
		frames.set_animation_loop(walk, true)
		for col in 3:
			var a := AtlasTexture.new()
			a.atlas  = tex
			a.region = Rect2(col * 32, row * 32, 32, 32)
			frames.add_frame(walk, a)

		# Idle (frame central)
		var idle: String = "idle_" + dir
		frames.add_animation(idle)
		frames.set_animation_speed(idle, 1.0)
		frames.set_animation_loop(idle, false)
		var ai := AtlasTexture.new()
		ai.atlas  = tex
		ai.region = Rect2(32, row * 32, 32, 32)
		frames.add_frame(idle, ai)

	_sprite.sprite_frames = frames
	_sprite.offset        = Vector2(0, -16)
	_sprite.play("idle_down")


# Bucle de física

func _physics_process(delta: float) -> void:
	if _in_battle:
		return

	if _freeze_timer > 0.0:
		_freeze_timer -= delta
		velocity = Vector2.ZERO
		move_and_slide()
		_play_anim(Vector2.ZERO)
		if _freeze_timer <= 0.0:
			_in_battle = false
			_detect.monitoring = true
		return

	if _waiting:
		_wait_timer -= delta
		if _wait_timer <= 0.0:
			_waiting = false
			_pick_dir()
		velocity = Vector2.ZERO
		move_and_slide()
		_play_anim(Vector2.ZERO)
		return

	_move_timer -= delta
	if _move_timer <= 0.0:
		_waiting    = true
		_wait_timer = randf_range(0.5, 1.4)
		return

	# Volver al spawn
	if global_position.distance_to(_spawn) > wander_radius:
		_dir = (_spawn - global_position).normalized()

	velocity = _dir * speed
	var prev := global_position
	move_and_slide()

	# Probablemente atascado
	if global_position.distance_squared_to(prev) < 0.1:
		_stuck_frames += 1
		if _stuck_frames >= 8:
			_stuck_frames = 0
			# Girar para desatascarse
			var escape_angle = _dir.angle() + randf_range(PI * 0.5, PI)
			_dir = Vector2(cos(escape_angle), sin(escape_angle))
			_move_timer = randf_range(0.8, 2.0)
	else:
		_stuck_frames = 0

	_play_anim(_dir)


# Helpers

func _pick_dir() -> void:
	var angle   := randf() * TAU
	_dir        = Vector2(cos(angle), sin(angle))
	_move_timer = randf_range(1.0, 3.2)


func _play_anim(dir: Vector2) -> void:
	if not _sprite or not _sprite.sprite_frames:
		return
	var anim: String
	if dir == Vector2.ZERO:
		anim = "idle_" + _last_dir
	else:
		if abs(dir.y) >= abs(dir.x):
			_last_dir = "down" if dir.y > 0 else "up"
		else:
			_last_dir = "right" if dir.x > 0 else "left"
		anim = "walk_" + _last_dir
	if _sprite.animation != anim:
		_sprite.play(anim)


# Contacto con el jugador → batalla

func _on_player_detected(body: Node) -> void:
	if _in_battle or not (body is PlayerController):
		return
	_in_battle = true
	Inventory.pre_battle_position   = body.global_position
	Inventory.pre_battle_direction  = body._last_dir
	Inventory.returning_from_battle = true
	Inventory.last_enemy_id         = name
	Inventory.battle_was_won        = false
	Inventory.battle_enemy_scenes   = battle_scenes.duplicate()
	SceneTransition.go_to(BATTLE_SCENE)
