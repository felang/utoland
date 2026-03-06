extends GutTest

func test_spawner_bounds_follow_game_config():
	var spawner = preload("res://scripts/systems/enemy_spawner.gd").new()
	assert_eq(spawner.map_min_x, -float(GameConfig.MAP_HALF_WIDTH))
	assert_eq(spawner.map_max_x, float(GameConfig.MAP_HALF_WIDTH))
	assert_eq(spawner.map_min_y, -float(GameConfig.MAP_HALF_HEIGHT))
	assert_eq(spawner.map_max_y, float(GameConfig.MAP_HALF_HEIGHT))
