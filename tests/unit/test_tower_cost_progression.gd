extends GutTest

func before_each() -> void:
	PlayerState.current_character = "ranger"
	InventoryManager.reset()
	InventoryManager.coins = 1000

func test_base_cost_with_no_deployed():
	var cost: int = InventoryManager.calc_tower_buy_cost("pea_shooter")
	assert_eq(cost, GameConfig.shop_config.tower_cost_base, "0 座时应等于 base cost")

func test_cost_increases_with_deployed_count():
	InventoryManager.deployed_towers.append({id = "pea_shooter", level = 1, grid_pos = Vector2i(0,0), deploy_id = 1})
	var cost: int = InventoryManager.calc_tower_buy_cost("pea_shooter")
	var expected: int = GameConfig.shop_config.tower_cost_base + GameConfig.shop_config.tower_cost_per_same_type
	assert_eq(cost, expected, "1 座已部署后价格应为 base + per_same_type")

func test_pending_towers_also_count():
	InventoryManager.pending_towers.append("pea_shooter")
	var cost: int = InventoryManager.calc_tower_buy_cost("pea_shooter")
	var expected: int = GameConfig.shop_config.tower_cost_base + GameConfig.shop_config.tower_cost_per_same_type
	assert_eq(cost, expected, "pending 塔也计入 N")

func test_different_types_independent():
	InventoryManager.deployed_towers.append({id = "pea_shooter", level = 1, grid_pos = Vector2i(0,0), deploy_id = 1})
	var pea_cost: int = InventoryManager.calc_tower_buy_cost("pea_shooter")
	var ice_cost: int = InventoryManager.calc_tower_buy_cost("ice_flower")
	assert_gt(pea_cost, ice_cost, "不同类型价格独立")
	assert_eq(ice_cost, GameConfig.shop_config.tower_cost_base, "ice_flower 无同类应为 base")
