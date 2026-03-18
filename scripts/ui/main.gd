extends Node2D

enum Phase { SHOP, BATTLE }

var current_phase: Phase = Phase.SHOP
var _tower_container: Node2D = null
var _shop_overlay: CanvasLayer = null
var _drag_manager: Node = null
var _camera: Camera2D = null

const CAMERA_TRANSITION_DURATION := 0.5
const SHOP_ZOOM := 0.56  # 稍小于 360/416=0.865，让地图边界也能露出
const SHOP_CAMERA_POS := Vector2(-196, 0)

func _ready() -> void:
	_tower_container = Node2D.new()
	_tower_container.name = "TowerContainer"
	add_child(_tower_container)

	_load_map()

	# ShopOverlay（预先在 main.tscn 中实例化）
	_shop_overlay = $ShopOverlay
	_shop_overlay.start_battle_pressed.connect(_on_start_battle)

	# DragManager（预先在 main.tscn 中添加）
	_drag_manager = $DragManager
	_drag_manager.initialize(_tower_container, $Player)
	_shop_overlay.drag_manager = _drag_manager

	# WeaponManager 注入（Player 的子节点）
	var player: Node2D = $Player
	if player.has_node("WeaponManager"):
		var wm: WeaponManager = player.get_node("WeaponManager")
		_shop_overlay.weapon_manager = wm
		# 武器点击 → 拖拽卖出
		wm.set_weapon_drag_callback(func(weapon_index: int):
			_drag_manager.start_weapon_drag(weapon_index, _shop_overlay._on_weapon_sold)
		)

	# 回收区注入
	_drag_manager.set_recycle_area(_shop_overlay.get_recycle_area())

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

	# 缓存相机引用
	_camera = $Player.get_node("Camera")

	# 进入首次 SHOP 阶段
	_enter_shop_phase(true)
	SceneFactory.warmup_initial()

func _enter_shop_phase(is_first: bool = false) -> void:
	current_phase = Phase.SHOP
	$Player.set_input_enabled(true)

	# top_level=true 使相机脱离 Player 父节点变换，可直接控制 global_position
	_camera.top_level = true
	_camera.offset = Vector2.ZERO
	_camera.set_process(false)
	_camera.position_smoothing_enabled = false
	_camera.drag_horizontal_enabled = false
	_camera.drag_vertical_enabled = false

	# 扩大相机限制
	_camera.limit_left = -10000
	_camera.limit_right = 10000
	_camera.limit_top = -10000
	_camera.limit_bottom = 10000

	var shop_zoom := Vector2(SHOP_ZOOM, SHOP_ZOOM)

	if is_first:
		_camera.global_position = SHOP_CAMERA_POS
		_camera.zoom = shop_zoom
	else:
		var tween := create_tween().set_parallel(true)
		tween.tween_property(_camera, "global_position", SHOP_CAMERA_POS, CAMERA_TRANSITION_DURATION)
		tween.tween_property(_camera, "zoom", shop_zoom, CAMERA_TRANSITION_DURATION)
		_shop_overlay.slide_in()

	# 波次结束奖励金币（首次商店不发，首次用初始金币）
	if not is_first:
		var reward: int = GameConfig.shop_config.wave_reward
		InventoryManager.coins += reward
		StatsTracker.record_coins_earned(reward)
		EventBus.coins_changed.emit(reward, InventoryManager.coins)
		# 同步 Player 金币
		var player_node: Node2D = $Player
		if player_node:
			player_node.coins = InventoryManager.coins

	_shop_overlay.refresh_shop(is_first)
	AudioManager.play_bgm("placement")
	$HUD.set_battle_phase(false)

func _enter_battle_phase() -> void:
	current_phase = Phase.BATTLE
	_shop_overlay.slide_out()

	# 过渡回玩家位置（预先计算 limits 钳制后的目标，避免恢复 limits 时跳变）
	var battle_zoom: float = GameConfig.effects.camera_zoom
	var clamped_pos: Vector2 = _get_clamped_camera_pos($Player.global_position, battle_zoom)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_camera, "global_position", clamped_pos, CAMERA_TRANSITION_DURATION)
	tween.tween_property(_camera, "zoom", Vector2(battle_zoom, battle_zoom), CAMERA_TRANSITION_DURATION)

	# 过渡完成后恢复正常相机行为
	tween.chain().tween_callback(_restore_battle_camera)

	AudioManager.play_bgm("battle")
	$HUD.set_battle_phase(true)
	$WaveManager.start_next_wave()

## 计算相机在 limits 约束下的实际位置（避免过渡后跳变）
func _get_clamped_camera_pos(target: Vector2, zoom_val: float) -> Vector2:
	var view_half_w: float = float(GameConfig.BASE_VIEWPORT_WIDTH) / (2.0 * zoom_val)
	var view_half_h: float = float(GameConfig.BASE_VIEWPORT_HEIGHT) / (2.0 * zoom_val)
	var map_hw: float = GameConfig.MAP_HALF_WIDTH
	var map_hh: float = GameConfig.MAP_HALF_HEIGHT
	return Vector2(
		clampf(target.x, -map_hw + view_half_w, map_hw - view_half_w),
		clampf(target.y, -map_hh + view_half_h, map_hh - view_half_h)
	)

func _restore_battle_camera() -> void:
	# 记录当前全局位置，关闭 top_level 后用局部偏移保持同一位置
	var final_global: Vector2 = _camera.global_position
	_camera.top_level = false
	_camera.position = final_global - $Player.global_position

	# 恢复相机限制
	_camera.limit_left = -int(GameConfig.MAP_HALF_WIDTH)
	_camera.limit_right = int(GameConfig.MAP_HALF_WIDTH)
	_camera.limit_top = -int(GameConfig.MAP_HALF_HEIGHT)
	_camera.limit_bottom = int(GameConfig.MAP_HALF_HEIGHT)

	# 恢复平滑和拖拽
	_camera.position_smoothing_enabled = true
	_camera.drag_horizontal_enabled = true
	_camera.drag_vertical_enabled = true

	# 恢复相机处理（震动/前瞻）
	_camera.set_process(true)

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

func _on_coins_generated(amount: int, _pos: Vector2) -> void:
	var player: Node2D = get_tree().get_first_node_in_group(Enums.Group.PLAYER)
	if player and player.has_method("add_coins"):
		player.add_coins(amount)
	else:
		InventoryManager.coins += amount

func _on_wave_started_warmup(_wave_num: int, wave_data: WaveData) -> void:
	SceneFactory.warmup_for_wave(wave_data)

func _exit_tree() -> void:
	SceneFactory.clear_all_pools()
