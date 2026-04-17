extends GutTest

func test_default_max_level_is_5():
	var perk: PerkData = PerkData.new()
	assert_eq(perk.max_level, 5, "PerkData.max_level 默认应为 5")

func test_category_default_is_generic():
	var perk: PerkData = PerkData.new()
	assert_eq(perk.category, PerkData.Category.GENERIC, "PerkData.category 默认应为 GENERIC")

func test_category_ranger_values_exist():
	assert_eq(typeof(PerkData.Category.RANGER_GUST), TYPE_INT)
	assert_eq(typeof(PerkData.Category.RANGER_RAIN), TYPE_INT)
	assert_eq(typeof(PerkData.Category.RANGER_MARK), TYPE_INT)
	assert_eq(typeof(PerkData.Category.RANGER_UTILITY), TYPE_INT)
