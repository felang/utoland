extends GutTest

## MapLayout 单元测试

var layout: MapLayout


func before_each():
	layout = MapLayout.new()


func test_grid_dimensions():
	assert_eq(layout.grid.size(), 24, "网格高度应为 24")
	assert_eq(layout.grid[0].size(), 40, "网格宽度应为 40")


func test_initial_cells_are_ground():
	for y in range(MapLayout.PLAYABLE_HEIGHT):
		for x in range(MapLayout.PLAYABLE_WIDTH):
			assert_eq(layout.get_cell(Vector2i(x, y)), MapLayout.CellType.GROUND)


func test_set_and_get_cell():
	layout.set_cell(Vector2i(5, 5), MapLayout.CellType.WALL)
	assert_eq(layout.get_cell(Vector2i(5, 5)), MapLayout.CellType.WALL)


func test_out_of_bounds_returns_border():
	assert_eq(layout.get_cell(Vector2i(-1, 0)), MapLayout.CellType.BORDER)
	assert_eq(layout.get_cell(Vector2i(40, 0)), MapLayout.CellType.BORDER)


func test_is_passable():
	assert_true(layout.is_passable(Vector2i(5, 5)), "GROUND 应可通行")
	layout.set_cell(Vector2i(5, 5), MapLayout.CellType.SPAWN_ZONE)
	assert_true(layout.is_passable(Vector2i(5, 5)), "SPAWN_ZONE 应可通行")
	layout.set_cell(Vector2i(5, 5), MapLayout.CellType.WALL)
	assert_false(layout.is_passable(Vector2i(5, 5)), "WALL 不可通行")
	layout.set_cell(Vector2i(5, 5), MapLayout.CellType.ABYSS)
	assert_false(layout.is_passable(Vector2i(5, 5)), "ABYSS 不可通行")


func test_grid_to_world_center():
	var world_pos := layout.grid_to_world(Vector2i(19, 11))
	assert_almost_eq(world_pos.x, 0.0, 1.0, "中心 x 应接近 0")
	assert_almost_eq(world_pos.y, -16.0, 1.0, "中心 y 应接近 -16")


func test_get_placeable_dict():
	layout.placeable_cells = [Vector2i(5, 5), Vector2i(10, 10)]
	var dict := layout.get_placeable_dict()
	assert_true(dict.has(Vector2i(5, 5)))
	assert_true(dict.has(Vector2i(10, 10)))
	assert_false(dict.has(Vector2i(0, 0)))

