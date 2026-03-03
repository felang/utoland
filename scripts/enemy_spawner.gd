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
	if not player:
		return
	
	var angle = randf() * TAU
	var offset = Vector2(cos(angle), sin(angle)) * spawn_distance
	var spawn_pos = player.global_position + offset
	
	var enemy = enemy_scene.instantiate()
	enemy.global_position = spawn_pos
	get_parent().add_child(enemy)
