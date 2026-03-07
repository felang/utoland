extends Node

var spawn_timer: float = 0.0
var player: Node2D
var _current_wave_config: Dictionary = {}
var _is_wave_active: bool = false

# Map boundaries
var map_min_x: float = -GameConfig.MAP_HALF_WIDTH
var map_max_x: float = GameConfig.MAP_HALF_WIDTH
var map_min_y: float = -GameConfig.MAP_HALF_HEIGHT
var map_max_y: float = GameConfig.MAP_HALF_HEIGHT
var min_distance_from_player: float = 200.0

func _ready():
	player = get_tree().get_first_node_in_group("player")
	# 从配置读取生成距离
	if GameConfig.spawn:
		min_distance_from_player = GameConfig.spawn.min_distance_from_player
	# 连接 EventBus 信号
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.wave_completed.connect(_on_wave_completed)
	EventBus.game_won.connect(_on_game_ended)
	EventBus.game_lost.connect(_on_game_ended)

func _process(delta):
	if not _is_wave_active:
		return

	spawn_timer -= delta
	if spawn_timer <= 0:
		spawn_enemy()
		spawn_timer = _current_wave_config.get("spawn_interval", 3.0)

func spawn_enemy():
	var enemy_types = _current_wave_config.get("enemy_types", ["normal"])
	var random_type = enemy_types[randi() % enemy_types.size()]
	var enemy = SceneFactory.create_enemy(random_type)

	var spawn_pos = get_random_spawn_position()
	enemy.global_position = spawn_pos
	get_parent().add_child(enemy)

func get_random_spawn_position() -> Vector2:
	var spawn_pos = Vector2.ZERO
	var attempts = 0
	var max_attempts = 10

	while attempts < max_attempts:
		spawn_pos.x = randf_range(map_min_x, map_max_x)
		spawn_pos.y = randf_range(map_min_y, map_max_y)

		if player and player.global_position.distance_to(spawn_pos) >= min_distance_from_player:
			break
		attempts += 1

	return spawn_pos

func _on_wave_started(wave_number: int, wave_config: Dictionary) -> void:
	_current_wave_config = wave_config
	_is_wave_active = true
	spawn_timer = 0.0

func _on_wave_completed(_wave_number: int) -> void:
	_is_wave_active = false

func _on_game_ended() -> void:
	_is_wave_active = false
