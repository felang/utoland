extends GutTest

var _original_owned_towers: Dictionary

func before_each():
	_original_owned_towers = GameData.owned_towers.duplicate()
	GameData.owned_towers = {"pea_shooter": 1}

func after_each():
	GameData.owned_towers = _original_owned_towers

func test_scene_factory_get_tower_cost_reads_level():
	GameData.owned_towers = {"pea_shooter": 3}
	var td: TowerData = GameConfig.towers["pea_shooter"]
	var expected_cost: int = td.place_cost_per_level[2]
	assert_eq(SceneFactory.get_tower_cost("pea_shooter"), expected_cost,
		"Lv3 放置费用应读 place_cost_per_level[2]")

func test_tower_upgrade_applies_globally():
	var tower: Node2D = SceneFactory.create_tower("pea_shooter")
	add_child_autofree(tower)
	var td: TowerData = GameConfig.towers["pea_shooter"]
	assert_almost_eq(tower.health.max_hp, td.hp_per_level[0], 0.01, "Lv1 HP")
	GameData.owned_towers["pea_shooter"] = 2
	EventBus.tower_upgraded.emit("pea_shooter")
	assert_almost_eq(tower.health.max_hp, td.hp_per_level[1], 0.01, "Lv2 HP 应全局更新")

func test_tower_data_has_level_fields():
	var td: TowerData = GameConfig.towers["pea_shooter"]
	assert_eq(td.max_level, 5, "应有最大等级 5")
	assert_eq(td.hp_per_level.size(), 5, "hp_per_level 应有 5 级")
	assert_eq(td.damage_per_level.size(), 5, "damage_per_level 应有 5 级")
	assert_eq(td.shop_price_per_level.size(), 5, "shop_price_per_level 应有 5 级")
	assert_eq(td.place_cost_per_level.size(), 5, "place_cost_per_level 应有 5 级")

func test_tower_wall_has_level_fields():
	var td: TowerData = GameConfig.towers["stump"]
	assert_eq(td.hp_per_level.size(), 5, "墙塔应有 5 级 HP")

func test_tower_slow_has_level_fields():
	var td: TowerData = GameConfig.towers["ice_flower"]
	assert_eq(td.slow_ratio_per_level.size(), 5, "减速塔应有 5 级减速比例")
