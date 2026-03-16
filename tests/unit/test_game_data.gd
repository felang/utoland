extends GutTest

func before_each() -> void:
	GameData.reset()
	GameData.deployed_weapons = []
	GameData.deployed_towers = []
	GameData.player_level = 1  # 人口上限 2
	GameData.coins = 100

# ===== can_buy_item =====

func test_can_buy_item_true_when_population_available() -> void:
	assert_true(GameData.can_buy_item("bow", 1))

func test_can_buy_item_false_when_pop_full_no_merge() -> void:
	GameData.deployed_weapons.append({id = "bow", level = 1})
	GameData.deployed_towers.append({id = "pea_shooter", level = 1, grid_pos = Vector2i(0, 0), deploy_id = 1})
	assert_false(GameData.can_buy_item("shuriken", 1))

func test_can_buy_item_true_when_pop_full_but_merge_possible() -> void:
	GameData.deployed_weapons.append({id = "bow", level = 1})
	GameData.deployed_weapons.append({id = "bow", level = 1})
	assert_true(GameData.can_buy_item("bow", 1))

func test_can_buy_item_false_when_pop_full_only_1_match() -> void:
	GameData.deployed_weapons.append({id = "bow", level = 1})
	GameData.deployed_towers.append({id = "pea_shooter", level = 1, grid_pos = Vector2i(0, 0), deploy_id = 1})
	assert_false(GameData.can_buy_item("bow", 1))

func test_can_buy_item_tower_merge_possible() -> void:
	GameData.deployed_towers.append({id = "pea_shooter", level = 1, grid_pos = Vector2i(0, 0), deploy_id = 1})
	GameData.deployed_towers.append({id = "pea_shooter", level = 1, grid_pos = Vector2i(1, 0), deploy_id = 2})
	assert_true(GameData.can_buy_item("pea_shooter", 1))
