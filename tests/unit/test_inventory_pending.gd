extends GutTest

func before_each() -> void:
	PlayerState.reset()
	PlayerProgression.reset()
	InventoryManager.reset()
	InventoryManager.coins = 100
	InventoryManager.deployed_towers = []
	InventoryManager.pending_towers = []
	InventoryManager._current_roll_offer = []

func test_roll_deducts_cost_and_offers_three() -> void:
	var ok: bool = InventoryManager.roll_tower()
	assert_true(ok)
	assert_eq(InventoryManager.coins, 100 - GameConfig.shop_config.roll_cost)
	assert_eq(InventoryManager.get_current_roll_offer().size(), 3)

func test_roll_blocked_when_no_coins() -> void:
	InventoryManager.coins = 0
	var ok: bool = InventoryManager.roll_tower()
	assert_false(ok)

func test_roll_blocked_when_pending_full() -> void:
	for i in GameConfig.shop_config.pending_queue_size:
		InventoryManager.pending_towers.append("pea_shooter")
	var ok: bool = InventoryManager.roll_tower()
	assert_false(ok)

func test_confirm_pick_adds_to_pending() -> void:
	InventoryManager.roll_tower()
	var picked_id: String = InventoryManager.get_current_roll_offer()[0]
	InventoryManager.confirm_roll_pick(0)
	assert_eq(InventoryManager.pending_towers.size(), 1)
	assert_eq(InventoryManager.pending_towers[0], picked_id)
	assert_eq(InventoryManager.get_current_roll_offer().size(), 0)

func test_cancel_refunds_cost() -> void:
	var pre: int = InventoryManager.coins
	InventoryManager.roll_tower()
	InventoryManager.cancel_roll()
	assert_eq(InventoryManager.coins, pre)
	assert_eq(InventoryManager.get_current_roll_offer().size(), 0)

func test_consume_pending_removes_and_returns_id() -> void:
	InventoryManager.pending_towers = ["pea_shooter", "ice_flower"]
	var tid: String = InventoryManager.consume_pending(0)
	assert_eq(tid, "pea_shooter")
	assert_eq(InventoryManager.pending_towers.size(), 1)
	assert_eq(InventoryManager.pending_towers[0], "ice_flower")

func test_consume_pending_invalid_index() -> void:
	var tid: String = InventoryManager.consume_pending(5)
	assert_eq(tid, "")

func test_sell_returns_70_percent() -> void:
	# 部署一座 lv1 pea_shooter
	InventoryManager.deployed_towers.append({
		id = "pea_shooter", level = 1,
		grid_pos = Vector2i(0, 0), deploy_id = 1,
	})
	var pre: int = InventoryManager.coins
	var data: TowerData = GameConfig.towers["pea_shooter"]
	var base_value: int = data.sell_price_per_level[0]
	var refund: int = InventoryManager.sell_from_deployed_tower(1)
	assert_eq(refund, int(round(base_value * 0.7)))
	assert_eq(InventoryManager.coins, pre + refund)

func test_reset_clears_pending() -> void:
	InventoryManager.pending_towers = ["pea_shooter"]
	InventoryManager._current_roll_offer = ["ice_flower", "sunflower", "pea_shooter"]
	InventoryManager.reset()
	assert_eq(InventoryManager.pending_towers.size(), 0)
	assert_eq(InventoryManager.get_current_roll_offer().size(), 0)

# ===== deploy_pending_tower(C2 + C3 修复)=====

func test_deploy_pending_tower_basic() -> void:
	InventoryManager.pending_towers = ["pea_shooter"]
	var result: Dictionary = InventoryManager.deploy_pending_tower(0, Vector2i(5, 5))
	assert_false(result.is_empty())
	assert_eq(result.tower_id, "pea_shooter")
	assert_eq(result.level, 1)
	assert_eq(result.merged_away.size(), 0)
	assert_eq(InventoryManager.pending_towers.size(), 0)
	assert_eq(InventoryManager.deployed_towers.size(), 1)

func test_deploy_pending_tower_invalid_index() -> void:
	InventoryManager.pending_towers = []
	var result: Dictionary = InventoryManager.deploy_pending_tower(0, Vector2i(5, 5))
	assert_true(result.is_empty(), "无效索引时应该拒绝部署")

func test_deploy_pending_tower_triggers_merge() -> void:
	# 已部署 1 座 pea_shooter Lv1,放下第 2 座触发合成
	InventoryManager.deployed_towers.append({
		id = "pea_shooter", level = 1,
		grid_pos = Vector2i(0, 0), deploy_id = 1,
	})
	InventoryManager._next_deploy_id = 2
	InventoryManager.pending_towers = ["pea_shooter"]
	# 给足人口
	PlayerProgression.player_level = 5
	var result: Dictionary = InventoryManager.deploy_pending_tower(0, Vector2i(5, 5))
	assert_false(result.is_empty())
	assert_eq(result.level, 2, "合成后 level = 2")
	assert_eq(result.merged_away.size(), 1, "1 个旧塔被合成消耗")
	assert_eq(result.merged_away[0], 1, "旧塔 deploy_id = 1 被消耗")
	assert_eq(InventoryManager.deployed_towers.size(), 1, "数据层只剩 1 座 Lv2")
