extends GutTest

var placement: Node2D
var _original_selected_map: String
var _original_coins: int
var _original_owned_towers: Dictionary

func before_each():
	_original_selected_map = GameData.selected_map
	_original_coins = GameData.coins
	_original_owned_towers = GameData.owned_towers.duplicate()

	GameData.tower_inventory.clear()
	GameData.owned_towers = {"pea_shooter": 1, "stump": 1, "ice_flower": 1}
	GameData.coins = 100

	var placement_scene = load("res://scenes/levels/placement.tscn")
	placement = placement_scene.instantiate()
	add_child_autofree(placement)

func after_each():
	GameData.selected_map = _original_selected_map
	GameData.coins = _original_coins
	GameData.owned_towers = _original_owned_towers

func test_get_grid_position_uses_game_config_grid_size():
	var gs = float(GameConfig.GRID_SIZE)
	assert_eq(placement.get_grid_position(Vector2(0, 0)), Vector2(gs / 2.0, gs / 2.0))
	assert_eq(
		placement.get_grid_position(Vector2(44, 44)),
		Vector2(floor(44.0 / gs) * gs + gs / 2.0, floor(44.0 / gs) * gs + gs / 2.0)
	)

func test_can_place_at_rejects_position_outside_map_extents():
	var outside_x = Vector2(GameConfig.MAP_HALF_WIDTH + GameConfig.GRID_SIZE, 0)
	var outside_y = Vector2(0, GameConfig.MAP_HALF_HEIGHT + GameConfig.GRID_SIZE)

	assert_false(placement.can_place_at(outside_x))
	assert_false(placement.can_place_at(outside_y))

func test_can_place_at_allows_position_on_map_boundary():
	# 使用略靠内的位置，避免 float32(Vector2) vs float64 精度边界问题
	var boundary_position = Vector2(GameConfig.MAP_HALF_WIDTH - 1.0, 0)
	assert_true(placement.can_place_at(boundary_position))

func test_find_tower_at_returns_closest_tower():
	var tower = SceneFactory.create_tower(Enums.TowerId.PEA_SHOOTER)
	tower.global_position = Vector2(105, 105)
	tower.add_to_group(Enums.Group.TOWERS)
	placement.add_child(tower)

	var found = placement.find_tower_at(Vector2(110, 110))
	assert_eq(found, tower, "应找到最近的塔")

func test_find_tower_at_returns_null_when_too_far():
	var tower = SceneFactory.create_tower(Enums.TowerId.PEA_SHOOTER)
	tower.global_position = Vector2(105, 105)
	tower.add_to_group(Enums.Group.TOWERS)
	placement.add_child(tower)

	var found = placement.find_tower_at(Vector2(300, 300))
	assert_null(found, "距离太远应返回 null")

func test_select_placed_tower_shows_range_for_shooter():
	var tower = SceneFactory.create_tower(Enums.TowerId.PEA_SHOOTER)
	tower.global_position = Vector2(150, 150)
	tower.add_to_group(Enums.Group.TOWERS)
	placement.add_child(tower)

	placement._placement_panel._select_placed_tower(tower)

	assert_eq(placement._placement_panel._selected_placed_tower, tower, "应记录选中的塔")
	assert_true(placement._range_indicator.visible, "射手塔攻击范围圈应可见")
	assert_gt(placement._range_indicator.radius, 0.0, "范围圈半径应大于 0")

func test_deselect_tower_hides_range():
	var tower = SceneFactory.create_tower(Enums.TowerId.PEA_SHOOTER)
	tower.global_position = Vector2(150, 150)
	tower.add_to_group(Enums.Group.TOWERS)
	placement.add_child(tower)

	placement._placement_panel._select_placed_tower(tower)
	placement._placement_panel._deselect_tower()

	assert_null(placement._placement_panel._selected_placed_tower, "取消选中后应清空 _selected_placed_tower")
	assert_false(placement._range_indicator.visible, "取消选中后范围圈应隐藏")

func test_remove_tower_refunds_coins():
	GameData.coins = 60

	var tower = SceneFactory.create_tower(Enums.TowerId.PEA_SHOOTER)
	tower.global_position = Vector2(105, 105)
	tower.add_to_group(Enums.Group.TOWERS)
	placement.add_child(tower)

	var cost: int = SceneFactory.get_tower_cost(Enums.TowerId.PEA_SHOOTER)
	placement._placement_panel._remove_tower_at(Vector2(110, 110))

	assert_eq(GameData.coins, 60 + cost, "移除塔应退还金币")

func test_remove_tower_at_empty_does_nothing():
	GameData.coins = 60
	placement._placement_panel._remove_tower_at(Vector2(500, 500))
	assert_eq(GameData.coins, 60, "空位置不应改变金币")

