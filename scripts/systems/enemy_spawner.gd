extends Node
class_name EnemySpawner

enum BossPhase { NONE, ESCORT, BOSS, DONE }

const SCALING_START_WAVE := 11
const HP_SCALING_PER_WAVE := 1.06
const DAMAGE_SCALING_PER_WAVE := 1.04

var spawn_timer: float = 0.0
var enemies_spawned: int = 0
var player: Node2D
var _current_wave_data: WaveData = null
var _is_wave_active: bool = false
var _boss_phase: int = BossPhase.NONE
var _boss_spawned: bool = false

# Map boundaries（_ready() 中从 GameConfig 读取动态值）
var map_min_x: float = 0.0
var map_max_x: float = 0.0
var map_min_y: float = 0.0
var map_max_y: float = 0.0
var min_distance_from_player: float = 100.0

func _ready() -> void:
	map_min_x = -GameConfig.MAP_HALF_WIDTH
	map_max_x = GameConfig.MAP_HALF_WIDTH
	map_min_y = -GameConfig.MAP_HALF_HEIGHT
	map_max_y = GameConfig.MAP_HALF_HEIGHT
	player = get_tree().get_first_node_in_group(Enums.Group.PLAYER)
	# 从配置读取生成距离
	if GameConfig.spawn:
		min_distance_from_player = GameConfig.spawn.min_distance_from_player
	# 连接 EventBus 信号
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.wave_completed.connect(_on_wave_completed)
	EventBus.game_won.connect(_on_game_ended)
	EventBus.game_lost.connect(_on_game_ended)

func _process(delta: float) -> void:
	if not _is_wave_active:
		return

	if _current_wave_data.is_boss_wave:
		_process_boss_wave(delta)
		return

	# 普通波
	spawn_timer -= delta
	if spawn_timer <= 0 and _should_spawn():
		spawn_enemy()
		spawn_timer = _current_wave_data.spawn_interval

func _should_spawn() -> bool:
	if not _current_wave_data:
		return false
	return enemies_spawned < _current_wave_data.total_enemies

## 返回指定波次的缩放倍率，第 11 波开始缩放
static func get_wave_scaling(wave_number: int) -> Dictionary:
	if wave_number < SCALING_START_WAVE:
		return {"hp_mult": 1.0, "damage_mult": 1.0}
	var waves_past: int = wave_number - SCALING_START_WAVE + 1
	return {
		"hp_mult": pow(HP_SCALING_PER_WAVE, waves_past),
		"damage_mult": pow(DAMAGE_SCALING_PER_WAVE, waves_past)
	}

func pick_weighted_enemy(weights: Dictionary) -> String:
	var total_weight: int = 0
	for w: int in weights.values():
		total_weight += w
	var roll: int = randi() % total_weight
	var cumulative: int = 0
	for enemy_id: String in weights:
		cumulative += weights[enemy_id]
		if roll < cumulative:
			return enemy_id
	return weights.keys()[0]

func spawn_enemy() -> void:
	var enemy_type: String = pick_weighted_enemy(_current_wave_data.enemy_weights)
	var enemy: Node = SceneFactory.create_enemy(enemy_type)
	if not enemy:
		return
	var spawn_pos: Vector2 = get_random_spawn_position()
	enemy.global_position = spawn_pos
	enemies_spawned += 1
	get_parent().add_child(enemy)
	# 精英怪检查（必须在 add_child 之后，_ready 已执行）
	if _current_wave_data.elite_chance > 0.0 and randf() < _current_wave_data.elite_chance:
		enemy.apply_elite(
			_current_wave_data.elite_hp_mult,
			_current_wave_data.elite_damage_mult,
			_current_wave_data.elite_coin_mult,
			_current_wave_data.elite_scale,
			_current_wave_data.elite_exp_mult
		)
	# 波次缩放（仅非 Boss 敌人，在精英化之后叠加）
	if not enemy.data.is_boss:
		var scaling = get_wave_scaling(_current_wave_data.wave_number)
		if scaling.hp_mult > 1.0:
			enemy.health.max_hp *= scaling.hp_mult
			enemy.health.current_hp = enemy.health.max_hp
			enemy._hitbox.damage *= scaling.damage_mult
			enemy.tower_attack_damage *= scaling.damage_mult

func get_random_spawn_position() -> Vector2:
	var spawn_pos = Vector2.ZERO
	var attempts = 0
	var max_attempts: int = GameConfig.spawn.max_spawn_attempts if GameConfig.spawn else 10

	while attempts < max_attempts:
		spawn_pos.x = randf_range(map_min_x, map_max_x)
		spawn_pos.y = randf_range(map_min_y, map_max_y)

		if player and player.global_position.distance_to(spawn_pos) >= min_distance_from_player:
			break
		attempts += 1

	return spawn_pos

func _process_boss_wave(delta: float) -> void:
	match _boss_phase:
		BossPhase.ESCORT:
			spawn_timer -= delta
			if spawn_timer <= 0 and _should_spawn_escort():
				spawn_enemy()
				spawn_timer = _current_wave_data.spawn_interval
			if not _should_spawn_escort():
				_boss_phase = BossPhase.BOSS
		BossPhase.BOSS:
			if not _boss_spawned:
				_spawn_boss()
				_boss_phase = BossPhase.DONE
		BossPhase.DONE:
			pass

func _should_spawn_escort() -> bool:
	return enemies_spawned < _current_wave_data.boss_escort_count

func _spawn_boss() -> void:
	var boss: Node = SceneFactory.create_enemy(_current_wave_data.boss_id)
	if not boss:
		push_error("无法创建 Boss: " + _current_wave_data.boss_id)
		return
	var spawn_pos: Vector2 = get_random_spawn_position()
	boss.global_position = spawn_pos
	_boss_spawned = true
	get_parent().add_child(boss)
	AudioManager.play("boss_appear")

func _on_wave_started(_wave_number: int, wave_data: WaveData) -> void:
	_current_wave_data = wave_data
	_is_wave_active = true
	spawn_timer = 0.0
	enemies_spawned = 0
	_boss_spawned = false
	if wave_data.is_boss_wave:
		_boss_phase = BossPhase.ESCORT
	else:
		_boss_phase = BossPhase.NONE

func _on_wave_completed(_wave_number: int) -> void:
	_is_wave_active = false

func _on_game_ended() -> void:
	_is_wave_active = false
