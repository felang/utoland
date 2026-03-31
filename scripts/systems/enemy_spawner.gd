extends Node
class_name EnemySpawner

const HP_SCALING_PER_WAVE: float = 0.055
const DAMAGE_SCALING_START_WAVE: int = 9
const DAMAGE_SCALING_PER_WAVE: float = 0.0375

var spawn_points: Array[Vector2] = []  # 由 main.gd 从 MapLayout 传入
var spawn_timer: float = 0.0
var player: Node2D
var _current_wave_data: WaveData = null
var _is_wave_active: bool = false
var _boss_spawned: bool = false

# 分段生成状态
var _current_phase_index: int = 0
var _phase_time_elapsed: float = 0.0
var _phase_duration: float = 0.0
var _current_spawn_interval: float = 1.0
var _current_enemy_weights: Dictionary = {}

# 地图边界
var map_min_x: float = 0.0
var map_max_x: float = 0.0
var map_min_y: float = 0.0
var map_max_y: float = 0.0
var min_distance_from_player: float = 200.0

func _ready() -> void:
	map_min_x = -GameConfig.MAP_HALF_WIDTH
	map_max_x = GameConfig.MAP_HALF_WIDTH
	map_min_y = -GameConfig.MAP_HALF_HEIGHT
	map_max_y = GameConfig.MAP_HALF_HEIGHT
	if GameConfig.spawn:
		min_distance_from_player = GameConfig.spawn.min_distance_from_player
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.wave_completed.connect(_on_wave_completed)
	EventBus.game_won.connect(_on_game_ended)
	EventBus.game_lost.connect(_on_game_ended)

func _process(delta: float) -> void:
	if not _is_wave_active:
		return
	_phase_time_elapsed += delta
	_check_phase_transition()
	# Boss 波次：最后阶段时生成 Boss
	if _should_spawn_boss():
		_spawn_boss()
	# max_alive 检查
	var alive_count: int = get_tree().get_nodes_in_group(Enums.Group.ENEMIES).size()
	if alive_count >= _current_wave_data.max_alive_enemies:
		return
	# 生成计时
	spawn_timer -= delta
	if spawn_timer <= 0:
		_spawn_normal_enemy()
		spawn_timer = _current_spawn_interval

func _check_phase_transition() -> void:
	if not _current_wave_data or _current_wave_data.spawn_phases.is_empty():
		return
	# 最后阶段不切换
	if _current_phase_index >= _current_wave_data.spawn_phases.size() - 1:
		return
	if _phase_time_elapsed >= _phase_duration:
		_enter_phase(_current_phase_index + 1)

func _enter_phase(index: int) -> void:
	_current_phase_index = index
	var phase: SpawnPhaseData = _current_wave_data.spawn_phases[index]
	_phase_duration = _current_wave_data.time_limit * phase.duration_ratio
	_phase_time_elapsed = 0.0
	_current_spawn_interval = phase.spawn_interval
	_current_enemy_weights = phase.enemy_weights if not phase.enemy_weights.is_empty() else _current_wave_data.enemy_weights

func _should_spawn_boss() -> bool:
	if not _current_wave_data or not _current_wave_data.is_boss_wave:
		return false
	return _current_phase_index == _current_wave_data.spawn_phases.size() - 1 and not _boss_spawned

static func get_wave_scaling(wave_number: int) -> Dictionary:
	var hp_mult: float = 1.0 + (wave_number - 1) * HP_SCALING_PER_WAVE
	var damage_mult: float = 1.0
	if wave_number >= DAMAGE_SCALING_START_WAVE:
		damage_mult = 1.0 + (wave_number - DAMAGE_SCALING_START_WAVE) * DAMAGE_SCALING_PER_WAVE
	return {"hp_mult": hp_mult, "damage_mult": damage_mult}

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

func _spawn_normal_enemy() -> void:
	var enemy_type: String = pick_weighted_enemy(_current_enemy_weights)
	var enemy: Node = SceneFactory.create_enemy(enemy_type)
	if not enemy:
		return
	var spawn_pos: Vector2 = get_random_spawn_position()
	enemy.global_position = spawn_pos
	SceneFactory.get_entity_layer().add_child(enemy)
	# 精英怪检查
	if _current_wave_data.elite_chance > 0.0 and randf() < _current_wave_data.elite_chance:
		enemy.apply_elite(
			_current_wave_data.elite_hp_mult,
			_current_wave_data.elite_damage_mult,
			_current_wave_data.elite_scale,
			_current_wave_data.elite_exp_mult
		)
	# 波次缩放
	if not enemy.data.is_boss:
		var scaling = get_wave_scaling(_current_wave_data.wave_number)
		if scaling.hp_mult > 1.0:
			enemy.health.max_hp *= scaling.hp_mult
			enemy.health.current_hp = enemy.health.max_hp
			enemy._hitbox.damage *= scaling.damage_mult

func _spawn_boss() -> void:
	var boss: Node = SceneFactory.create_enemy(_current_wave_data.boss_id)
	if not boss:
		push_error("无法创建 Boss: " + _current_wave_data.boss_id)
		return
	var spawn_pos: Vector2 = get_random_spawn_position()
	boss.global_position = spawn_pos
	_boss_spawned = true
	SceneFactory.get_entity_layer().add_child(boss)
	AudioManager.play("boss_appear")

func get_random_spawn_position() -> Vector2:
	if spawn_points.is_empty():
		return _legacy_random_position()
	var base_pos := spawn_points[randi() % spawn_points.size()]
	var offset := Vector2(randf_range(-16, 16), randf_range(-16, 16))
	return base_pos + offset

func _legacy_random_position() -> Vector2:
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

func _on_wave_started(_wave_number: int, wave_data: WaveData) -> void:
	if player == null:
		player = get_tree().get_first_node_in_group(Enums.Group.PLAYER)
	_current_wave_data = wave_data
	_is_wave_active = true
	spawn_timer = 0.0
	_boss_spawned = false
	if wave_data.spawn_phases.size() > 0:
		_enter_phase(0)
	else:
		_current_spawn_interval = 1.0
		_current_enemy_weights = wave_data.enemy_weights

func _on_wave_completed(_wave_number: int) -> void:
	_is_wave_active = false

func _on_game_ended() -> void:
	_is_wave_active = false
