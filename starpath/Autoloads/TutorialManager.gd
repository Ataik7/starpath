extends Node

# Emitido cuando un paso de tutorial debe mostrarse.
signal show_requested(id: String, title: String, body: String, blocking: bool)

var _seen: Dictionary = {}

# Llama esto al iniciar nueva partida para que los tutoriales vuelvan a aparecer.
func reset() -> void:
	_seen.clear()

# Llama esto al cargar una partida para que los tutoriales no vuelvan a salir.
func skip_all() -> void:
	for id in ["lore", "movement", "npc", "pause"]:
		_seen[id] = true

# Muestra el paso 'id' solo si no se ha visto antes en esta partida.
# blocking=true pausa el juego mientras se muestra (para el lore).
func try_show(id: String, title: String, body: String, blocking: bool = false) -> void:
	if _seen.get(id, false):
		return
	_seen[id] = true
	show_requested.emit(id, title, body, blocking)
