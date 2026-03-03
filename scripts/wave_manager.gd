extends Node

signal wave_started(wave_number: int)
signal wave_completed(wave_number: int)
signal game_won()
signal game_lost()

@export var total_waves: int = 10
var current_wave: int = 0
var wave_time_left: float = 0.0
var is_wave_active: bool = false

# 波次配置
var wave_configs = {
	1: {"duration": 45, "enemy_types": ["normal"], "spawn_interval": 4.0, "max_enemies": 15},
	2: {"duration": 45, "enemy_types": ["normal"], "spawn_interval": 4.0, "max_enemies": 15},
	3: {"duration": 45, "enemy_types": ["normal"], "spawn_interval": 4.0, "max_enemies": 15},
	4: {"duration": 50, "enemy_types": ["normal", "fast"], "spawn_interval": 3.0, "max_enemies": 25},
	5: {"duration": 50, "enemy_types": ["normal", "fast"], "spawn_interval": 3.0, "max_enemies": 25},
	6: {"duration": 50, "enemy_types": ["normal", "fast"], "spawn_interval": 3.0, "max_enemies": 25},
	7: {"duration": 60, "enemy_types": ["normal", "fast", "tank"], "spawn_interval": 2.0, "max_enemies": 35},
	8: {"duration": 60, "enemy_types": ["normal", "fast", "tank"], "spawn_interval": 2.0, "max_enemies": 35},
	9: {"duration": 60, "enemy_types": ["normal", "fast", "tank"], "spawn_interval": 2.0, "max_enemies": 35},
	10: {"duration": 60, "enemy_types": ["normal", "fast", "tank"], "spawn_interval": 1.0, "max_enemies": 50}
}

func _ready():
	add_to_group("wave_manager")
	# 从 GameData 恢复波次
	if GameData.current_wave > 0:
		current_wave = GameData.current_wave
	start_next_wave()

func _process(delta):
	if is_wave_active:
		wave_time_left -= delta
		if wave_time_left <= 0:
			complete_wave()

func start_next_wave():
	current_wave += 1
	GameData.current_wave = current_wave  # 同步到 GameData

	if current_wave > total_waves:
		game_won.emit()
		print("Victory! You completed all 10 waves!")
		await get_tree().create_timer(1.0).timeout
		get_tree().change_scene_to_file("res://scenes/ui/result.tscn")
		return

	var config = wave_configs[current_wave]
	wave_time_left = config["duration"]
	is_wave_active = true
	wave_started.emit(current_wave)
	print("Wave ", current_wave, " started!")

func complete_wave():
	is_wave_active = false
	attract_all_coins()
	await get_tree().create_timer(2.0).timeout
	clear_all_enemies()
	wave_completed.emit(current_wave)
	print("Wave ", current_wave, " completed!")

	await get_tree().create_timer(1.0).timeout
	get_tree().change_scene_to_file("res://scenes/ui/shop.tscn")

func attract_all_coins():
	var coins = get_tree().get_nodes_in_group("coins")
	for coin in coins:
		if coin.has_method("force_attract"):
			coin.force_attract()

func clear_all_enemies():
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy.has_method("set_physics_process"):
			enemy.set_physics_process(false)
			enemy.set_process(false)
		enemy.queue_free()

func get_current_wave_config():
	return wave_configs.get(current_wave, {})
