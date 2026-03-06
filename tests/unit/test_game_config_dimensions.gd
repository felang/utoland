extends GutTest

func test_world_size_constants_are_defined():
	assert_eq(GameConfig.BASE_VIEWPORT_WIDTH, 640)
	assert_eq(GameConfig.BASE_VIEWPORT_HEIGHT, 360)
	assert_eq(GameConfig.PPU, 30)
	assert_eq(GameConfig.GRID_SIZE, 30)
	assert_eq(GameConfig.MAP_COLS, 40)
	assert_eq(GameConfig.MAP_ROWS, 30)
	assert_eq(GameConfig.MAP_PIXEL_WIDTH, 1200)
	assert_eq(GameConfig.MAP_PIXEL_HEIGHT, 900)

func test_map_half_extents_are_correct():
	assert_eq(GameConfig.MAP_HALF_WIDTH, 600)
	assert_eq(GameConfig.MAP_HALF_HEIGHT, 450)

func test_viewport_matches_new_standard():
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_width"), 640)
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_height"), 360)

func test_new_dimension_standard_values_are_stable():
	assert_eq(GameConfig.GRID_SIZE, GameConfig.PPU)
	assert_eq(GameConfig.MAP_PIXEL_WIDTH, 40 * 30)
	assert_eq(GameConfig.MAP_PIXEL_HEIGHT, 30 * 30)

func test_entity_dimension_constants_are_stable():
	assert_eq(GameConfig.ENTITY_SIZE_STANDARD, 30)
	assert_eq(GameConfig.ENTITY_SIZE_TANK, 45)
	assert_eq(GameConfig.BULLET_SIZE, 6)
	assert_eq(GameConfig.COIN_RADIUS, 6)
