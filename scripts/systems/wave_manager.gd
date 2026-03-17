extends Node

const VICTORY_DELAY: float = 1.0
const WAVE_CLEANUP_DELAY: float = 2.0
const SHOP_TRANSITION_DELAY: float = 1.0

var total_waves: int = 0
var current_wave: int = 0
var wave_time_left: float = 0.0
var is_wave_active: bool = false
var _current_wave_data: WaveData = null
var _boss_killed_this_wave: bool = false

func _ready() -> void:
	add_to_group(Enums.Group.WAVE_MANAGER)
	EventBus.player_died.connect(_on_player_died)
	EventBus.boss_killed.connect(_on_boss_killed)
	var map_waves: Array = GameConfig.get_waves_for_map(PlayerState.selected_map)
	if map_waves.size() > 0:
		GameConfig.waves = map_waves
	total_waves = GameConfig.waves.size()
	if PlayerState.current_wave > 0:
		current_wave = PlayerState.current_wave

func _process(delta: float) -> void:
	if not is_wave_active:
		return
	wave_time_left -= delta
	if wave_time_left <= 0:
		complete_wave()

func start_next_wave() -> void:
	current_wave += 1
	PlayerState.current_wave = current_wave
	if current_wave > total_waves:
		EventBus.game_won.emit()
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
	# Boss 波次：时间到但 Boss 未被击杀 → 发送逃跑信号
	if _current_wave_data and _current_wave_data.is_boss_wave and not _boss_killed_this_wave:
		EventBus.boss_escaped.emit(_current_wave_data.boss_id)
	if not is_inside_tree():
		return
	attract_all_coins()
	attract_all_exp_orbs()
	await get_tree().create_timer(WAVE_CLEANUP_DELAY).timeout
	clear_all_enemies()
	await get_tree().create_timer(SHOP_TRANSITION_DELAY).timeout
	EventBus.wave_transition_ready.emit()

func attract_all_coins() -> void:
	var coins: Array[Node] = get_tree().get_nodes_in_group(Enums.Group.COINS)
	for coin in coins:
		if coin.has_method("force_attract"):
			coin.force_attract()

func attract_all_exp_orbs() -> void:
	var orbs: Array[Node] = get_tree().get_nodes_in_group(Enums.Group.EXP_ORBS)
	for orb in orbs:
		if orb.has_method("force_attract"):
			orb.force_attract()

func clear_all_enemies() -> void:
	var enemies: Array[Node] = get_tree().get_nodes_in_group(Enums.Group.ENEMIES)
	for enemy in enemies:
		SceneFactory.release_enemy(enemy)

func _start_wave_with_data(wave_num: int, wave_data: WaveData) -> void:
	_current_wave_data = wave_data
	_boss_killed_this_wave = false
	wave_time_left = wave_data.time_limit
	is_wave_active = true
	EventBus.wave_started.emit(wave_num, wave_data)
	AudioManager.play("wave_start")
	var fx: EffectConfigData = GameConfig.effects
	if fx:
		EventBus.camera_shake_requested.emit(fx.camera_shake_wave_start_intensity, fx.camera_shake_wave_start_duration)

func _on_enemy_killed(_enemy_type: String, _position: Vector2, _is_elite: bool) -> void:
	# 纯时间制：击杀不影响波次结束
	pass

func _on_boss_killed(_boss_id: String) -> void:
	if not is_wave_active:
		return
	_boss_killed_this_wave = true

func _on_player_died() -> void:
	EventBus.game_lost.emit()
