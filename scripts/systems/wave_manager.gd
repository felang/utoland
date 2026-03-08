extends Node

const VICTORY_DELAY: float = 1.0       # 胜利后跳转延迟（秒）
const WAVE_CLEANUP_DELAY: float = 2.0   # 波次结束清理延迟（秒）
const SHOP_TRANSITION_DELAY: float = 1.0 # 进入商店延迟（秒）

var total_waves: int = GameConfig.waves.size()
var current_wave: int = 0
var wave_time_left: float = 0.0
var is_wave_active: bool = false

func _ready() -> void:
	add_to_group(Enums.Group.WAVE_MANAGER)
	EventBus.player_died.connect(_on_player_died)
	if GameData.current_wave > 0:
		current_wave = GameData.current_wave
	start_next_wave()

func _process(delta: float) -> void:
	if is_wave_active:
		wave_time_left -= delta
		if wave_time_left <= 0:
			complete_wave()

func start_next_wave() -> void:
	current_wave += 1
	GameData.current_wave = current_wave

	if current_wave > total_waves:
		EventBus.game_won.emit()
		print("Victory! You completed all waves!")
		await get_tree().create_timer(VICTORY_DELAY).timeout
		SceneManager.go_to(Enums.Scene.RESULT)
		return

	var wave_data: WaveData = GameConfig.waves[current_wave - 1]
	wave_time_left = wave_data.duration
	is_wave_active = true
	EventBus.wave_started.emit(current_wave, wave_data)
	var fx: EffectConfigData = GameConfig.effects
	EventBus.camera_shake_requested.emit(fx.camera_shake_wave_start_intensity, fx.camera_shake_wave_start_duration)
	print("Wave ", current_wave, " started!")

func complete_wave() -> void:
	is_wave_active = false
	attract_all_coins()
	await get_tree().create_timer(WAVE_CLEANUP_DELAY).timeout
	clear_all_enemies()
	EventBus.wave_completed.emit(current_wave)
	print("Wave ", current_wave, " completed!")

	await get_tree().create_timer(SHOP_TRANSITION_DELAY).timeout
	SceneManager.go_to(Enums.Scene.SHOP)

func attract_all_coins() -> void:
	var coins: Array[Node] = get_tree().get_nodes_in_group(Enums.Group.COINS)
	for coin in coins:
		if coin.has_method("force_attract"):
			coin.force_attract()

func clear_all_enemies() -> void:
	var enemies: Array[Node] = get_tree().get_nodes_in_group(Enums.Group.ENEMIES)
	for enemy in enemies:
		if enemy.has_method("set_physics_process"):
			enemy.set_physics_process(false)
			enemy.set_process(false)
		enemy.queue_free()

func _on_player_died() -> void:
	EventBus.game_lost.emit()
