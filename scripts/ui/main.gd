extends Node2D

const PLAYER_SCENE := preload("res://scenes/entities/player.tscn")
const BATTLE_HUD_SCENE := preload("res://scenes/ui/battle_hud.tscn")
const PERK_OVERLAY_SCENE := preload("res://scenes/ui/perk_selection_overlay.tscn")
const TOWER_ROLL_SCENE := preload("res://scenes/ui/tower_roll_overlay.tscn")

var _battle_hud: CanvasLayer = null
var _perk_overlay: CanvasLayer = null
var _tower_roll_overlay: CanvasLayer = null
var _drag_manager: Node = null
var _player: Node2D = null
var _entity_layer: Node2D = null
var _projectile_layer: Node2D = null
var _pickup_layer: Node2D = null
var _player_spawn_pos: Vector2 = Vector2.ZERO
var _map_layout: MapLayout = null

func _ready() -> void:
	_load_map()

	_player = PLAYER_SCENE.instantiate()
	_player.position = _player_spawn_pos
	_entity_layer.add_child(_player)
	SceneFactory.init_containers(_entity_layer, _projectile_layer, _pickup_layer)

	# DragManager(预先在 main.tscn 中)
	_drag_manager = $DragManager
	_drag_manager.initialize(_entity_layer, _player)
	if _map_layout:
		_drag_manager.placeable_cells = _map_layout.get_placeable_dict()
	# Battle 阶段:塔点击菜单始终启用
	_drag_manager.set_shop_mode(true)

	# 战斗 HUD(替代 ShopOverlay)
	_battle_hud = BATTLE_HUD_SCENE.instantiate()
	add_child(_battle_hud)
	_battle_hud.set_drag_manager(_drag_manager)

	# Perk 选择弹窗(常驻,视实时升级而显示)
	_perk_overlay = PERK_OVERLAY_SCENE.instantiate()
	add_child(_perk_overlay)

	# Roll 时 3 选 1 弹窗
	_tower_roll_overlay = TOWER_ROLL_SCENE.instantiate()
	add_child(_tower_roll_overlay)

	# 暂停覆盖层 / 调试面板
	var pause_overlay = load("res://scripts/ui/pause_overlay.gd").new()
	add_child(pause_overlay)
	var debug_panel = load("res://scripts/ui/debug_panel.gd").new()
	add_child(debug_panel)

	# 信号连接
	EventBus.wave_transition_ready.connect(_on_wave_transition_ready)
	EventBus.coins_generated.connect(_on_coins_generated)
	EventBus.wave_started.connect(_on_wave_started_warmup)
	EventBus.tower_destroyed.connect(_on_tower_destroyed)
	EventBus.wave_completed.connect(_on_wave_completed_heal_towers)

	# HUD(顶部信息栏 — 现有的 HUD)
	$HUD.set_battle_phase(true)

	# 立刻进入战斗
	AudioManager.play_bgm("battle")
	SceneFactory.warmup_initial()
	$WaveManager.start_next_wave()

func _on_wave_transition_ready() -> void:
	# 旧版进入 SHOP 阶段;新版直接进入下一波
	# 短暂呼吸期由 wave_manager 自带的 SHOP_TRANSITION_DELAY(Task 21 重命名为 WAVE_BREATHER_DELAY)提供
	$WaveManager.start_next_wave()

func _load_map() -> void:
	var map_data: MapData = GameConfig.maps.get(PlayerState.selected_map)
	if map_data == null or map_data.map_scene.is_empty():
		push_warning("地图场景未配置: " + PlayerState.selected_map)
		return
	if not ResourceLoader.exists(map_data.map_scene):
		push_warning("地图场景文件不存在: " + map_data.map_scene)
		return
	var map_instance = load(map_data.map_scene).instantiate()
	add_child(map_instance)
	move_child(map_instance, 0)

	if map_data.generator_config != null:
		var generator := MapGenerator.new()
		var layout := generator.generate(map_data.generator_config)
		generator.apply_to_tilemap(map_instance, layout, map_data.generator_config)
		_map_layout = layout
		_player_spawn_pos = layout.get_player_spawn_world()
	else:
		_player_spawn_pos = Vector2.ZERO

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

func _on_wave_started_warmup(_wave_num: int, wave_data: WaveData) -> void:
	SceneFactory.warmup_for_wave(wave_data)

func _on_tower_destroyed(_tower_type: String, _position: Vector2, deploy_id: int) -> void:
	InventoryManager.remove_destroyed_tower(deploy_id)
	_drag_manager.untrack_tower(deploy_id)

func _on_wave_completed_heal_towers(_wave_number: int) -> void:
	var towers: Array[Node] = get_tree().get_nodes_in_group(Enums.Group.TOWERS)
	for tower in towers:
		if tower.has_method("heal"):
			tower.heal(tower.health.max_hp * 0.3)

func _exit_tree() -> void:
	SceneFactory.clear_all_pools()
