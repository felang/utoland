class_name SynergyEffectProcessor
extends Node

## 羁绊效果处理器 — 管理 3/5 档羁绊的机制型效果
## 作为 Node 挂载在 main 战斗场景下，支持 _process / 计时器

# ===== 狂热 (Assault 3) =====
var _frenzy_active: bool = false
var _frenzy_timer: float = 0.0
var _frenzy_duration: float = 3.0

# ===== 应急护盾 (Fortify 3) =====
# {tower_instance_id: cooldown_remaining}
var _shield_cooldowns: Dictionary = {}
const SHIELD_CHECK_INTERVAL: float = 0.5
var _shield_check_timer: float = 0.0

# ===== 不屈 (Fortify 5) =====
# {tower_instance_id: true} — 已使用复活的塔
var _revived_towers: Dictionary = {}
# 复活队列 [{tower_type, level, position, timer}]
var _revive_queue: Array[Dictionary] = []

# ===== 战术轰炸 (Blast 5) =====
var _tactical_bomb_timer: float = 0.0
var _tactical_bomb_interval: float = 15.0
var _tactical_bomb_count: int = 3

# ===== 溢杀 (Assault 5) =====
# 由 HealthComponent 在 died 时记录，processor 读取
# 实际实现：监听 enemy_killed，通过最后伤害推算

# ===== 连锁控制 (Control 5) =====
# 标记：由 SlowHandler 在减速到期时触发
# 由 _on_timed_slow_expired 中检查

var _is_active: bool = false

func _ready() -> void:
	add_to_group("synergy_processor")
	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.synergy_changed.connect(_on_synergy_changed)
	EventBus.tower_destroyed.connect(_on_tower_destroyed)


func activate() -> void:
	_is_active = true

func deactivate() -> void:
	_is_active = false

func _process(delta: float) -> void:
	if not _is_active:
		return
	# 狂热计时
	if _frenzy_active:
		_frenzy_timer -= delta
		if _frenzy_timer <= 0.0:
			_deactivate_frenzy()

	# 应急护盾冷却 & 检测
	_update_shield_cooldowns(delta)
	_shield_check_timer -= delta
	if _shield_check_timer <= 0.0:
		_shield_check_timer = SHIELD_CHECK_INTERVAL
		_check_emergency_shields()

	# 战术轰炸
	if _is_tier_active(Enums.Tag.BLAST, 5):
		_tactical_bomb_timer -= delta
		if _tactical_bomb_timer <= 0.0:
			_tactical_bomb_timer = _tactical_bomb_interval
			_execute_tactical_bombing()

	# 不屈复活队列
	_update_revive_queue(delta)


# ===== 公共查询接口 =====

## 狂热是否激活（武器/塔查询用）
func is_frenzy_active() -> bool:
	return _frenzy_active


## 获取脆弱伤害倍率（敌人受伤时查询）
func get_vulnerable_mult(enemy: Node2D) -> float:
	if not _is_tier_active(Enums.Tag.CONTROL, 3):
		return 1.0
	# 检查敌人是否处于减速或定身状态
	if _is_enemy_controlled(enemy):
		var synergy: SynergyData = GameConfig.synergies.get(Enums.Tag.CONTROL)
		if synergy:
			return 1.0 + synergy.tier3_value  # 1.0 + 0.2 = 1.2
	return 1.0


## 获取殉爆参数（塔 AOE 攻击时查询）
## 返回 {chance: float, damage_mult: float} 或空字典
func get_chain_blast_params() -> Dictionary:
	if not _is_tier_active(Enums.Tag.BLAST, 3):
		return {}
	var synergy: SynergyData = GameConfig.synergies.get(Enums.Tag.BLAST)
	if not synergy:
		return {}
	return {chance = synergy.tier3_value, damage_mult = synergy.tier3_value_2}


## 检查是否应触发连锁控制（SlowHandler 到期时调用）
func should_chain_freeze() -> bool:
	return _is_tier_active(Enums.Tag.CONTROL, 5)


## 检查是否启用自增益（TowerBuff 查询）
func is_self_boost_active() -> bool:
	return _is_tier_active(Enums.Tag.BOOST, 3)


## 检查是否启用全域共享（TowerBuff/TowerGenerator 查询）
func is_global_boost_active() -> bool:
	return _is_tier_active(Enums.Tag.BOOST, 5)


# ===== 内部方法 =====

func _is_tier_active(tag: String, tier: int) -> bool:
	return GameData.synergy_active_tiers.get(tag, 0) >= tier


func _is_enemy_controlled(enemy: Node2D) -> bool:
	# 检查是否被定身
	if "is_rooted" in enemy and enemy.is_rooted:
		return true
	# 检查是否被减速
	if enemy.has_node("SlowHandler"):
		var handler: SlowHandler = enemy.get_node("SlowHandler")
		if not handler._active_slows.is_empty():
			return true
	return false


# ===== Assault 3: 狂热 =====

func _on_enemy_killed(_enemy_type: String, _position: Vector2, _is_elite: bool) -> void:
	# 狂热：assault 3 档激活时，击杀触发全队加速
	if _is_tier_active(Enums.Tag.ASSAULT, 3):
		_activate_frenzy()
	# 溢杀：assault 5 档，由 HealthComponent 扩展处理（见 health_component.gd 修改）


func _activate_frenzy() -> void:
	var synergy: SynergyData = GameConfig.synergies.get(Enums.Tag.ASSAULT)
	if not synergy:
		return
	_frenzy_duration = synergy.tier3_duration  # 3 秒
	_frenzy_timer = _frenzy_duration
	if not _frenzy_active:
		_frenzy_active = true
		# 对所有 assault 标签的塔应用攻速 buff
		_apply_frenzy_to_towers()
	EventBus.synergy_effect_triggered.emit(Enums.Tag.ASSAULT, "frenzy")


func _deactivate_frenzy() -> void:
	_frenzy_active = false
	_frenzy_timer = 0.0
	# 移除塔的狂热 buff
	_remove_frenzy_from_towers()


func _apply_frenzy_to_towers() -> void:
	if not is_inside_tree():
		return
	var towers: Array[Node] = get_tree().get_nodes_in_group(Enums.Group.TOWERS)
	for tower_node in towers:
		if tower_node is Tower and _is_unit_tagged(tower_node.tower_type, Enums.Tag.ASSAULT):
			tower_node.apply_buff(1.0, 2.0, "synergy_frenzy")


func _remove_frenzy_from_towers() -> void:
	if not is_inside_tree():
		return
	var towers: Array[Node] = get_tree().get_nodes_in_group(Enums.Group.TOWERS)
	for tower_node in towers:
		if tower_node is Tower:
			tower_node.remove_buff("synergy_frenzy")


func _is_unit_tagged(unit_id: String, tag: String) -> bool:
	if not GameData._synergy_manager:
		return false
	return GameData._synergy_manager.get_tag(unit_id) == tag


# ===== Fortify 3: 应急护盾 =====

func _update_shield_cooldowns(delta: float) -> void:
	var to_remove: Array = []
	for key in _shield_cooldowns:
		_shield_cooldowns[key] -= delta
		if _shield_cooldowns[key] <= 0.0:
			to_remove.append(key)
	for key in to_remove:
		_shield_cooldowns.erase(key)


func _check_emergency_shields() -> void:
	if not _is_tier_active(Enums.Tag.FORTIFY, 3):
		return
	if not is_inside_tree():
		return
	var synergy: SynergyData = GameConfig.synergies.get(Enums.Tag.FORTIFY)
	if not synergy:
		return
	var hp_threshold: float = synergy.tier3_value  # 0.3 = 30%
	var shield_duration: float = synergy.tier3_duration  # 3 秒
	var cooldown: float = synergy.tier3_value_2  # 10 秒

	var towers: Array[Node] = get_tree().get_nodes_in_group(Enums.Group.TOWERS)
	for tower_node in towers:
		if not (tower_node is Tower):
			continue
		if not _is_unit_tagged(tower_node.tower_type, Enums.Tag.FORTIFY):
			continue
		var tid: int = tower_node.get_instance_id()
		# 冷却中跳过
		if _shield_cooldowns.has(tid):
			continue
		# 已有护盾跳过
		if tower_node.health.invincible:
			continue
		# 检查血量阈值
		if tower_node.health.current_hp > 0 and tower_node.health.current_hp / tower_node.health.max_hp < hp_threshold:
			tower_node.health.invincible = true
			_shield_cooldowns[tid] = cooldown
			# 护盾到期后取消无敌
			get_tree().create_timer(shield_duration).timeout.connect(
				_on_shield_expired.bind(tower_node)
			)
			EventBus.synergy_effect_triggered.emit(Enums.Tag.FORTIFY, "emergency_shield")


func _on_shield_expired(tower: Tower) -> void:
	if is_instance_valid(tower):
		tower.health.invincible = false


# ===== Fortify 5: 不屈 =====

func _on_tower_destroyed(tower_type: String, position: Vector2) -> void:
	if not _is_tier_active(Enums.Tag.FORTIFY, 5):
		return
	if not _is_unit_tagged(tower_type, Enums.Tag.FORTIFY):
		return
	# 查找对应的 deployed_tower 条目获取等级
	var level: int = 1
	for entry in GameData.deployed_towers:
		if entry.id == tower_type:
			level = entry.level
			break
	# 检查是否已复活过（用 tower_type + position 作为 key）
	var revive_key: String = tower_type + "_" + str(position)
	if _revived_towers.has(revive_key):
		return
	_revived_towers[revive_key] = true
	var synergy: SynergyData = GameConfig.synergies.get(Enums.Tag.FORTIFY)
	if not synergy:
		return
	var revive_delay: float = synergy.tier5_value  # 5 秒
	var hp_ratio: float = synergy.tier5_value_2  # 0.5 = 50%
	_revive_queue.append({
		tower_type = tower_type,
		level = level,
		position = position,
		timer = revive_delay,
		hp_ratio = hp_ratio
	})
	EventBus.synergy_effect_triggered.emit(Enums.Tag.FORTIFY, "undying")


func _update_revive_queue(delta: float) -> void:
	var completed: Array[int] = []
	for i in range(_revive_queue.size()):
		_revive_queue[i].timer -= delta
		if _revive_queue[i].timer <= 0.0:
			completed.append(i)
	# 逆序移除，避免索引偏移
	for i in range(completed.size() - 1, -1, -1):
		var entry: Dictionary = _revive_queue[completed[i]]
		_revive_queue.remove_at(completed[i])
		_spawn_revived_tower(entry)


func _spawn_revived_tower(entry: Dictionary) -> void:
	if not is_inside_tree():
		return
	var tower: Node2D = SceneFactory.create_tower(entry.tower_type, entry.level)
	if not tower:
		return
	tower.global_position = entry.position
	# 找到塔容器
	var tower_container: Node = get_parent().get_node_or_null("TowerContainer")
	if tower_container:
		tower_container.add_child(tower)
	else:
		get_parent().add_child(tower)
	# 设置为 50% 血量
	await get_tree().process_frame
	if is_instance_valid(tower) and tower.health:
		tower.health.current_hp = tower.health.max_hp * entry.hp_ratio


# ===== Blast 5: 战术轰炸 =====

func _execute_tactical_bombing() -> void:
	if not is_inside_tree():
		return
	var enemies: Array[Node] = get_tree().get_nodes_in_group(Enums.Group.ENEMIES)
	if enemies.is_empty():
		return
	var synergy: SynergyData = GameConfig.synergies.get(Enums.Tag.BLAST)
	if not synergy:
		return
	# 计算轰炸伤害：基于 blast 标签塔的平均伤害
	var blast_damage: float = _calculate_blast_bomb_damage()
	# 找到最密集的敌人位置
	var bomb_positions: Array[Vector2] = _find_dense_enemy_positions(enemies, _tactical_bomb_count)
	var bomb_radius: float = 40.0  # 轰炸半径
	for pos in bomb_positions:
		# 对范围内敌人造成伤害
		for enemy_node in enemies:
			if not is_instance_valid(enemy_node):
				continue
			if enemy_node.global_position.distance_to(pos) <= bomb_radius:
				if enemy_node.has_method("take_damage"):
					enemy_node.take_damage(blast_damage)
		# 视觉特效
		EffectsManager.spawn_death_effect(pos, Color.ORANGE)
	EventBus.synergy_effect_triggered.emit(Enums.Tag.BLAST, "tactical_bomb")


func _calculate_blast_bomb_damage() -> float:
	# 基于已部署的 blast 标签塔的平均伤害
	var total_damage: float = 0.0
	var count: int = 0
	for entry in GameData.deployed_towers:
		if _is_unit_tagged(entry.id, Enums.Tag.BLAST):
			var tower_data: TowerData = GameConfig.towers.get(entry.id)
			if tower_data and tower_data.damage_per_level.size() > entry.level - 1:
				total_damage += tower_data.damage_per_level[entry.level - 1]
				count += 1
	if count == 0:
		return 30.0  # 默认伤害
	return total_damage / count


func _find_dense_enemy_positions(enemies: Array[Node], count: int) -> Array[Vector2]:
	if enemies.size() <= count:
		var positions: Array[Vector2] = []
		for e in enemies:
			if is_instance_valid(e):
				positions.append(e.global_position)
		return positions
	# 简单贪心：逐个选择周围敌人最多的位置
	var positions: Array[Vector2] = []
	var used: Array[int] = []
	for _i in range(count):
		var best_idx: int = -1
		var best_count: int = 0
		for j in range(enemies.size()):
			if j in used or not is_instance_valid(enemies[j]):
				continue
			var nearby: int = 0
			for k in range(enemies.size()):
				if k == j or not is_instance_valid(enemies[k]):
					continue
				if enemies[j].global_position.distance_to(enemies[k].global_position) <= 50.0:
					nearby += 1
			if nearby > best_count or best_idx == -1:
				best_count = nearby
				best_idx = j
		if best_idx >= 0:
			positions.append(enemies[best_idx].global_position)
			used.append(best_idx)
	return positions


# ===== Assault 5: 溢杀 =====

## 由 HealthComponent 调用：敌人死亡时传入溢杀伤害
func handle_overkill(overkill_damage: float, death_position: Vector2) -> void:
	if not _is_tier_active(Enums.Tag.ASSAULT, 5):
		return
	if overkill_damage <= 0.0:
		return
	var synergy: SynergyData = GameConfig.synergies.get(Enums.Tag.ASSAULT)
	if not synergy:
		return
	var explosion_damage: float = overkill_damage * synergy.tier5_value  # * 0.3
	if explosion_damage < 1.0:
		return
	if not is_inside_tree():
		return
	# 对周围敌人造成溢杀爆炸伤害
	var explosion_radius: float = 40.0
	var enemies: Array[Node] = get_tree().get_nodes_in_group(Enums.Group.ENEMIES)
	for enemy_node in enemies:
		if not is_instance_valid(enemy_node):
			continue
		if enemy_node.global_position.distance_to(death_position) <= explosion_radius:
			if enemy_node.has_method("take_damage"):
				enemy_node.take_damage(explosion_damage)
	EffectsManager.spawn_hit_sparks(death_position)
	EventBus.synergy_effect_triggered.emit(Enums.Tag.ASSAULT, "overkill")


# ===== 羁绊变化处理 =====

func _on_synergy_changed(tag: String, _old_tier: int, new_tier: int) -> void:
	# 狂热失效时清理
	if tag == Enums.Tag.ASSAULT and new_tier < 3:
		if _frenzy_active:
			_deactivate_frenzy()
	# 战术轰炸重置计时器
	if tag == Enums.Tag.BLAST and new_tier >= 5:
		_tactical_bomb_timer = _tactical_bomb_interval


# ===== 清理 =====

func _exit_tree() -> void:
	_deactivate_frenzy()
	_revive_queue.clear()
	_shield_cooldowns.clear()
