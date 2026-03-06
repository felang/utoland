extends GutTest

var placement: Node2D

func before_each():
	GameData.tower_inventory.clear()
	GameData.purchased_towers.clear()
	GameData.coins = 100

	var placement_scene = load("res://scenes/placement.tscn")
	placement = placement_scene.instantiate()
	add_child_autofree(placement)

func test_get_grid_position_uses_30_size_grid():
	assert_eq(placement.get_grid_position(Vector2(0, 0)), Vector2(15, 15))
	assert_eq(placement.get_grid_position(Vector2(44, 44)), Vector2(45, 45))

func test_can_place_at_rejects_position_outside_map_extents():
	var outside_x = Vector2(GameConfig.MAP_HALF_WIDTH + GameConfig.GRID_SIZE, 0)
	var outside_y = Vector2(0, GameConfig.MAP_HALF_HEIGHT + GameConfig.GRID_SIZE)

	assert_false(placement.can_place_at(outside_x))
	assert_false(placement.can_place_at(outside_y))
