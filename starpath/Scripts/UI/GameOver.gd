extends CanvasLayer

# Pantalla de Game Over con animación de fade-in y opciones para el jugador.

@onready var background: Panel = $Background
@onready var overlay: ColorRect = $Overlay
@onready var content: VBoxContainer = $Content
@onready var game_over_label: Label = $Content/GameOverLabel

const MENU_SCENE := "res://Scenes/UI/menu_inicio.tscn"
const WORLD_MAP_SCENE := "res://Scenes/World/WorldMap.tscn"


func _ready() -> void:
	# Empezar todo invisible y animar la entrada
	background.modulate.a = 0.0
	content.modulate.a = 0.0
	overlay.color.a = 0.0
	_animate_in()


func _animate_in() -> void:
	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_CUBIC)

	# Fade del fondo con la imagen pexels
	tween.tween_property(background, "modulate:a", 1.0, 1.2)

	# Fade del overlay oscuro encima
	tween.parallel().tween_property(overlay, "color:a", 0.5, 1.5)

	# Fade del contenido (título, mensaje, botones)
	tween.tween_property(content, "modulate:a", 1.0, 1.0)

	# Efecto de pulsación en el título
	await tween.finished
	_pulse_title()


func _pulse_title() -> void:
	var pulse := create_tween()
	pulse.set_loops()
	pulse.set_ease(Tween.EASE_IN_OUT)
	pulse.set_trans(Tween.TRANS_SINE)
	pulse.tween_property(game_over_label, "modulate:a", 0.6, 1.5)
	pulse.tween_property(game_over_label, "modulate:a", 1.0, 1.5)


# Botones

func _on_retry_pressed() -> void:
	get_tree().reload_current_scene()


func _on_load_pressed() -> void:
	for slot in range(SaveManager.SLOT_COUNT):
		if SaveManager.has_save(slot):
			if SaveManager.load_game(slot):
				SceneTransition.go_to(WORLD_MAP_SCENE)
				return
	# Si no hay partidas, ir al menú
	SceneTransition.go_to(MENU_SCENE)


func _on_menu_pressed() -> void:
	SceneTransition.go_to(MENU_SCENE)
