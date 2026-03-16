extends GutTest

var _drag_manager: Node
var _tower_container: Node2D

func before_each() -> void:
	GameData.reset()
	GameData.coins = 50
	GameData.player_level = 5
	GameData.deployed_weapons = []
	GameData.deployed_towers = []
	_tower_container = Node2D.new()
	add_child(_tower_container)
	_drag_manager = load("res://scripts/systems/drag_manager.gd").new()
	_drag_manager._tower_container = _tower_container
	add_child(_drag_manager)

func after_each() -> void:
	_drag_manager.queue_free()
	_tower_container.queue_free()

func test_grid_to_world_conversion() -> void:
	var world: Vector2 = _drag_manager._grid_to_world(Vector2i(5, 5))
	var expected := Vector2(5 * 16 + 8, 5 * 16 + 8)
	assert_eq(world, expected)

func test_world_to_grid_conversion() -> void:
	var grid: Vector2i = _drag_manager._world_to_grid(Vector2(88, 88))
	assert_eq(grid, Vector2i(5, 5))

func test_is_valid_grid_pos() -> void:
	assert_true(_drag_manager._is_valid_grid_pos(Vector2i(0, 0)))
	assert_true(_drag_manager._is_valid_grid_pos(Vector2i(33, 25)))
	assert_false(_drag_manager._is_valid_grid_pos(Vector2i(-1, 0)))
	assert_false(_drag_manager._is_valid_grid_pos(Vector2i(34, 0)))
	assert_false(_drag_manager._is_valid_grid_pos(Vector2i(0, 26)))

func test_is_grid_available_empty() -> void:
	assert_true(_drag_manager._is_grid_available(Vector2i(5, 5)))

func test_is_grid_available_occupied() -> void:
	GameData.deployed_towers.append({id = "pea_shooter", level = 1, grid_pos = Vector2i(5, 5), deploy_id = 1})
	assert_false(_drag_manager._is_grid_available(Vector2i(5, 5)))
	assert_true(_drag_manager._is_grid_available(Vector2i(6, 6)))

func test_spawn_tower_node() -> void:
	var deploy_id := 1
	GameData.deployed_towers.append({id = "pea_shooter", level = 1, grid_pos = Vector2i(5, 5), deploy_id = deploy_id})
	_drag_manager.spawn_tower_node(deploy_id, "pea_shooter", 1, Vector2i(5, 5))
	assert_true(deploy_id in _drag_manager._tower_nodes)
	assert_eq(_tower_container.get_child_count(), 1)

func test_remove_tower_node() -> void:
	var deploy_id := 1
	GameData.deployed_towers.append({id = "pea_shooter", level = 1, grid_pos = Vector2i(5, 5), deploy_id = deploy_id})
	_drag_manager.spawn_tower_node(deploy_id, "pea_shooter", 1, Vector2i(5, 5))
	_drag_manager._remove_tower_node(deploy_id)
	assert_false(deploy_id in _drag_manager._tower_nodes)

func test_remove_tower_nodes_batch() -> void:
	GameData.deployed_towers.append({id = "pea_shooter", level = 1, grid_pos = Vector2i(5, 5), deploy_id = 1})
	GameData.deployed_towers.append({id = "ice_flower", level = 1, grid_pos = Vector2i(10, 10), deploy_id = 2})
	_drag_manager.spawn_tower_node(1, "pea_shooter", 1, Vector2i(5, 5))
	_drag_manager.spawn_tower_node(2, "ice_flower", 1, Vector2i(10, 10))
	_drag_manager.remove_tower_nodes([1, 2])
	assert_eq(_drag_manager._tower_nodes.size(), 0)
