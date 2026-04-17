extends GutTest

func before_each() -> void:
	var pool: Array[PerkData] = []
	var categories := [
		PerkData.Category.RANGER_GUST,
		PerkData.Category.RANGER_RAIN,
		PerkData.Category.RANGER_MARK,
		PerkData.Category.RANGER_UTILITY,
	]
	for cat in categories:
		for i in range(3):
			var p := PerkData.new()
			p.id = "cat%d_perk%d" % [cat, i]
			p.display_name = p.id
			p.category = cat
			p.max_level = 2
			p.effect_type = PerkData.EffectType.HP_PERCENT
			p.effect_value = 0.05
			pool.append(p)
	PerkManager.set_pool_for_test(pool)
	PerkManager.reset()

func after_all() -> void:
	PerkManager.reset()

func test_draw_three_spans_three_categories():
	var offer: Array = PerkManager.draw_three_for_test()
	assert_eq(offer.size(), 3, "应抽 3 个")
	var cats: Array = []
	for p in offer:
		assert_false(p.category in cats, "抽的 perk 应来自不同 category")
		cats.append(p.category)

func test_max_level_filters_exhausted_perks():
	for p in PerkManager.get_pool_for_test():
		if p.category == PerkData.Category.RANGER_GUST:
			PerkManager.force_level_for_test(p.id, p.max_level)
	var offer: Array = PerkManager.draw_three_for_test()
	for p in offer:
		assert_ne(p.category, PerkData.Category.RANGER_GUST, "满级类别不应被抽到")

func test_reset_clears_perk_levels():
	for p in PerkManager.get_pool_for_test():
		PerkManager.force_level_for_test(p.id, 1)
	PerkManager.reset()
	for p in PerkManager.get_pool_for_test():
		assert_eq(PerkManager.get_perk_level(p.id), 0, "reset 后等级应为 0")

func test_all_exhausted_emits_no_perk_available():
	for p in PerkManager.get_pool_for_test():
		PerkManager.force_level_for_test(p.id, p.max_level)
	watch_signals(EventBus)
	PerkManager.trigger_offer_for_test()
	assert_signal_emitted(EventBus, "no_perk_available")

func test_select_perk_increments_level():
	PerkManager.trigger_offer_for_test()
	var offer: Array = PerkManager.get_current_offer()
	if offer.is_empty():
		pending("无 offer")
		return
	var picked: PerkData = offer[0]
	var old_level: int = PerkManager.get_perk_level(picked.id)
	PerkManager.select_perk(picked.id)
	assert_eq(PerkManager.get_perk_level(picked.id), old_level + 1)

func test_get_perk_level_default_zero():
	assert_eq(PerkManager.get_perk_level("nonexistent_perk"), 0)
