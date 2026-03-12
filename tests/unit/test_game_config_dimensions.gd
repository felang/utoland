extends GutTest

func test_viewport_constants_unchanged():
	assert_eq(GameConfig.BASE_VIEWPORT_WIDTH, 640)
	assert_eq(GameConfig.BASE_VIEWPORT_HEIGHT, 360)
	assert_eq(GameConfig.PPU, 32)
	assert_eq(GameConfig.GRID_SIZE, 32)

func test_map_dimensions_are_dynamically_computed():
	var fx: EffectConfigData = GameConfig.effects
	var expected_w: float = GameConfig.BASE_VIEWPORT_WIDTH / fx.camera_zoom * fx.map_size_ratio
	var expected_h: float = GameConfig.BASE_VIEWPORT_HEIGHT / fx.camera_zoom * fx.map_size_ratio
	assert_almost_eq(GameConfig.MAP_PIXEL_WIDTH, expected_w, 0.01, "MAP_PIXEL_WIDTH 应等于 viewport/zoom*ratio")
	assert_almost_eq(GameConfig.MAP_PIXEL_HEIGHT, expected_h, 0.01, "MAP_PIXEL_HEIGHT 应等于 viewport/zoom*ratio")

func test_map_half_extents_are_half_of_full():
	assert_almost_eq(GameConfig.MAP_HALF_WIDTH, GameConfig.MAP_PIXEL_WIDTH / 2.0, 0.01)
	assert_almost_eq(GameConfig.MAP_HALF_HEIGHT, GameConfig.MAP_PIXEL_HEIGHT / 2.0, 0.01)

func test_viewport_matches_project_settings():
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_width"), 640)
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_height"), 360)

func test_entity_dimension_constants_are_stable():
	assert_eq(GameConfig.ENTITY_SIZE_STANDARD, 32)
	assert_eq(GameConfig.ENTITY_SIZE_TANK, 48)
	assert_eq(GameConfig.BULLET_SIZE, 6)
	assert_eq(GameConfig.COIN_RADIUS, 6)

func test_entity_and_ui_size_tokens_are_grid_aligned():
	assert_eq(GameConfig.ENTITY_SIZE_STANDARD, GameConfig.GRID_SIZE)
	assert_eq(GameConfig.BULLET_SIZE, int(GameConfig.GRID_SIZE * 0.2))
	assert_eq(GameConfig.UI_BUTTON_SIZE, Vector2(160, 36))
