extends GutTest

func test_scene_factory_create_tower_with_level():
	var tower: Node2D = SceneFactory.create_tower("pea_shooter", 2)
	add_child_autofree(tower)
	var td: TowerData = GameConfig.towers["pea_shooter"]
	assert_almost_eq(tower.health.max_hp, td.hp_per_level[1], 0.01,
		"Lv2 HP 应读 hp_per_level[1]")

func test_tower_data_has_level_fields():
	var td: TowerData = GameConfig.towers["pea_shooter"]
	assert_eq(td.max_level, 3, "应有最大等级 3")
	assert_eq(td.hp_per_level.size(), 3, "hp_per_level 应有 3 级")
	assert_eq(td.damage_per_level.size(), 3, "damage_per_level 应有 3 级")
	assert_eq(td.sell_price_per_level.size(), 3, "sell_price_per_level 应有 3 级")

func test_tower_ice_flower_has_level_fields():
	var td: TowerData = GameConfig.towers["ice_flower"]
	assert_eq(td.hp_per_level.size(), 3, "冰花塔应有 3 级 HP")

func test_tower_slow_has_level_fields():
	var td: TowerData = GameConfig.towers["ice_flower"]
	assert_eq(td.slow_ratio_per_level.size(), 3, "减速塔应有 3 级减速比例")
