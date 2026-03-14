extends GutTest

var config: ShopConfig

func before_each() -> void:
	config = ShopConfig.new()

func test_default_values() -> void:
	assert_eq(config.slot_count, 4)
	assert_eq(config.refresh_cost, 2)
	assert_eq(config.bag_capacity, 10)

func test_cost_by_rarity() -> void:
	assert_eq(config.cost_by_rarity[0], 3)
	assert_eq(config.cost_by_rarity[1], 5)
	assert_eq(config.cost_by_rarity[2], 8)

func test_level_up_costs() -> void:
	assert_eq(config.level_up_costs[0], 4)
	assert_eq(config.level_up_costs[5], 36)

func test_population_per_level() -> void:
	assert_eq(config.population_per_level[0], 2)
	assert_eq(config.population_per_level[6], 8)

func test_rarity_weights_structure() -> void:
	assert_eq(config.rarity_weights.size(), 7)
	assert_eq(config.rarity_weights[0][0], 100.0)
	assert_eq(config.rarity_weights[0][1], 0.0)
	assert_eq(config.rarity_weights[2][0], 70.0)
	assert_eq(config.rarity_weights[2][1], 30.0)
