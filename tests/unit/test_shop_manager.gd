extends GutTest
## ShopManager 单元测试
## 覆盖：刷新商店、首次刷新保证推荐物品、购买逻辑、手动刷新、稀有度权重

var _shop: ShopManager

func before_each() -> void:
	GameData.reset()
	GameData.bag = []
	GameData.deployed_weapons = []
	GameData.deployed_towers = []
	GameData.shop_slots = []
	GameData.player_level = 1
	GameData.coins = 100
	_shop = ShopManager.new()

# ===== refresh_shop =====

func test_refresh_shop_generates_4_slots() -> void:
	_shop.refresh_shop()
	assert_eq(GameData.shop_slots.size(), 4, "刷新后应有 4 个商店槽位")

func test_refresh_shop_slots_have_required_fields() -> void:
	_shop.refresh_shop()
	for slot in GameData.shop_slots:
		if slot.is_empty():
			continue
		assert_true(slot.has("id"), "槽位应有 id")
		assert_true(slot.has("type"), "槽位应有 type")
		assert_true(slot.has("rarity"), "槽位应有 rarity")
		assert_true(slot.has("cost"), "槽位应有 cost")

func test_refresh_shop_level1_all_rarity0() -> void:
	# level 1 权重 [100, 0, 0]，所有物品均为 common (rarity 0)
	GameData.player_level = 1
	_shop.refresh_shop()
	for slot in GameData.shop_slots:
		if not slot.is_empty():
			assert_eq(slot.rarity, 0, "等级 1 时所有槽位应为稀有度 0")

func test_refresh_shop_type_is_weapon_or_tower() -> void:
	_shop.refresh_shop()
	for slot in GameData.shop_slots:
		if not slot.is_empty():
			assert_true(slot.type in ["weapon", "tower"], "槽位 type 应为 weapon 或 tower")

# ===== 首次刷新保证推荐物品 =====

func test_first_shop_has_recommended_weapon() -> void:
	GameData._recommended_weapon = "rifle"
	GameData._recommended_tower = "pea_shooter"
	_shop.refresh_shop(true)
	var ids: Array[String] = []
	for slot in GameData.shop_slots:
		if not slot.is_empty():
			ids.append(slot.id)
	assert_true("rifle" in ids, "首次商店应包含推荐武器 rifle")

func test_first_shop_has_recommended_tower() -> void:
	GameData._recommended_weapon = "rifle"
	GameData._recommended_tower = "pea_shooter"
	_shop.refresh_shop(true)
	var ids: Array[String] = []
	for slot in GameData.shop_slots:
		if not slot.is_empty():
			ids.append(slot.id)
	assert_true("pea_shooter" in ids, "首次商店应包含推荐塔 pea_shooter")

func test_first_shop_recommended_weapon_is_first_slot() -> void:
	GameData._recommended_weapon = "rifle"
	GameData._recommended_tower = "pea_shooter"
	_shop.refresh_shop(true)
	assert_eq(GameData.shop_slots[0].id, "rifle", "首次商店第 0 槽为推荐武器")

func test_first_shop_recommended_tower_is_second_slot() -> void:
	GameData._recommended_weapon = "rifle"
	GameData._recommended_tower = "pea_shooter"
	_shop.refresh_shop(true)
	assert_eq(GameData.shop_slots[1].id, "pea_shooter", "首次商店第 1 槽为推荐塔")

# ===== buy_item =====

func test_buy_item_deducts_coins() -> void:
	GameData.coins = 50
	_shop.refresh_shop()
	var slot: Dictionary = GameData.shop_slots[0]
	if slot.is_empty():
		pass_test("槽位为空，跳过测试")
		return
	var cost: int = slot.cost
	_shop.buy_item(0)
	assert_eq(GameData.coins, 50 - cost, "购买后金币应减少 cost")

func test_buy_item_adds_to_bag() -> void:
	_shop.refresh_shop()
	var slot: Dictionary = GameData.shop_slots[0]
	if slot.is_empty():
		pass_test("槽位为空，跳过测试")
		return
	var expected_id: String = slot.id
	_shop.buy_item(0)
	assert_eq(GameData.bag.size(), 1, "购买后背包应有 1 个物品")
	assert_eq(GameData.bag[0].id, expected_id, "背包物品 id 应匹配槽位")
	assert_eq(GameData.bag[0].level, 1, "新购买物品应为 level 1")

func test_buy_item_clears_slot() -> void:
	_shop.refresh_shop()
	if GameData.shop_slots[0].is_empty():
		pass_test("槽位为空，跳过测试")
		return
	_shop.buy_item(0)
	assert_true(GameData.shop_slots[0].is_empty(), "购买后槽位应被清空（空字典）")

func test_buy_item_fails_insufficient_coins() -> void:
	_shop.refresh_shop()
	var slot: Dictionary = GameData.shop_slots[0]
	if slot.is_empty():
		pass_test("槽位为空，跳过测试")
		return
	GameData.coins = 0
	var result: bool = _shop.buy_item(0)
	assert_false(result, "金币不足时购买应失败")
	assert_eq(GameData.bag.size(), 0, "购买失败后背包应为空")
	assert_false(GameData.shop_slots[0].is_empty(), "购买失败后槽位应保留")

func test_buy_item_fails_when_bag_full() -> void:
	var config: ShopConfig = GameConfig.shop_config
	for idx in range(config.bag_capacity):
		GameData.bag.append({id = "rifle", type = "weapon", level = 1})
	_shop.refresh_shop()
	if GameData.shop_slots[0].is_empty():
		pass_test("槽位为空，跳过测试")
		return
	GameData.coins = 9999
	var result: bool = _shop.buy_item(0)
	assert_false(result, "背包满时购买应失败")
	assert_eq(GameData.bag.size(), config.bag_capacity, "背包满时购买失败，物品数不变")

func test_buy_item_fails_invalid_index() -> void:
	_shop.refresh_shop()
	var result: bool = _shop.buy_item(99)
	assert_false(result, "无效索引购买应失败")

func test_buy_item_fails_empty_slot() -> void:
	GameData.shop_slots = [{}, {}, {}, {}]
	var result: bool = _shop.buy_item(0)
	assert_false(result, "空槽位购买应失败")

func test_buy_item_returns_true_on_success() -> void:
	GameData.coins = 9999
	_shop.refresh_shop()
	if GameData.shop_slots[0].is_empty():
		pass_test("槽位为空，跳过测试")
		return
	var result: bool = _shop.buy_item(0)
	assert_true(result, "购买成功应返回 true")

# ===== buy_item 触发合成 =====

func test_buy_item_triggers_merge_when_3_of_same() -> void:
	# 背包中已有同 ID Lv1 物品 x2，再购买第 3 个触发合成 → 变成 Lv2
	GameData.coins = 9999
	GameData.bag.append({id = "rifle", type = "weapon", level = 1})
	GameData.bag.append({id = "rifle", type = "weapon", level = 1})
	# 手动设置商店槽位为 rifle Lv1
	GameData.shop_slots = [
		{id = "rifle", type = "weapon", rarity = 0, cost = 3},
		{}, {}, {}
	]
	_shop.buy_item(0)
	# 3 个 rifle Lv1 → 合成为 1 个 rifle Lv2
	var lv2_count: int = 0
	for item in GameData.bag:
		if item.id == "rifle" and item.level == 2:
			lv2_count += 1
	assert_eq(lv2_count, 1, "3 个同 ID Lv1 购买后应合成为 1 个 Lv2")

# ===== manual_refresh =====

func test_manual_refresh_costs_2_coins() -> void:
	GameData.coins = 50
	var config: ShopConfig = GameConfig.shop_config
	_shop.refresh_shop()
	_shop.manual_refresh()
	assert_eq(GameData.coins, 50 - config.refresh_cost, "手动刷新应扣除 refresh_cost 金币")

func test_manual_refresh_returns_true_on_success() -> void:
	GameData.coins = 50
	_shop.refresh_shop()
	var result: bool = _shop.manual_refresh()
	assert_true(result, "金币充足时手动刷新应返回 true")

func test_manual_refresh_fails_insufficient_coins() -> void:
	GameData.coins = 1
	var config: ShopConfig = GameConfig.shop_config
	# 确保金币不足 refresh_cost
	GameData.coins = config.refresh_cost - 1
	_shop.refresh_shop()
	var result: bool = _shop.manual_refresh()
	assert_false(result, "金币不足时手动刷新应返回 false")

func test_manual_refresh_does_not_deduct_on_failure() -> void:
	var config: ShopConfig = GameConfig.shop_config
	GameData.coins = config.refresh_cost - 1
	_shop.refresh_shop()
	var coins_before: int = GameData.coins
	_shop.manual_refresh()
	assert_eq(GameData.coins, coins_before, "手动刷新失败时不应扣除金币")

func test_manual_refresh_generates_new_slots() -> void:
	GameData.coins = 50
	_shop.refresh_shop()
	_shop.manual_refresh()
	assert_eq(GameData.shop_slots.size(), 4, "手动刷新后应有 4 个槽位")

# ===== 槽位费用匹配稀有度 =====

func test_slot_cost_matches_rarity_config() -> void:
	var config: ShopConfig = GameConfig.shop_config
	_shop.refresh_shop()
	for slot in GameData.shop_slots:
		if not slot.is_empty():
			var expected_cost: int = config.cost_by_rarity[slot.rarity]
			assert_eq(slot.cost, expected_cost,
				"槽位费用应与稀有度对应的 cost_by_rarity 一致 (rarity=%d)" % slot.rarity)
