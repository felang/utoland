extends GutTest

var manager: Node

func before_each():
	manager = preload("res://scripts/systems/shop_manager.gd").new()
	add_child_autofree(manager)

func test_rarity_weights_early_waves():
	var weights: Dictionary = manager._get_rarity_weights(2)
	assert_eq(weights["common"], 100)
	assert_eq(weights.get("rare", 0), 0)
	assert_eq(weights.get("epic", 0), 0)

func test_rarity_weights_mid_waves():
	var weights: Dictionary = manager._get_rarity_weights(5)
	assert_gt(weights.get("rare", 0), 0)
	assert_eq(weights.get("epic", 0), 0)

func test_rarity_weights_final_wave():
	var weights: Dictionary = manager._get_rarity_weights(10)
	assert_gt(weights.get("epic", 0), 0)

func test_affinity_discount_applied():
	GameData.current_character = "warrior"
	var item: ShopItemData = GameConfig.items["sharp_bullet"]
	var price: int = manager._calculate_price(item)
	assert_lt(price, item.cost_max)

func test_no_discount_for_non_affinity():
	GameData.current_character = "warrior"
	var item: ShopItemData = GameConfig.items["engineer_manual"]
	var price: int = manager._calculate_price(item)
	assert_gte(price, item.cost_min)
	assert_lte(price, item.cost_max)

func test_can_buy_unlimited_item():
	GameData.purchased_items = {}
	var item: ShopItemData = GameConfig.items["medkit"]
	assert_true(manager._can_buy(item))
	GameData.purchased_items["medkit"] = 99
	assert_true(manager._can_buy(item))  # max_stack = -1，无限

func test_cannot_buy_maxed_item():
	GameData.purchased_items = {"sharp_bullet": 3}
	var item: ShopItemData = GameConfig.items["sharp_bullet"]
	assert_false(manager._can_buy(item))  # max_stack = 3，已买满
