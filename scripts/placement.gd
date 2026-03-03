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
	# 保存塔的位置到 GameData
	var towers = get_tree().get_nodes_in_group("towers")
	GameData.tower_inventory = []
	for tower in towers:
		var tower_type = ""
		if tower.name.begins_with("TowerShooter"):
			tower_type = "shooter"
		elif tower.name.begins_with("TowerWall"):
			tower_type = "wall"
		elif tower.name.begins_with("TowerSlow"):
			tower_type = "slow"
		
		GameData.tower_inventory.append({
			"type": tower_type,
			"position": tower.global_position
		})

	get_tree().change_scene_to_file("res://scenes/main.tscn")
