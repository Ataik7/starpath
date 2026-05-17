class_name CombatantSprite
extends Node2D

signal clicked(entity: BaseEntity)

const FRAME_W: int = 32
const FRAME_H: int = 32

# Referencias a los Nodos Visuales
@onready var sprite:      AnimatedSprite2D = $AnimatedSprite2D
@onready var health_bar:  ProgressBar      = $ProgressBar
@onready var mana_bar:    ProgressBar      = $ManaBar

# Configuración exportable
@export var entity_logic:  BaseEntity
@export var sprite_texture: Texture2D = null
# true = el sprite mira a la izquierda (enemigos); false = mira a la derecha (héroes)
@export var facing_left:   bool = false

var is_selectable: bool = false
var _is_hovered:   bool = false

var _prev_hp:      int  = 0
var _initialized:  bool = false
var _idle_anim:    String = "idle_down"

func _ready() -> void:
	if not entity_logic:
		push_error("CombatantSprite: ¡A " + name + " le falta asignarle su nodo Logic!")
		return

	if sprite_texture:
		_build_sprite_frames(sprite_texture)

	entity_logic.stats_changed.connect(_on_stats_changed)
	entity_logic.defeated.connect(_on_defeated)
	entity_logic.defense_changed.connect(_on_defense_changed)

	if has_node("ClickArea"):
		$ClickArea.input_event.connect(_on_click_area_input)
		$ClickArea.mouse_entered.connect(_on_mouse_entered)
		$ClickArea.mouse_exited.connect(_on_mouse_exited)

	_on_stats_changed()
	_initialized = true

# Construcción de SpriteFrames desde el spritesheet

func _build_sprite_frames(tex: Texture2D) -> void:
	var sheet_rows: int = tex.get_height() / FRAME_H  # 3 ó 4

	# Row layout Pipoya: 0=down 1=left 2=right [3=up]
	var row_map: Dictionary = {
		"down":  0,
		"left":  1,
		"right": 2,
		"up":    0 if sheet_rows < 4 else 3
	}

	var frames := SpriteFrames.new()
	frames.remove_animation("default")

	for dir: String in ["down", "left", "right", "up"]:
		var row: int = row_map[dir]

		# Animación de idle (2 primeros frames, 3 fps)
		var idle: String = "idle_" + dir
		frames.add_animation(idle)
		frames.set_animation_loop(idle, true)
		frames.set_animation_speed(idle, 3.0)
		for col in range(2):
			var at := AtlasTexture.new()
			at.atlas  = tex
			at.region = Rect2(col * FRAME_W, row * FRAME_H, FRAME_W, FRAME_H)
			frames.add_frame(idle, at)

		# Animación de caminar (3 frames, 8 fps)
		var walk: String = "walk_" + dir
		frames.add_animation(walk)
		frames.set_animation_loop(walk, true)
		frames.set_animation_speed(walk, 8.0)
		for col in range(3):
			var at := AtlasTexture.new()
			at.atlas  = tex
			at.region = Rect2(col * FRAME_W, row * FRAME_H, FRAME_W, FRAME_H)
			frames.add_frame(walk, at)

	sprite.sprite_frames = frames

	# Elegir idle según si mira a la izquierda o derecha
	_idle_anim = "idle_left" if facing_left else "idle_right"
	sprite.flip_h = false
	sprite.play(_idle_anim)

# Selección de objetivo

# Detecta clics vía _unhandled_input + estado de hover (más fiable que
# Area2D.input_event cuando hay CanvasLayers activos en la escena).
func _unhandled_input(event: InputEvent) -> void:
	if not is_selectable or not _is_hovered:
		return
	if event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed:
		get_viewport().set_input_as_handled()
		clicked.emit(entity_logic)

func _on_click_area_input(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	# Fallback por si _unhandled_input no llega (p.ej. enfoque en UI).
	if not is_selectable:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		get_viewport().set_input_as_handled()
		clicked.emit(entity_logic)

func _on_mouse_entered() -> void:
	_is_hovered = true
	if is_selectable:
		sprite.modulate = Color(1.5, 1.4, 0.7)

func _on_mouse_exited() -> void:
	_is_hovered = false
	if is_selectable:
		sprite.modulate = Color(0.55, 0.8, 1.0) if entity_logic.is_defending else Color(1, 1, 1)

# Reacciones Visuales

func _on_stats_changed() -> void:
	var new_hp: int = entity_logic.current_hp
	health_bar.max_value = entity_logic.stats.max_hp
	health_bar.value     = new_hp
	mana_bar.max_value   = entity_logic.stats.max_mp
	mana_bar.value       = entity_logic.current_mp

	if _initialized:
		var delta: int = new_hp - _prev_hp
		if delta < 0:
			_spawn_floating_text("-%d" % -delta, Color(1.0, 0.30, 0.30))
		elif delta > 0:
			_spawn_floating_text("+%d" % delta, Color(0.30, 1.0, 0.45))
	_prev_hp = new_hp

func _on_defense_changed(defending: bool) -> void:
	sprite.modulate = Color(0.55, 0.8, 1.0) if defending else Color(1, 1, 1)

func _on_defeated() -> void:
	print(name + " ha sido derrotado visualmente.")
	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 1.0)

# Número flotante de daño / curación

# Llama esto externamente al aplicar daño para el flash de color.
func play_hit_flash(is_magical: bool = false) -> void:
	var hit_color := Color(0.35, 0.55, 1.0) if is_magical else Color(1.0, 0.25, 0.25)
	sprite.modulate = hit_color
	var tw := create_tween()
	var restore := Color(0.55, 0.8, 1.0) if entity_logic.is_defending else Color(1.0, 1.0, 1.0)
	tw.tween_property(sprite, "modulate", restore, 0.35)

func _spawn_floating_text(text: String, color: Color) -> void:
	var label := Label.new()
	label.text     = text
	label.modulate = color
	label.z_index  = 10
	label.add_theme_font_size_override("font_size", 22)
	label.position = sprite.position + Vector2(-20, -80)
	add_child(label)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 60, 1.2)
	tween.tween_property(label, "modulate:a", 0.0, 1.2)
	tween.finished.connect(label.queue_free)
