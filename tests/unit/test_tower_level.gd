extends GutTest

func test_tower_data_has_level_fields():
	var td: TowerData = GameConfig.towers["shooter"]
	assert_eq(td.max_level, 5, "应有最大等级 5")
	assert_eq(td.hp_per_level.size(), 5, "hp_per_level 应有 5 级")
	assert_eq(td.damage_per_level.size(), 5, "damage_per_level 应有 5 级")
	assert_eq(td.shop_price_per_level.size(), 5, "shop_price_per_level 应有 5 级")
	assert_eq(td.place_cost_per_level.size(), 5, "place_cost_per_level 应有 5 级")

func test_tower_wall_has_level_fields():
	var td: TowerData = GameConfig.towers["wall"]
	assert_eq(td.hp_per_level.size(), 5, "墙塔应有 5 级 HP")

func test_tower_slow_has_level_fields():
	var td: TowerData = GameConfig.towers["slow"]
	assert_eq(td.slow_ratio_per_level.size(), 5, "减速塔应有 5 级减速比例")
