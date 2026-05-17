extends Node2D

@onready var battle_manager: BattleManager = $BattleManager
@onready var hero_logic     = $HeroSprite/Logic
@onready var enemy_logic    = $EnemySprite/Logic
@onready var enemy2_logic   = $Enemy2Sprite/Logic
@onready var battle_hud     = $BattleHUD
@onready var turn_queue: TurnQueue = $TurnQueue

# ── Compañeros dinámicos ──────────────────────────────────────────────────────
var hero2_logic  : BaseEntity = null   # Athelios (si está en el grupo)
var hero3_logic  : BaseEntity = null   # Byran    (si está en el grupo)

# Arrays dinámicos para hover/click y selección de objetivo
var _all_hero_entities  : Array[BaseEntity] = []
var _all_enemy_entities : Array[BaseEntity] = []

# ── Orden de turnos estilo Octopath ──────────────────────────────────────────
const _SLOT_SHOW  : int = 7    # iconos visibles
const _SLOT_SZ    : int = 50   # px por icono
const _SLOT_GAP   : int = 6    # separación entre iconos
const _SLOT_STRIDE: int = 56   # _SLOT_SZ + _SLOT_GAP

var _slot_clip  : Control = null
var _slots      : Array   = []    # Array of Dictionaries { card, portrait, team_bar, style }
var _slot_tween : Tween   = null
var _first_turn : bool    = true

@onready var menu_combate     = $BattleUI/VBoxContainer
@onready var cancel_btn       = $BattleUI/CancelarButton
@onready var curar_btn        = $BattleUI/VBoxContainer/CurarButton
@onready var magia_btn        = $BattleUI/VBoxContainer/MagiaButton
@onready var skills_panel     = $BattleUI/SkillsPanel
@onready var skills_container = $BattleUI/SkillsPanel/VBoxContainer
@onready var objetos_panel      = $BattleUI/ObjetosPanel
@onready var objetos_container  = $BattleUI/ObjetosPanel/VBoxContainer
@onready var end_panel        = $BattleUI/Panel
@onready var result_label     = $BattleUI/Panel/VBoxContainer/LblResolution
@onready var replay_btn       = $BattleUI/Panel/VBoxContainer/BtnReplay

var _active_hero: BaseEntity = null
var _player_won: bool = false

# Nombres de clase para el botón de habilidades
const _COMPANION_STATS_PATHS: Dictionary = {
	"athelios": "res://Resources/Characters/Athelios.tres",
	"byran":    "res://Resources/Characters/Byran.tres",
}

const CLASS_NAMES := {
	0: "Guerrero",
	1: "Mago",
	2: "Pícaro",
	3: "Sanador",
	4: "Paladín",
	5: "Arquero"
}

# Clases que tienen panel de habilidades mágicas
const MAGIC_CLASSES := [
	CharacterStats.ClassType.MAGO,
	CharacterStats.ClassType.SANADOR
]

func _ready() -> void:
	print("--- CARGANDO ESCENA DE BATALLA ---")
	AudioManager.play_bgm("battle")

	menu_combate.visible  = false
	end_panel.visible     = false
	skills_panel.visible  = false
	objetos_panel.visible = false
	cancel_btn.visible    = false

	battle_manager.action_menu_toggled.connect(_on_menu_toggled)
	battle_manager.battle_ended.connect(_on_battle_ended)
	battle_manager.attack_animation_needed.connect(_on_attack_anim)
	battle_manager.active_entity_changed.connect(battle_hud.set_active_entity)
	battle_manager.active_entity_changed.connect(_on_active_entity_changed)
	battle_manager.active_entity_changed.connect(_update_turn_order_highlight)
	battle_manager.target_selection_needed.connect(_on_target_selection_needed)
	battle_manager.ally_target_selection_needed.connect(_on_ally_target_selection_needed)

	var team_heroes:  Array[BaseEntity] = [hero_logic]
	var team_enemies: Array[BaseEntity] = [enemy_logic, enemy2_logic]
	_all_enemy_entities = [enemy_logic, enemy2_logic]
	_all_hero_entities  = [hero_logic]

	# ── Instanciar compañeros si están en el grupo ────────────────────────────
	var hero_x_positions := [380, 300, 220]   # posiciones X para 1-3 héroes

	if Inventory.has_party_member("athelios"):
		var s2 := preload("res://Scenes/Battle/Hero2Sprite.tscn").instantiate() as Node2D
		add_child(s2)
		s2.position = Vector2(hero_x_positions[1], 430)
		hero2_logic = s2.get_node("Logic") as BaseEntity
		team_heroes.append(hero2_logic)
		_all_hero_entities.append(hero2_logic)

	if Inventory.has_party_member("byran"):
		var s3 := preload("res://Scenes/Battle/Hero3Sprite.tscn").instantiate() as Node2D
		add_child(s3)
		var x_idx := 2 if Inventory.has_party_member("athelios") else 1
		s3.position = Vector2(hero_x_positions[x_idx], 450)
		hero3_logic = s3.get_node("Logic") as BaseEntity
		team_heroes.append(hero3_logic)
		_all_hero_entities.append(hero3_logic)

	battle_hud.setup(team_heroes)
	battle_manager.start_battle(team_heroes, team_enemies)

	# La cola ya está ordenada por velocidad tras start_battle → construir HUD
	_build_turn_order_ui()

# ── Hover visual en selección de objetivo ────────────────────────────────────

func _process(_delta: float) -> void:
	if battle_manager == null:
		return
	var selecting := battle_manager.current_state == BattleManager.BattleState.SELECTING_TARGET
	var mouse     := get_global_mouse_position()
	var half      := Vector2(72, 72)

	for entity: BaseEntity in _all_enemy_entities + _all_hero_entities:
		var s := entity.get_parent() as CombatantSprite
		if s == null:
			continue
		if not selecting or not s.is_selectable:
			if s._is_hovered:
				s._is_hovered = false
				if entity.is_alive:
					s.sprite.modulate = Color(1.0, 1.0, 1.0)
			continue
		var over := Rect2(s.global_position - half, half * 2).has_point(mouse)
		if over == s._is_hovered:
			continue
		s._is_hovered = over
		if over:
			s.sprite.modulate = Color(1.6, 1.5, 0.6)
			s.sprite.scale    = Vector2(4.3, 4.3)
		else:
			s.sprite.modulate = Color(1.0, 1.0, 1.0)
			s.sprite.scale    = Vector2(4.0, 4.0)

# ── Seguimiento del héroe activo ──────────────────────────────────────────────

func _on_active_entity_changed(entity: BaseEntity) -> void:
	if entity.get_parent().is_in_group("Heroes"):
		_active_hero = entity

# ── Actualización del menú según la clase del héroe ──────────────────────────

func _update_menu_for_hero(hero: BaseEntity) -> void:
	if hero == null:
		return

	var class_id: int = hero.stats.character_class
	var class_label: String = CLASS_NAMES.get(class_id, "Héroe")

	# Botón de habilidades: cualquier héroe con habilidades asignadas
	var has_skills: bool = not hero.stats.skills.is_empty()
	magia_btn.visible = has_skills
	if has_skills:
		magia_btn.text = "Hab. de %s ▶" % class_label

	# Curar: solo Sanador
	curar_btn.visible = (class_id == CharacterStats.ClassType.SANADOR)

	# Reconstruir botones de habilidades para este héroe
	_build_skill_buttons(hero)

func _build_skill_buttons(hero: BaseEntity) -> void:
	for child in skills_container.get_children():
		child.queue_free()
	for skill: SkillData in hero.stats.skills:
		var btn := Button.new()
		btn.text = "%s  (%d MP)" % [skill.skill_name, skill.mp_cost]
		btn.custom_minimum_size = Vector2(160, 0)
		btn.pressed.connect(_on_skill_btn_pressed.bind(skill))
		skills_container.add_child(btn)

# ── Señales del BattleManager ─────────────────────────────────────────────────

func _on_menu_toggled(show_menu: bool) -> void:
	if not end_panel.visible:
		menu_combate.visible = show_menu
		if not show_menu:
			skills_panel.visible  = false
			objetos_panel.visible = false
			cancel_btn.visible    = false
		else:
			cancel_btn.visible = false
			_update_menu_for_hero(_active_hero)

func _on_target_selection_needed(enemies: Array[BaseEntity]) -> void:
	for entity in [enemy_logic, enemy2_logic]:
		var s := entity.get_parent() as CombatantSprite
		if s:
			s.is_selectable = false
			if s.clicked.is_connected(_on_enemy_sprite_clicked):
				s.clicked.disconnect(_on_enemy_sprite_clicked)

	if enemies.is_empty():
		cancel_btn.visible = false
		return

	var mouse_world := get_global_mouse_position()
	var half        := Vector2(72, 72)

	for entity: BaseEntity in enemies:
		var s := entity.get_parent() as CombatantSprite
		if s:
			s.is_selectable = true
			s.clicked.connect(_on_enemy_sprite_clicked)
			# Si el ratón ya está encima, marcar hover ahora mismo
			if Rect2(s.global_position - half, half * 2).has_point(mouse_world):
				s._is_hovered = true
				s.sprite.modulate = Color(1.5, 1.4, 0.7)

	cancel_btn.visible = true

func _on_ally_target_selection_needed(allies: Array[BaseEntity]) -> void:
	for entity in _all_hero_entities:
		var s := entity.get_parent() as CombatantSprite
		if s:
			s.is_selectable = false
			if s.clicked.is_connected(_on_ally_sprite_clicked):
				s.clicked.disconnect(_on_ally_sprite_clicked)

	if allies.is_empty():
		cancel_btn.visible = false
		return

	var mouse_world_a := get_global_mouse_position()
	var half_a        := Vector2(72, 72)

	for entity: BaseEntity in allies:
		var s := entity.get_parent() as CombatantSprite
		if s:
			s.is_selectable = true
			s.clicked.connect(_on_ally_sprite_clicked)
			if Rect2(s.global_position - half_a, half_a * 2).has_point(mouse_world_a):
				s._is_hovered = true
				s.sprite.modulate = Color(1.5, 1.4, 0.7)

	cancel_btn.visible = true

func _on_ally_sprite_clicked(entity: BaseEntity) -> void:
	battle_manager.player_target_confirmed(entity)

func _on_enemy_sprite_clicked(entity: BaseEntity) -> void:
	battle_manager.player_target_confirmed(entity)

# ── Detección de clic (_input se llama siempre, antes que la GUI) ─────────────

func _input(event: InputEvent) -> void:
	if battle_manager.current_state != BattleManager.BattleState.SELECTING_TARGET:
		return
	if not (event is InputEventMouseButton
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
			and (event as InputEventMouseButton).pressed):
		return

	# Prioridad 1: entidad que tiene el ratón encima (mouse_entered funciona)
	for entity: BaseEntity in _all_enemy_entities + _all_hero_entities:
		var s := entity.get_parent() as CombatantSprite
		if s and s.is_selectable and s._is_hovered:
			get_viewport().set_input_as_handled()
			battle_manager.player_target_confirmed(entity)
			return

	# Prioridad 2: test geométrico con coordenadas de mundo
	var mouse := get_global_mouse_position()
	var half  := Vector2(72, 72)
	for entity: BaseEntity in _all_enemy_entities + _all_hero_entities:
		var s := entity.get_parent() as CombatantSprite
		if s and s.is_selectable:
			if Rect2(s.global_position - half, half * 2).has_point(mouse):
				get_viewport().set_input_as_handled()
				battle_manager.player_target_confirmed(entity)
				return

# ── Botones del menú ──────────────────────────────────────────────────────────

func _on_btn_atacar_pressed() -> void:
	battle_manager.player_action_selected("Atacar")

func _on_btn_curar_pressed() -> void:
	battle_manager.player_action_selected("Curar")

func _on_btn_defender_pressed() -> void:
	battle_manager.player_action_selected("Defender")

func _on_btn_magia_pressed() -> void:
	objetos_panel.visible = false
	skills_panel.visible  = not skills_panel.visible
	cancel_btn.visible    = skills_panel.visible

func _on_btn_objetos_pressed() -> void:
	skills_panel.visible = false
	if not objetos_panel.visible:
		_refresh_item_buttons()
	objetos_panel.visible = not objetos_panel.visible
	cancel_btn.visible    = objetos_panel.visible

func _refresh_item_buttons() -> void:
	for child in objetos_container.get_children():
		child.queue_free()
	var available := Inventory.get_available()
	if available.is_empty():
		var lbl := Label.new()
		lbl.text = "Sin objetos"
		objetos_container.add_child(lbl)
	else:
		for item: ItemData in available:
			var btn := Button.new()
			btn.text = "%s  x%d" % [item.item_name, item.quantity]
			btn.custom_minimum_size = Vector2(160, 0)
			btn.pressed.connect(_on_item_btn_pressed.bind(item))
			objetos_container.add_child(btn)

func _on_item_btn_pressed(item: ItemData) -> void:
	objetos_panel.visible = false
	battle_manager.player_item_selected(item)

func _on_btn_cancelar_pressed() -> void:
	cancel_btn.visible    = false
	skills_panel.visible  = false
	objetos_panel.visible = false
	if battle_manager.current_state == BattleManager.BattleState.SELECTING_TARGET:
		battle_manager.player_target_cancelled()
	else:
		menu_combate.visible = true

func _on_skill_btn_pressed(skill: SkillData) -> void:
	skills_panel.visible = false
	cancel_btn.visible   = false
	battle_manager.player_skill_selected(skill)

func _on_battle_ended(player_won: bool) -> void:
	_player_won          = player_won
	menu_combate.visible = false

	if player_won:
		AudioManager.play_bgm("victory", false)
		await get_tree().create_timer(0.8).timeout
		_show_victory_screen()
	else:
		# Pantalla de Game Over completa
		AudioManager.stop_bgm()
		await get_tree().create_timer(1.5).timeout
		var game_over_scene := preload("res://Scenes/UI/GameOver.tscn")
		var game_over := game_over_scene.instantiate()
		get_tree().current_scene.add_child(game_over)

func _on_btn_reiniciar_pressed() -> void:
	SceneTransition.go_to("res://Scenes/World/WorldMap.tscn")

# ── Pantalla de victoria animada ──────────────────────────────────────────────

func _show_victory_screen() -> void:
	var xp_reward   := battle_manager.victory_xp
	var gold_reward := battle_manager.victory_gold

	# Estado antes de aplicar las recompensas
	var xp_before     := Inventory.current_xp
	var level_before  := Inventory.current_level
	var xp_cap_before := Inventory.xp_to_next()

	# Capturar estado XP de compañeros antes de aplicar
	var comp_xp_before:    Dictionary = {}
	var comp_level_before: Dictionary = {}
	for id in Inventory.party_members:
		comp_xp_before[id]    = Inventory.get_companion_xp(id)
		comp_level_before[id] = Inventory.get_companion_level(id)

	# Aplicar recompensas al Inventario
	Inventory.add_xp(xp_reward)
	Inventory.gold += gold_reward

	# Dar la misma XP a cada compañero activo
	for id in Inventory.party_members:
		Inventory.add_companion_xp(id, xp_reward)

	var level_after  := Inventory.current_level
	var xp_after     := Inventory.current_xp
	var xp_cap_after := Inventory.xp_to_next()
	var leveled_up   := level_after > level_before

	# ── Overlay oscuro ────────────────────────────────────────────────────────
	var ui := CanvasLayer.new()
	ui.layer = 50
	add_child(ui)

	var dimmer := ColorRect.new()
	dimmer.color = Color(0.0, 0.0, 0.0, 0.0)
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(dimmer)

	var tw_dim := create_tween()
	tw_dim.tween_property(dimmer, "color:a", 0.65, 0.35)
	await tw_dim.finished

	# ── Panel central ─────────────────────────────────────────────────────────
	var vp_size := get_viewport().get_visible_rect().size

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 0)
	panel.position = Vector2(vp_size.x * 0.5 - 260, vp_size.y * 0.5 - 190)
	ui.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var inner := MarginContainer.new()
	inner.add_theme_constant_override("margin_left",   24)
	inner.add_theme_constant_override("margin_right",  24)
	inner.add_theme_constant_override("margin_top",    18)
	inner.add_theme_constant_override("margin_bottom", 18)
	vbox.add_child(inner)

	var inner_vbox := VBoxContainer.new()
	inner_vbox.add_theme_constant_override("separation", 10)
	inner.add_child(inner_vbox)

	# Título
	var lbl_title := Label.new()
	lbl_title.text = "★  ¡VICTORIA!  ★"
	lbl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_title.add_theme_font_size_override("font_size", 30)
	lbl_title.modulate = Color(1.0, 0.92, 0.3)
	inner_vbox.add_child(lbl_title)

	inner_vbox.add_child(HSeparator.new())

	# Fila EXP ganada
	var lbl_xp_earned := Label.new()
	lbl_xp_earned.text = "Experiencia:   + %d EXP" % xp_reward
	lbl_xp_earned.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_xp_earned.add_theme_font_size_override("font_size", 18)
	inner_vbox.add_child(lbl_xp_earned)

	# Fila Oro ganado
	var lbl_gold := Label.new()
	lbl_gold.text = "Oro obtenido:   + %d ✦" % gold_reward
	lbl_gold.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_gold.add_theme_font_size_override("font_size", 18)
	lbl_gold.modulate = Color(1.0, 0.85, 0.2)
	inner_vbox.add_child(lbl_gold)

	inner_vbox.add_child(HSeparator.new())

	# Nombre del héroe + nivel
	var lbl_hero := Label.new()
	lbl_hero.text = "Lyra   —   Nv. %d" % level_before
	lbl_hero.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_hero.add_theme_font_size_override("font_size", 16)
	inner_vbox.add_child(lbl_hero)

	# Barra de XP
	var xp_bar := ProgressBar.new()
	xp_bar.min_value = 0
	xp_bar.max_value = xp_cap_before
	xp_bar.value = xp_before
	xp_bar.show_percentage = false
	xp_bar.custom_minimum_size = Vector2(0, 24)
	inner_vbox.add_child(xp_bar)

	var lbl_xp_vals := Label.new()
	lbl_xp_vals.text = "%d / %d XP" % [xp_before, xp_cap_before]
	lbl_xp_vals.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner_vbox.add_child(lbl_xp_vals)

	# Label de subida de nivel (vacío hasta que ocurra)
	var lbl_levelup := Label.new()
	lbl_levelup.text = ""
	lbl_levelup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_levelup.add_theme_font_size_override("font_size", 20)
	lbl_levelup.modulate = Color(1.0, 0.9, 0.2)
	inner_vbox.add_child(lbl_levelup)

	# ── Animación de la barra de XP ───────────────────────────────────────────
	await get_tree().create_timer(0.4).timeout

	if leveled_up:
		# Llenar hasta el máximo del nivel anterior
		var tw1 := create_tween()
		tw1.tween_property(xp_bar, "value", float(xp_cap_before), 0.7)
		tw1.parallel().tween_method(
			func(v: float): lbl_xp_vals.text = "%d / %d XP" % [int(v), xp_cap_before],
			float(xp_before), float(xp_cap_before), 0.7)
		await tw1.finished

		await get_tree().create_timer(0.25).timeout
		lbl_levelup.text = "★ ¡NIVEL %d! ★" % level_after
		lbl_hero.text = "Lyra   —   Nv. %d" % level_after

		# Reiniciar barra al nuevo umbral
		xp_bar.max_value = xp_cap_after
		xp_bar.value     = 0.0
		await get_tree().create_timer(0.3).timeout

		# Llenar hasta el XP residual
		var tw2 := create_tween()
		tw2.tween_property(xp_bar, "value", float(xp_after), 0.7)
		tw2.parallel().tween_method(
			func(v: float): lbl_xp_vals.text = "%d / %d XP" % [int(v), xp_cap_after],
			0.0, float(xp_after), 0.7)
		await tw2.finished
	else:
		var tw := create_tween()
		tw.tween_property(xp_bar, "value", float(xp_after), 1.0)
		tw.parallel().tween_method(
			func(v: float): lbl_xp_vals.text = "%d / %d XP" % [int(v), xp_cap_after],
			float(xp_before), float(xp_after), 1.0)
		await tw.finished

	lbl_xp_vals.text = "%d / %d XP" % [xp_after, xp_cap_after]

	# ── EXP de compañeros del grupo ───────────────────────────────────────────
	for id in Inventory.party_members:
		var c_stats: CharacterStats = load(_COMPANION_STATS_PATHS.get(id, ""))
		if c_stats == null:
			continue

		inner_vbox.add_child(HSeparator.new())

		var c_lv_b   : int  = comp_level_before.get(id, 1)
		var c_xp_b   : int  = comp_xp_before.get(id, 0)
		var c_xp_cap : int  = c_lv_b * 100
		var c_lv_a   : int  = Inventory.get_companion_level(id)
		var c_xp_a   : int  = Inventory.get_companion_xp(id)
		var c_leveled: bool = c_lv_a > c_lv_b

		var lbl_c_hero := Label.new()
		lbl_c_hero.text = "%s   —   Nv. %d" % [c_stats.character_name, c_lv_b]
		lbl_c_hero.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_c_hero.add_theme_font_size_override("font_size", 16)
		inner_vbox.add_child(lbl_c_hero)

		var c_xp_bar := ProgressBar.new()
		c_xp_bar.min_value = 0
		c_xp_bar.max_value = c_xp_cap
		c_xp_bar.value = c_xp_b
		c_xp_bar.show_percentage = false
		c_xp_bar.custom_minimum_size = Vector2(0, 24)
		inner_vbox.add_child(c_xp_bar)

		var lbl_c_xp := Label.new()
		lbl_c_xp.text = "%d / %d XP" % [c_xp_b, c_xp_cap]
		lbl_c_xp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		inner_vbox.add_child(lbl_c_xp)

		var lbl_c_lv := Label.new()
		lbl_c_lv.text = ""
		lbl_c_lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_c_lv.add_theme_font_size_override("font_size", 18)
		lbl_c_lv.modulate = Color(1.0, 0.9, 0.2)
		inner_vbox.add_child(lbl_c_lv)

		if c_leveled:
			c_xp_bar.max_value = c_lv_a * 100
			c_xp_bar.value     = c_xp_a
			lbl_c_xp.text      = "%d / %d XP" % [c_xp_a, c_lv_a * 100]
			lbl_c_lv.text      = "★ ¡NIVEL %d! ★" % c_lv_a
			lbl_c_hero.text    = "%s   —   Nv. %d" % [c_stats.character_name, c_lv_a]
		else:
			var c_tw := create_tween()
			c_tw.tween_property(c_xp_bar, "value", float(c_xp_a), 0.8)
			c_tw.parallel().tween_method(
				func(v: float): lbl_c_xp.text = "%d / %d XP" % [int(v), c_xp_cap],
				float(c_xp_b), float(c_xp_a), 0.8)
			await c_tw.finished

	# ── Botón de regreso ──────────────────────────────────────────────────────
	inner_vbox.add_child(HSeparator.new())

	var btn_hbox := HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	inner_vbox.add_child(btn_hbox)

	var btn_map := Button.new()
	btn_map.text = "Volver al mapa"
	btn_map.custom_minimum_size = Vector2(220, 40)
	btn_hbox.add_child(btn_map)

	btn_map.pressed.connect(func():
		SceneTransition.go_to("res://Scenes/World/WorldMap.tscn")
	)

# ── Orden de turnos – conveyor belt estilo Octopath ──────────────────────────

func _build_turn_order_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 6
	add_child(canvas)

	# Contenedor con clip: corta los slots que salen/entran por los lados
	_slot_clip = Control.new()
	_slot_clip.clip_contents  = true
	_slot_clip.position       = Vector2(10, 10)
	_slot_clip.size           = Vector2(
		_SLOT_SHOW * _SLOT_STRIDE - _SLOT_GAP,
		_SLOT_SZ
	)
	_slot_clip.mouse_filter   = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(_slot_clip)

	# SLOT_SHOW visibles + 1 extra que entra desde la derecha al animar
	for i in range(_SLOT_SHOW + 1):
		var slot := _make_slot()
		slot["card"].position = Vector2(i * _SLOT_STRIDE, 0)
		_slot_clip.add_child(slot["card"])
		_slots.append(slot)

# ── Fabrica un slot vacío y devuelve su diccionario ───────────────────────────

func _make_slot() -> Dictionary:
	var style := StyleBoxFlat.new()
	style.bg_color                   = Color(0.07, 0.07, 0.12, 0.92)
	style.corner_radius_top_left     = 7
	style.corner_radius_top_right    = 7
	style.corner_radius_bottom_left  = 7
	style.corner_radius_bottom_right = 7
	style.border_width_left          = 2
	style.border_width_right         = 2
	style.border_width_top           = 2
	style.border_width_bottom        = 2
	style.border_color               = Color(0.45, 0.45, 0.50, 0.75)
	style.shadow_size                = 4
	style.shadow_color               = Color(0.0, 0.0, 0.0, 0.50)
	style.shadow_offset              = Vector2(2, 2)

	# Panel (no Container → no gestiona el layout de sus hijos)
	var card := Panel.new()
	card.size         = Vector2(_SLOT_SZ, _SLOT_SZ)
	card.add_theme_stylebox_override("panel", style)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.pivot_offset = Vector2(_SLOT_SZ * 0.5, _SLOT_SZ * 0.5)

	# Retrato pixel-art
	var portrait := TextureRect.new()
	portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait.expand_mode    = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	portrait.stretch_mode   = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.mouse_filter   = Control.MOUSE_FILTER_IGNORE
	card.add_child(portrait)

	# Franja de equipo (abajo)
	var team_bar := ColorRect.new()
	team_bar.anchor_left   = 0.0
	team_bar.anchor_right  = 1.0
	team_bar.anchor_top    = 1.0
	team_bar.anchor_bottom = 1.0
	team_bar.offset_top    = -6
	team_bar.offset_bottom = 0
	team_bar.color         = Color(0.5, 0.5, 0.5, 0.6)
	team_bar.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	card.add_child(team_bar)

	return { "card": card, "portrait": portrait, "team_bar": team_bar, "style": style }

# ── Rellena / actualiza el contenido visual de un slot ───────────────────────

func _set_slot_content(slot: Dictionary, entity: BaseEntity, is_active: bool) -> void:
	var card     : Panel        = slot["card"]
	var portrait : TextureRect  = slot["portrait"]
	var team_bar : ColorRect    = slot["team_bar"]
	var style    : StyleBoxFlat = slot["style"]

	if entity == null:
		card.visible = false
		return
	card.visible = true

	if not entity.is_alive:
		card.modulate = Color(0.28, 0.28, 0.28, 0.45)
		return

	card.modulate = Color(1.18, 1.12, 1.0) if is_active else Color(1.0, 1.0, 1.0)
	card.scale    = Vector2(1.10, 1.10)    if is_active else Vector2(1.0, 1.0)

	var is_hero := entity.get_parent().is_in_group("Heroes")
	team_bar.color = Color(0.25, 0.55, 1.0, 0.85) if is_hero else Color(0.9, 0.22, 0.22, 0.85)

	# Borde: dorado si activo, gris si no
	if is_active:
		style.border_color        = Color(1.0, 0.85, 0.15, 1.0)
		style.border_width_left   = 3
		style.border_width_right  = 3
		style.border_width_top    = 3
		style.border_width_bottom = 3
	else:
		style.border_color        = Color(0.45, 0.45, 0.50, 0.75)
		style.border_width_left   = 2
		style.border_width_right  = 2
		style.border_width_top    = 2
		style.border_width_bottom = 2

	# Retrato: recorta el frame 0 de la fila correspondiente
	var cs := entity.get_parent() as CombatantSprite
	if cs != null and cs.sprite_texture != null:
		var row      : int = 2 if not cs.facing_left else 1
		var n_rows   : int = cs.sprite_texture.get_height() / 32
		if row >= n_rows:
			row = 0
		var at := AtlasTexture.new()
		at.atlas  = cs.sprite_texture
		at.region = Rect2(0, row * 32, 32, 32)
		portrait.texture = at

# ── Calcula los próximos `count` turnos (índice 0 = activo actual) ───────────

func _get_turn_sequence(active: BaseEntity, count: int) -> Array[BaseEntity]:
	var result : Array[BaseEntity] = [active]
	var q_size  : int = turn_queue.queue.size()
	if q_size == 0:
		return result
	var idx      : int = turn_queue.active_index   # ya apunta al siguiente
	var attempts : int = 0
	while result.size() < count and attempts < q_size * (count + 2):
		var e := turn_queue.queue[idx % q_size]
		idx      += 1
		attempts += 1
		if e.is_alive:
			result.append(e)
	return result

# ── Actualiza la cola con animación de conveyor belt ─────────────────────────

func _update_turn_order_highlight(active: BaseEntity) -> void:
	var sequence := _get_turn_sequence(active, _SLOT_SHOW + 1)

	# Primera vez: rellenar sin animación
	if _first_turn:
		_first_turn = false
		for i in range(_SLOT_SHOW + 1):
			_set_slot_content(_slots[i], sequence[i] if i < sequence.size() else null, i == 0)
		return

	# Matar tween anterior y restaurar posiciones si estaba a medias
	if _slot_tween and _slot_tween.is_running():
		_slot_tween.kill()
		for i in range(_slots.size()):
			_slots[i]["card"].position.x = i * _SLOT_STRIDE

	# Preparar slot extra (oculto a la derecha) con el último de la secuencia
	var tail_entity : BaseEntity = sequence[_SLOT_SHOW] if _SLOT_SHOW < sequence.size() else null
	_set_slot_content(_slots[_SLOT_SHOW], tail_entity, false)
	_slots[_SLOT_SHOW]["card"].position.x = _SLOT_SHOW * _SLOT_STRIDE

	# ── Animar: todos los slots se deslizan a la izquierda ───────────────────
	_slot_tween = create_tween()
	_slot_tween.set_parallel(true)
	for slot in _slots:
		var c : Panel = slot["card"]
		_slot_tween.tween_property(c, "position:x",
			c.position.x - _SLOT_STRIDE, 0.20) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	await _slot_tween.finished

	# ── Post-slide: rotar array y reciclar el primer slot ───────────────────
	var recycled = _slots[0]
	_slots = _slots.slice(1) + [recycled]          # rotación lógica
	recycled["card"].position.x = _SLOT_SHOW * _SLOT_STRIDE  # off-screen derecha

	# Actualizar contenido de todos los slots según la nueva secuencia
	for i in range(_SLOT_SHOW + 1):
		_set_slot_content(_slots[i], sequence[i] if i < sequence.size() else null, i == 0)

# ── Animaciones de ataque ─────────────────────────────────────────────────────

func _on_attack_anim(attacker: BaseEntity, target: BaseEntity, is_magical: bool) -> void:
	var a_cs := attacker.get_parent() as CombatantSprite
	var t_cs := target.get_parent()   as CombatantSprite
	if a_cs == null or t_cs == null:
		return
	if is_magical:
		_play_cast_pulse(a_cs)
		AudioManager.play_sfx("cast_spell")
	else:
		_play_dash(a_cs, t_cs)
	# Flash + SFX de impacto al llegar (0.4 s después)
	get_tree().create_timer(0.4).timeout.connect(func():
		if not is_instance_valid(t_cs):
			return
		t_cs.play_hit_flash(is_magical)
		AudioManager.play_sfx("hit_magic" if is_magical else "hit_physical")
	, CONNECT_ONE_SHOT)

func _play_dash(attacker: CombatantSprite, target: CombatantSprite) -> void:
	var origin    := attacker.position
	var direction := (target.global_position - attacker.global_position).normalized()
	var dest      := origin + direction * 55.0
	var tw := create_tween()
	tw.tween_property(attacker, "position", dest,   0.22).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(attacker, "position", origin, 0.20).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)

func _play_cast_pulse(caster: CombatantSprite) -> void:
	var tw := create_tween()
	tw.tween_property(caster.sprite, "scale", Vector2(4.6, 4.6), 0.18).set_ease(Tween.EASE_OUT)
	tw.tween_property(caster.sprite, "scale", Vector2(4.0, 4.0), 0.18).set_ease(Tween.EASE_IN)
