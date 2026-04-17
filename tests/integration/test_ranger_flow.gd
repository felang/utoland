extends GutTest

func before_each() -> void:
	PlayerState.init_character("ranger")
	PlayerProgression.reset()
	InventoryManager.reset()
	PerkManager.refresh_pool_for_current_character()
	PerkManager.reset()

func test_ranger_loads_with_18_perks():
	var char_data: CharacterData = GameConfig.characters.get("ranger")
	assert_not_null(char_data, "ranger CharacterData 应存在")
	assert_eq(char_data.perk_pool.size(), 18, "游侠应有 18 个专属 perk")
	assert_eq(char_data.ability_scenes.size(), 4, "游侠应有 4 个能力场景")
	assert_not_null(char_data.exp_config, "游侠应有专属 ExpConfig")

func test_ranger_perk_pool_has_four_categories():
	var char_data: CharacterData = GameConfig.characters.get("ranger")
	var categories: Dictionary = {}
	for p in char_data.perk_pool:
		categories[p.category] = true
	assert_true(categories.has(PerkData.Category.RANGER_GUST), "应有 RANGER_GUST")
	assert_true(categories.has(PerkData.Category.RANGER_RAIN), "应有 RANGER_RAIN")
	assert_true(categories.has(PerkData.Category.RANGER_MARK), "应有 RANGER_MARK")
	assert_true(categories.has(PerkData.Category.RANGER_UTILITY), "应有 RANGER_UTILITY")

func test_levelup_offers_three_from_different_categories():
	PerkManager.refresh_pool_for_current_character()
	PerkManager.trigger_offer_for_test()
	var offer: Array = PerkManager.get_current_offer()
	assert_eq(offer.size(), 3, "应 offer 3 个 perk")
	var cats: Array = []
	for p in offer:
		assert_false(p.category in cats, "每个 perk 应来自不同 category")
		cats.append(p.category)

func test_select_perk_increments_level():
	PerkManager.refresh_pool_for_current_character()
	PerkManager.trigger_offer_for_test()
	var offer: Array = PerkManager.get_current_offer()
	if offer.is_empty():
		pending("无 perk offer")
		return
	var picked: PerkData = offer[0]
	var old_level: int = PerkManager.get_perk_level(picked.id)
	PerkManager.select_perk(picked.id)
	assert_eq(PerkManager.get_perk_level(picked.id), old_level + 1)

func test_full_exhaust_emits_no_perk_available():
	PerkManager.refresh_pool_for_current_character()
	var char_data: CharacterData = GameConfig.characters.get("ranger")
	for p in char_data.perk_pool:
		PerkManager.force_level_for_test(p.id, p.max_level)
	watch_signals(EventBus)
	PerkManager.trigger_offer_for_test()
	assert_signal_emitted(EventBus, "no_perk_available")

func test_tower_cost_progression():
	InventoryManager.coins = 1000
	var cost_0: int = InventoryManager.calc_tower_buy_cost("pea_shooter")
	InventoryManager.deployed_towers.append({id = "pea_shooter", level = 1, grid_pos = Vector2i(0,0), deploy_id = 1})
	var cost_1: int = InventoryManager.calc_tower_buy_cost("pea_shooter")
	assert_gt(cost_1, cost_0, "价格应递增")

func test_exp_config_uses_ranger_config():
	var exp_for_2: int = PlayerProgression.exp_for_level(2)
	var char_data: CharacterData = GameConfig.characters.get("ranger")
	var expected: int = int(floor(char_data.exp_config.base_exp * pow(2, char_data.exp_config.exp_exponent)))
	assert_eq(exp_for_2, expected, "应使用游侠专属 ExpConfig")
