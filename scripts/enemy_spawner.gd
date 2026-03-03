extends Node

@export var spawn_interval: float = 5.0
@export var max_enemies: int = 20
@export var spawn_distance: float = 600.0

var enemy_scene = preload("res://scenes/enemies/enemy_normal.tscn")
var spawn_timer: float = 0.0
var player: Node2D = null

func _ready():
	player = get_tree().get_first_node_in_group("player")

func _process(delta):
	spawn_timer -= delta
	
	if spawn_timer <= 0:
		var current_enemies = get_tree().get_nodes_in_group("enemies").size()
		if current_enemies < max_enemies:
			spawn_enemy()
		spawn_timer = spawn_interval

func spawn_enemy():
	if not player or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		if not player:
			return

	# Map boundaries with margin
	var map_min_x = -1250.0
	var map_max_x = 1250.0
	var map_min_y = -950.0
	var map_max_y = 950.0
	var min_distance_from_player = 200.0

	var spawn_pos = Vector2.ZERO
	var attempts = 0
	var max_attempts = 10

	# Try to find a valid spawn position
	while attempts < max_attempts:
		spawn_pos.x = randf_range(map_min_x, map_max_x)
		spawn_pos.y = randf_range(map_min_y, map_max_y)

		# Check if far enough from player
		if player.global_position.distance_to(spawn_pos) >= min_distance_from_player:
			break
		attempts += 1

	var enemy = enemy_scene.instantiate()
	enemy.global_position = spawn_pos
	get_parent().add_child(enemy)
