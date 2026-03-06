extends Node

signal wave_started(wave_number: int)
signal wave_completed(wave_number: int)
signal game_won()
signal game_lost()

var total_waves: int = GameConfig.WAVES["total_waves"]
var current_wave: int = 0
var wave_time_left: float = 0.0
var is_wave_active: bool = false

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
		print("Victory! You completed all waves!")
		await get_tree().create_timer(1.0).timeout
		get_tree().change_scene_to_file("res://scenes/ui/result.tscn")
		return

	var config = GameConfig.WAVES["wave_configs"][current_wave - 1]
	wave_time_left = config["duration"]
	is_wave_active = true
	wave_started.emit(current_wave)
	# 波次开始屏幕震动
	var player_node: Node2D = get_tree().get_first_node_in_group("player")
	if player_node:
		var camera: Camera2D = player_node.get_node_or_null("Camera")
		if camera and camera.has_method("shake"):
			var shake_config: Dictionary = GameConfig.EFFECTS["camera_shake"]["wave_start"]
			camera.shake(shake_config["intensity"], shake_config["duration"])
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
	if current_wave > 0 and current_wave <= total_waves:
		return GameConfig.WAVES["wave_configs"][current_wave - 1]
	return {}
