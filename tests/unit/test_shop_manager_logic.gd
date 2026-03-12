extends GutTest

var generator: ShopItemGenerator

func before_each():
	generator = ShopItemGenerator.new()

func test_rarity_weights_early_waves():
	var weights: Dictionary = generator.get_rarity_weights(2)
	assert_eq(weights["common"], 100)
	assert_eq(weights.get("rare", 0), 0)
	assert_eq(weights.get("epic", 0), 0)

func test_rarity_weights_mid_waves():
	var weights: Dictionary = generator.get_rarity_weights(5)
	assert_gt(weights.get("rare", 0), 0)
	assert_eq(weights.get("epic", 0), 0)

func test_rarity_weights_final_wave():
	var weights: Dictionary = generator.get_rarity_weights(10)
	assert_gt(weights.get("epic", 0), 0)

func test_affinity_discount_applied():
	GameData.current_character = "dora"
	var item: ShopItemData = GameConfig.items["sharp_bullet"]
	var tags: PackedStringArray = GameConfig.characters["dora"].affinity_tags
	var discount: float = GameConfig.characters["dora"].affinity_discount
	var price: int = generator.calculate_price(item, tags, discount)
	assert_lt(price, item.cost_max)

func test_no_discount_for_non_affinity():
	GameData.current_character = "dora"
	var item: ShopItemData = GameConfig.items["engineer_manual"]
	var tags: PackedStringArray = GameConfig.characters["dora"].affinity_tags
	var discount: float = GameConfig.characters["dora"].affinity_discount
	var price: int = generator.calculate_price(item, tags, discount)
	assert_gte(price, item.cost_min)
	assert_lte(price, item.cost_max)

func test_can_buy_unlimited_item():
	GameData.purchased_items = {}
	var item: ShopItemData = GameConfig.items["medkit"]
	assert_true(generator.can_buy(item))
	GameData.purchased_items["medkit"] = 99
	assert_true(generator.can_buy(item))  # max_stack = -1，无限

func test_cannot_buy_maxed_item():
	GameData.purchased_items = {"sharp_bullet": 3}
	var item: ShopItemData = GameConfig.items["sharp_bullet"]
	assert_false(generator.can_buy(item))  # max_stack = 3，已买满

func test_tower_effect_items_not_filtered():
	var result := generator.generate_items(
		5, PackedStringArray(), 0.0,
		[false, false, false, false], [], [])
	var all_items: Array = GameConfig.items.values()
	var tower_items: Array = all_items.filter(func(it: ShopItemData) -> bool:
		return it.effect_type in [
			Enums.ItemEffect.TOWER_STAT,
			Enums.ItemEffect.TOWER_LINK,
			Enums.ItemEffect.WAVE_HEAL_TOWERS,
			Enums.ItemEffect.TOWER_REGEN,
			Enums.ItemEffect.SYMBIOSIS,
			Enums.ItemEffect.WAR_MACHINE,
		])
	assert_gt(tower_items.size(), 0, "GameConfig 应有塔相关物品")
