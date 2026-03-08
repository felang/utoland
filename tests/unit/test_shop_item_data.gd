extends GutTest

func test_shop_item_data_has_required_fields():
	var item := ShopItemData.new()
	# 验证所有必需字段存在（通过 get_property_list 检查）
	var props: Array = item.get_property_list().map(func(p): return p["name"])
	assert_has(props, "id")
	assert_has(props, "display_name")
	assert_has(props, "description")
	assert_has(props, "tags")
	assert_has(props, "rarity")
	assert_has(props, "effect_type")
	assert_has(props, "effect_params")
	assert_has(props, "cost_min")
	assert_has(props, "cost_max")
	assert_has(props, "max_stack")

func test_shop_item_default_values():
	var item := ShopItemData.new()
	assert_eq(item.rarity, Enums.ItemRarity.COMMON)
	assert_eq(item.max_stack, 1)
	assert_eq(item.cost_max, 35)
