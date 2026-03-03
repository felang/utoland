extends Node

var enemy_scenes = {
	"normal": preload("res://scenes/enemies/enemy_normal.tscn"),
	"fast": preload("res://scenes/enemies/enemy_fast.tscn"),
	"tank": preload("res://scenes/enemies/enemy_tank.tscn")
}

var spawn_timer: float = 0.0
var wave_manager: Node
var player: Node2D

# Map boundaries
var map_min_x = -1250.0
var map_max_x = 1250.0
var map_min_y = -950.0
var map_max_y = 950.0
var min_distance_from_player = 200.0

func _ready():
	player = get_tree().get_first_node_in_group("player")

	# Defer wave_manager lookup to avoid initialization order issues
	call_deferred("_setup_wave_manager")

func _setup_wave_manager():
	wave_manager = get_tree().get_first_node_in_group("wave_manager")

	if wave_manager:
		wave_manager.wave_started.connect(_on_wave_started)

func _process(delta):
	if not wave_manager or not wave_manager.is_wave_active:
		return

	spawn_timer -= delta
	if spawn_timer <= 0:
		spawn_enemy()
		var config = wave_manager.get_current_wave_config()
		spawn_timer = config.get("spawn_interval", 3.0)

func spawn_enemy():
	if not wave_manager:
		return

	var config = wave_manager.get_current_wave_config()
	var current_enemies = get_tree().get_nodes_in_group("enemies").size()

	if current_enemies >= config.get("max_enemies", 20):
		return

	var enemy_types = config.get("enemy_types", ["normal"])
	var random_type = enemy_types[randi() % enemy_types.size()]
	var enemy = enemy_scenes[random_type].instantiate()

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

func _on_wave_started(_wave_number: int):
	spawn_timer = 0.0
