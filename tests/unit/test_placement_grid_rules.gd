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
	var boundary_position = Vector2(GameConfig.MAP_HALF_WIDTH, 0)
	assert_true(placement.can_place_at(boundary_position))
