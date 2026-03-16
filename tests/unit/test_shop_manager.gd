extends GutTest
## ShopManager 单元测试
## 覆盖：刷新商店、首次刷新保证推荐物品、购买武器/塔、手动刷新

var _shop: ShopManager

func before_each() -> void:
	GameData.reset()
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
		assert_true(slot.has("cost"), "槽位应有 cost")

func test_refresh_shop_all_cost_equals_item_cost() -> void:
	var config: ShopConfig = GameConfig.shop_config
	_shop.refresh_shop()
	for slot in GameData.shop_slots:
		if not slot.is_empty():
			assert_eq(slot.cost, config.item_cost, "所有槽位费用应为 item_cost")

func test_refresh_shop_type_is_weapon_or_tower() -> void:
	_shop.refresh_shop()
	for slot in GameData.shop_slots:
		if not slot.is_empty():
			assert_true(slot.type in ["weapon", "tower"], "槽位 type 应为 weapon 或 tower")

# ===== 首次刷新保证推荐物品 =====

func test_first_shop_has_recommended_weapon() -> void:
	GameData._recommended_weapon = "bow"
	GameData._recommended_tower = "pea_shooter"
	_shop.refresh_shop(true)
	var ids: Array[String] = []
	for slot in GameData.shop_slots:
		if not slot.is_empty():
			ids.append(slot.id)
	assert_true("bow" in ids, "首次商店应包含推荐武器 bow")

func test_first_shop_has_recommended_tower() -> void:
	GameData._recommended_weapon = "bow"
	GameData._recommended_tower = "pea_shooter"
	_shop.refresh_shop(true)
	var ids: Array[String] = []
	for slot in GameData.shop_slots:
		if not slot.is_empty():
			ids.append(slot.id)
	assert_true("pea_shooter" in ids, "首次商店应包含推荐塔 pea_shooter")

func test_first_shop_recommended_weapon_is_first_slot() -> void:
	GameData._recommended_weapon = "bow"
	GameData._recommended_tower = "pea_shooter"
	_shop.refresh_shop(true)
	assert_eq(GameData.shop_slots[0].id, "bow", "首次商店第 0 槽为推荐武器")

func test_first_shop_recommended_tower_is_second_slot() -> void:
	GameData._recommended_weapon = "bow"
	GameData._recommended_tower = "pea_shooter"
	_shop.refresh_shop(true)
	assert_eq(GameData.shop_slots[1].id, "pea_shooter", "首次商店第 1 槽为推荐塔")

# ===== buy_weapon =====

func test_buy_weapon_deducts_coins() -> void:
	GameData.coins = 50
	GameData.shop_slots = [
		{id = "bow", type = "weapon", cost = 3},
		{}, {}, {}
	]
	var coins_before: int = GameData.coins
	_shop.buy_weapon(0)
	assert_eq(GameData.coins, coins_before - 3, "购买武器后金币应减少")

func test_buy_weapon_adds_to_deployed_weapons() -> void:
	GameData.coins = 50
	GameData.shop_slots = [
		{id = "bow", type = "weapon", cost = 3},
		{}, {}, {}
	]
	_shop.buy_weapon(0)
	assert_eq(GameData.deployed_weapons.size(), 1, "购买武器后应出现在 deployed_weapons")
	assert_eq(GameData.deployed_weapons[0].id, "bow")
	assert_eq(GameData.deployed_weapons[0].level, 1)

func test_buy_weapon_clears_slot() -> void:
	GameData.coins = 50
	GameData.shop_slots = [
		{id = "bow", type = "weapon", cost = 3},
		{}, {}, {}
	]
	_shop.buy_weapon(0)
	assert_true(GameData.shop_slots[0].is_empty(), "购买后槽位应被清空")

func test_buy_weapon_fails_insufficient_coins() -> void:
	GameData.coins = 0
	GameData.shop_slots = [
		{id = "bow", type = "weapon", cost = 3},
		{}, {}, {}
	]
	var result: bool = _shop.buy_weapon(0)
	assert_false(result, "金币不足时购买应失败")
	assert_eq(GameData.deployed_weapons.size(), 0)
	assert_false(GameData.shop_slots[0].is_empty(), "购买失败后槽位应保留")

func test_buy_weapon_fails_when_population_full() -> void:
	GameData.player_level = 1
	# 填满种群上限（cap=2）
	GameData.deployed_weapons.append({id = "bow", level = 1})
	GameData.deployed_towers.append({id = "pea_shooter", level = 1, grid_pos = Vector2i(0, 0)})
	GameData.coins = 9999
	GameData.shop_slots = [
		{id = "bow", type = "weapon", cost = 3},
		{}, {}, {}
	]
	var result: bool = _shop.buy_weapon(0)
	assert_false(result, "种群满时购买应失败")

func test_buy_weapon_fails_invalid_index() -> void:
	_shop.refresh_shop()
	var result: bool = _shop.buy_weapon(99)
	assert_false(result, "无效索引购买应失败")

func test_buy_weapon_fails_empty_slot() -> void:
	GameData.shop_slots = [{}, {}, {}, {}]
	var result: bool = _shop.buy_weapon(0)
	assert_false(result, "空槽位购买应失败")

func test_buy_weapon_returns_true_on_success() -> void:
	GameData.coins = 9999
	GameData.shop_slots = [
		{id = "bow", type = "weapon", cost = 3},
		{}, {}, {}
	]
	var result: bool = _shop.buy_weapon(0)
	assert_true(result, "购买成功应返回 true")

# ===== buy_weapon 触发合成 =====

func test_buy_weapon_triggers_merge_when_3_of_same() -> void:
	# deployed 中已有同 ID Lv1 物品 x2，再购买第 3 个触发合成 -> 变成 Lv2
	GameData.coins = 9999
	GameData.player_level = 4  # 人口上限 5，允许第 3 个装备
	GameData.deployed_weapons.append({id = "bow", level = 1})
	GameData.deployed_weapons.append({id = "bow", level = 1})
	GameData.shop_slots = [
		{id = "bow", type = "weapon", cost = 3},
		{}, {}, {}
	]
	_shop.buy_weapon(0)
	# 3 个 bow Lv1 -> 合成为 1 个 bow Lv2
	var lv2_count: int = 0
	for item in GameData.deployed_weapons:
		if item.id == "bow" and item.level == 2:
			lv2_count += 1
	assert_eq(lv2_count, 1, "3 个同 ID Lv1 购买后应合成为 1 个 Lv2")

# ===== confirm_tower_purchase =====

func test_confirm_tower_purchase_success() -> void:
	GameData.coins = 50
	GameData.shop_slots = [
		{id = "pea_shooter", type = "tower", cost = 3},
		{}, {}, {}
	]
	var deploy_id: int = _shop.confirm_tower_purchase(0, Vector2i(5, 5))
	assert_gt(deploy_id, 0, "确认塔购买应返回 > 0 的 deploy_id")
	assert_eq(GameData.deployed_towers.size(), 1)
	assert_eq(GameData.deployed_towers[0].id, "pea_shooter")
	assert_true(GameData.shop_slots[0].is_empty(), "购买后槽位应被清空")

func test_get_tower_slot_returns_slot_data() -> void:
	GameData.coins = 50
	GameData.shop_slots = [
		{id = "pea_shooter", type = "tower", cost = 3},
		{}, {}, {}
	]
	var slot: Dictionary = _shop.get_tower_slot(0)
	assert_false(slot.is_empty())
	assert_eq(slot.id, "pea_shooter")

func test_get_tower_slot_fails_for_weapon() -> void:
	GameData.coins = 50
	GameData.shop_slots = [
		{id = "bow", type = "weapon", cost = 3},
		{}, {}, {}
	]
	var slot: Dictionary = _shop.get_tower_slot(0)
	assert_true(slot.is_empty(), "武器槽位不应被 get_tower_slot 返回")

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

# ===== 槽位费用匹配 item_cost =====

func test_slot_cost_matches_item_cost() -> void:
	var config: ShopConfig = GameConfig.shop_config
	_shop.refresh_shop()
	for slot in GameData.shop_slots:
		if not slot.is_empty():
			assert_eq(slot.cost, config.item_cost,
				"槽位费用应与 item_cost 一致")
