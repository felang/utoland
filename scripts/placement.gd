extends Node2D

const GRID_SIZE = 32
var selected_tower_type: String = ""
var preview_tower: Node2D = null
var tower_scenes = {
	"shooter": preload("res://scenes/towers/tower_shooter.tscn"),
	"wall": preload("res://scenes/towers/tower_wall.tscn"),
	"slow": preload("res://scenes/towers/tower_slow.tscn")
}
var tower_costs = {
	"shooter": 30,
	"wall": 40,
	"slow": 35
}

func _ready():
	load_map_background()

	# 恢复之前布置的塔
	for tower_data in GameData.tower_inventory:
		var tower_type = tower_data["type"]
		var tower_pos = tower_data["position"]

		if tower_scenes.has(tower_type):
			var tower = tower_scenes[tower_type].instantiate()
			tower.global_position = tower_pos
			tower.add_to_group("towers")
			add_child(tower)

	# 将商店购买的塔添加到金币中（作为可用资源）
	for tower_type in GameData.purchased_towers:
		GameData.coins += tower_costs[tower_type]
	GameData.purchased_towers.clear()

	# 连接按钮信号
	$UI/TowerButtons/ShooterButton.pressed.connect(func(): select_tower("shooter"))
	$UI/TowerButtons/WallButton.pressed.connect(func(): select_tower("wall"))
	$UI/TowerButtons/SlowButton.pressed.connect(func(): select_tower("slow"))
	$UI/StartBattleButton.pressed.connect(start_battle)

	update_ui()

func _input(event):
	if event is InputEventMouseMotion and preview_tower:
		var grid_pos = get_grid_position(get_global_mouse_position())
		preview_tower.global_position = grid_pos

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and preview_tower:
			place_tower()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			cancel_placement()

func select_tower(type: String):
	if GameData.coins < tower_costs[type]:
		return

	selected_tower_type = type
	if preview_tower:
		preview_tower.queue_free()

	preview_tower = tower_scenes[type].instantiate()
	preview_tower.modulate = Color(1, 1, 1, 0.5)
	add_child(preview_tower)

func place_tower():
	if not can_place_at(preview_tower.global_position):
		return

	GameData.coins -= tower_costs[selected_tower_type]
	preview_tower.modulate = Color(1, 1, 1, 1)
	preview_tower.add_to_group("towers")
	preview_tower = null
	selected_tower_type = ""
	update_ui()

func can_place_at(pos: Vector2) -> bool:
	# 检查是否在地图边界内
	if abs(pos.x) > 1300 or abs(pos.y) > 1000:
		return false
	
	# 检查是否与其他塔重叠
	var towers = get_tree().get_nodes_in_group("towers")
	for tower in towers:
		if tower != preview_tower and tower.global_position.distance_to(pos) < GRID_SIZE:
			return false
	
	# 检查是否与玩家重叠
	var player = $Player
	if player.global_position.distance_to(pos) < GRID_SIZE:
		return false
	
	return true

func get_grid_position(pos: Vector2) -> Vector2:
	return Vector2(
		floor(pos.x / GRID_SIZE) * GRID_SIZE + GRID_SIZE / 2,
		floor(pos.y / GRID_SIZE) * GRID_SIZE + GRID_SIZE / 2
	)

func cancel_placement():
	if preview_tower:
		preview_tower.queue_free()
		preview_tower = null
		selected_tower_type = ""

func update_ui():
	$UI/CoinsLabel.text = "金币: %d" % GameData.coins
	
	# 更新按钮状态
	$UI/TowerButtons/ShooterButton.disabled = GameData.coins < tower_costs["shooter"]
	$UI/TowerButtons/WallButton.disabled = GameData.coins < tower_costs["wall"]
	$UI/TowerButtons/SlowButton.disabled = GameData.coins < tower_costs["slow"]

func start_battle():
	# 收集场景中所有塔的当前位置
	var towers = get_tree().get_nodes_in_group("towers")
	var current_towers = []

	for tower in towers:
		# 优先使用 tower_type 属性
		var tower_type = ""
		if "tower_type" in tower:
			tower_type = tower.tower_type
		else:
			# 降级方案：通过名称判断
			if tower.name.begins_with("TowerShooter"):
				tower_type = "shooter"
			elif tower.name.begins_with("TowerWall"):
				tower_type = "wall"
			elif tower.name.begins_with("TowerSlow"):
				tower_type = "slow"

		if tower_type != "":
			current_towers.append({
				"type": tower_type,
				"position": tower.global_position
			})

	# 更新 tower_inventory 为当前所有塔（包括之前的和新布置的）
	GameData.tower_inventory = current_towers

	get_tree().change_scene_to_file("res://scenes/main.tscn")

func load_map_background():
	# 获取选择的地图
	var map_id = GameData.selected_map

	# 验证地图配置存在
	if not GameConfig.MAPS.has(map_id):
		push_warning("未知地图: " + map_id + ", 使用默认地图")
		map_id = "forest"
		GameData.selected_map = map_id

	var map_config = GameConfig.MAPS[map_id]
	var bg_path = map_config["background"]

	# 尝试加载背景图
	if ResourceLoader.exists(bg_path):
		var bg_texture = load(bg_path)
		$Background/BackgroundSprite.texture = bg_texture
		print("加载地图背景: ", map_config["name"])
	else:
		# 降级方案：使用纯色背景
		push_warning("背景图不存在: " + bg_path + ", 使用纯色背景")
		use_fallback_background(map_id)

func use_fallback_background(map_id: String):
	# 移除 Sprite2D，使用 ColorRect
	var sprite = $Background/BackgroundSprite
	if sprite:
		sprite.queue_free()

	var color_rect = ColorRect.new()
	color_rect.size = Vector2(1920, 1080)
	color_rect.position = Vector2(-960, -540)  # 相对于 Background 节点

	var map_config = GameConfig.MAPS[map_id]
	color_rect.color = Color(map_config["fallback_color"])

	$Background.add_child(color_rect)
	print("使用纯色背景: ", map_config["name"], " (", map_config["fallback_color"], ")")
