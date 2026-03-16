extends Node2D

enum Phase { SHOP, BATTLE }

var current_phase: Phase = Phase.SHOP
var _tower_container: Node2D = null
var _shop_overlay: CanvasLayer = null
var _drag_manager: Node = null

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

	# 进入首次 SHOP 阶段
	_enter_shop_phase(true)


func _enter_shop_phase(is_first: bool = false) -> void:
	current_phase = Phase.SHOP
	_shop_overlay.refresh_shop(is_first)
	if not is_first:
		_shop_overlay.slide_in()
	AudioManager.play_bgm("placement")
	$HUD.set_battle_phase(false)

func _enter_battle_phase() -> void:
	current_phase = Phase.BATTLE
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
	var map_data: MapData = GameConfig.maps.get(GameData.selected_map)
	if map_data == null or map_data.map_scene.is_empty():
		push_warning("地图场景未配置，跳过加载: " + GameData.selected_map)
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
		GameData.coins += amount
