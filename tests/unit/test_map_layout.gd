extends GutTest

var layout: MapLayout

func before_each() -> void:
	layout = MapLayout.new()
	layout.grid_width = 40
	layout.grid_height = 24
	layout.player_spawn = Vector2i(19, 12)
	layout.spawn_points = {
		"north": Vector2i(20, 0),
		"south": Vector2i(20, 23),
		"east": Vector2i(39, 12),
		"west": Vector2i(0, 12),
	}
	layout.init_grid()

func test_grid_dimensions() -> void:
	assert_eq(layout.grid.size(), 24, "grid should have 24 rows")
	assert_eq(layout.grid[0].size(), 40, "grid should have 40 columns")

func test_default_cells_are_ground() -> void:
	assert_eq(layout.grid[0][0], MapLayout.CellType.GROUND)
	assert_eq(layout.grid[12][20], MapLayout.CellType.GROUND)

func test_set_and_get_cell() -> void:
	layout.set_cell(Vector2i(5, 3), MapLayout.CellType.OBSTACLE)
	assert_eq(layout.get_cell(Vector2i(5, 3)), MapLayout.CellType.OBSTACLE)

func test_is_ground() -> void:
	assert_true(layout.is_ground(Vector2i(10, 10)))
	layout.set_cell(Vector2i(10, 10), MapLayout.CellType.OBSTACLE)
	assert_false(layout.is_ground(Vector2i(10, 10)))

func test_out_of_bounds_is_not_ground() -> void:
	assert_false(layout.is_ground(Vector2i(-1, 0)))
	assert_false(layout.is_ground(Vector2i(40, 0)))
	assert_false(layout.is_ground(Vector2i(0, 24)))

func test_is_placeable_on_ground() -> void:
	assert_true(layout.is_placeable(Vector2i(10, 10)))

func test_is_placeable_false_on_obstacle() -> void:
	layout.set_cell(Vector2i(10, 10), MapLayout.CellType.OBSTACLE)
	assert_false(layout.is_placeable(Vector2i(10, 10)))

func test_is_placeable_false_on_player_spawn() -> void:
	assert_false(layout.is_placeable(Vector2i(19, 12)))

func test_is_placeable_false_on_spawn_point() -> void:
	assert_false(layout.is_placeable(Vector2i(20, 0)))
	assert_false(layout.is_placeable(Vector2i(0, 12)))

func test_grid_to_world() -> void:
	var world := layout.grid_to_world(Vector2i(0, 0))
	assert_almost_eq(world.x, -608.0, 0.1)
	assert_almost_eq(world.y, -368.0, 0.1)

func test_grid_to_world_center() -> void:
	var world := layout.grid_to_world(Vector2i(19, 12))
	assert_almost_eq(world.x, 0.0, 0.1)
	assert_almost_eq(world.y, 16.0, 0.1)

func test_world_to_grid() -> void:
	var grid_pos := layout.world_to_grid(Vector2(-608.0, -368.0))
	assert_eq(grid_pos, Vector2i(0, 0))

func test_world_to_grid_roundtrip() -> void:
	var original := Vector2i(15, 8)
	var world := layout.grid_to_world(original)
	var back := layout.world_to_grid(world)
	assert_eq(back, original)

func test_get_placeable_dict() -> void:
	layout.set_cell(Vector2i(5, 5), MapLayout.CellType.OBSTACLE)
	var dict := layout.get_placeable_dict()
	assert_true(dict.has(Vector2i(10, 10)))
	assert_false(dict.has(Vector2i(5, 5)))
	assert_false(dict.has(Vector2i(19, 12)))

func test_get_spawn_points_world() -> void:
	var world_points := layout.get_spawn_points_world()
	assert_eq(world_points.size(), 4)
	assert_true(world_points.has("north"))
	assert_true(world_points.has("south"))
	assert_true(world_points.has("east"))
	assert_true(world_points.has("west"))
