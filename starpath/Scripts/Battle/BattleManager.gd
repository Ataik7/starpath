class_name BattleManager
extends Node

# Máquina de Estados
enum BattleState { STARTING, NEXT_TURN, PLAYER_INPUT, SELECTING_TARGET, ENEMY_TURN, WON, LOST }
var current_state: BattleState = BattleState.STARTING

var _pending_attacker: BaseEntity = null
var _pending_skill: SkillData     = null
var _pending_item: ItemData       = null
var _current_entity: BaseEntity   = null   # Bug 4: evita active_index - 1 cuando es 0

# Recompensas de victoria (se leen desde BattleScene)
var victory_xp:    int   = 0
var victory_gold:  int   = 0
var victory_items: Array = []   # Array[Dictionary] {name, effect, amount}

# Referencias a los componentes de Lógica
@export var turn_queue: TurnQueue

# Señales para que la Interfaz Gráfica escuche
signal text_log_updated(message: String)
signal action_menu_toggled(show: bool)
signal battle_ended(player_won: bool)
signal battle_fled
signal active_entity_changed(entity: BaseEntity)
signal target_selection_needed(enemies: Array[BaseEntity])
signal ally_target_selection_needed(allies: Array[BaseEntity])
signal attack_animation_needed(attacker: BaseEntity, target: BaseEntity, is_magical: bool)

func _ready() -> void:
	if not turn_queue:
		push_error("BattleManager: No se ha asignado un TurnQueue.")
		return

# BUCLE PRINCIPAL DEL COMBATE

func start_battle(heroes: Array[BaseEntity], enemies: Array[BaseEntity]) -> void:
	current_state = BattleState.STARTING
	_log("¡El combate comienza!")
	
	# Inicializar cola
	var all_combatants: Array[BaseEntity] = []
	all_combatants.append_array(heroes)
	all_combatants.append_array(enemies)
	
	turn_queue.setup_queue(all_combatants)
	
	# Pausa inicial
	await get_tree().create_timer(1.0).timeout
	advance_to_next_turn()

func advance_to_next_turn() -> void:
	# 1. Comprobar si alguien ha ganado antes de dar el turno
	if _check_battle_end():
		return
		
	current_state = BattleState.NEXT_TURN
	
	# 2. Pedimos a la cola de turnos quién va ahora
	var active_entity = turn_queue.get_next_entity()
	_current_entity = active_entity   # Bug 4: guardar referencia directa
	_log("Es el turno de: " + active_entity.stats.character_name)
	active_entity_changed.emit(active_entity)

	await get_tree().create_timer(0.5).timeout
	
	# 3. Decidimos qué pasa según quién sea el atacante
	if active_entity.get_parent().is_in_group("Heroes"):
		current_state = BattleState.PLAYER_INPUT
		_log("Esperando tu orden...")
		action_menu_toggled.emit(true) # Avisamos a la UI para mostrar botones
	else:
		current_state = BattleState.ENEMY_TURN
		action_menu_toggled.emit(false) # Ocultamos botones
		_execute_enemy_ai(active_entity)

func _execute_enemy_ai(enemy: BaseEntity) -> void:
	_log("El enemigo " + enemy.stats.character_name + " está pensando...")
	await get_tree().create_timer(1.0).timeout

	var alive_heroes = _get_alive_heroes()
	# Sin héroes vivos — comprobar derrota en lugar de avanzar turno (Bug 6: bucle infinito)
	if alive_heroes.is_empty():
		_check_battle_end()
		return

	var target = alive_heroes[randi() % alive_heroes.size()]

	# Habilidades con MP suficiente
	var usable_skills := enemy.stats.skills.filter(
		func(sk: SkillData) -> bool: return enemy.current_mp >= sk.mp_cost
	) as Array[SkillData]

	# 40% de probabilidad de usar habilidad si tiene alguna disponible
	if not usable_skills.is_empty() and randf() < 0.40:
		await _enemy_use_skill(enemy, target, usable_skills[randi() % usable_skills.size()])
	else:
		await _enemy_basic_attack(enemy, target)

	await get_tree().create_timer(1.0).timeout
	advance_to_next_turn()

func _enemy_use_skill(enemy: BaseEntity, target: BaseEntity, skill: SkillData) -> void:
	_log(enemy.stats.character_name + " usa " + skill.skill_name + "!")
	await get_tree().create_timer(0.3).timeout
	attack_animation_needed.emit(enemy, target, skill.is_magical)
	await get_tree().create_timer(0.4).timeout
	enemy.spend_mp(skill.mp_cost)
	target.take_damage(skill.damage, skill.is_magical)
	var tipo = "mágico" if skill.is_magical else "físico"
	_log("¡" + skill.skill_name + "! " + target.stats.character_name + " recibe daño " + tipo + ".")

func _enemy_basic_attack(enemy: BaseEntity, target: BaseEntity) -> void:
	_log(enemy.stats.character_name + " ataca ferozmente.")
	await get_tree().create_timer(0.3).timeout
	attack_animation_needed.emit(enemy, target, false)
	await get_tree().create_timer(0.4).timeout
	# Reducción por nivel
	var damage = maxi(1, enemy.stats.attack - Inventory.get_level_def_bonus())
	target.take_damage(damage)
	_log(enemy.stats.character_name + " ataca a " + target.stats.character_name + ". ¡Ay!")

func player_action_selected(action_name: String) -> void:
	if current_state != BattleState.PLAYER_INPUT:
		return

	var attacker = _current_entity   # Bug 4: era active_index-1, índice -1 cuando 0

	if action_name == "Atacar":
		# Entra en selección de objetivo igual que las habilidades
		action_menu_toggled.emit(false)
		_pending_attacker = attacker
		_pending_skill    = null
		_pending_item     = null
		current_state     = BattleState.SELECTING_TARGET
		target_selection_needed.emit(_get_alive_enemies())
		return

	action_menu_toggled.emit(false)
	_log(attacker.stats.character_name + " usa " + action_name + "!")
	await get_tree().create_timer(1.0).timeout

	if action_name == "Curar":
		var success = attacker.heal_self()
		if success:
			AudioManager.play_sfx("heal")
			_log(attacker.stats.character_name + " se cura y recupera HP.")
		else:
			_log("¡MP insuficiente para curar!")
	elif action_name == "Defender":
		attacker.is_defending = true
		attacker.defense_changed.emit(true)
		AudioManager.play_sfx("defend")
		_log(attacker.stats.character_name + " se pone en guardia. ¡El siguiente golpe hará menos daño!")

	await get_tree().create_timer(1.0).timeout
	advance_to_next_turn()

# Hechizo elegido
func player_skill_selected(skill: SkillData) -> void:
	if current_state != BattleState.PLAYER_INPUT:
		return

	var attacker = _current_entity   # Bug 4
	action_menu_toggled.emit(false)

	if skill.targets_enemy:
		_start_target_selection(attacker, skill)
	else:
		# Hechizo sin objetivo
		_log(attacker.stats.character_name + " lanza " + skill.skill_name + "!")
		await get_tree().create_timer(1.0).timeout
		if attacker.spend_mp(skill.mp_cost):
			attacker.heal_hp(skill.damage)   # Bug 5: heal_self(-dmg,0) era llamada incorrecta
		else:
			_log("¡MP insuficiente!")
		await get_tree().create_timer(1.0).timeout
		advance_to_next_turn()

# Objetivo confirmado
func player_target_confirmed(target: BaseEntity) -> void:
	if current_state != BattleState.SELECTING_TARGET:
		return

	current_state = BattleState.PLAYER_INPUT
	var _empty: Array[BaseEntity] = []
	target_selection_needed.emit(_empty)
	ally_target_selection_needed.emit(_empty)

	var attacker = _pending_attacker
	var skill    = _pending_skill
	var item     = _pending_item
	_pending_item = null

	if item != null:
		_log(attacker.stats.character_name + " usa " + item.item_name + " en " + target.stats.character_name + "!")
		await get_tree().create_timer(1.0).timeout
		Inventory.use_item(item)
		match item.effect_type:
			"heal_hp":
				target.heal_hp(item.amount)
				_log(target.stats.character_name + " recupera " + str(item.amount) + " HP.")
			"heal_mp":
				target.heal_mp(item.amount)
				_log(target.stats.character_name + " recupera " + str(item.amount) + " MP.")
			"damage":
				target.take_damage(item.amount)
				_log("¡" + item.item_name + "! " + target.stats.character_name + " recibe daño.")
	elif skill != null:
		_log(attacker.stats.character_name + " lanza " + skill.skill_name + "!")
		await get_tree().create_timer(0.3).timeout
		attack_animation_needed.emit(attacker, target, skill.is_magical)
		await get_tree().create_timer(0.4).timeout
		if attacker.spend_mp(skill.mp_cost):
			target.take_damage(skill.damage, skill.is_magical)
			var tipo = "mágico" if skill.is_magical else "físico"
			_log("¡" + skill.skill_name + "! " + target.stats.character_name + " recibe daño " + tipo + ".")
		else:
			_log("¡MP insuficiente para " + skill.skill_name + "!")
	else:
		_log(attacker.stats.character_name + " ataca a " + target.stats.character_name + "!")
		await get_tree().create_timer(0.3).timeout
		attack_animation_needed.emit(attacker, target, false)
		await get_tree().create_timer(0.4).timeout
		var equip_bonus := Inventory.get_attack_bonus() + Inventory.get_level_atk_bonus() \
				if attacker.get_parent().is_in_group("Heroes") else 0
		target.take_damage(attacker.stats.attack + equip_bonus)
		_log("¡PUM! " + target.stats.character_name + " recibe daño.")

	await get_tree().create_timer(1.0).timeout
	advance_to_next_turn()

func player_flee() -> void:
	if current_state != BattleState.PLAYER_INPUT:
		return
	action_menu_toggled.emit(false)
	# 75% de éxito; si falla el enemigo aprovecha para atacar
	if randf() < 0.75:
		_log("¡Huiste del combate!")
		current_state = BattleState.LOST
		await get_tree().create_timer(1.0).timeout
		battle_fled.emit()
	else:
		_log("¡No pudiste escapar!")
		await get_tree().create_timer(1.0).timeout
		advance_to_next_turn()

func player_item_selected(item: ItemData) -> void:
	if current_state != BattleState.PLAYER_INPUT:
		return
	var attacker = _current_entity   # Bug 4
	action_menu_toggled.emit(false)
	_pending_attacker = attacker
	_pending_item     = item
	_pending_skill    = null
	current_state     = BattleState.SELECTING_TARGET
	if item.targets_enemy:
		target_selection_needed.emit(_get_alive_enemies())
	else:
		ally_target_selection_needed.emit(_get_alive_heroes())

# Cancelar objetivo
func player_target_cancelled() -> void:
	if current_state != BattleState.SELECTING_TARGET:
		return
	_pending_item = null
	current_state = BattleState.PLAYER_INPUT
	var _empty: Array[BaseEntity] = []
	target_selection_needed.emit(_empty)
	ally_target_selection_needed.emit(_empty)
	action_menu_toggled.emit(true)

# COMPROBACIÓN DE VICTORIA/DERROTA

func _check_battle_end() -> bool:
	var heroes_alive = false
	var enemies_alive = false
	
	for entity in turn_queue.queue:
		if entity.is_alive:
			if entity.get_parent().is_in_group("Heroes"):
				heroes_alive = true
			elif entity.get_parent().is_in_group("Enemies"):
				enemies_alive = true
				
	if not heroes_alive:
		_log("¡Derrota! Todos los héroes han caído.")
		current_state = BattleState.LOST
		battle_ended.emit(false) # false = el jugador no ganó
		return true
	elif not enemies_alive:
		# Calcular recompensas
		victory_xp    = 0
		victory_gold  = 0
		victory_items = []
		for entity in turn_queue.queue:
			if entity.get_parent().is_in_group("Enemies") and not entity.is_alive:
				var xp_val := entity.stats.xp_reward
				if xp_val <= 0:
					xp_val = (entity.stats.max_hp >> 1) + entity.stats.attack
				victory_xp   += xp_val
				victory_gold += entity.stats.gold_reward
		_log("¡Victoria! Los enemigos han sido derrotados.")
		_log("+ %d EXP   + %d G" % [victory_xp, victory_gold])
		current_state = BattleState.WON
		battle_ended.emit(true)
		return true
		
	return false # Si ambos equipos tienen vivos, el combate sigue

# FUNCIONES AUXILIARES (HELPERS)

func _log(message: String) -> void:
	print(message)
	text_log_updated.emit(message)
	
func _start_target_selection(attacker: BaseEntity, skill: SkillData) -> void:
	current_state    = BattleState.SELECTING_TARGET
	_pending_attacker = attacker
	_pending_skill    = skill
	target_selection_needed.emit(_get_alive_enemies())

func _get_alive_enemies() -> Array[BaseEntity]:
	var result: Array[BaseEntity] = []
	for entity in turn_queue.queue:
		if entity.get_parent().is_in_group("Enemies") and entity.is_alive:
			result.append(entity)
	return result

func _get_first_enemy() -> BaseEntity:
	for entity in turn_queue.queue:
		if entity.get_parent().is_in_group("Enemies") and entity.is_alive:
			return entity
	return null

func _get_alive_heroes() -> Array[BaseEntity]:
	var result: Array[BaseEntity] = []
	for entity in turn_queue.queue:
		if entity.get_parent().is_in_group("Heroes") and entity.is_alive:
			result.append(entity)
	return result

func _get_first_hero() -> BaseEntity:
	for entity in turn_queue.queue:
		if entity.get_parent().is_in_group("Heroes") and entity.is_alive:
			return entity
	return null
