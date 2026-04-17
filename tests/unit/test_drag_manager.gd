extends GutTest

var _drag_manager: Node
var _tower_container: Node2D

func before_each() -> void:
	PlayerState.reset()
	PlayerProgression.reset()
	InventoryManager.reset()
	StatsTracker.reset()
	InventoryManager.coins = 50
	PlayerProgression.player_level = 5
	InventoryManager.deployed_towers = []
	_tower_container = Node2D.new()
	add_child(_tower_container)
	# 初始化 SceneFactory 容器，让 spawn_tower_node 能正确添加到 entity_layer
	SceneFactory.init_containers(_tower_container, _tower_container, _tower_container)
	_drag_manager = load("res://scripts/systems/drag_manager.gd").new()
	add_child(_drag_manager)

func after_each() -> void:
	_drag_manager.queue_free()
	_tower_container.queue_free()
	# 清理 SceneFactory 容器引用，避免影响其他测试
	SceneFactory.init_containers(null, null, null)

func test_grid_to_world_conversion() -> void:
	# X: 格子水平中心 = grid_x * 32 + 16 - MAP_HALF_WIDTH
	# Y: 格子底部边缘 = (grid_y + 1) * 32 - MAP_HALF_HEIGHT（塔底部对齐网格底线）
	var world_origin: Vector2 = _drag_manager._grid_to_world(Vector2i(0, 0))
	var half_w: float = GameConfig.MAP_HALF_WIDTH
	var half_h: float = GameConfig.MAP_HALF_HEIGHT
	assert_eq(world_origin, Vector2(-half_w + 16, -half_h + 32))
	var world: Vector2 = _drag_manager._grid_to_world(Vector2i(5, 5))
	assert_eq(world, Vector2(-half_w + 176, -half_h + 192))

func test_world_to_grid_conversion() -> void:
	var half_w: float = GameConfig.MAP_HALF_WIDTH
	var half_h: float = GameConfig.MAP_HALF_HEIGHT
	# 左上角世界坐标 → grid(0,0)
	var grid: Vector2i = _drag_manager._world_to_grid(Vector2(-half_w + 16, -half_h + 16))
	assert_eq(grid, Vector2i(0, 0))
	# 地图中心 → grid(22,15)（1440/32=45 格，45/2=22；960/32=30 格，30/2=15）
	var grid_center: Vector2i = _drag_manager._world_to_grid(Vector2(0, 0))
	assert_eq(grid_center, Vector2i(22, 15))

func test_is_valid_grid_pos() -> void:
	assert_true(_drag_manager._is_valid_grid_pos(Vector2i(0, 0)))
	assert_true(_drag_manager._is_valid_grid_pos(Vector2i(44, 29)))
	assert_false(_drag_manager._is_valid_grid_pos(Vector2i(-1, 0)))
	assert_false(_drag_manager._is_valid_grid_pos(Vector2i(45, 0)))
	assert_false(_drag_manager._is_valid_grid_pos(Vector2i(0, 30)))

func test_is_grid_available_empty() -> void:
	assert_true(_drag_manager._is_grid_available(Vector2i(5, 5)))

func test_is_grid_available_occupied() -> void:
	InventoryManager.deployed_towers.append({id = "pea_shooter", level = 1, grid_pos = Vector2i(5, 5), deploy_id = 1})
	assert_false(_drag_manager._is_grid_available(Vector2i(5, 5)))
	assert_true(_drag_manager._is_grid_available(Vector2i(6, 6)))

func test_spawn_tower_node() -> void:
	var deploy_id := 1
	InventoryManager.deployed_towers.append({id = "pea_shooter", level = 1, grid_pos = Vector2i(5, 5), deploy_id = deploy_id})
	_drag_manager.spawn_tower_node(deploy_id, "pea_shooter", 1, Vector2i(5, 5))
	assert_true(deploy_id in _drag_manager._tower_nodes)
	assert_eq(_tower_container.get_child_count(), 1)

func test_remove_tower_node() -> void:
	var deploy_id := 1
	InventoryManager.deployed_towers.append({id = "pea_shooter", level = 1, grid_pos = Vector2i(5, 5), deploy_id = deploy_id})
	_drag_manager.spawn_tower_node(deploy_id, "pea_shooter", 1, Vector2i(5, 5))
	_drag_manager._remove_tower_node(deploy_id)
	assert_false(deploy_id in _drag_manager._tower_nodes)

func test_remove_tower_nodes_batch() -> void:
	InventoryManager.deployed_towers.append({id = "pea_shooter", level = 1, grid_pos = Vector2i(5, 5), deploy_id = 1})
	InventoryManager.deployed_towers.append({id = "ice_flower", level = 1, grid_pos = Vector2i(10, 10), deploy_id = 2})
	_drag_manager.spawn_tower_node(1, "pea_shooter", 1, Vector2i(5, 5))
	_drag_manager.spawn_tower_node(2, "ice_flower", 1, Vector2i(10, 10))
	_drag_manager.remove_tower_nodes([1, 2])
	assert_eq(_drag_manager._tower_nodes.size(), 0)

# ===== 商店模式 =====

func test_set_shop_mode() -> void:
	_drag_manager.set_shop_mode(true)
	assert_true(_drag_manager._is_shop_mode)
	_drag_manager.set_shop_mode(false)
	assert_false(_drag_manager._is_shop_mode)

func test_is_grid_available_move_tower_excludes_self() -> void:
	InventoryManager.deployed_towers.append({id = "pea_shooter", level = 1, grid_pos = Vector2i(5, 5), deploy_id = 1})
	_drag_manager._drag_source = _drag_manager.DragSource.MOVE_TOWER
	_drag_manager._drag_original_deploy_id = 1
	assert_true(_drag_manager._is_grid_available(Vector2i(5, 5)))

# ===== 塔升级 =====

func test_upgrade_tower_node() -> void:
	var deploy_id := 1
	InventoryManager.deployed_towers.append({id = "pea_shooter", level = 1, grid_pos = Vector2i(5, 5), deploy_id = deploy_id})
	_drag_manager.spawn_tower_node(deploy_id, "pea_shooter", 1, Vector2i(5, 5))
	assert_true(deploy_id in _drag_manager._tower_nodes)
	_drag_manager.upgrade_tower_node(deploy_id, "pea_shooter", 2, Vector2i(5, 5))
	assert_true(deploy_id in _drag_manager._tower_nodes)

# ===== 可放置性校验 =====

func test_placeable_cells_blocks_invalid_pos():
	_drag_manager.placeable_cells = {Vector2i(5, 5): true, Vector2i(6, 6): true}
	assert_true(_drag_manager._is_grid_available(Vector2i(5, 5)), "在 placeable_cells 中的位置应可用")
	assert_false(_drag_manager._is_grid_available(Vector2i(10, 10)), "不在 placeable_cells 中的位置应不可用")


func test_empty_placeable_cells_allows_all():
	_drag_manager.placeable_cells = {}
	assert_true(_drag_manager._is_grid_available(Vector2i(10, 10)), "空 placeable_cells 应允许所有位置")

