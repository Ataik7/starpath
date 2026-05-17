# BridgeArea.gd
# Area2D que cubre el puente.
# Al entrar el jugador retira la capa 2 de su máscara (ignora el agua).
# Al salir la restaura.

extends Area2D

const MASK_NORMAL : int = 3   # capas 1 + 2  (paredes + agua)
const MASK_BRIDGE : int = 1   # solo capa 1  (solo paredes)

func _ready() -> void:
	collision_mask = 1
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	print("BridgeArea en: ", global_position, " tamaño shape: ", $CollisionShape2D.shape.size)

func _on_body_entered(body: Node2D) -> void:
	print("BridgeArea entered: ", body.name, " | player mask antes: ", body.collision_mask if body is PlayerController else "N/A")
	if body is PlayerController:
		body.collision_mask = MASK_BRIDGE
		print("→ máscara cambiada a BRIDGE (1)")

func _on_body_exited(body: Node2D) -> void:
	print("BridgeArea exited: ", body.name)
	if body is PlayerController:
		body.collision_mask = MASK_NORMAL
		print("→ máscara restaurada a NORMAL (3)")
