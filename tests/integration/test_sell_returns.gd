extends GutTest

func before_each() -> void:
	PlayerState.reset()
	PlayerProgression.reset()
	InventoryManager.reset()
	InventoryManager.coins = 0

func test_sell_lv1_tower_70_percent() -> void:
	# 新公式: N_before=1(无其他同类), cost_at_0 = tower_cost_base
	var cfg: ShopConfig = GameConfig.shop_config
	InventoryManager.deployed_towers.append({
		id = "pea_shooter", level = 1,
		grid_pos = Vector2i(0, 0), deploy_id = 1,
	})
	var refund: int = InventoryManager.sell_from_deployed_tower(1)
	assert_eq(refund, int(round(cfg.tower_cost_base * cfg.sell_return_ratio)))
	assert_eq(InventoryManager.coins, refund)
	assert_eq(InventoryManager.deployed_towers.size(), 0)

func test_sell_lv2_tower_70_percent_of_lv2_price() -> void:
	# 新公式: lv2 塔被卖出前 N_before=1, cost_at_0 = tower_cost_base(等级不影响价格)
	var cfg: ShopConfig = GameConfig.shop_config
	InventoryManager.deployed_towers.append({
		id = "pea_shooter", level = 2,
		grid_pos = Vector2i(0, 0), deploy_id = 1,
	})
	var refund: int = InventoryManager.sell_from_deployed_tower(1)
	assert_eq(refund, int(round(cfg.tower_cost_base * cfg.sell_return_ratio)))
