extends CanvasLayer

const BG_TEX := "res://Assets/Backgrounds/battle_field.png"

func _ready() -> void:
	var vp := get_viewport().get_visible_rect().size

	# Fondo base
	var sky := ColorRect.new()
	sky.color    = Color(0.55, 0.68, 0.55)   # verde grisáceo que imita la nxxiebla del PNG
	sky.position = Vector2.ZERO
	sky.size     = Vector2(vp.x, vp.y)
	sky.z_index  = -10
	add_child(sky)

	# Imagen de fondo
	var bg      := Sprite2D.new()
	bg.texture   = load(BG_TEX) as Texture2D
	bg.centered  = false
	bg.z_index   = -9
	if bg.texture:
		var tex_size := bg.texture.get_size()
		# Escalar al tamaño de pantalla
		var scale_x := vp.x / tex_size.x
		var scale_y := vp.y / tex_size.y
		var sc      : float = max(scale_x, scale_y)   # usar el mayor para no dejar huecos
		bg.scale     = Vector2(sc, sc)
		# Centrar
		bg.position.x = (vp.x - tex_size.x * sc) / 2.0
		bg.position.y = vp.y - tex_size.y * sc
	# Aclarar
	bg.modulate = Color(1.30, 1.30, 1.25)
	add_child(bg)
