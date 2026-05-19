class_name FollowerController
extends Node2D

# Sprite que camina detrás del líder del grupo (estilo Octopath).
# WorldMap.gd le llama update_from_history() cada physics frame.

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D

var _last_dir: String = "down"

# Animaciones del spritesheet

func setup_texture(tex: Texture2D) -> void:
	if tex == null:
		return
	var frames := SpriteFrames.new()
	var dirs: Array[String] = ["down", "left", "right", "up"]
	for i in dirs.size():
		var row: int = i
		# Animación de caminar (3 frames)
		var walk := "walk_" + dirs[i]
		frames.add_animation(walk)
		frames.set_animation_speed(walk, 8.0)
		frames.set_animation_loop(walk, true)
		for col in 3:
			var atlas       := AtlasTexture.new()
			atlas.atlas      = tex
			atlas.region     = Rect2(col * 32, row * 32, 32, 32)
			frames.add_frame(walk, atlas)
		# Animación idle (frame central)
		var idle := "idle_" + dirs[i]
		frames.add_animation(idle)
		frames.set_animation_speed(idle, 1.0)
		frames.set_animation_loop(idle, false)
		var idle_atlas       := AtlasTexture.new()
		idle_atlas.atlas      = tex
		idle_atlas.region     = Rect2(32, row * 32, 32, 32)
		frames.add_frame(idle, idle_atlas)
	_sprite.sprite_frames = frames
	_sprite.offset        = Vector2(0, -16)
	_sprite.play("idle_down")

# Actualizar posición

func update_from_history(target_pos: Vector2, target_dir: String) -> void:
	var diff := target_pos - global_position
	global_position = target_pos
	if diff.length() > 0.5:
		_update_walk_anim(diff)
	else:
		_play_idle(target_dir)

# Animación

func _update_walk_anim(diff: Vector2) -> void:
	var dir: String
	if abs(diff.y) >= abs(diff.x):
		dir = "down" if diff.y > 0 else "up"
	else:
		dir = "right" if diff.x > 0 else "left"
	_last_dir = dir
	var anim := "walk_" + dir
	if _sprite.animation != anim:
		_sprite.play(anim)

func _play_idle(dir: String) -> void:
	_last_dir = dir
	var anim := "idle_" + dir
	if _sprite.animation != anim:
		_sprite.play(anim)
