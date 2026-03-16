extends GutTest

var config: ShopConfig

func before_each() -> void:
	config = ShopConfig.new()

func test_default_values() -> void:
	assert_eq(config.slot_count, 4)
	assert_eq(config.refresh_cost, 2)

func test_item_cost() -> void:
	assert_eq(config.item_cost, 3)

func test_level_up_costs() -> void:
	assert_eq(config.level_up_costs[0], 4)
	assert_eq(config.level_up_costs[5], 36)

func test_population_per_level() -> void:
	assert_eq(config.population_per_level[0], 2)
	assert_eq(config.population_per_level[6], 8)
