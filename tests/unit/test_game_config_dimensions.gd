extends GutTest

func test_world_size_constants_are_defined():
	assert_eq(GameConfig.BASE_VIEWPORT_WIDTH, 640)
	assert_eq(GameConfig.BASE_VIEWPORT_HEIGHT, 360)
	assert_eq(GameConfig.PPU, 32)
	assert_eq(GameConfig.GRID_SIZE, 32)
	assert_eq(GameConfig.MAP_COLS, 40)
	assert_eq(GameConfig.MAP_ROWS, 30)
	assert_eq(GameConfig.MAP_PIXEL_WIDTH, 1280)
	assert_eq(GameConfig.MAP_PIXEL_HEIGHT, 960)

func test_map_half_extents_are_correct():
	assert_eq(GameConfig.MAP_HALF_WIDTH, 640)
	assert_eq(GameConfig.MAP_HALF_HEIGHT, 480)

func test_viewport_matches_new_standard():
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_width"), 640)
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_height"), 360)

func test_new_dimension_standard_values_are_stable():
	assert_eq(GameConfig.GRID_SIZE, GameConfig.PPU)
	assert_eq(GameConfig.MAP_PIXEL_WIDTH, 40 * 32)
	assert_eq(GameConfig.MAP_PIXEL_HEIGHT, 30 * 32)

func test_entity_dimension_constants_are_stable():
	assert_eq(GameConfig.ENTITY_SIZE_STANDARD, 32)
	assert_eq(GameConfig.ENTITY_SIZE_TANK, 48)
	assert_eq(GameConfig.BULLET_SIZE, 6)
	assert_eq(GameConfig.COIN_RADIUS, 6)

func test_entity_and_ui_size_tokens_are_grid_aligned():
	assert_eq(GameConfig.ENTITY_SIZE_STANDARD, GameConfig.GRID_SIZE)
	assert_eq(GameConfig.BULLET_SIZE, int(GameConfig.GRID_SIZE * 0.2))
	assert_eq(GameConfig.UI_BUTTON_SIZE, Vector2(160, 36))
