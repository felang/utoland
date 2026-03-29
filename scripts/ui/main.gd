extends Node2D

enum Phase { SHOP, BATTLE }

const PLAYER_SCENE := preload("res://scenes/entities/player.tscn")

var current_phase: Phase = Phase.SHOP
var _shop_overlay: CanvasLayer = null
var _drag_manager: Node = null
var _player: Node2D = null
var _entity_layer: Node2D = null
var _projectile_layer: Node2D = null
var _pickup_layer: Node2D = null
var _player_spawn_pos: Vector2 = Vector2.ZERO
var _map_layout: MapLayout = null  # 随机地图生成结果，供延迟初始化用

func _ready() -> void:
	_load_map()

	# 创建玩家并添加到地图的 EntityLayer
	_player = PLAYER_SCENE.instantiate()
	_player.position = _player_spawn_pos
	_entity_layer.add_child(_player)
	print("Player position after add_child: ", _player.position, " global: ", _player.global_position)

	# 初始化分层容器（供 SceneFactory 全局使用）
	SceneFactory.init_containers(_entity_layer, _projectile_layer, _pickup_layer)

	# ShopOverlay（预先在 main.tscn 中实例化）
	_shop_overlay = $ShopOverlay
	_shop_overlay.start_battle_pressed.connect(_on_start_battle)

	# DragManager（预先在 main.tscn 中添加）
	_drag_manager = $DragManager
	_drag_manager.initialize(_entity_layer, _player)
	if _map_layout:
		_drag_manager.placeable_cells = _map_layout.get_placeable_dict()
	_shop_overlay.drag_manager = _drag_manager

	# WeaponManager 注入（Player 的子节点）
	if _player.has_node("WeaponManager"):
		var wm: WeaponManager = _player.get_node("WeaponManager")
		_shop_overlay.weapon_manager = wm

	# 暂停覆盖层
	var pause_overlay = load("res://scripts/ui/pause_overlay.gd").new()
	add_child(pause_overlay)
	# 调试面板
	var debug_panel = load("res://scripts/ui/debug_panel.gd").new()
	add_child(debug_panel)

	# 信号连接
	EventBus.wave_transition_ready.connect(_on_wave_transition_ready)
	EventBus.coins_generated.connect(_on_coins_generated)
	EventBus.wave_started.connect(_on_wave_started_warmup)
	EventBus.boss_killed.connect(_on_boss_killed)

	# 进入首次 SHOP 阶段
	_enter_shop_phase(true)
	SceneFactory.warmup_initial()

func _enter_shop_phase(is_first: bool = false) -> void:
	current_phase = Phase.SHOP
	_player.set_input_enabled(true)
	_drag_manager.set_shop_mode(true)

	# 波次结束奖励金币（首次不发）
	if not is_first:
		_shop_overlay.slide_in()
		var reward: int = GameConfig.shop_config.get_wave_reward(PlayerState.current_wave)
		_add_coins(reward)

	# 以下无条件执行（首次和非首次都需要）
	_shop_overlay.refresh_shop(is_first)
	AudioManager.play_bgm("placement")
	$HUD.set_battle_phase(false)

func _enter_battle_phase() -> void:
	current_phase = Phase.BATTLE
	_drag_manager.set_shop_mode(false)
	_shop_overlay.slide_out()
	AudioManager.play_bgm("battle")
	$HUD.set_battle_phase(true)
	$WaveManager.start_next_wave()

func _on_start_battle() -> void:
	if current_phase == Phase.SHOP:
		_enter_battle_phase()

func _on_wave_transition_ready() -> void:
	_enter_shop_phase()

func _load_map() -> void:
	var map_data: MapData = GameConfig.maps.get(PlayerState.selected_map)
	if map_data == null or map_data.map_scene.is_empty():
		push_warning("地图场景未配置，跳过加载: " + PlayerState.selected_map)
		return
	if not ResourceLoader.exists(map_data.map_scene):
		push_warning("地图场景文件不存在: " + map_data.map_scene)
		return
	var map_instance = load(map_data.map_scene).instantiate()
	add_child(map_instance)
	move_child(map_instance, 0)

	# 随机地图生成
	if map_data.generator_config != null:
		var generator := MapGenerator.new()
		var layout := generator.generate(map_data.generator_config)
		generator.apply_to_tilemap(map_instance, layout, map_data.generator_config)
		# 传递生成数据
		var enemy_spawner = get_node_or_null("EnemySpawner")
		if enemy_spawner:
			enemy_spawner.spawn_points = layout.get_spawn_points_world()
		_map_layout = layout
		_player_spawn_pos = layout.get_player_spawn_world()
	else:
		_player_spawn_pos = Vector2.ZERO

	# 从地图场景中获取分层容器
	_entity_layer = map_instance.get_node("EntityLayer")
	_projectile_layer = map_instance.get_node("ProjectileLayer")
	_pickup_layer = map_instance.get_node("PickupLayer")
	assert(_entity_layer != null, "地图缺少 EntityLayer 节点")
	assert(_projectile_layer != null, "地图缺少 ProjectileLayer 节点")
	assert(_pickup_layer != null, "地图缺少 PickupLayer 节点")

func _add_coins(amount: int) -> void:
	InventoryManager.coins += amount
	StatsTracker.record_coins_earned(amount)
	EventBus.coins_changed.emit(amount, InventoryManager.coins)
	if _player:
		_player.coins = InventoryManager.coins

func _on_coins_generated(amount: int, _pos: Vector2) -> void:
	_add_coins(amount)

func _on_boss_killed(boss_id: String) -> void:
	var bounty: int = GameConfig.shop_config.boss_bounty.get(boss_id, 0)
	if bounty > 0:
		_add_coins(bounty)

func _on_wave_started_warmup(_wave_num: int, wave_data: WaveData) -> void:
	SceneFactory.warmup_for_wave(wave_data)

func _exit_tree() -> void:
	SceneFactory.clear_all_pools()
