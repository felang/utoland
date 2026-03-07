extends GutTest

var placement: Node2D
var _original_selected_map: String
var _original_coins: int

func before_each():
	_original_selected_map = GameData.selected_map
	_original_coins = GameData.coins

	GameData.tower_inventory.clear()
	GameData.purchased_towers.clear()
	GameData.coins = 100

	var placement_scene = load("res://scenes/levels/placement.tscn")
	placement = placement_scene.instantiate()
	add_child_autofree(placement)

func after_each():
	GameData.selected_map = _original_selected_map
	GameData.coins = _original_coins

func test_get_grid_position_uses_game_config_grid_size():
	var gs = float(GameConfig.GRID_SIZE)
	assert_eq(placement._get_grid_position(Vector2(0, 0)), Vector2(gs / 2.0, gs / 2.0))
	assert_eq(
		placement._get_grid_position(Vector2(44, 44)),
		Vector2(floor(44.0 / gs) * gs + gs / 2.0, floor(44.0 / gs) * gs + gs / 2.0)
	)

func test_can_place_at_rejects_position_outside_map_extents():
	var outside_x = Vector2(GameConfig.MAP_HALF_WIDTH + GameConfig.GRID_SIZE, 0)
	var outside_y = Vector2(0, GameConfig.MAP_HALF_HEIGHT + GameConfig.GRID_SIZE)

	assert_false(placement._can_place_at(outside_x))
	assert_false(placement._can_place_at(outside_y))

func test_can_place_at_allows_position_on_map_boundary():
	var boundary_position = Vector2(GameConfig.MAP_HALF_WIDTH, 0)
	assert_true(placement._can_place_at(boundary_position))

func test_find_tower_at_returns_closest_tower():
	var tower = SceneFactory.create_tower(Enums.TowerId.SHOOTER)
	tower.global_position = Vector2(105, 105)
	tower.add_to_group(Enums.Group.TOWERS)
	placement.add_child(tower)

	var found = placement._find_tower_at(Vector2(110, 110))
	assert_eq(found, tower, "应找到最近的塔")

func test_find_tower_at_returns_null_when_too_far():
	var tower = SceneFactory.create_tower(Enums.TowerId.SHOOTER)
	tower.global_position = Vector2(105, 105)
	tower.add_to_group(Enums.Group.TOWERS)
	placement.add_child(tower)

	var found = placement._find_tower_at(Vector2(300, 300))
	assert_null(found, "距离太远应返回 null")

func test_select_placed_tower_shows_range_for_shooter():
	var tower = SceneFactory.create_tower(Enums.TowerId.SHOOTER)
	tower.global_position = Vector2(150, 150)
	tower.add_to_group(Enums.Group.TOWERS)
	placement.add_child(tower)

	placement._select_placed_tower(tower)

	assert_eq(placement._selected_placed_tower, tower, "应记录选中的塔")
	assert_true(placement._range_indicator.visible, "射手塔攻击范围圈应可见")
	assert_gt(placement._range_indicator.radius, 0.0, "范围圈半径应大于 0")

func test_deselect_tower_hides_range():
	var tower = SceneFactory.create_tower(Enums.TowerId.SHOOTER)
	tower.global_position = Vector2(150, 150)
	tower.add_to_group(Enums.Group.TOWERS)
	placement.add_child(tower)

	placement._select_placed_tower(tower)
	placement._deselect_tower()

	assert_null(placement._selected_placed_tower, "取消选中后应清空 _selected_placed_tower")
	assert_false(placement._range_indicator.visible, "取消选中后范围圈应隐藏")
