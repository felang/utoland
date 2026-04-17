extends GutTest

func test_enemy_data_has_targets_towers_field():
	var data := EnemyData.new()
	assert_eq(data.targets_towers, false, "targets_towers 默认应为 false")

func test_enemy_data_targets_towers_settable():
	var data := EnemyData.new()
	data.targets_towers = true
	assert_eq(data.targets_towers, true, "targets_towers 应可设为 true")

func test_enums_has_tower_breaker():
	assert_eq(Enums.Enemy.TOWER_BREAKER, "tower_breaker")
