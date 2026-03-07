extends Node2D

const GRID_SIZE = GameConfig.GRID_SIZE
@onready var background_sprite: Sprite2D = $Background/BackgroundSprite
var selected_tower_type: String = ""
var preview_tower: Node2D = null

func _ready() -> void:
	_load_map_background()

	# 添加网格覆层
	var grid_overlay: Node2D = preload("res://scripts/ui/grid_overlay.gd").new()
	grid_overlay.z_index = -50
	add_child(grid_overlay)

	# 恢复之前布置的塔
	for tower_data in GameData.tower_inventory:
		var tower_type: String = tower_data["type"]
		var tower_pos: Vector2 = tower_data["position"]

		var tower: Node2D = SceneFactory.create_tower(tower_type)
		if tower:
			tower.global_position = tower_pos
			tower.add_to_group(Enums.Group.TOWERS)
			add_child(tower)

	# 将商店购买的塔添加到金币中（作为可用资源）
	for tower_type in GameData.purchased_towers:
		GameData.coins += SceneFactory.get_tower_cost(tower_type)
	GameData.purchased_towers.clear()

	# 连接按钮信号
	$UI/TowerButtons/ShooterButton.pressed.connect(func() -> void: _select_tower(Enums.TowerId.SHOOTER))
	$UI/TowerButtons/WallButton.pressed.connect(func() -> void: _select_tower(Enums.TowerId.WALL))
	$UI/TowerButtons/SlowButton.pressed.connect(func() -> void: _select_tower(Enums.TowerId.SLOW))
	$UI/StartBattleButton.pressed.connect(_start_battle)

	_update_ui()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and preview_tower:
		var grid_pos: Vector2 = _get_grid_position(get_global_mouse_position())
		preview_tower.global_position = grid_pos

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and preview_tower:
			_place_tower()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_cancel_placement()

func _select_tower(type: String) -> void:
	var cost: int = SceneFactory.get_tower_cost(type)
	if GameData.coins < cost:
		return

	selected_tower_type = type
	if preview_tower:
		preview_tower.queue_free()

	preview_tower = SceneFactory.create_tower(type)
	if preview_tower:
		preview_tower.modulate = Color(1, 1, 1, 0.5)
		add_child(preview_tower)

func _place_tower() -> void:
	if not preview_tower:
		return

	if not _can_place_at(preview_tower.global_position):
		return

	var cost: int = SceneFactory.get_tower_cost(selected_tower_type)
	GameData.coins -= cost
	preview_tower.modulate = Color(1, 1, 1, 1)
	preview_tower.add_to_group(Enums.Group.TOWERS)
	preview_tower = null
	selected_tower_type = ""
	_update_ui()

func _can_place_at(pos: Vector2) -> bool:
	# 检查是否在地图边界内
	if abs(pos.x) > GameConfig.MAP_HALF_WIDTH or abs(pos.y) > GameConfig.MAP_HALF_HEIGHT:
		return false

	# 检查是否与其他塔重叠
	var towers: Array[Node] = get_tree().get_nodes_in_group(Enums.Group.TOWERS)
	for tower in towers:
		if tower != preview_tower and tower.global_position.distance_to(pos) < GRID_SIZE:
			return false
	
	# 检查是否与玩家重叠
	var player = $Player
	if player.global_position.distance_to(pos) < GRID_SIZE:
		return false
	
	return true

func _get_grid_position(pos: Vector2) -> Vector2:
	return Vector2(
		floor(pos.x / GRID_SIZE) * GRID_SIZE + GRID_SIZE / 2.0,
		floor(pos.y / GRID_SIZE) * GRID_SIZE + GRID_SIZE / 2.0
	)

func _cancel_placement() -> void:
	if preview_tower:
		preview_tower.queue_free()
		preview_tower = null
		selected_tower_type = ""

func _update_ui() -> void:
	$UI/CoinsLabel.text = "金币: %d" % GameData.coins

	# 更新按钮状态
	$UI/TowerButtons/ShooterButton.disabled = GameData.coins < SceneFactory.get_tower_cost(Enums.TowerId.SHOOTER)
	$UI/TowerButtons/WallButton.disabled = GameData.coins < SceneFactory.get_tower_cost(Enums.TowerId.WALL)
	$UI/TowerButtons/SlowButton.disabled = GameData.coins < SceneFactory.get_tower_cost(Enums.TowerId.SLOW)

func _start_battle() -> void:
	# 收集场景中所有塔的当前位置
	var towers: Array[Node] = get_tree().get_nodes_in_group(Enums.Group.TOWERS)
	var current_towers: Array[Dictionary] = []

	for tower in towers:
		# 优先使用 tower_type 属性
		var tower_type: String = ""
		if "tower_type" in tower:
			tower_type = tower.tower_type
		else:
			# 降级方案：通过名称判断
			if tower.name.begins_with("TowerShooter"):
				tower_type = Enums.TowerId.SHOOTER
			elif tower.name.begins_with("TowerWall"):
				tower_type = Enums.TowerId.WALL
			elif tower.name.begins_with("TowerSlow"):
				tower_type = Enums.TowerId.SLOW

		if tower_type != "":
			current_towers.append({
				"type": tower_type,
				"position": tower.global_position
			})

	# 更新 tower_inventory 为当前所有塔（包括之前的和新布置的）
	GameData.tower_inventory = current_towers

	SceneManager.go_to(Enums.Scene.MAIN)

func _load_map_background() -> void:
	# 获取选择的地图
	var map_id: String = GameData.selected_map

	# 验证地图配置存在
	if not GameConfig.maps.has(map_id):
		push_warning("未知地图: " + map_id + ", 使用默认地图")
		map_id = Enums.Map.FOREST
		GameData.selected_map = map_id

	var md: MapData = GameConfig.maps[map_id]
	var bg_path: String = md.background

	# 尝试加载背景图
	if ResourceLoader.exists(bg_path):
		var bg_texture: Resource = load(bg_path)
		if bg_texture and background_sprite:
			background_sprite.texture = bg_texture
			print("加载地图背景: ", md.display_name)
		else:
			push_warning("背景图加载失败或节点不存在，使用纯色背景")
			_use_fallback_background(map_id)
	else:
		# 降级方案：使用纯色背景
		push_warning("背景图不存在: " + bg_path + ", 使用纯色背景")
		_use_fallback_background(map_id)

func _use_fallback_background(map_id: String) -> void:
	# 移除 Sprite2D，使用 ColorRect
	if background_sprite:
		background_sprite.queue_free()

	# 获取视口尺寸（而非硬编码）
	var viewport_size: Vector2 = get_viewport_rect().size

	var color_rect: ColorRect = ColorRect.new()
	color_rect.size = viewport_size
	color_rect.position = -viewport_size / 2  # 居中对齐

	var md: MapData = GameConfig.maps[map_id]
	color_rect.color = Color(md.fallback_color)

	$Background.add_child(color_rect)
	print("使用纯色背景: ", md.display_name, " (", md.fallback_color, ")")
