extends Node2D

const GRID_SIZE: int = GameConfig.GRID_SIZE

var _tower_container: Node2D = null

func _ready() -> void:
	_tower_container = Node2D.new()
	_tower_container.name = "TowerContainer"
	add_child(_tower_container)
	_load_map()
	_restore_towers()
	# 暂停覆盖层
	var pause_overlay = load("res://scripts/ui/pause_overlay.gd").new()
	add_child(pause_overlay)
	# 调试面板
	var debug_panel = load("res://scripts/ui/debug_panel.gd").new()
	add_child(debug_panel)
	# 波次结束跳转商店
	EventBus.wave_transition_ready.connect(_on_wave_transition_ready)
	# 监听 sunflower 产金事件
	EventBus.coins_generated.connect(_on_coins_generated)

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
	move_child(map_instance, 0)  # 确保地图在最底层

func _restore_towers() -> void:
	for tower_entry in GameData.deployed_towers:
		var tower: Node2D = SceneFactory.create_tower(tower_entry.id, tower_entry.level)
		if tower:
			tower.global_position = _grid_to_world(tower_entry.grid_pos)
			_tower_container.add_child(tower)

func _grid_to_world(grid_pos: Vector2i) -> Vector2:
	return Vector2(grid_pos.x * GRID_SIZE + GRID_SIZE / 2.0,
				   grid_pos.y * GRID_SIZE + GRID_SIZE / 2.0)

func _on_wave_transition_ready() -> void:
	SceneManager.go_to("shop")

func _on_coins_generated(amount: int, _pos: Vector2) -> void:
	var player: Node2D = get_tree().get_first_node_in_group(Enums.Group.PLAYER)
	if player and player.has_method("add_coins"):
		player.add_coins(amount)
	else:
		GameData.coins += amount
