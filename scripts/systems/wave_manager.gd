extends Node

const VICTORY_DELAY: float = 1.0       # 胜利后跳转延迟（秒）
const WAVE_CLEANUP_DELAY: float = 2.0   # 波次结束清理延迟（秒）
const SHOP_TRANSITION_DELAY: float = 1.0 # 进入商店延迟（秒）

var total_waves: int = 0
var current_wave: int = 0
var wave_time_left: float = 0.0
var is_wave_active: bool = false
var enemies_killed: int = 0
var _current_wave_data: WaveData = null

func _ready() -> void:
	add_to_group(Enums.Group.WAVE_MANAGER)
	EventBus.player_died.connect(_on_player_died)
	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.boss_killed.connect(_on_boss_killed)
	# 按选择的地图加载波次
	var map_waves: Array = GameConfig.get_waves_for_map(GameData.selected_map)
	if map_waves.size() > 0:
		GameConfig.waves = map_waves
	total_waves = GameConfig.waves.size()
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
	_start_wave_with_data(current_wave, wave_data)

func complete_wave() -> void:
	if not is_wave_active:
		return
	is_wave_active = false
	EventBus.wave_completed.emit(current_wave)
	AudioManager.play("wave_complete")
	print("Wave ", current_wave, " completed!")
	if not is_inside_tree():
		return
	attract_all_coins()
	await get_tree().create_timer(WAVE_CLEANUP_DELAY).timeout
	clear_all_enemies()
	await get_tree().create_timer(SHOP_TRANSITION_DELAY).timeout
	EventBus.wave_transition_ready.emit()

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

func _start_wave_with_data(wave_num: int, wave_data: WaveData) -> void:
	_current_wave_data = wave_data
	enemies_killed = 0
	wave_time_left = wave_data.time_limit
	is_wave_active = true
	EventBus.wave_started.emit(wave_num, wave_data)
	AudioManager.play("wave_start")
	var fx: EffectConfigData = GameConfig.effects
	if fx:
		EventBus.camera_shake_requested.emit(fx.camera_shake_wave_start_intensity, fx.camera_shake_wave_start_duration)
	print("Wave ", wave_num, " started!")

func _on_enemy_killed(_enemy_type: String, _position: Vector2, _is_elite: bool) -> void:
	if not is_wave_active:
		return
	enemies_killed += 1
	if _current_wave_data and not _current_wave_data.is_boss_wave:
		if enemies_killed >= _current_wave_data.total_enemies:
			complete_wave()

func _on_boss_killed(_boss_id: String) -> void:
	if not is_wave_active:
		return
	complete_wave()

func _on_player_died() -> void:
	EventBus.game_lost.emit()
