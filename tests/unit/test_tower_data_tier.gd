extends GutTest

func test_pea_shooter_tier_loaded() -> void:
	var data: TowerData = GameConfig.towers["pea_shooter"]
	assert_eq(data.tier, 1)

func test_ice_flower_tier_loaded() -> void:
	var data: TowerData = GameConfig.towers["ice_flower"]
	assert_eq(data.tier, 1)

func test_sunflower_tier_loaded() -> void:
	var data: TowerData = GameConfig.towers["sunflower"]
	assert_eq(data.tier, 1)
